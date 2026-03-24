"""
finding_enricher.py
────────────────────────────────────────────────────────────────
SecurityHub Finding Enricher Lambda

트리거: EventBridge (source: aws.securityhub, detail-type: Security Hub Findings - Imported)
동작:
  1. SecurityHub Finding 수신 (batch — findings[] 전체 처리)
  2. event_key 매핑 (sh-* 14개 항목 전체)
  3. 워크스페이스 이벤트 설정 조회 → 토글 OFF면 스킵
  4. 리소스 타입별 데이터 수집 (13개 타입 대응)
  5. FSBP/CIS에 한해 CloudTrail 취약 이벤트 조회
  6. canonical_model.schema.json 포맷 변환 → S3(canonical/) 저장
     S3 PutObject 이벤트 → SQS(s3-event) → Reporter 자동 트리거

수집 전략:
  - ASFF Details 필드 우선 사용 (추가 API 호출 없음)
  - Details에 없는 필드만 AWS API fallback 호출
  - GuardDuty / Access Analyzer / Inspector: CloudTrail 역추적 없음 (NA)
  - FSBP/CIS: 컨트롤별 CloudTrail 취약 이벤트 조회 (best-effort)

환경 변수:
  OUTPUT_BUCKET  - S3 버킷 이름 (없으면 S3 저장 생략)
"""

import json
import logging
import os
import uuid
from datetime import datetime, timezone
from typing import Any

import boto3
from botocore.exceptions import ClientError

from event_router import get_workspace_id, is_event_enabled, get_customer_session

logger = logging.getLogger()
logger.setLevel(logging.INFO)

SCHEMA_VERSION    = "0.1.0"
COLLECTOR_NAME    = "dndn-finding-enricher"
COLLECTOR_VERSION = "1.4.0"

# ── 고객 계정 세션 (invocation 단위로 설정) ───────────────────────────
_session = None   # _process_finding()에서 AssumeRole 결과를 저장


def _client(service: str, **kwargs):
    """고객 계정 세션이 있으면 고객 컨텍스트, 없으면 플랫폼 계정 fallback."""
    return (_session or boto3).client(service, **kwargs)


# ── ASFF 리소스 타입 → AWS Config 리소스 타입 ─────────────────────
ASFF_TO_CONFIG_TYPE: dict[str, str] = {
    "AwsEc2Instance":                   "AWS::EC2::Instance",
    "AwsEc2SecurityGroup":              "AWS::EC2::SecurityGroup",
    "AwsEc2Vpc":                        "AWS::EC2::VPC",
    "AwsEc2NetworkInterface":           "AWS::EC2::NetworkInterface",
    "AwsEc2Subnet":                     "AWS::EC2::Subnet",
    "AwsEbsVolume":                     "AWS::EC2::Volume",
    "AwsElbv2LoadBalancer":             "AWS::ElasticLoadBalancingV2::LoadBalancer",
    "AwsElbLoadBalancer":               "AWS::ElasticLoadBalancing::LoadBalancer",
    "AwsS3Bucket":                      "AWS::S3::Bucket",
    "AwsS3Object":                      "AWS::S3::Object",
    "AwsRdsDbInstance":                 "AWS::RDS::DBInstance",
    "AwsRdsDbCluster":                  "AWS::RDS::DBCluster",
    "AwsDynamoDbTable":                 "AWS::DynamoDB::Table",
    "AwsElastiCacheReplicationGroup":   "AWS::ElastiCache::ReplicationGroup",
    "AwsRedshiftCluster":               "AWS::Redshift::Cluster",
    "AwsElasticsearchDomain":           "AWS::Elasticsearch::Domain",
    "AwsOpenSearchDomain":              "AWS::OpenSearch::Domain",
    "AwsIamAccessKey":                  "AWS::IAM::AccessKey",
    "AwsIamUser":                       "AWS::IAM::User",
    "AwsIamRole":                       "AWS::IAM::Role",
    "AwsIamPolicy":                     "AWS::IAM::ManagedPolicy",
    "AwsIamGroup":                      "AWS::IAM::Group",
    "AwsKmsKey":                        "AWS::KMS::Key",
    "AwsSecretsManagerSecret":          "AWS::SecretsManager::Secret",
    "AwsLambdaFunction":                "AWS::Lambda::Function",
    "AwsEcsCluster":                    "AWS::ECS::Cluster",
    "AwsEcsService":                    "AWS::ECS::Service",
    "AwsEksCluster":                    "AWS::EKS::Cluster",
    "AwsEcrRepository":                 "AWS::ECR::Repository",
    "AwsEcrContainerImage":             "AWS::ECR::Repository",
    "AwsCloudFrontDistribution":        "AWS::CloudFront::Distribution",
    "AwsApiGatewayRestApi":             "AWS::ApiGateway::RestApi",
    "AwsApiGatewayV2Api":               "AWS::ApiGatewayV2::Api",
    "AwsWafWebAcl":                     "AWS::WAF::WebACL",
    "AwsWafv2WebAcl":                   "AWS::WAFv2::WebACL",
    "AwsCloudTrailTrail":               "AWS::CloudTrail::Trail",
    "AwsCloudWatchAlarm":               "AWS::CloudWatch::Alarm",
    "AwsSqsQueue":                      "AWS::SQS::Queue",
    "AwsSnsTopic":                      "AWS::SNS::Topic",
    "AwsCertificateManagerCertificate": "AWS::ACM::Certificate",
    "AwsSsmParameter":                  "AWS::SSM::Parameter",
    "AwsAutoScalingAutoScalingGroup":   "AWS::AutoScaling::AutoScalingGroup",
}


