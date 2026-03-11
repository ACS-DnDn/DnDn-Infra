"""
health_enricher.py
────────────────────────────────────────────────────────────────
AWS Health Event Enricher Lambda

트리거: EventBridge (source: aws.health, detail-type: AWS Health Event)
동작:
  1. AWS Health 이벤트 수신 (EventBridge detail)
  2. event_key 매핑 (ah-ec2-maint, ah-rds-hw 등)
  3. 워크스페이스 이벤트 설정 조회 → 토글 OFF면 조기 종료
  4. describe_event_details → 이벤트 상세 설명(latestDescription) 조회
  5. describe_affected_entities → 영향받는 리소스 목록 조회
  6. contracts/canonical_model.schema.json 포맷으로 변환 → S3 저장
  7. 보고서 생성 SQS 트리거

출력:
  - meta              : run_id, account_id, regions, time_range, collector, evidence, trigger
  - collection_status : cloudtrail NA/NO_DATA (Health 이벤트는 사용자 행위 없음)
  - events[]          : [] (빈 배열 고정)
  - resources[]       : resource_group, extensions.health_event에 Health 데이터 포함

NOTE:
  - AWS Health API는 us-east-1에서만 호출 가능.
  - Lambda 배포 리전도 us-east-1 권장.

환경 변수:
  OUTPUT_BUCKET    - enriched 결과를 저장할 S3 버킷 이름 (없으면 S3 저장 생략)
  DB_HOST / DB_PORT / DB_NAME / DB_USER / DB_PASSWORD  - 이벤트 설정 DB
  REPORT_QUEUE_URL - 보고서 생성 SQS Queue URL
"""

import json
import logging
import os
import uuid
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from typing import Any

import boto3

from event_router import get_workspace_id, is_event_enabled, trigger_report, get_customer_session

logger = logging.getLogger()
logger.setLevel(logging.INFO)

SCHEMA_VERSION    = "0.1.0"
COLLECTOR_NAME    = "dndn-health-enricher"
COLLECTOR_VERSION = "1.1.0"

# ── 고객 계정 세션 (invocation 단위로 설정) ───────────────────────────
_session = None   # handler()에서 AssumeRole 결과를 저장


def _client(service: str, **kwargs):
    """고객 계정 세션이 있으면 고객 컨텍스트, 없으면 플랫폼 계정 fallback."""
    return (_session or boto3).client(service, **kwargs)

# AWS Health API는 us-east-1 고정
HEALTH_REGION = "us-east-1"

# AWS 서비스명 → AWS Config 리소스 타입 기본 매핑
SERVICE_TO_CONFIG_TYPE: dict[str, str] = {
    "EKS":                  "AWS::EKS::Cluster",
    "EC2":                  "AWS::EC2::Instance",
    "RDS":                  "AWS::RDS::DBInstance",
    "LAMBDA":               "AWS::Lambda::Function",
    "ACM":                  "AWS::ACM::Certificate",
    "S3":                   "AWS::S3::Bucket",
    "IAM":                  "AWS::IAM::Role",
    "ELASTICLOADBALANCING": "AWS::ElasticLoadBalancingV2::LoadBalancer",
}

# entity ARN의 서비스 파트 → AWS Config 리소스 타입
ARN_SERVICE_TO_CONFIG_TYPE: dict[str, str] = {
    "eks":                  "AWS::EKS::Cluster",
    "ec2":                  "AWS::EC2::Instance",
    "rds":                  "AWS::RDS::DBInstance",
    "lambda":               "AWS::Lambda::Function",
    "acm":                  "AWS::ACM::Certificate",
    "s3":                   "AWS::S3::Bucket",
    "iam":                  "AWS::IAM::Role",
    "elasticloadbalancing": "AWS::ElasticLoadBalancingV2::LoadBalancer",
}


# ── event_key 매핑 ────────────────────────────────────────────────

