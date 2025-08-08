output "aws_account_id"      { value = data.aws_caller_identity.current.account_id }
output "region"              { value = var.aws_region }
output "frontend_bucket"     { value = aws_s3_bucket.frontend_bucket.id }
output "uploads_bucket"      { value = aws_s3_bucket.uploads_bucket.id }
output "cf_distribution_id"  { value = aws_cloudfront_distribution.site.id }
output "cognito_user_pool_id" { value = aws_cognito_user_pool.user_pool.id }
output "cognito_client_id"    { value = aws_cognito_user_pool_client.app.id }
output "cognito_domain"       { value = aws_cognito_user_pool_domain.pool_domain.domain }
output "api_url"              { value = aws_apigatewayv2_api.http_api.api_endpoint }
output "aws_oidc_role_arn"    { value = aws_iam_role.github_actions_role.arn }
# Lex bot outputs (may be empty if creation is skipped/failed)
output "lex_bot_id"       { value = try(aws_lexv2models_bot.bot.id, "") }
output "lex_bot_alias_id" { value = try(aws_lexv2models_bot_alias.alias.bot_alias_id, "") }
output "lex_locale_id"    { value = "en_US" }
