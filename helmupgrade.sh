#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# PodWatcher v1.0.6 — Helm Install / Upgrade Script
# Edit the variables below then run: bash helmupgrade.sh
# -----------------------------------------------------------------------------

CLUSTER_NAME="podwatcher-preprod-us-east-1"
WATCH_NAMESPACES="default\,test"   # leave blank ("") to watch all namespaces; use \, between namespaces
TEAMS_WEBHOOK="https://defaultfd7e1a2c168845a7a331a1a24ae2fb.53.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/f9ecce2722ba480d99fd4a6922eb4c8f/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=x-4VkcG33gRrB4Ta-MXyW4s957tACfwn0xT_uPo6IVc"
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