# ── event_key 매핑 ─────────────────────────────────────────────────

GD_TYPE_MAP = [
    ("TTPs/Command and Control/",           "sh-malicious-network"),
    ("TTPs/Initial Access/",                "sh-unauthorized-access"),
    ("TTPs/Credential Access/",             "sh-unauthorized-access"),
    ("TTPs/Privilege Escalation/",          "sh-anomalous-behavior"),
    ("Unusual Behaviors/User/",             "sh-anomalous-behavior"),
    ("Unusual Behaviors/VM/",               "sh-anomalous-behavior"),
    ("TTPs/Discovery/",                     "sh-recon"),
    ("TTPs/Exfiltration/",                  "sh-exfiltration"),
    ("Effects/Data Exfiltration/",          "sh-exfiltration"),
]

FSBP_CONTROL_MAP = [
    (["EC2.2","EC2.13","EC2.18","EC2.19","EC2.21",
      "ELB.","ELBV2.","CloudFront.","APIGateway.","WAF."],          "sh-network"),
    (["S3.","EBS.1","EBS.2","EBS.3","EBS.4",
      "KMS.","ES.","OpenSearch."],                                   "sh-data-protection"),
    (["IAM.","STS.","CIS.1."],                                       "sh-iam"),
    (["CloudTrail.","CloudWatch.","Config.1","EC2.6"],                "sh-logging"),
    (["Lambda.","ECS.","EKS.","ECR."],                               "sh-compute"),
    (["RDS.","DynamoDB.","ElastiCache.","Redshift.","DocumentDB."],  "sh-database"),
]


def _map_finding_to_key(finding: dict) -> str | None:
    product = finding.get("ProductName", "")
    types   = finding.get("Types", [])
    gen_id  = finding.get("GeneratorId", "")

    if product == "GuardDuty":
        for prefix, key in GD_TYPE_MAP:
            if any(t.startswith(prefix) for t in types):
                return key
        logger.warning("GuardDuty finding type 미매핑: %s", types)
        return None

    if product in ("Access Analyzer", "IAM Access Analyzer"):
        if any("External Access" in t for t in types):
            return "sh-external-access"
        if any("Unused" in t for t in types):
            return "sh-unused-access"
        return None

    if product == "Inspector":
        return "sh-vulnerability"

    if product == "Security Hub":
        for prefixes, key in FSBP_CONTROL_MAP:
            if any(p in gen_id for p in prefixes):
                return key
        logger.warning("FSBP/CIS GeneratorId 미매핑: %s", gen_id)
        return None

    return None


# ── 핸들러 ─────────────────────────────────────────────────────────

def handler(event: dict, context: Any) -> dict:
    findings = event.get("detail", {}).get("findings", [])
    if not findings:
        return {"statusCode": 400, "body": "No findings"}

    results = []
    for finding in findings:
        if finding.get("RecordState") != "ACTIVE":
            continue
        if finding.get("Workflow", {}).get("Status") not in ("NEW", "NOTIFIED"):
            continue
        results.append(_process_finding(finding))

    return {"statusCode": 200, "processed": len(results), "results": results}


def _process_finding(finding: dict) -> dict:
    global _session
    event_key  = _map_finding_to_key(finding)
    account_id = finding.get("AwsAccountId", "")
    try:
        _session = get_customer_session(account_id) if account_id else None
    except Exception:
        logger.warning("AssumeRole 실패로 고객 계정 데이터 수집 불가: account_id=%s", account_id)
        _session = None

    workspace_id = get_workspace_id(account_id) if account_id else None
    if event_key and workspace_id:
        if not is_event_enabled(workspace_id, event_key):
            logger.info("토글 OFF: workspace=%s, key=%s", workspace_id, event_key)
            return {"result": "disabled", "key": event_key}

    run_id = str(uuid.uuid4())
    now    = datetime.now(timezone.utc)
    region = finding.get("Region", "ap-northeast-2")

    finding_id     = finding.get("Id", "unknown").split("/")[-1]
    date_prefix    = now.strftime("%Y/%m/%d")
    bucket         = os.environ.get("OUTPUT_BUCKET", "")
    ws_prefix      = workspace_id or "unknown"
    raw_uri        = f"s3://{bucket}/raw/{ws_prefix}/findings/{date_prefix}/{finding_id}.json"       if bucket else "s3://not-configured/raw/"
    normalized_uri = f"s3://{bucket}/canonical/{ws_prefix}/findings/{date_prefix}/{finding_id}.json"  if bucket else "s3://not-configured/canonical/"

    # 공통 수집 (계정 별칭, display name)
    common = _collect_common(finding)

    # FSBP/CIS만 CloudTrail 취약 이벤트 조회
    vulnerable_event = None
    if finding.get("ProductName") == "Security Hub":
        vulnerable_event = _get_vulnerable_event(finding, region)
        if vulnerable_event:
            common["vulnerable_event"] = vulnerable_event
            first_observed = finding.get("FirstObservedAt", "")
            if first_observed:
                common["detection_delay"] = _calc_elapsed(
                    vulnerable_event["event_time"], first_observed
                )

    canonical = _build_canonical(finding, common, run_id, now, raw_uri, normalized_uri)

    if bucket:
        _save_to_s3(finding,   bucket, f"raw/{ws_prefix}/findings/{date_prefix}/{finding_id}.json",       "raw finding")
        _save_to_s3(canonical, bucket, f"canonical/{ws_prefix}/findings/{date_prefix}/{finding_id}.json",  "canonical")
        # S3 PutObject (canonical/) → s3-event SQS → Reporter 자동 트리거

    logger.info("완료: key=%s, run_id=%s", event_key, run_id)
    return {"result": "ok", "key": event_key, "run_id": run_id}