# eventTypeCode 정확 매핑
# 참고: https://docs.aws.amazon.com/health/latest/ug/aws-health-event-types.html
EXACT_TYPE_MAP: dict[str, str] = {
    # EC2 예정 유지보수
    "AWS_EC2_INSTANCE_SCHEDULED_MAINTENANCE":            "ah-ec2-maint",
    "AWS_EC2_INSTANCE_REBOOT_MAINTENANCE_SCHEDULED":     "ah-ec2-maint",
    "AWS_EC2_PERSISTENT_INSTANCE_RETIREMENT":            "ah-ec2-maint",
    "AWS_EC2_INSTANCE_STORE_DRIVE_PERFORMANCE_DEGRADED": "ah-ec2-maint",
    # RDS 예정 유지보수
    "AWS_RDS_MAINTENANCE_SCHEDULED":                     "ah-rds-maint",
    "AWS_RDS_OPERATING_SYSTEM_UPGRADE_SCHEDULED":        "ah-rds-maint",
    "AWS_RDS_CERTIFICATE_ROTATION_SCHEDULED":            "ah-rds-maint",
    "AWS_RDS_MAJOR_VERSION_UPGRADE_REQUIRED":            "ah-rds-maint",
    # EC2 Retirement
    "AWS_EC2_INSTANCE_RETIREMENT_SCHEDULED":             "ah-ec2-retire",
    "AWS_EC2_DEDICATED_HOST_RETIREMENT_SCHEDULED":       "ah-ec2-retire",
    # EBS 이슈
    "AWS_EBS_VOLUME_LOST":                               "ah-ebs-issue",
    "AWS_EBS_DEGRADED_EBS_VOLUME":                       "ah-ebs-issue",
    "AWS_EBS_POTENTIAL_DATA_INCONSISTENCY":              "ah-ebs-issue",
    # RDS 하드웨어 이슈
    "AWS_RDS_HARDWARE_MAINTENANCE_SCHEDULED":            "ah-rds-hw",
    "AWS_RDS_STORAGE_FAILURE":                           "ah-rds-hw",
    "AWS_RDS_FAILOVER_COMPLETED":                        "ah-rds-hw",
    "AWS_RDS_INSTANCE_PATCHING_MAINTENANCE_SCHEDULED":   "ah-rds-hw",
    # ACM 인증서 만료
    "AWS_ACM_RENEWAL_STATE_CHANGE":                      "ah-cert-expire",
    "AWS_ACMPCA_CERTIFICATE_EXPIRY":                     "ah-cert-expire",
    # 계정 Abuse
    "AWS_RISK_CREDENTIALS_EXPOSED":                      "ah-abuse",
    "AWS_ABUSE_DOS_REPORT":                              "ah-abuse",
    "AWS_ABUSE_BITCOIN_REPORT":                          "ah-abuse",
    "AWS_ABUSE_SPAM_REPORT":                             "ah-abuse",
}

# service + scheduledChange → ah-other-maint
OTHER_MAINT_SERVICES = {"EBS", "ELASTICLOADBALANCING", "ELASTICACHE", "REDSHIFT"}


def _map_health_event_to_key(detail: dict) -> str | None:
    """Health 이벤트 detail → event_key. 매핑 실패 시 None."""
    type_code = detail.get("eventTypeCode", "")
    service   = detail.get("service", "").upper()
    category  = detail.get("eventTypeCategory", "")

    if type_code in EXACT_TYPE_MAP:
        return EXACT_TYPE_MAP[type_code]

    if category == "scheduledChange" and service in OTHER_MAINT_SERVICES:
        return "ah-other-maint"

    if category == "issue":
        return "ah-service-event"

    logger.warning("Health event 미매핑: code=%s, service=%s, category=%s",
                   type_code, service, category)
    return None


# ── 핸들러 ───────────────────────────────────────────────────────

