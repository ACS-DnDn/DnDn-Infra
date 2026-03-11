"""
공통 모듈: DB 조회 + 보고서 트리거 + 고객 계정 AssumeRole
두 Lambda(finding_enricher, health_enricher)가 공유한다.

환경변수:
  DB_HOST                  RDS MariaDB 호스트
  DB_PORT                  기본 3306
  DB_NAME                  데이터베이스 이름
  DB_USER                  사용자
  DB_PASSWORD              비밀번호 (Secrets Manager ARN도 가능)
  REPORT_QUEUE_URL         SQS Queue URL (보고서 생성 요청 전달)
  CUSTOMER_ROLE_NAME       고객 계정 IAM Role 이름 (기본: DnDnOpsAgentRole)
  ASSUME_ROLE_EXTERNAL_ID  AssumeRole External ID (기본: dndn-ops-agent)
"""

import json
import logging
import os
from datetime import datetime, timezone
import boto3
import pymysql

logger = logging.getLogger()


# ── DB 연결 ─────────────────────────────────────────────────────────────

def _get_conn():
    return pymysql.connect(
        host=os.environ["DB_HOST"],
        port=int(os.environ.get("DB_PORT", 3306)),
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        database=os.environ["DB_NAME"],
        cursorclass=pymysql.cursors.DictCursor,
        connect_timeout=3,
    )


# ── 워크스페이스 조회 ─────────────────────────────────────────────────────

def get_workspace_id(account_id: str) -> str | None:
    """AWS account_id(12자리) → workspace primary key(id).
    결과 캐시: Lambda 컨테이너 재사용 시 DB 왕복 절감.
    DB 오류 시 캐시하지 않고 예외를 전파한다.
    """
    cached = _workspace_cache.get(account_id)
    if cached is not None:
        return cached

    conn = _get_conn()
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM workspaces WHERE acct_id = %s LIMIT 1",
            (account_id,),
        )
        row = cur.fetchone()
    conn.close()
    result = row["id"] if row else None
    _workspace_cache[account_id] = result
    return result


_workspace_cache: dict[str, str | None] = {}


# ── 이벤트 토글 확인 ───────────────────────────────────────────────────────

def is_event_enabled(workspace_id: str, event_key: str) -> bool:
    """report_settings 테이블의 event_settings JSON 컬럼에서 토글 상태를 반환.

    DB 스키마:
        report_settings.event_settings = JSON
        예: {"sh-malicious-network": true, "ah-ec2-maint": false, ...}

    레코드가 없거나 해당 키가 없으면 기본값 False.
    """
    try:
        conn = _get_conn()
        with conn.cursor() as cur:
            cur.execute(
                "SELECT event_settings FROM report_settings WHERE workspace_id = %s LIMIT 1",
                (workspace_id,),
            )
            row = cur.fetchone()
        conn.close()

        if not row or not row["event_settings"]:
            return False

        settings = row["event_settings"]
        if isinstance(settings, str):
            settings = json.loads(settings)

        return bool(settings.get(event_key, False))
    except Exception:
        logger.exception("is_event_enabled 실패: workspace_id=%s, key=%s", workspace_id, event_key)
        return False


# ── 보고서 생성 트리거 ─────────────────────────────────────────────────────

_sqs = boto3.client("sqs", region_name=os.environ.get("AWS_REGION", "ap-northeast-2"))

def trigger_report(
    workspace_id: str,
    event_key: str,
    source: str,        # "securityhub" | "health"
    payload: dict,
) -> None:
    """SQS로 보고서 생성 요청을 전달한다.

    SQS 메시지 구조:
        {
          "type": "event_report",
          "workspace_id": "ws-abc123",
          "event_key": "sh-malicious-network",
          "source": "securityhub",
          "triggered_at": "2026-03-09T12:00:00Z",
          "payload": { ... }   ← 이벤트 원본 데이터 (요약)
        }
    Report 서비스가 이 메시지를 소비하여 AI 보고서를 생성한다.
    """
    queue_url = os.environ.get("REPORT_QUEUE_URL")
    if not queue_url:
        raise RuntimeError("REPORT_QUEUE_URL 환경변수가 설정되지 않았습니다")

    message = {
        "type":         "event_report",
        "workspace_id": workspace_id,
        "event_key":    event_key,
        "source":       source,
        "triggered_at": datetime.now(timezone.utc).isoformat(),
        "payload":      payload,
    }

    try:
        _sqs.send_message(
            QueueUrl=queue_url,
            MessageBody=json.dumps(message, ensure_ascii=False),
            MessageAttributes={
                "event_key": {
                    "DataType":    "String",
                    "StringValue": event_key,
                },
                "workspace_id": {
                    "DataType":    "String",
                    "StringValue": str(workspace_id),
                },
            },
        )
        logger.info("SQS 전송 완료: workspace=%s, key=%s", workspace_id, event_key)
    except Exception:
        logger.exception("SQS 전송 실패: workspace=%s, key=%s", workspace_id, event_key)
        raise


# ── 고객 계정 AssumeRole ─────────────────────────────────────────────────

_sts = boto3.client("sts", region_name=os.environ.get("AWS_REGION", "ap-northeast-2"))


def get_customer_session(account_id: str) -> boto3.Session:
    """고객 계정의 DnDnOpsAgentRole을 AssumeRole → boto3 Session 반환.

    Lambda가 고객 계정 리소스(EC2, RDS, Health 등)에 접근할 때 사용.
    AssumeRole 실패 시 예외를 전파한다 (플랫폼 계정 fallback 방지).
    """
    if not account_id:
        raise ValueError("account_id가 비어있습니다")

    role_name   = os.environ.get("CUSTOMER_ROLE_NAME", "DnDnOpsAgentRole")
    external_id = os.environ.get("ASSUME_ROLE_EXTERNAL_ID", "dndn-ops-agent")
    role_arn    = f"arn:aws:iam::{account_id}:role/{role_name}"

    try:
        resp  = _sts.assume_role(
            RoleArn=role_arn,
            RoleSessionName=f"dndn-enricher-{account_id}",
            ExternalId=external_id,
            DurationSeconds=900,
        )
    except Exception:
        logger.exception("AssumeRole 실패: account_id=%s, role=%s", account_id, role_arn)
        raise

    creds = resp["Credentials"]
    return boto3.Session(
        aws_access_key_id=creds["AccessKeyId"],
        aws_secret_access_key=creds["SecretAccessKey"],
        aws_session_token=creds["SessionToken"],
    )