# ── canonical model 조립 ───────────────────────────────────────────

def _build_canonical(
    finding:        dict,
    common:         dict,
    run_id:         str,
    now:            datetime,
    raw_uri:        str,
    normalized_uri: str,
) -> dict:
    account_id     = finding.get("AwsAccountId", "")
    region         = finding.get("Region", "ap-northeast-2")
    first_observed = finding.get("FirstObservedAt", now.isoformat())
    vulnerable_event = common.get("vulnerable_event")

    # events[] — FSBP/CIS에서 CloudTrail 취약 이벤트가 있을 때만 채움
    events = []
    if vulnerable_event:
        first_resource     = finding.get("Resources", [{}])[0]
        asff_type          = first_resource.get("Type", "")
        first_resource_id  = _extract_resource_id(first_resource)
        first_config_type  = ASFF_TO_CONFIG_TYPE.get(asff_type, f"AWS::{asff_type}")
        evt_id = vulnerable_event.get("event_id") or str(uuid.uuid4())
        events.append({
            "event_id":      evt_id,
            "event_time":    vulnerable_event["event_time"],
            "aws_region":    region,
            "event_source":  vulnerable_event.get("event_source", ""),
            "event_name":    vulnerable_event["event_name"],
            "read_only":     False,
            "user_identity": {"user_name": vulnerable_event.get("username", "")},
            "resources": [{
                "resource_type": first_config_type,
                "resource_id":   first_resource_id,
                "arn":           first_resource.get("Id", ""),
                "account_id":    account_id,
                "region":        region,
            }],
            "raw": {"lookup_event_s3_uri": None, "cloudtrail_event_s3_uri": None},
        })

    cloudtrail_status = (
        {"status": "OK"}
        if vulnerable_event
        else {"status": "NA", "na_reason": "NO_DATA"}
    )

    # resources[] — finding.Resources 전체를 범용 처리
    resource_groups = _build_resource_groups(finding, common, vulnerable_event, account_id, region)

    return {
        "meta": {
            "schema_version": SCHEMA_VERSION,
            "type":           "EVENT",
            "run_id":         run_id,
            "account_id":     account_id,
            "regions":        [region],
            "time_range": {
                "start":    vulnerable_event["event_time"] if vulnerable_event else first_observed,
                "end":      first_observed,
                "timezone": "Asia/Seoul",
            },
            "generated_at": now.isoformat(),
            "collector": {"name": COLLECTOR_NAME, "version": COLLECTOR_VERSION},
            "evidence": {
                "raw_prefix_s3_uri":        raw_uri,
                "normalized_prefix_s3_uri": normalized_uri,
            },
            "trigger": {
                "source":      "EVENTBRIDGE",
                "received_at": now.isoformat(),
                "detail_type": "Security Hub Findings - Imported",
            },
        },
        "collection_status": {
            "assume_role": {"status": "OK"} if _session else {"status": "FAIL", "na_reason": "ASSUME_ROLE_FAILED"},
            "cloudtrail":  cloudtrail_status,
            "config":      {"status": "NA", "na_reason": "NOT_SUPPORTED"},
            "normalized":  {"status": "OK"},
        },
        "events":    events,
        "resources": resource_groups,
    }


