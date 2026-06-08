#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# PodWatcher v1.0.8 — Helm Install / Upgrade Script
# Edit the variables below then run: bash helmupgrade.sh
#
# AWS Marketplace subscribers:
#   The ServiceAccount name is automatically substituted by AWS at deploy time.
#   Leave SA_NAME below empty ("").
#
# Direct / non-Marketplace installs (AKS, GKE, on-prem, self-managed EKS):
#   Set SA_NAME="podwatcher" — a ServiceAccount will be created with that name.
# -----------------------------------------------------------------------------

CLUSTER_NAME="my-cluster"            # shown on every alert card
WATCH_NAMESPACES=""                  # leave blank ("") to watch all namespaces; use \, between namespaces
TEAMS_WEBHOOK=""                     # paste your Teams webhook URL here (optional)
SLACK_WEBHOOK=""                     # paste your Slack webhook URL here (optional)
PAGERDUTY_ROUTING_KEY=""             # paste your PagerDuty Events API v2 integration key here (optional)
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
  --create-namespace \
  --atomic \
  --set clusterName="${CLUSTER_NAME}" \
  --set monitoring.watchNamespaces="${WATCH_NAMESPACES}" \
  --set image.tag=1.0.6 \
  ${SA_NAME:+--set serviceAccount.name="${SA_NAME}"} \
  ${TEAMS_WEBHOOK:+--set webhooks.teams="${TEAMS_WEBHOOK}"} \
  ${SLACK_WEBHOOK:+--set webhooks.slack="${SLACK_WEBHOOK}"} \
  ${PAGERDUTY_ROUTING_KEY:+--set webhooks.pagerduty="${PAGERDUTY_ROUTING_KEY}"}
