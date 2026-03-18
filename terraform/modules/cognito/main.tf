# ── Cognito User Pool ─────────────────────────────────────────────────────

resource "aws_cognito_user_pool" "main" {
  name = "DnDn_UserPool_${var.environment}"

  # 로그인: 이메일, AdminCreateUser 전용
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  admin_create_user_config {
    allow_admin_create_user_only = true
    invite_message_template {
      email_subject = "[DnDn] 계정이 생성되었습니다"
      email_message = "안녕하세요, DnDn 플랫폼 계정이 생성되었습니다.<br><br>임시 비밀번호: {####}<br><br><a href='https://www.dndn.cloud/login'>로그인 하러 가기</a><br><br>첫 로그인 시 비밀번호를 변경해 주세요."
      sms_message   = "DnDn 임시 비밀번호: {####}"
    }
  }

  password_policy {
    minimum_length                   = 8
    require_uppercase                = true
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  mfa_configuration = "OFF"

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }

  schema {
    name                = "name"
    attribute_data_type = "String"
    required            = false
    mutable             = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  username_configuration {
    case_sensitive = false
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# ── App Client ────────────────────────────────────────────────────────────

resource "aws_cognito_user_pool_client" "main" {
  name         = "DnDn_AppClient_${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  enable_token_revocation       = true
  prevent_user_existence_errors = "ENABLED"
}

# ── 그룹 ──────────────────────────────────────────────────────────────────

resource "aws_cognito_user_pool_group" "hr" {
  name         = "hr"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "HR 관리자. dndn-hr 접근 및 사원/부서 관리 권한."
}

resource "aws_cognito_user_pool_group" "leader" {
  name         = "leader"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "부서장. 메인 앱에서 워크스페이스 생성 권한."
}

resource "aws_cognito_user_pool_group" "member" {
  name         = "member"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "일반 사원. 부서장이 연동한 워크스페이스 접근."
}