def _build_resource_groups(
    finding:          dict,
    common:           dict,
    vulnerable_event: dict | None,
    account_id:       str,
    region:           str,
) -> list[dict]:
    compliance = finding.get("Compliance", {})
    severity   = finding.get("Severity", {})
    finding_ext_base = {
        "finding_id":            finding.get("Id", ""),
        "product":               finding.get("ProductName", ""),
        "control_id":            compliance.get("SecurityControlId", ""),
        "severity":              severity.get("Label", ""),
        "severity_normalized":   severity.get("Normalized", 0),
        "compliance_status":     compliance.get("Status", ""),
        "types":                 finding.get("Types", []),
        "title":                 finding.get("Title", ""),
        "description":           finding.get("Description", ""),
        "first_observed_at":     finding.get("FirstObservedAt", ""),
        "last_observed_at":      finding.get("LastObservedAt", ""),
        "account_alias":         common.get("account_alias", ""),
        "detection_delay":       common.get("detection_delay", ""),
        "remediation_url": (
            finding.get("Remediation", {})
            .get("Recommendation", {})
            .get("Url", "")
        ),
    }

    groups = []
    for i, resource in enumerate(finding.get("Resources", [])):
        asff_type   = resource.get("Type", "")
        resource_id = (
            common.get("resource_display_name")
            if i == 0
            else _extract_resource_id(resource)
        )
        config_type = ASFF_TO_CONFIG_TYPE.get(asff_type) or f"AWS::{asff_type}"
        res_region  = resource.get("Region") or region

        # 리소스 타입별 수집
        resource_data = {}
        fn = _COLLECTORS.get(asff_type)
        if fn:
            try:
                resource_data = fn(resource, res_region)
            except Exception as e:
                logger.warning("Collector 실패 (%s): %s", asff_type, e)

        # event_link (첫 번째 리소스 + vulnerable_event 있을 때)
        event_links = []
        if i == 0 and vulnerable_event:
            evt_id = vulnerable_event.get("event_id") or str(uuid.uuid4())
            event_links.append({
                "event_id":     evt_id,
                "event_time":   vulnerable_event["event_time"],
                "event_name":   vulnerable_event["event_name"],
                "event_source": vulnerable_event.get("event_source", ""),
                "user_arn":     "",
            })

        finding_ext = {
            **finding_ext_base,
            "resource_display_name": resource_id,
            "exposure_scope":        resource_data.get("ExposureScope", "unknown"),
            "affected_resources":    resource_data.get("AffectedResources", []),
        }

        groups.append({
            "key":      f"{config_type}/{resource_id}/{res_region}",
            "resource": {
                "resource_type": config_type,
                "resource_id":   resource_id,
                "arn":           resource.get("Id", ""),
                "account_id":    account_id,
                "region":        res_region,
            },
            "events":         event_links,
            "change_summary": {
                "first_event_time": vulnerable_event["event_time"] if vulnerable_event and i == 0 else "",
                "last_event_time":  vulnerable_event["event_time"] if vulnerable_event and i == 0 else "",
                "event_count":      len(event_links),
            },
            "config":     {"status": "NA", "na_reason": "NOT_SUPPORTED"},
            "extensions": {"security_finding": finding_ext},
        })

    if not groups:
        groups.append({
            "key":      f"unknown/unknown/{region}",
            "resource": {"resource_type": "unknown", "resource_id": "unknown",
                         "arn": "", "account_id": account_id, "region": region},
            "events":         [],
            "change_summary": {"event_count": 0},
            "config":         {"status": "NA", "na_reason": "NOT_SUPPORTED"},
            "extensions":     {"security_finding": finding_ext_base},
        })

    return groups


# ── 공통 수집 ──────────────────────────────────────────────────────

def _collect_common(finding: dict) -> dict:
    result = {}
    alias = _get_account_alias()
    if alias:
        result["account_alias"] = alias
    resource = finding.get("Resources", [{}])[0]
    name = _extract_resource_id(resource)
    if name:
        result["resource_display_name"] = name
    return result


def _get_account_alias() -> str:
    try:
        aliases = _client("iam").list_account_aliases().get("AccountAliases", [])
        return aliases[0] if aliases else ""
    except Exception as e:
        logger.warning("IAM ListAccountAliases failed: %s", e)
        return ""


# ── 리소스 타입별 수집 ─────────────────────────────────────────────

def _collect_elb(resource: dict, region: str) -> dict:
    """ALB/NLB — ExposureScope + TargetGroups."""
    details = resource.get("Details", {}).get("AwsElbv2LoadBalancer", {})
    scheme  = details.get("Scheme", "")

    if not scheme:
        try:
            resp   = _client("elbv2", region_name=region).describe_load_balancers(
                LoadBalancerArns=[resource.get("Id", "")]
            )
            lbs    = resp.get("LoadBalancers", [])
            scheme = lbs[0].get("Scheme", "") if lbs else ""
        except Exception as e:
            logger.warning("ELBv2 DescribeLoadBalancers failed: %s", e)

    exposure = (
        "internet-facing" if scheme == "internet-facing"
        else "internal"   if scheme == "internal"
        else "unknown"
    )

    try:
        tgs = _client("elbv2", region_name=region).describe_target_groups(
            LoadBalancerArn=resource.get("Id", "")
        ).get("TargetGroups", [])
        affected = [
            {"Type": "TargetGroup", "Name": tg["TargetGroupName"],
             "Protocol": tg.get("Protocol",""), "Port": tg.get("Port"),
             "TargetType": tg.get("TargetType","")}
            for tg in tgs
        ]
    except Exception as e:
        logger.warning("ELBv2 DescribeTargetGroups failed: %s", e)
        affected = []

    return {"ExposureScope": exposure, "AffectedResources": affected}


def _collect_ec2(resource: dict, region: str) -> dict:
    """EC2 Instance — ExposureScope + 인스턴스 상태."""
    details    = resource.get("Details", {}).get("AwsEc2Instance", {})
    public_ip  = details.get("IpV4Addresses", [None])[0] if details.get("IpV4Addresses") else None

    if public_ip is None:
        instance_id = resource.get("Id", "").split("/")[-1]
        try:
            reservations = _client("ec2", region_name=region).describe_instances(
                InstanceIds=[instance_id]
            ).get("Reservations", [])
            if reservations:
                inst      = reservations[0]["Instances"][0]
                public_ip = inst.get("PublicIpAddress")
                details   = {"InstanceType": inst.get("InstanceType",""),
                             "State": inst.get("State",{}).get("Name",""),
                             "SubnetId": inst.get("SubnetId",""),
                             "VpcId": inst.get("VpcId",""),
                             "LaunchTime": inst["LaunchTime"].isoformat() if "LaunchTime" in inst else ""}
        except Exception as e:
            logger.warning("EC2 DescribeInstances failed: %s", e)

    return {
        "ExposureScope": "internet-facing" if public_ip else "internal",
        "AffectedResources": [{"Type": "EC2Instance", **details}],
    }


