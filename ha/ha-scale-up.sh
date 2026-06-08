#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# PodWatcher — Scale to 2 replicas with leader election (HA mode)
# Run this after the standard helmupgrade.sh install.
# Set the variables below to match your helmupgrade.sh settings.
# -----------------------------------------------------------------------------

CLUSTER_NAME="my-cluster"            # must match your helmupgrade.sh value
WATCH_NAMESPACES=""                  # must match your helmupgrade.sh value
TEAMS_WEBHOOK=""                     # paste your Teams webhook URL (optional)
SLACK_WEBHOOK=""                     # paste your Slack webhook URL (optional)
PAGERDUTY_ROUTING_KEY=""             # paste your PagerDuty routing key (optional)

# -----------------------------------------------------------------------------
# Do not edit below this line
# -----------------------------------------------------------------------------
helm upgrade --install podwatcher \
  oci://709825985650.dkr.ecr.us-east-1.amazonaws.com/saqtek-us/podwatcher \
  --version 1.0.8 \
  --namespace podwatcher \
  --create-namespace \
  --atomic \
  --set clusterName="${CLUSTER_NAME}" \
  --set monitoring.watchNamespaces="${WATCH_NAMESPACES}" \
  --set image.tag=1.0.6 \
  --set replicaCount=2 \
  --set leaderElection.enabled=true \
  ${TEAMS_WEBHOOK:+--set webhooks.teams="${TEAMS_WEBHOOK}"} \
  ${SLACK_WEBHOOK:+--set webhooks.slack="${SLACK_WEBHOOK}"} \
  ${PAGERDUTY_ROUTING_KEY:+--set webhooks.pagerduty="${PAGERDUTY_ROUTING_KEY}"}

echo ""
echo "Waiting for both replicas to be ready..."
kubectl rollout status deployment/podwatcher -n podwatcher --timeout=120s

echo ""
echo "Replica status:"
kubectl get pods -n podwatcher -l app.kubernetes.io/name=podwatcher

echo ""
echo "Leader election status (allow 30s for lease acquisition):"
kubectl logs -n podwatcher -l app.kubernetes.io/name=podwatcher --tail=50 2>/dev/null \
  | grep -E 'is_leader|leader|lease' || echo "  (no leader log lines yet — wait 30s and check manually)"
