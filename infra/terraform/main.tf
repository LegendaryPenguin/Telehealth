# KMS
resource "aws_kms_key" "main" {
  description             = "${var.project_name} primary KMS key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

# S3: Frontend (static site)
resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "${var.project_name}-frontend-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend_sse" {
  bucket = aws_s3_bucket.frontend_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.main.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# S3: Uploads (PHI attachments)
resource "aws_s3_bucket" "uploads_bucket" {
  bucket = "${var.project_name}-uploads-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "uploads_sse" {
  bucket = aws_s3_bucket.uploads_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.main.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# DynamoDB: medical_records
resource "aws_dynamodb_table" "records" {
  name         = "${var.project_name}-records"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute { name = "pk" type = "S" }
  attribute { name = "sk" type = "S" }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.main.arn
  }
}

# Cognito
resource "aws_cognito_user_pool" "user_pool" {
  name = "${var.project_name}-users"

  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  mfa_configuration = "ON"
  software_token_mfa_configuration { enabled = true }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
}

resource "aws_cognito_user_pool_client" "app" {
  name         = "${var.project_name}-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  generate_secret = false

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "phone"]
  allowed_oauth_flows_user_pool_client = true
  callback_urls                        = ["http://localhost:3000/api/auth/callback/cognito", "https://${aws_cloudfront_distribution.site.domain_name}/api/auth/callback/cognito"]
  logout_urls                          = ["http://localhost:3000", "https://${aws_cloudfront_distribution.site.domain_name}"]
  supported_identity_providers         = ["COGNITO"]
}

resource "aws_cognito_user_pool_domain" "pool_domain" {
  domain       = "${var.project_name}-${data.aws_caller_identity.current.account_id}"
  user_pool_id = aws_cognito_user_pool.user_pool.id
}

# Lambda + API Gateway (HTTP API)
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_extra" {
  name   = "${var.project_name}-lambda-extra"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["dynamodb:*"], Resource = [aws_dynamodb_table.records.arn, "${aws_dynamodb_table.records.arn}/*"] },
      { Effect = "Allow", Action = ["s3:*"], Resource = [aws_s3_bucket.uploads_bucket.arn, "${aws_s3_bucket.uploads_bucket.arn}/*"] },
      { Effect = "Allow", Action = ["kms:Decrypt","kms:Encrypt","kms:GenerateDataKey*"], Resource = [aws_kms_key.main.arn] },
      { Effect = "Allow", Action = ["lex:RecognizeText","polly:SynthesizeSpeech","polly:StartSpeechSynthesisTask"], Resource = "*" }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_extra_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_extra.arn
}

resource "aws_lambda_function" "api" {
  function_name = "${var.project_name}-api"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "${path.module}/lambda.zip"

  environment {
    variables = {
      TABLE_NAME           = aws_dynamodb_table.records.name
      UPLOADS_BUCKET       = aws_s3_bucket.uploads_bucket.id
      COGNITO_USER_POOL_ID = aws_cognito_user_pool.user_pool.id
      LEX_LOCALE_ID        = "en_US"
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_basic, aws_iam_role_policy_attachment.lambda_extra_attach]
}

# Package placeholder (user will run workflow to deploy real code)
resource "null_resource" "zip_placeholder" {}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.project_name}-http"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "any_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_allow" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# CloudFront for frontend
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.project_name}-oac"
  description                       = "OAC for S3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
  origin_access_control_origin_type = "s3"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_id   = "s3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    forwarded_values {
      query_string = true
      cookies { forward = "none" }
    }
  }

  restrictions { geo_restriction { restriction_type = "none" } }

  viewer_certificate { cloudfront_default_certificate = true }
}

# Grant CloudFront access to S3
resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {"Service": "cloudfront.amazonaws.com"},
      Action = "s3:GetObject",
      Resource = "${aws_s3_bucket.frontend_bucket.arn}/*",
      Condition = {
        StringEquals = { "AWS:SourceArn": aws_cloudfront_distribution.site.arn }
      }
    }]
  })
}

# GitHub OIDC Provider + Role
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals { type = "Federated" identifiers = [aws_iam_openid_connect_provider.github.arn] }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions_role" {
  name               = "${var.project_name}-github-oidc-role"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
}

resource "aws_iam_policy" "github_actions_policy" {
  name = "${var.project_name}-github-oidc-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = [
        "s3:PutObject","s3:ListBucket","s3:DeleteObject","s3:GetObject"
      ], Resource = [
        aws_s3_bucket.frontend_bucket.arn, "${aws_s3_bucket.frontend_bucket.arn}/*"
      ]},
      { Effect = "Allow", Action = [
        "cloudfront:CreateInvalidation","cloudfront:GetDistribution","cloudfront:GetDistributionConfig"
      ], Resource = [aws_cloudfront_distribution.site.arn]},
      { Effect = "Allow", Action: [
        "lambda:UpdateFunctionCode","lambda:GetFunction","lambda:CreateFunction","lambda:PublishVersion","iam:PassRole"
      ], Resource: "*" },
      { Effect = "Allow", Action: ["apigateway:*","logs:*","iam:PassRole"], Resource: "*" }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_attach" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.github_actions_policy.arn
}

# --- Optional: Lex bot scaffold (may require manual steps depending on account/region) ---
resource "aws_lexv2models_bot" "bot" {
  name                        = "${var.project_name}-lex"
  role_arn                    = aws_iam_role.lambda_exec.arn
  data_privacy { child_directed = false }
  idle_session_ttl_in_seconds = 300
  locale { locale_id = "en_US" nlu_confidence_threshold = 0.4 voice_settings { voice_id = "Joanna" } }
  intents { intent_name = "FallbackIntent" }
  timeouts { }
}

resource "aws_lexv2models_bot_alias" "alias" {
  bot_id      = aws_lexv2models_bot.bot.id
  bot_version = "$LATEST"
  name        = "dev"
}