def _collect_s3(resource: dict, region: str) -> dict:
    """S3 Bucket — 퍼블릭 액세스 블록 상태."""
    bucket_name = resource.get("Id", "").split(":::")[-1]
    s3          = _client("s3")
    exposure    = "unknown"
    try:
        cfg         = s3.get_public_access_block(Bucket=bucket_name).get("PublicAccessBlockConfiguration", {})
        all_blocked = all([cfg.get("BlockPublicAcls"), cfg.get("IgnorePublicAcls"),
                           cfg.get("BlockPublicPolicy"), cfg.get("RestrictPublicBuckets")])
        exposure = "internal" if all_blocked else "internet-facing"
    except ClientError as e:
        code = e.response["Error"]["Code"]
        if code == "NoSuchPublicAccessBlockConfiguration":
            # PAB 설정 없음 = 퍼블릭 액세스 차단 안 됨
            exposure = "internet-facing"
        else:
            logger.warning("S3 GetPublicAccessBlock failed: %s", e)
    except Exception as e:
        logger.warning("S3 GetPublicAccessBlock failed: %s", e)

    bucket_region = "unknown"
    try:
        bucket_region = s3.get_bucket_location(Bucket=bucket_name).get("LocationConstraint") or "us-east-1"
    except Exception as e:
        logger.warning("S3 GetBucketLocation failed: %s", e)

    return {
        "ExposureScope": exposure,
        "AffectedResources": [{"Type": "S3Bucket", "Name": bucket_name, "Region": bucket_region}],
    }


def _collect_rds(resource: dict, region: str) -> dict:
    """RDS DBInstance — PubliclyAccessible."""
    details     = resource.get("Details", {}).get("AwsRdsDbInstance", {})
    publicly    = details.get("PubliclyAccessible")

    if publicly is None:
        db_id = resource.get("Id", "").split(":")[-1]
        try:
            instances = _client("rds", region_name=region).describe_db_instances(
                DBInstanceIdentifier=db_id
            ).get("DBInstances", [])
            if instances:
                db       = instances[0]
                publicly = db.get("PubliclyAccessible", False)
                details  = {"DBInstanceClass": db.get("DBInstanceClass",""),
                            "Engine": db.get("Engine",""), "EngineVersion": db.get("EngineVersion",""),
                            "DBInstanceStatus": db.get("DBInstanceStatus",""), "MultiAZ": db.get("MultiAZ", False)}
        except Exception as e:
            logger.warning("RDS DescribeDBInstances failed: %s", e)

    return {
        "ExposureScope": "internet-facing" if publicly else "internal",
        "AffectedResources": [{"Type": "RDSInstance", **details}],
    }


def _collect_iam_role(resource: dict, region: str) -> dict:
    """IAM Role — 외부 계정 trust policy 여부."""
    details   = resource.get("Details", {}).get("AwsIamRole", {})
    role_name = details.get("RoleName", "") or resource.get("Id", "").split("/")[-1]
    trust_doc = details.get("AssumeRolePolicyDocument", {})

    if not trust_doc:
        try:
            resp      = _client("iam").get_role(RoleName=role_name)
            role      = resp.get("Role", {})
            trust_doc = role.get("AssumeRolePolicyDocument", {})
            details   = {"RoleName": role_name, "RoleId": role.get("RoleId",""),
                         "CreateDate": str(role.get("CreateDate",""))}
        except Exception as e:
            logger.warning("IAM GetRole failed: %s", e)

    # trust policy에 외부 계정 또는 * principal 있으면 internet-facing
    exposure = "internal"
    # role의 account_id 추출 (arn:aws:iam::ACCOUNT:role/NAME)
    role_arn_str = resource.get("Id", "")
    role_account = ""
    arn_parts = role_arn_str.split(":")
    if len(arn_parts) >= 5:
        role_account = arn_parts[4]

    for stmt in (trust_doc.get("Statement") or []):
        principal = stmt.get("Principal", {})
        # Principal이 "*" 문자열일 수 있음
        if principal == "*":
            exposure = "internet-facing"
            break
        aws_p = principal.get("AWS", []) if isinstance(principal, dict) else []
        # 단일 문자열을 리스트로 정규화
        if isinstance(aws_p, str):
            aws_p = [aws_p]
        for entry in aws_p:
            if entry == "*":
                exposure = "internet-facing"
                break
            if ":root" in entry:
                # 다른 계정의 root면 외부 접근
                if role_account and role_account not in entry:
                    exposure = "internet-facing"
                    break
                # 자기 계정 root는 internal 유지
            elif entry.startswith("arn:aws:iam::"):
                # 다른 계정의 role/user
                entry_parts = entry.split(":")
                if len(entry_parts) >= 5 and entry_parts[4] != role_account:
                    exposure = "internet-facing"
                    break
        if exposure == "internet-facing":
            break

    return {
        "ExposureScope": exposure,
        "AffectedResources": [{"Type": "IAMRole", "Name": role_name, **details}],
    }


