"""scheduler_trigger — EventBridge Scheduler → API 서버 /reports/summary 브릿지

EventBridge Scheduler가 스케줄 시각에 이 Lambda를 호출.
API 서버에 POST /reports/summary 를 전달하여 보고서 생성 payload를 만들게 함.

환경변수:
    API_INTERNAL_URL   : API 서버 URL (예: https://www.dndn.cloud/api)
    INTERNAL_API_KEY   : 내부 인증 공유 시크릿 (API 서버의 X-Internal-Key 헤더 검증용)
"""

import json
import os
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

API_INTERNAL_URL = os.environ["API_INTERNAL_URL"].rstrip("/")
INTERNAL_API_KEY = os.environ["INTERNAL_API_KEY"]

_PRESET_DELTAS = {
    "daily": timedelta(days=1),
    "weekly": timedelta(days=7),
    "monthly": timedelta(days=30),
}


def _compute_date_range(preset: str) -> tuple[str, str]:
    """preset(daily/weekly/monthly) 기준으로 수집 기간(UTC ISO 8601) 계산."""
    if preset not in _PRESET_DELTAS:
        raise ValueError(f"Unknown preset '{preset}'. Allowed: {list(_PRESET_DELTAS.keys())}")
    now = datetime.now(timezone.utc)
    return (now - _PRESET_DELTAS[preset]).isoformat(), now.isoformat()


def _format_title(title: str, preset: str, end_dt: datetime, include_range: bool) -> str:
    """includeRange가 True이면 제목에 수집 기간을 붙인다."""
    if not include_range:
        return title
    days = _PRESET_DELTAS[preset].days
    start_dt = end_dt - _PRESET_DELTAS[preset]
    fmt = lambda d: f"{d.year % 100:02d}-{d.month:02d}-{d.day:02d}"
    if days == 1:
        return f"{title} {fmt(end_dt)}"
    return f"{title} ({fmt(start_dt)} ~ {fmt(end_dt)})"


def handler(event, context):
    workspace_id = event["workspaceId"]
    title = event["title"]
    preset = event.get("preset", "weekly")
    include_range = event.get("includeRange", False)

    start_date, end_date = _compute_date_range(preset)
    end_dt = datetime.fromisoformat(end_date)

    final_title = _format_title(title, preset, end_dt, include_range)

    payload = json.dumps({
        "title": final_title,
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