def handler(event: dict, context: Any) -> dict:
    """EventBridge → Lambda 진입점."""
    global _session
    detail    = event.get("detail", {})
    event_arn = detail.get("eventArn", "")

    if not event_arn:
        logger.warning("eventArn not found in event detail")
        return {"statusCode": 400, "body": "No eventArn in detail"}

    # 토글 확인
    event_key  = _map_health_event_to_key(detail)
    account_id = event.get("account", "")
    _session   = get_customer_session(account_id) if account_id else None
    if event_key and account_id:
        workspace_id = get_workspace_id(account_id)
        if workspace_id and not is_event_enabled(workspace_id, event_key):
            logger.info("이벤트 토글 OFF: workspace=%s, key=%s", workspace_id, event_key)
            return {"statusCode": 200, "result": "disabled"}
    else:
        workspace_id = None

    run_id = str(uuid.uuid4())
    now    = datetime.now(timezone.utc)

    logger.info("Processing Health event: %s  run_id=%s  key=%s", event_arn, run_id, event_key)

    # EventBridge detail.eventDescription → API 실패 시 fallback으로 사용
    detail_desc_fallback = _extract_detail_description(detail)

    # AWS Health API 호출 (한국어 우선)
    event_detail, description = _describe_event(event_arn)
    if not description:
        description = detail_desc_fallback

    entities = _describe_affected_entities(event_arn)

    # S3 경로 계산
    event_id_short = event_arn.split("/")[-1]
    date_prefix    = now.strftime("%Y/%m/%d")
    bucket         = os.environ.get("OUTPUT_BUCKET", "")
    raw_uri        = f"s3://{bucket}/raw-health-events/{date_prefix}/{event_id_short}.json"      if bucket else "s3://not-configured/raw/"
    normalized_uri = f"s3://{bucket}/enriched-health-events/{date_prefix}/{event_id_short}.json" if bucket else "s3://not-configured/normalized/"

    # canonical model 조립
    canonical = _build_canonical(
        raw_event=event,
        detail=detail,
        event_detail=event_detail,
        description=description,
        entities=entities,
        run_id=run_id,
        now=now,
        raw_uri=raw_uri,
        normalized_uri=normalized_uri,
    )

    # S3 저장
    if bucket:
        raw_payload = {
            "eventbridge_event": event,
            "event_detail":      event_detail,
            "entities":          entities,
        }
        _save_to_s3(raw_payload, bucket, f"raw-health-events/{date_prefix}/{event_id_short}.json",      "raw health event")
        _save_to_s3(canonical,   bucket, f"enriched-health-events/{date_prefix}/{event_id_short}.json", "canonical model")

    # 보고서 생성 트리거
    if event_key and workspace_id:
        affected = [e.get("entityValue") for e in entities]
        trigger_report(
            workspace_id=workspace_id,
            event_key=event_key,
            source="health",
            payload={
                "event_type_code":   detail.get("eventTypeCode"),
                "service":           detail.get("service"),
                "event_category":    detail.get("eventTypeCategory"),
                "status_code":       detail.get("statusCode"),
                "event_region":      detail.get("eventRegion"),
                "start_time":        detail.get("startTime"),
                "end_time":          detail.get("endTime"),
                "affected_entities": affected,
                "account_id":        account_id,
                "canonical_uri":     normalized_uri,
            },
        )

    return {
        "statusCode": 200,
        "body": json.dumps(canonical, ensure_ascii=False, default=str),
    }


# ── EventBridge detail 유틸 ──────────────────────────────────────

def _extract_detail_description(detail: dict) -> str:
    """
    EventBridge detail.eventDescription 에서 latestDescription 추출.
    한국어(ko / ko_KR) 우선, 없으면 첫 번째 항목.
    AWS Health API 호출 실패 시 fallback으로 사용.
    """
    descriptions = detail.get("eventDescription", [])
    if not descriptions:
        return ""
    for item in descriptions:
        if str(item.get("language", "")).startswith("ko"):
            return item.get("latestDescription", "")
    return descriptions[0].get("latestDescription", "")