def _collect_iam_user(resource: dict, region: str) -> dict:
    """IAM User — 액세스 키 목록 및 마지막 사용 정보."""
    details   = resource.get("Details", {}).get("AwsIamUser", {})
    user_name = details.get("UserName", "") or resource.get("Id", "").split("/")[-1]
    keys_info = []

    try:
        keys = _client("iam").list_access_keys(UserName=user_name).get("AccessKeyMetadata", [])
        for key in keys:
            key_id   = key.get("AccessKeyId", "")
            last_used = ""
            try:
                resp      = _client("iam").get_access_key_last_used(AccessKeyId=key_id)
                last_used = str(resp.get("AccessKeyLastUsed", {}).get("LastUsedDate", ""))
            except Exception:
                pass
            keys_info.append({"AccessKeyId": key_id, "Status": key.get("Status",""), "LastUsed": last_used})
    except Exception as e:
        logger.warning("IAM ListAccessKeys failed: %s", e)

    return {
        "ExposureScope": "unknown",
        "AffectedResources": [{"Type": "IAMUser", "Name": user_name, "AccessKeys": keys_info}],
    }


def _collect_iam_access_key(resource: dict, region: str) -> dict:
    """IAM Access Key — 마지막 사용 정보."""
    details    = resource.get("Details", {}).get("AwsIamAccessKey", {})
    key_id     = details.get("AccessKeyId", "") or resource.get("Id", "").split("/")[-1]
    user_name  = details.get("PrincipalName", "")
    last_used  = ""
    try:
        resp      = _client("iam").get_access_key_last_used(AccessKeyId=key_id)
        last_used = str(resp.get("AccessKeyLastUsed", {}).get("LastUsedDate", ""))
        if not user_name:
            user_name = resp.get("UserName", "")
    except Exception as e:
        logger.warning("IAM GetAccessKeyLastUsed failed: %s", e)

    return {
        "ExposureScope": "internet-facing",   # 외부에서 사용 가능한 자격증명
        "AffectedResources": [{"Type": "IAMAccessKey", "KeyId": key_id,
                                "User": user_name, "LastUsed": last_used}],
    }


def _collect_lambda(resource: dict, region: str) -> dict:
    """Lambda Function — VPC 여부로 ExposureScope 판단."""
    details  = resource.get("Details", {}).get("AwsLambdaFunction", {})
    fn_name  = details.get("FunctionName", "") or resource.get("Id", "").split(":")[-1]
    vpc_conf = details.get("VpcConfig", {})

    if not details:
        try:
            fn       = _client("lambda", region_name=region).get_function(FunctionName=fn_name)
            cfg      = fn.get("Configuration", {})
            vpc_conf = cfg.get("VpcConfig", {})
            details  = {"FunctionName": fn_name, "Runtime": cfg.get("Runtime",""),
                        "Handler": cfg.get("Handler",""), "Role": cfg.get("Role","")}
        except Exception as e:
            logger.warning("Lambda GetFunction failed: %s", e)

    in_vpc   = bool(vpc_conf.get("VpcId") or vpc_conf.get("SubnetIds"))
    exposure = "internal" if in_vpc else "internet-facing"

    return {
        "ExposureScope": exposure,
        "AffectedResources": [{"Type": "LambdaFunction", "Name": fn_name, **details}],
    }


def _collect_kms_key(resource: dict, region: str) -> dict:
    """KMS Key — 키 상태 및 외부 접근 가능 여부."""
    details = resource.get("Details", {}).get("AwsKmsKey", {})
    key_id  = details.get("KeyId", "") or resource.get("Id", "").split("/")[-1]
    key_state = details.get("KeyState", "")

    if not details:
        try:
            key_meta  = _client("kms", region_name=region).describe_key(KeyId=key_id).get("KeyMetadata", {})
            key_state = key_meta.get("KeyState", "")
            details   = {"KeyId": key_id, "KeyState": key_state,
                         "KeyUsage": key_meta.get("KeyUsage",""),
                         "MultiRegion": key_meta.get("MultiRegion", False)}
        except Exception as e:
            logger.warning("KMS DescribeKey failed: %s", e)

    # Access Analyzer가 외부 접근 보고 → internet-facing
    exposure = "internet-facing" if resource.get("Details") else "unknown"

    return {
        "ExposureScope": exposure,
        "AffectedResources": [{"Type": "KMSKey", "KeyId": key_id, "KeyState": key_state}],
    }


def _collect_eks(resource: dict, region: str) -> dict:
    """EKS Cluster — 퍼블릭 엔드포인트 여부."""
    details      = resource.get("Details", {}).get("AwsEksCluster", {})
    cluster_name = details.get("Name", "") or resource.get("Id", "").split("/")[-1]
    public_access = details.get("ResourcesVpcConfig", {}).get("EndpointPublicAccess", None)

    if public_access is None:
        try:
            cluster      = _client("eks", region_name=region).describe_cluster(name=cluster_name).get("cluster", {})
            public_access = cluster.get("resourcesVpcConfig", {}).get("endpointPublicAccess", False)
            details       = {"Name": cluster_name, "Version": cluster.get("version",""),
                             "Status": cluster.get("status","")}
        except Exception as e:
            logger.warning("EKS DescribeCluster failed: %s", e)

    return {
        "ExposureScope": "internet-facing" if public_access else "internal",
        "AffectedResources": [{"Type": "EKSCluster", "Name": cluster_name}],
    }


def _collect_ecr_image(resource: dict, region: str) -> dict:
    """ECR Container Image — 이미지 다이제스트 추출."""
    arn        = resource.get("Id", "")
    # arn:aws:ecr:region:account:repository/name@sha256:digest
    repo_name  = ""
    image_tag  = ""
    parts      = arn.split(":")
    if len(parts) >= 6:
        last = parts[-1]
        if "/" in last:
            repo_name = last.split("/")[-1].split("@")[0]
        image_tag = parts[-1].split("@sha256:")[-1] if "@sha256:" in parts[-1] else ""

    return {
        "ExposureScope": "internal",   # ECR은 기본적으로 private
        "AffectedResources": [{"Type": "ECRImage", "Repository": repo_name,
                                "ImageDigest": f"sha256:{image_tag}" if image_tag else ""}],
    }


