#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# PodWatcher v1.0.6 — Helm Install / Upgrade Script
# Edit the variables below then run: bash helmupgrade.sh
# -----------------------------------------------------------------------------

CLUSTER_NAME="podwatcher-preprod-us-east-1"
WATCH_NAMESPACES="default\,test"   # leave blank ("") to watch all namespaces; use \, between namespaces
TEAMS_WEBHOOK=""
SLACK_WEBHOOK=""                        # paste your Slack webhook URL here (optional)

# -----------------------------------------------------------------------------
# Do not edit below this line
# -----------------------------------------------------------------------------
helm upgrade --install podwatcher \
  oci://137751749418.dkr.ecr.us-east-1.amazonaws.com/saqtek-us/podwatcher \
  --version 1.0.6 \
  --namespace podwatcher \
  --create-namespace \
  --atomic \
  --set clusterName="${CLUSTER_NAME}" \
  --set monitoring.watchNamespaces="${WATCH_NAMESPACES}" \
  --set image.registry=137751749418.dkr.ecr.us-east-1.amazonaws.com \
  ${TEAMS_WEBHOOK:+--set webhooks.teams="${TEAMS_WEBHOOK}"} \
  ${SLACK_WEBHOOK:+--set webhooks.slack="${SLACK_WEBHOOK}"}
