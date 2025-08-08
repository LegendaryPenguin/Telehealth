#!/usr/bin/env bash
set -euo pipefail
# Run this locally after `git init` to create a clean 7‑commit history.

git add README.md
git commit -m "chore: scaffold repo and docs"

git add infra/terraform
git commit -m "infra: terraform for KMS, S3, DynamoDB, Cognito, API GW, Lambda, CloudFront, GitHub OIDC"

git add backend
git commit -m "backend: Node.js Lambda API for records, uploads, Lex, Polly"

git add frontend/pages/index.js frontend/pages/login.js frontend/pages/api/auth/callback/cognito.js frontend/pages/dashboard.js frontend/pages/voice.js frontend/package.json frontend/next.config.js frontend/.env.example
git commit -m "frontend: Next.js app with auth flow and Lex page"

git add .github/workflows/deploy.yml
git commit -m "ci: GitHub Actions deploy via AWS OIDC"

git add backend/package.json backend/index.js
git commit -m "backend: wire API routes and JWT verification"

git add scripts
git commit -m "scripts: helper for commits and docs"