# ── AWS Health API 호출 ───────────────────────────────────────────

def _describe_event(event_arn: str) -> tuple[dict, str]:
    """
    describe_event_details 호출.
    반환: (event 메타 dict, latestDescription 문자열)
    """
    try:
        health = _client("health", region_name=HEALTH_REGION)
        resp   = health.describe_event_details(
            eventArns=[event_arn],
            locale="ko",
        )
        items = resp.get("successfulSet", [])
        if not items:
            logger.warning("No event detail returned for: %s", event_arn)
            return {}, ""
        item = items[0]
        desc = item.get("eventDescription", {}).get("latestDescription", "")
        return item.get("event", {}), desc
    except Exception as e:
        logger.warning("Health DescribeEventDetails failed: %s", e)
        return {}, ""


def _describe_affected_entities(event_arn: str) -> list[dict]:
    """
    describe_affected_entities 호출.
    반환: entities 목록 (entityArn, entityValue, statusCode 포함)
    """
    try:
        health = _client("health", region_name=HEALTH_REGION)
        resp   = health.describe_affected_entities(
            filter={"eventArns": [event_arn]}
        )
        return resp.get("entities", [])
    except Exception as e:
        logger.warning("Health DescribeAffectedEntities failed: %s", e)
        return []


# ── canonical model 조립 ──────────────────────────────────────────

def _build_canonical(
    raw_event:      dict,
    detail:         dict,
    event_detail:   dict,
    description:    str,
    entities:       list[dict],
    run_id:         str,
    now:            datetime,
    raw_uri:        str,
    normalized_uri: str,
) -> dict:
    """AWS Health 이벤트 + API 조회 결과 → canonical_model.schema.json 포맷."""

    account_id = raw_event.get("account", "")

    region = (
        detail.get("eventRegion")
        or event_detail.get("region")
        or raw_event.get("region", "ap-northeast-2")
    )

    service         = detail.get("service",           event_detail.get("service", ""))
    event_type_code = detail.get("eventTypeCode",     event_detail.get("eventTypeCode", ""))
    event_type_cat  = detail.get("eventTypeCategory", event_detail.get("eventTypeCategory", ""))
    status_code     = detail.get("statusCode",        event_detail.get("statusCode", "open"))
    event_arn       = detail.get("eventArn",          event_detail.get("arn", ""))

    start_time = _parse_time(detail.get("startTime") or event_detail.get("startTime"))
    end_time   = _parse_time(detail.get("endTime")   or event_detail.get("endTime"))

    time_start = start_time or now.isoformat()
    time_end   = end_time   or now.isoformat()

    resource_groups = _build_resource_groups(entities, service, account_id, region)

    health_event_ext = {
        "event_arn":             event_arn,
        "event_type_code":       event_type_code,
        "event_type_category":   event_type_cat,
        "status_code":           status_code,
        "start_time":            start_time,
        "end_time":              end_time,
        "description":           description,
        "affected_entity_count": len(entities),
    }

    for rg in resource_groups:
        entity_status = rg.pop("_entity_status", "")
        rg["extensions"] = {
            "health_event": {
                **health_event_ext,
                "entity_status": entity_status,
            }
        }

    return {
        "meta": {
            "schema_version": SCHEMA_VERSION,
            "type":           "EVENT",
            "run_id":         run_id,
            "account_id":     account_id,
            "regions":        [region],
            "time_range": {
                "start":    time_start,
                "end":      time_end,
                "timezone": "Asia/Seoul",
            },
            "generated_at": now.isoformat(),
            "collector": {
                "name":    COLLECTOR_NAME,
                "version": COLLECTOR_VERSION,
            },
            "evidence": {
                "raw_prefix_s3_uri":        raw_uri,
                "normalized_prefix_s3_uri": normalized_uri,
            },
            "trigger": {
                "source":      "EVENTBRIDGE",
                "received_at": now.isoformat(),
                "detail_type": "AWS Health Event",
            },
        },
        "collection_status": {
            "assume_role": {"status": "OK"} if _session else {"status": "FAIL", "na_reason": "ASSUME_ROLE_FAILED"},
            "cloudtrail":  {"status": "NA", "na_reason": "NO_DATA"},
            "config":      {"status": "NA", "na_reason": "NOT_SUPPORTED"},
            "normalized":  {"status": "OK"},
        },
        "events":    [],
        "resources": resource_groups,
    }


