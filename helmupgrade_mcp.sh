#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# PodWatcher MCP v1.0.1 — Helm Install / Upgrade Script
# Edit the variables below then run: bash helmupgrade_mcp.sh
# -----------------------------------------------------------------------------

CLUSTER_NAME="my-cluster"             # EKS cluster name (shown on alerts and used for OIDC trust)
AWS_REGION="us-east-1"               # AWS region where the cluster runs
PODWATCHER_HOST="podwatcher"         # Kubernetes Service name of the running PodWatcher instance
PODWATCHER_NAMESPACE="podwatcher"    # Namespace where PodWatcher is installed

# -----------------------------------------------------------------------------
# Do not edit below this line
# -----------------------------------------------------------------------------

AWSMP_PRODUCT_SKU="prod-b7m2oxa3yjgpo"
AWSMP_KEY_FINGERPRINT="aws:294406891311:AWS/Marketplace:issuer-fingerprint"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ROLE_NAME="podwatcher-mcp"
SA_NAME="podwatcher-mcp-sa"

echo "[1/4] Resolving OIDC provider for cluster: ${CLUSTER_NAME}"
OIDC_URL=$(aws eks describe-cluster \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}" \
  --query "cluster.identity.oidc.issuer" \
  --output text)
OIDC_ID="${OIDC_URL#https://}"

echo "[2/4] Creating IAM role: ${ROLE_NAME}"
TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_ID}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_ID}:sub": "system:serviceaccount:${PODWATCHER_NAMESPACE}:${SA_NAME}",
          "${OIDC_ID}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF
)

if aws iam get-role --role-name "${ROLE_NAME}" &>/dev/null; then
  echo "  Role ${ROLE_NAME} already exists — skipping create"
else
  aws iam create-role \
    --role-name "${ROLE_NAME}" \
    --assume-role-policy-document "${TRUST_POLICY}" \
    --description "IRSA role for PodWatcher MCP - License Manager CheckoutLicense" \
    --region "${AWS_REGION}" \
    --output text --query "Role.RoleName"
  echo "  Created role: ${ROLE_NAME}"
fi

echo "[3/4] Attaching License Manager policy to role: ${ROLE_NAME}"
LM_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "license-manager:CheckoutLicense",
      "Resource": "*"
    }
  ]
}
EOF
)

aws iam put-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-name "PodWatcherMCPLicenseManager" \
  --policy-document "${LM_POLICY}"
echo "  Policy attached"

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo "  Role ARN: ${ROLE_ARN}"

echo "[4/4] Installing / upgrading PodWatcher MCP helm chart"

aws ecr get-login-password --region us-east-1 \
  | helm registry login --username AWS --password-stdin \
    709825985650.dkr.ecr.us-east-1.amazonaws.com

helm upgrade --install podwatcher-mcp \
  oci://709825985650.dkr.ecr.us-east-1.amazonaws.com/saqtek-us/podwatcher-mcp \
  --version 1.0.1 \
  --set image.tag=1.0.0 \
  --namespace "${PODWATCHER_NAMESPACE}" \
  --create-namespace \
  --atomic \
  --set podwatcher.host="${PODWATCHER_HOST}" \
  --set serviceAccount.name="${SA_NAME}" \
  --set "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=${ROLE_ARN}" \
  --set awsMarketplace.productSku="${AWSMP_PRODUCT_SKU}" \
  --set "awsMarketplace.keyFingerprint=${AWSMP_KEY_FINGERPRINT}"

echo ""
echo "PodWatcher MCP deployed successfully."
echo "Role ARN: ${ROLE_ARN}"
echo ""
echo "Verify deployment:"
echo "  kubectl get pods -n ${PODWATCHER_NAMESPACE}"
echo "  kubectl logs -n ${PODWATCHER_NAMESPACE} deployment/podwatcher-mcp"
