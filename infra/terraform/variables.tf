variable "project_name" { type = string  default = "telehealth-voice" }
variable "aws_region"   { type = string  default = "us-east-1" }

# GitHub OIDC
variable "github_org"  { type = string }
variable "github_repo" { type = string }

# Optional domain (leave empty if not using custom domain)
variable "domain_name" { type = string  default = "" }
