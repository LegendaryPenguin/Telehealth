# Telehealth Voice (AWS) — Full‑Stack App

Production‑oriented starter that’s HIPAA‑friendly by design. Features:
- Cognito user pools for auth (MFA supported)
- Voice agent via Amazon Lex V2 + Polly
- Encrypted medical records (DynamoDB + KMS)
- Encrypted file storage (S3 + KMS)
- Serverless backend (API Gateway HTTP APIs + Lambda/Node.js)
- Next.js frontend (exported to S3 + CloudFront)
- Amazon Chime SDK placeholder for synchronous telehealth sessions
- GitHub Actions CI/CD with AWS OIDC (no long‑lived AWS keys)
- 7‑commit script to stage your history before pushing to GitHub

## Quickstart

### 0) Prereqs
- AWS account with admin access (for initial bootstrap)
- Domain (optional) if you want custom HTTPS via ACM + CloudFront
- GitHub repository created (private recommended)
- Node.js 18+, npm 9+
- Terraform 1.6+

### 1) Bootstrap AWS OIDC for GitHub (no access keys)
In `infra/terraform/variables.tf`, fill:
- `github_org` and `github_repo`
- `aws_region`, `project_name`

```
cd infra/terraform
terraform init
terraform apply -auto-approve
```
This creates:
- KMS key
- S3 buckets (frontend + uploads) with SSE‑KMS
- DynamoDB table
- Cognito user pool + app client
- API Gateway + Lambda backends
- Lex Bot + Alias scaffold (see notes below)
- CloudFront distribution (frontend)
- IAM Role for GitHub OIDC deploys

Outputs will include values for your frontend `.env` and backend config.

### 2) Configure GitHub Secrets (required)
Set the following repository secrets:
- `AWS_ACCOUNT_ID`
- `AWS_REGION`
- `AWS_OIDC_ROLE_ARN` (output from Terraform)
- `CF_DISTRIBUTION_ID` (output from Terraform)
- `FRONTEND_BUCKET` (output from Terraform)
- `UPLOADS_BUCKET` (output from Terraform)
- `COGNITO_USER_POOL_ID`
- `COGNITO_CLIENT_ID`
- `COGNITO_DOMAIN`
- `API_URL` (API Gateway endpoint output)
- `LEX_BOT_ID`
- `LEX_BOT_ALIAS_ID`
- `LEX_LOCALE_ID` (e.g., `en_US`)

### 3) Local dev
Backend:
```
cd backend
npm i
npm run dev
```
Frontend:
```
cd frontend
npm i
cp .env.example .env.local  # fill values from terraform outputs
npm run dev
```

### 4) CI/CD via GitHub Actions
Push to `main`. Workflow will:
- Build Next.js → export static site
- Sync to S3
- Invalidate CloudFront
- Package backend → deploy Lambda via AWS SAM (sam build/deploy) (already wired)

### 5) Lex setup
Terraform scaffolds a Lex bot and alias if service-linked roles are allowed. If creation fails due to region/service constraints, create the bot in console and set `LEX_BOT_ID`, `LEX_BOT_ALIAS_ID`, `LEX_LOCALE_ID` secrets accordingly.

### HIPAA‑Friendly Design Notes
- All PHI stays in encrypted stores (DynamoDB/S3 with KMS).
- No third‑party analytics by default.
- Fine‑grained IAM; backend validates Cognito JWTs per request.
- Audit logs via API Gateway + Lambda logs → CloudWatch (enable retention & export as needed).
- Use VPC endpoints for API->DynamoDB/S3 in regulated environments.

---

## Repo Structure

```
backend/          Lambda (Node.js/Express)
frontend/         Next.js
infra/terraform/  Provision AWS infra (OIDC, KMS, S3, DynamoDB, Cognito, API GW, Lambda, CloudFront, Lex)
.github/workflows/ GitHub Actions pipelines
scripts/          Utilities incl. a 7‑commit script
```

See each folder for details.
