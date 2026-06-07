#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# PodWatcher v1.0.7 — Helm Install / Upgrade Script
# Edit the variables below then run: bash helmupgrade.sh
# -----------------------------------------------------------------------------

CLUSTER_NAME="podwatcher-preprod-us-east-1"
WATCH_NAMESPACES="default\,test"   # leave blank ("") to watch all namespaces; use \, between namespaces
TEAMS_WEBHOOK=""                        # paste your Teams webhook URL here (optional)
SLACK_WEBHOOK=""                        # paste your Slack webhook URL here (optional)
PAGERDUTY_ROUTING_KEY=""                # paste your PagerDuty Events API v2 integration key here (optional)

# -----------------------------------------------------------------------------
# Do not edit below this line
# -----------------------------------------------------------------------------
helm upgrade --install podwatcher \
  oci://709825985650.dkr.ecr.us-east-1.amazonaws.com/saqtek-us/podwatcher \
  --version 1.0.7 \
  --namespace podwatcher \
  --create-namespace \
  --atomic \
  --set clusterName="${CLUSTER_NAME}" \
  --set monitoring.watchNamespaces="${WATCH_NAMESPACES}" \
  --set image.registry=709825985650.dkr.ecr.us-east-1.amazonaws.com \
  --set image.tag=1.0.6 \
  ${TEAMS_WEBHOOK:+--set webhooks.teams="${TEAMS_WEBHOOK}"} \
  ${SLACK_WEBHOOK:+--set webhooks.slack="${SLACK_WEBHOOK}"} \
  ${PAGERDUTY_ROUTING_KEY:+--set webhooks.pagerduty="${PAGERDUTY_ROUTING_KEY}"}
