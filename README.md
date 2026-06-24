# PodWatcher — Install

Installation scripts and integration guides for PodWatcher.

PodWatcher is a lightweight Kubernetes monitoring agent that explains why pods fail
and delivers actionable alerts to Microsoft Teams, Slack, and PagerDuty — reducing
MTTR without complex observability stacks.

Available on [AWS Marketplace](https://aws.amazon.com/marketplace/pp/prodview-ggifdgzilupgq).

---

## Quick start

```bash
curl -O https://raw.githubusercontent.com/saqtek/podwatcher-install/main/helmupgrade.sh
```

Edit the variables at the top of `helmupgrade.sh`, then follow **USAGE.txt** for
the complete step-by-step installation guide.

---

## Contents

| File | Purpose |
|---|---|
| `helmupgrade.sh` | Helm install / upgrade script — edit variables and run |
| `USAGE.txt` | Full installation guide including prerequisites and verification |
| `SECURITY.md` | RBAC permissions, CIS benchmark controls, vulnerability scan results |
| `TEAMS_LIST_INTEGRATION.md` | Available after onboarding — contact support@saqtek.com |
| `ha/` | High availability deployment (2 replicas + leader election) |

---

## Support

support@saqtek.com
