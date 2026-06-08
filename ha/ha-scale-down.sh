#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# PodWatcher — Scale back to 1 replica, disable leader election
# Set the variables below to match your helmupgrade.sh settings.
# -----------------------------------------------------------------------------

CLUSTER_NAME="my-cluster"            # must match your helmupgrade.sh value
WATCH_NAMESPACES=""                  # must match your helmupgrade.sh value
TEAMS_WEBHOOK=""                     # paste your Teams webhook URL (optional)
SLACK_WEBHOOK=""                     # paste your Slack webhook URL (optional)
PAGERDUTY_ROUTING_KEY=""             # paste your PagerDuty routing key (optional)
SA_NAME=""  # AWS Marketplace subscribers: leave blank — AWS substitutes the
            # ServiceAccount name automatically at deploy time.
            # Direct installs (AKS, GKE, on-prem, self-managed EKS): set to
            # "podwatcher" — a ServiceAccount will be created with that name.
            # If left blank on a direct install, the deploy will fail with an
            # invalid name error.

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
  ${SA_NAME:+--set serviceAccount.name="${SA_NAME}"} \
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
