#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# PodWatcher — Scale back to 1 replica, disable leader election
# Edit the variables below to match your helmupgrade.sh settings.
# -----------------------------------------------------------------------------

CLUSTER_NAME="my-cluster"
WATCH_NAMESPACES=""
TEAMS_WEBHOOK=""
SLACK_WEBHOOK=""
PAGERDUTY_ROUTING_KEY=""

# -----------------------------------------------------------------------------
# Do not edit below this line
# -----------------------------------------------------------------------------
helm upgrade --install podwatcher \
  oci://709825985650.dkr.ecr.us-east-1.amazonaws.com/saqtek-us/podwatcher \
  --version 1.0.8 \
  --namespace podwatcher \
  --atomic \
  --set clusterName="${CLUSTER_NAME}" \
  --set monitoring.watchNamespaces="${WATCH_NAMESPACES}" \
  --set image.tag=1.0.6 \
  --set replicaCount=1 \
  --set leaderElection.enabled=false \
  ${TEAMS_WEBHOOK:+--set webhooks.teams="${TEAMS_WEBHOOK}"} \
  ${SLACK_WEBHOOK:+--set webhooks.slack="${SLACK_WEBHOOK}"} \
  ${PAGERDUTY_ROUTING_KEY:+--set webhooks.pagerduty="${PAGERDUTY_ROUTING_KEY}"}

echo ""
echo "Waiting for rollout..."
kubectl rollout status deployment/podwatcher -n podwatcher --timeout=120s

echo ""
echo "Replica status:"
kubectl get pods -n podwatcher -l app.kubernetes.io/name=podwatcher