def _sqs_arn_to_url(arn: str) -> str:
    """SQS ARN → Queue URL 변환.
    arn:aws:sqs:region:account:queue-name → https://sqs.region.amazonaws.com/account/queue-name
    """
    parts = arn.split(":")
    if len(parts) >= 6:
        region_part  = parts[3]
        account_part = parts[4]
        queue_name   = parts[5]
        return f"https://sqs.{region_part}.amazonaws.com/{account_part}/{queue_name}"
    return arn  # fallback: 원본 반환


def _collect_security_group(resource: dict, region: str) -> dict:
    """EC2 SecurityGroup — 0.0.0.0/0 또는 ::/0 인바운드 규칙 여부."""
    details = resource.get("Details", {}).get("AwsEc2SecurityGroup", {})
    ip_permissions = details.get("IpPermissions", [])

    if not ip_permissions:
        sg_id = resource.get("Id", "").split("/")[-1]
        try:
            sgs = _client("ec2", region_name=region).describe_security_groups(
                GroupIds=[sg_id]
            ).get("SecurityGroups", [])
            if sgs:
                ip_permissions = sgs[0].get("IpPermissions", [])
                details = {"GroupId": sg_id, "GroupName": sgs[0].get("GroupName", "")}
        except Exception as e:
            logger.warning("EC2 DescribeSecurityGroups failed: %s", e)

    exposure = "internal"
    for rule in ip_permissions:
        for ipv4 in rule.get("IpRanges", []):
            if ipv4.get("CidrIp") == "0.0.0.0/0":
                exposure = "internet-facing"
                break
        for ipv6 in rule.get("Ipv6Ranges", []):
            if ipv6.get("CidrIpv6") == "::/0":
                exposure = "internet-facing"
                break
        if exposure == "internet-facing":
            break

    sg_id   = details.get("GroupId", "") or resource.get("Id", "").split("/")[-1]
    sg_name = details.get("GroupName", "")
    return {
        "ExposureScope": exposure,
        "AffectedResources": [{"Type": "EC2SecurityGroup", "GroupId": sg_id, "GroupName": sg_name}],
    }


def _collect_vpc(resource: dict, region: str) -> dict:
    """EC2 VPC — 라우팅 테이블 기반 IGW 연결 여부로 ExposureScope 판단.
    ec2:DescribeInternetGateways 대신 ec2:DescribeRouteTables 사용
    (BaseReadPolicy에 포함된 권한).
    """
    vpc_id = resource.get("Id", "").split("/")[-1]
    exposure = "unknown"
    try:
        route_tables = _client("ec2", region_name=region).describe_route_tables(
            Filters=[{"Name": "vpc-id", "Values": [vpc_id]}]
        ).get("RouteTables", [])
        exposure = "internal"
        for rt in route_tables:
            for route in rt.get("Routes", []):
                if route.get("GatewayId", "").startswith("igw-") and route.get("State") == "active":
                    exposure = "internet-facing"
                    break
            if exposure == "internet-facing":
                break
    except Exception as e:
        logger.warning("EC2 DescribeRouteTables failed: %s", e)

    return {
        "ExposureScope": exposure,
        "AffectedResources": [{"Type": "EC2Vpc", "VpcId": vpc_id}],
    }


def _collect_sqs_queue(resource: dict, region: str) -> dict:
    """SQS Queue — 퍼블릭 정책 여부."""
    raw_id    = resource.get("Id", "")
    queue_url = _sqs_arn_to_url(raw_id) if raw_id.startswith("arn:") else raw_id
    exposure  = "unknown"
    try:
        attrs    = _client("sqs", region_name=region).get_queue_attributes(
            QueueUrl=queue_url, AttributeNames=["Policy"]
        ).get("Attributes", {})
        policy   = json.loads(attrs.get("Policy", "{}"))
        for stmt in (policy.get("Statement") or []):
            if stmt.get("Principal") in ("*", {"AWS": "*"}):
                exposure = "internet-facing"
                break
        else:
            exposure = "internal"
    except Exception as e:
        logger.warning("SQS GetQueueAttributes failed: %s", e)

    queue_name = queue_url.split("/")[-1] if queue_url else ""
    return {
        "ExposureScope": exposure,
        "AffectedResources": [{"Type": "SQSQueue", "Name": queue_name}],
    }


# 수집 함수 디스패치 테이블
_COLLECTORS = {
    "AwsElbv2LoadBalancer": _collect_elb,
    "AwsEc2Instance":       _collect_ec2,
    "AwsEc2SecurityGroup":  _collect_security_group,
    "AwsEc2Vpc":            _collect_vpc,
    "AwsS3Bucket":          _collect_s3,
    "AwsRdsDbInstance":     _collect_rds,
    "AwsIamRole":           _collect_iam_role,
    "AwsIamUser":           _collect_iam_user,
    "AwsIamAccessKey":      _collect_iam_access_key,
    "AwsLambdaFunction":    _collect_lambda,
    "AwsKmsKey":            _collect_kms_key,
    "AwsEksCluster":        _collect_eks,
    "AwsEcrContainerImage": _collect_ecr_image,
    "AwsEcrRepository":     _collect_ecr_image,
    "AwsSqsQueue":          _collect_sqs_queue,
}


