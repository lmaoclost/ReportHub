#!/bin/bash
# localstack/init.sh
# Executado automaticamente pelo LocalStack após subir todos os serviços.
# Cria os recursos AWS necessários para o ReportHub.

set -e

echo ">>> [LocalStack] Iniciando setup dos recursos AWS..."

# ── S3 ─────────────────────────────────────────────────────────────────────────
echo ">>> Criando bucket S3..."
awslocal s3 mb s3://reporthub-reports
awslocal s3api put-bucket-cors \
  --bucket reporthub-reports \
  --cors-configuration '{
    "CORSRules": [{
      "AllowedOrigins": ["http://localhost:5173"],
      "AllowedMethods": ["GET"],
      "AllowedHeaders": ["*"],
      "MaxAgeSeconds": 86400
    }]
  }'
echo ">>> Bucket reporthub-reports criado."

# ── SES ────────────────────────────────────────────────────────────────────────
echo ">>> Verificando identidade SES..."
awslocal ses verify-email-identity --email-address noreply@reporthub.local
echo ">>> Identidade noreply@reporthub.local verificada."

# ── Secrets Manager ────────────────────────────────────────────────────────────
echo ">>> Criando secrets..."
awslocal secretsmanager create-secret \
  --name reporthub/django-secret-key \
  --secret-string "dev-secret-key-troque-em-producao"

awslocal secretsmanager create-secret \
  --name reporthub/database \
  --secret-string '{"host":"postgres","port":"5432","name":"reporthub","user":"reporthub","password":"reporthub"}'

echo ">>> Secrets criados."

echo ">>> [LocalStack] Setup concluído."
