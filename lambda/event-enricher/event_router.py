"""
공통 모듈: DB 조회 + 보고서 트리거 + 고객 계정 AssumeRole
두 Lambda(finding_enricher, health_enricher)가 공유한다.

환경변수:
  RDS_SECRET_ARN           Secrets Manager 시크릿 ARN (host/username/password/port/dbname 포함)
  REPORT_QUEUE_URL         SQS Queue URL (보고서 생성 요청 전달)
  CUSTOMER_ROLE_NAME       고객 계정 IAM Role 이름 (기본: DnDnOpsAgentRole)
  ASSUME_ROLE_EXTERNAL_ID  AssumeRole 기본 External ID (고객별 ID는 DB에서 조회)
"""

import json
import logging
import os
from datetime import datetime, timezone
import boto3
import pymysql

logger = logging.getLogger()


# ── Secrets Manager DB 자격증명 조회 (모듈 레벨 캐시) ──────────────────

_db_secret_cache: dict | None = None


def _get_db_credentials() -> dict:
    """RDS_SECRET_ARN으로 Secrets Manager에서 DB 자격증명 조회.
    Lambda 컨테이너 재사용 시 캐시를 통해 API 호출 절감.
    """
    global _db_secret_cache
    if _db_secret_cache is not None:
        return _db_secret_cache

    secret_arn = os.environ["RDS_SECRET_ARN"]
    sm = boto3.client("secretsmanager", region_name=os.environ.get("AWS_REGION", "ap-northeast-2"))
    resp = sm.get_secret_value(SecretId=secret_arn)
    _db_secret_cache = json.loads(resp["SecretString"])
    return _db_secret_cache


# ── DB 연결 ─────────────────────────────────────────────────────────────

def _get_conn():
    creds = _get_db_credentials()
    return pymysql.connect(
        host=creds["host"],
        port=int(creds.get("port", 3306)),
        user=creds["username"],
        password=creds["password"],
        database=creds.get("dbname", "dndn"),
        cursorclass=pymysql.cursors.DictCursor,
        connect_timeout=3,
    )


# ── 워크스페이스 조회 ─────────────────────────────────────────────────────

_workspace_cache: dict[str, str | None] = {}


def get_workspace_id(account_id: str) -> str | None:
    """AWS account_id(12자리) → workspace primary key(id).
    결과 캐시: Lambda 컨테이너 재사용 시 DB 왕복 절감.
    DB 오류 시 캐시하지 않고 예외를 전파한다.
    workspace가 존재하지 않는 경우(None)도 캐시하므로 재조회하지 않는다.
    """
    if account_id in _workspace_cache:
        return _workspace_cache[account_id]

    conn = _get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id FROM workspaces WHERE acct_id = %s LIMIT 1",
                (account_id,),
            )
            row = cur.fetchone()
        result = row["id"] if row else None
    finally:
        conn.close()
    _workspace_cache[account_id] = result
    return result


# ── 이벤트 토글 확인 ───────────────────────────────────────────────────────

def is_event_enabled(workspace_id: str, event_key: str) -> bool:
    """report_settings 테이블의 event_settings JSON 컬럼에서 토글 상태를 반환.

    DB 스키마:
        report_settings.event_settings = JSON
        예: {"sh-malicious-network": true, "ah-ec2-maint": false, ...}

    레코드가 없거나 해당 키가 없으면 기본값 False.
    """
    conn = _get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT event_settings FROM report_settings WHERE workspace_id = %s LIMIT 1",
                (workspace_id,),
            )
            row = cur.fetchone()

        if not row or not row["event_settings"]:
            return False

        settings = row["event_settings"]
        if isinstance(settings, str):
            settings = json.loads(settings)

        return bool(settings.get(event_key, False))
    except Exception:
        logger.exception("is_event_enabled 실패: workspace_id=%s, key=%s", workspace_id, event_key)
        raise
    finally:
        conn.close()


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


def _get_external_id(account_id: str) -> str:
    """고객별 ExternalId를 DB에서 조회. 없으면 환경변수 기본값 사용."""
    default_id = os.environ.get("ASSUME_ROLE_EXTERNAL_ID", "")
    conn = _get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT external_id FROM workspaces WHERE acct_id = %s LIMIT 1",
                (account_id,),
            )
            row = cur.fetchone()
        if row and row.get("external_id"):
            return row["external_id"]
        if default_id:
            return default_id
        raise ValueError(f"ExternalId를 찾을 수 없습니다: account_id={account_id}")
    finally:
        conn.close()


def get_customer_session(account_id: str) -> boto3.Session:
    """고객 계정의 DnDnOpsAgentRole을 AssumeRole → boto3 Session 반환.

    Lambda가 고객 계정 리소스(EC2, RDS, Health 등)에 접근할 때 사용.
    AssumeRole 실패 시 예외를 전파한다 (플랫폼 계정 fallback 방지).
    고객별 ExternalId를 DB에서 조회하여 사용한다.
    """
    if not account_id:
        raise ValueError("account_id가 비어있습니다")

    role_name   = os.environ.get("CUSTOMER_ROLE_NAME", "DnDnOpsAgentRole")
    external_id = _get_external_id(account_id)
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
