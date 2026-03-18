"""scheduler_trigger — EventBridge Scheduler → API 서버 /reports/summary 브릿지

EventBridge Scheduler가 스케줄 시각에 이 Lambda를 호출.
VPC 내부 API 서버에 POST /reports/summary 를 전달하여 보고서 생성 payload를 만들게 함.

환경변수:
    API_INTERNAL_URL   : API 서버 K8s 서비스 URL (예: http://api-service.dndn-api.svc.cluster.local)
    INTERNAL_API_KEY   : 내부 인증 공유 시크릿 (API 서버의 X-Internal-Key 헤더 검증용)
"""

import json
import os
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

API_INTERNAL_URL = os.environ["API_INTERNAL_URL"].rstrip("/")
INTERNAL_API_KEY = os.environ["INTERNAL_API_KEY"]


def _compute_date_range(include_range: bool) -> tuple[str, str]:
    """includeRange 기준으로 수집 기간(UTC ISO 8601) 계산."""
    now = datetime.now(timezone.utc)
    delta = timedelta(days=7) if include_range else timedelta(hours=24)
    return (now - delta).isoformat(), now.isoformat()


def handler(event, context):
    workspace_id = event["workspaceId"]
    title = event["title"]
    include_range = event.get("includeRange", True)

    start_date, end_date = _compute_date_range(include_range)

    payload = json.dumps({
        "title": title,
        "startDate": start_date,
        "endDate": end_date,
    }).encode("utf-8")

    url = f"{API_INTERNAL_URL}/reports/summary?workspaceId={workspace_id}"
    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "X-Internal-Key": INTERNAL_API_KEY,
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return {"statusCode": resp.status, "body": resp.read().decode("utf-8")}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        raise RuntimeError(f"API 호출 실패 [{e.code}]: {body}") from e