# ── CloudTrail 취약 이벤트 조회 (FSBP/CIS 전용) ────────────────────

def _get_vulnerable_event(finding: dict, region: str) -> dict | None:
    resource      = finding.get("Resources", [{}])[0]
    resource_id   = resource.get("Id", "")
    resource_type = resource.get("Type", "")
    control_id    = finding.get("Compliance", {}).get("SecurityControlId", "")

    # 컨트롤별 전용 핸들러
    control_handlers = {
        "ELB.16": lambda: _get_elb16_vulnerable_event(resource_id, region),
    }
    fn = control_handlers.get(control_id)
    if fn:
        return fn()

    return _get_creation_event(resource_id, resource_type, region)


def _get_elb16_vulnerable_event(alb_arn: str, region: str) -> dict | None:
    """ELB.16 — DisassociateWebACL 또는 CreateLoadBalancer."""
    ct = _client("cloudtrail", region_name=region)
    try:
        for e in ct.lookup_events(
            LookupAttributes=[{"AttributeKey": "EventName", "AttributeValue": "DisassociateWebACL"}],
            MaxResults=50,
        ).get("Events", []):
            raw = json.loads(e.get("CloudTrailEvent", "{}"))
            if raw.get("requestParameters", {}).get("ResourceArn") == alb_arn:
                return _fmt_ct_event(e, raw)
    except Exception as e:
        logger.warning("CloudTrail DisassociateWebACL lookup failed: %s", e)

    alb_name = alb_arn.split("/")[-2]
    try:
        for e in ct.lookup_events(
            LookupAttributes=[{"AttributeKey": "ResourceName", "AttributeValue": alb_name}],
            MaxResults=50,
        ).get("Events", []):
            if e["EventName"] == "CreateLoadBalancer":
                return _fmt_ct_event(e, json.loads(e.get("CloudTrailEvent", "{}")))
    except Exception as e:
        logger.warning("CloudTrail CreateLoadBalancer lookup failed: %s", e)

    return None


def _get_creation_event(resource_id: str, resource_type: str, region: str) -> dict | None:
    """리소스 생성 이벤트 범용 조회."""
    EVENT_MAP = {
        "AwsElbv2LoadBalancer": ("CreateLoadBalancer", lambda a: a.split("/")[-2]),
        "AwsEc2Instance":       ("RunInstances",       lambda a: a.split("/")[-1]),
        "AwsS3Bucket":          ("CreateBucket",       lambda a: a.split(":::")[-1]),
        "AwsRdsDbInstance":     ("CreateDBInstance",   lambda a: a.split(":")[-1]),
        "AwsEksCluster":        ("CreateCluster",      lambda a: a.split("/")[-1]),
        "AwsLambdaFunction":    ("CreateFunction20150331", lambda a: a.split(":")[-1]),
    }
    entry = EVENT_MAP.get(resource_type)
    if not entry:
        return None
    event_name, extract_name = entry
    resource_name = extract_name(resource_id)
    try:
        ct = _client("cloudtrail", region_name=region)
        for e in ct.lookup_events(
            LookupAttributes=[{"AttributeKey": "ResourceName", "AttributeValue": resource_name}],
            MaxResults=50,
        ).get("Events", []):
            if e["EventName"] == event_name:
                return _fmt_ct_event(e, json.loads(e.get("CloudTrailEvent", "{}")))
    except Exception as e:
        logger.warning("CloudTrail LookupEvents failed: %s", e)
    return None


def _fmt_ct_event(e: dict, raw: dict) -> dict:
    return {
        "event_id":     e.get("EventId", ""),
        "event_time":   e["EventTime"].isoformat(),
        "event_name":   e["EventName"],
        "event_source": raw.get("eventSource", ""),
        "username":     e.get("Username", ""),
    }


# ── 유틸 ───────────────────────────────────────────────────────────

def _extract_resource_id(resource: dict) -> str:
    """Tags.Name 우선, 없으면 ARN 마지막 세그먼트."""
    tags = resource.get("Tags") or {}
    if isinstance(tags, dict) and tags.get("Name"):
        return tags["Name"]
    arn  = resource.get("Id", "")
    if not arn:
        return "unknown"
    last = arn.split(":")[-1]
    return last.split("/")[-1] if "/" in last else last or arn


def _calc_elapsed(start: str, end: str) -> str:
    try:
        t1    = datetime.fromisoformat(start.replace("Z", "+00:00"))
        t2    = datetime.fromisoformat(end.replace("Z", "+00:00"))
        total = int((t2 - t1).total_seconds())
        if total < 0:
            return ""
        h, rem = divmod(total, 3600)
        m, s   = divmod(rem, 60)
        return f"{h:02d}:{m:02d}:{s:02d}"
    except Exception:
        return ""


def _save_to_s3(data: dict, bucket: str, key: str, label: str = "") -> None:
    try:
        boto3.client("s3").put_object(
            Bucket=bucket, Key=key,
            Body=json.dumps(data, ensure_ascii=False, default=str),
            ContentType="application/json",
        )
        logger.info("Saved %s → s3://%s/%s", label, bucket, key)
    except Exception as e:
        logger.error("S3 PutObject (%s) failed: %s", label, e)