def _build_resource_groups(
    entities:   list[dict],
    service:    str,
    account_id: str,
    region:     str,
) -> list[dict]:
    """
    describe_affected_entities 결과 → resource_group 목록.
    엔티티가 없으면 서비스명 기반 빈 리소스 1개 생성.
    """
    if not entities:
        config_type = SERVICE_TO_CONFIG_TYPE.get(service, f"AWS::{service}::Unknown")
        return [{
            "_entity_status": "",
            "key":      f"{config_type}/unknown/{region}",
            "resource": {
                "resource_type": config_type,
                "resource_id":   "unknown",
                "arn":           "",
                "account_id":    account_id,
                "region":        region,
            },
            "events":         [],
            "change_summary": {"event_count": 0},
            "config":         {"status": "NA", "na_reason": "NOT_SUPPORTED"},
        }]

    groups = []
    for entity in entities:
        entity_arn    = entity.get("entityArn", "")
        entity_value  = entity.get("entityValue", "")
        entity_status = entity.get("statusCode", "")

        config_type = _resolve_resource_type(entity_arn, service)
        resource_id = entity_value or _extract_id_from_arn(entity_arn)

        groups.append({
            "_entity_status": entity_status,
            "key":      f"{config_type}/{resource_id}/{region}",
            "resource": {
                "resource_type": config_type,
                "resource_id":   resource_id,
                "arn":           entity_arn,
                "account_id":    account_id,
                "region":        region,
            },
            "events":         [],
            "change_summary": {"event_count": 0},
            "config":         {"status": "NA", "na_reason": "NOT_SUPPORTED"},
        })

    return groups


# ── 유틸 ─────────────────────────────────────────────────────────

def _resolve_resource_type(entity_arn: str, service: str) -> str:
    if entity_arn:
        parts = entity_arn.split(":")
        if len(parts) >= 3:
            svc = parts[2].lower()
            if svc in ARN_SERVICE_TO_CONFIG_TYPE:
                return ARN_SERVICE_TO_CONFIG_TYPE[svc]
    return SERVICE_TO_CONFIG_TYPE.get(service, f"AWS::{service}::Unknown")


def _extract_id_from_arn(arn: str) -> str:
    if not arn:
        return "unknown"
    last = arn.split(":")[-1]
    return last.split("/")[-1] or last


def _parse_time(value: Any) -> str:
    """
    datetime 객체 또는 문자열을 ISO 8601 문자열로 변환.
    EventBridge detail의 시각은 RFC 2822 형식("Wed, 01 Mar 2026 00:00:00 GMT")으로 옴.
    """
    if value is None:
        return ""
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, str) and value:
        try:
            return parsedate_to_datetime(value).isoformat()
        except Exception:
            return value
    return ""


# ── S3 저장 ───────────────────────────────────────────────────────

def _save_to_s3(data: dict, bucket: str, key: str, label: str = "") -> None:
    try:
        s3 = boto3.client("s3")
        s3.put_object(
            Bucket=bucket,
            Key=key,
            Body=json.dumps(data, ensure_ascii=False, default=str),
            ContentType="application/json",
        )
        logger.info("Saved %s to s3://%s/%s", label, bucket, key)
    except Exception as e:
        logger.error("S3 PutObject (%s) failed: %s", label, e)
