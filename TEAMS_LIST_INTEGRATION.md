# PodWatcher — Teams List Integration Guide

**Audience:** Channel partners, customers, junior engineers.
**Time required:** ~45 minutes end to end.
**What you get:** Every PodWatcher alert automatically logged as a row in a
Microsoft Teams tab — filterable, sortable, persistent. Your SRE team sees a
live triage dashboard without needing Kubernetes access.

---

## What this solves

| Without Teams List | With Teams List |
|---|---|
| Alert cards scroll away in Teams chat | Every alert is a permanent, searchable row |
| No shared incident view | Whole team sees all open / resolved alerts in one tab |
| No filtering by namespace, workload, or environment | Filter, sort, group by any column |
| No triage workflow | Status column (Active / Investigating / Resolved) tracks every incident |
| No severity visibility | Priority column (P1 / P2) surfaces critical incidents instantly |
| No time-to-resolve tracking | Incident Opened + Time to Resolve columns track SLA |
| Managers need kubectl access | Anyone with Teams access can view the dashboard |

---

## Prerequisites checklist

Before starting, confirm all of these:

- [ ] PodWatcher Helm chart is deployed on your cluster
- [ ] You have a Microsoft 365 account (Teams + SharePoint — standard Business/Enterprise licence)
- [ ] You have **Member** or **Owner** access to a SharePoint site
- [ ] Python 3.9 or newer is installed on your laptop/workstation
- [ ] You have internet access from the machine running the script

**Not sure about Python version?**
```bash
python3 --version
```
Expected output:
```
Python 3.11.4        ← any 3.9 or higher is fine
```

---

## Step 1 — Install script dependencies

```bash
pip install msal requests
```

Expected output:
```
Collecting msal
  Downloading msal-1.29.0-py3-none-any.whl (99 kB)
Collecting requests
  Downloading requests-2.32.3-py3-none-any.whl (64 kB)
Successfully installed msal-1.29.0 requests-2.32.3
```

> If you see `Successfully installed` at the end — you are good. If you see
> `Requirement already satisfied` for both packages that is also fine.

---

## Step 2 — Run the provisioning script

This script creates the `podwatcher` list on your SharePoint site with all
16 columns. It is safe to re-run — it skips anything that already exists.

**First, identify your SharePoint site base URL.**
This is only the site address — stop before `/Lists` or any `?` parameters.

| Correct | Wrong |
|---|---|
| `https://contoso.sharepoint.com/sites/ITOps` | `https://contoso.sharepoint.com/sites/ITOps/Lists/podwatcher/AllItems.aspx?...` |

**Run the script:**
```bash
python3 podwatcher_testing.py --site https://YOUR-TENANT.sharepoint.com/sites/YOUR-SITE
```

To use a custom list name:
```bash
python3 podwatcher_testing.py --site https://YOUR-TENANT.sharepoint.com/sites/YOUR-SITE --list my-list
```

**What happens next — authentication:**

The terminal prints a device code and a URL:
```
============================================================
To sign in, use a web browser to open the page
https://aka.ms/devicelogin and enter the code ABCD1234 to authenticate.
============================================================
```

1. Open any browser
2. Go to **https://aka.ms/devicelogin**
3. Type the code shown in the terminal (e.g. `ABCD1234`)
4. Sign in with your Microsoft 365 account
5. Click **Continue** when asked to confirm

Switch back to the terminal. The script continues automatically.

**Expected output — success:**
```
[podwatcher] Authenticated successfully.
[podwatcher] Resolving site: https://contoso.sharepoint.com/sites/ITOps
[podwatcher] Site ID: contoso.sharepoint.com,a1b2c3d4-...,e5f6g7h8-...
[podwatcher] Creating list 'podwatcher' ...
[podwatcher] List 'podwatcher' created (ID: 9a8b7c6d-...)
[podwatcher] Provisioning columns ...
[podwatcher]   [+] 'Operational Environment' added.
[podwatcher]   [+] 'Alert Time' added.
[podwatcher]   [+] 'Namespace' added.
[podwatcher]   [+] 'Workload' added.
[podwatcher]   [+] 'Pod' added.
[podwatcher]   [+] 'Node' added.
[podwatcher]   [+] 'Pod Age' added.
[podwatcher]   [+] 'Total Restarts' added.
[podwatcher]   [+] 'Original Reason Value' added.
[podwatcher]   [+] 'Details' added.
[podwatcher]   [+] 'Runtime Evidence' added.
[podwatcher]   [+] 'Incident Opened' added.
[podwatcher]   [+] 'Time to Resolve' added.
[podwatcher]   [+] 'Status' added.
[podwatcher]   [+] 'Priority' added.

[podwatcher] All 16 columns provisioned. (15 added, 0 skipped)
[podwatcher] List URL : https://contoso.sharepoint.com/sites/ITOps/Lists/podwatcher
[podwatcher] Next     : In Teams, open your channel > + Add a tab > Lists > podwatcher
```

> "16 columns" = 15 custom columns + the built-in **Title** column that every
> SharePoint list includes automatically.

**Expected output — re-run (list already exists):**
```
[podwatcher] List 'podwatcher' already exists — skipping list creation.
[podwatcher] Provisioning columns ...
[podwatcher]   [skip] 'Operational Environment' already exists.
...
[podwatcher] All 16 columns provisioned. (0 added, 15 skipped)
```

> `[skip]` lines are normal — it means the columns are already there.

---

## Step 3 — Pin the list as a tab in Teams

1. Open Microsoft Teams
2. Navigate to the channel where PodWatcher alert cards appear
3. Click the **+** icon in the tab bar at the top of the channel
4. In the search box type `Lists` and select the **Lists** app
5. Click **Add an existing list**
6. Under "Select a list from this site" select **podwatcher**
7. Click **Save**

You will now see a **podwatcher** tab next to Posts and Files.
Clicking it shows an empty table — rows appear once the Power Automate flow is running.

---

## Step 4 — Create the Power Automate flow

This flow receives the PodWatcher webhook call, writes each alert as a row in
the SharePoint list, and posts the alert card to the Teams channel.

**Overview of what you are building:**
```
[HTTP Request received]
        ↓
[Apply to each attachment in the webhook body]
        ├─ [SharePoint — Create item in podwatcher list]
        └─ [Teams — Post card in a chat or channel]
```

### 4.1 — Open Power Automate and create a new flow

1. Go to **https://make.powerautomate.com**
2. Sign in with the same Microsoft 365 account
3. In the left sidebar click **+ Create**
4. Click **Automated cloud flow**
5. In the "Flow name" box type: `PodWatcher Alert to List`
6. In the "Choose your flow's trigger" search box type: `HTTP`
7. Select **When a HTTP request is received**
8. Click **Create**

### 4.2 — Configure the HTTP trigger

1. Click on the **When a HTTP request is received** step to expand it
2. Click **Save** (top right) — Power Automate generates the HTTP POST URL
3. The **HTTP POST URL** field is now populated — **copy this URL and save it** (you need it in Step 5)

> The URL looks like:
> `https://prod-xx.westus.logic.azure.com:443/workflows/abc123.../triggers/manual/paths/invoke?...`
> Keep it safe — it is the endpoint PodWatcher calls to send alerts.

### 4.3 — Add the "Apply to each" loop

1. Click **+ New step** below the trigger
2. Search for `Apply to each` and select **Apply to each** (under Control)
3. Click inside the **Select an output from previous steps** box
4. Click the **`fx`** (Expression) tab and paste:
```
triggerBody()?['attachments']
```
5. Click **OK**

> This feeds the attachments array from the webhook payload directly into the loop.

### 4.4 — Add the SharePoint "Create item" action inside the loop

All actions go **inside** the Apply to each loop — click **Add an action** from within the grey loop box.

1. Search for `SharePoint Create item`
2. Select **SharePoint — Create item**
3. In the **Site Address** dropdown select your SharePoint site
4. In the **List Name** dropdown select **podwatcher**

The form now shows all columns. Fill each one using the **`fx`** (Expression) tab.

> **How to enter an expression:**
> Click the field → click the small **`fx`** button (Expression tab) →
> paste the expression → click **OK**.
> Never paste into the Dynamic content tab — it will save the formula as plain text.

| Column | Expression to paste in fx |
|---|---|
| **Title** | `items('Apply_to_each')?['content']?['body']?[2]?['facts']?[2]?['value']` |
| **Operational Environment** | `items('Apply_to_each')?['content']?['body']?[1]?['facts']?[0]?['value']` |
| **Alert Time** | `items('Apply_to_each')?['content']?['body']?[1]?['facts']?[2]?['value']` |
| **Namespace** | `items('Apply_to_each')?['content']?['body']?[2]?['facts']?[0]?['value']` |
| **Workload** | `items('Apply_to_each')?['content']?['body']?[2]?['facts']?[1]?['value']` |
| **Pod** | `items('Apply_to_each')?['content']?['body']?[2]?['facts']?[2]?['value']` |
| **Node** | `items('Apply_to_each')?['content']?['body']?[2]?['facts']?[3]?['value']` |
| **Pod Age** | `items('Apply_to_each')?['content']?['body']?[2]?['facts']?[4]?['value']` |
| **Total Restarts** | `coalesce(items('Apply_to_each')?['content']?['body']?[2]?['facts']?[5]?['value'], '0')` |
| **Original Reason Value** | `items('Apply_to_each')?['content']?['body']?[1]?['facts']?[1]?['value']` |
| **Details** | `items('Apply_to_each')?['content']?['body']?[2]?['facts']?[6]?['value']` |
| **Runtime Evidence** | `string(items('Apply_to_each')?['content']?['body']?[4])` |
| **Incident Opened** | leave blank — SRE fills manually |
| **Time to Resolve** | leave blank — SRE fills manually |
| **Status** | leave blank — defaults to Active automatically |
| **Priority** | leave blank — defaults to P2 automatically |

> **Critical — Total Restarts:** always use `coalesce(..., '0')` exactly as shown.
> Never use `int(...)` on this field — it crashes the flow when the value is null.

> **Alert Time is stored in UTC.** This is intentional — PodWatcher is deployed
> globally across multiple regions and timezones. UTC is unambiguous for all
> customers. Add your local UTC offset to read local time (e.g. UK BST = UTC+1).

> **If your loop was renamed:** Power Automate sometimes names the loop
> `Apply_to_each_1` or `For_each_1`. Check the step title and replace
> `Apply_to_each` in every expression with the exact name shown.

### 4.5 — Add the Teams "Post card" action inside the loop

This posts the full PodWatcher alert card to your Teams channel on every alert.

1. Click **Add an action** inside the loop, after Create item
2. Search for `Post card in a chat or channel`
3. Select it and fill as follows:

| Field | Value |
|---|---|
| **Post as** | Flow bot |
| **Post in** | Channel |
| **Team** | select your team |
| **Channel** | select your alerts channel |
| **Card** | `fx` → `string(items('Apply_to_each')?['content'])` |

### 4.6 — Save and confirm

1. Click **Save** (top right)
2. The flow shows a green banner: **Your flow is ready to use**
3. Click **← Back** to return to the flow detail page
4. Confirm the flow status shows **On**

Expected flow structure when done:
```
✓ When a HTTP request is received
  └─ ✓ Apply to each [triggerBody()?['attachments']]
         ├─ ✓ Create item (podwatcher)
         └─ ✓ Post card in a chat or channel
```

---

## Step 5 — Point PodWatcher at the flow URL

You copied the HTTP POST URL from Step 4.2. Now give it to PodWatcher.

Update your Helm values file or override inline:

```bash
helm upgrade podwatcher podwatcher/podwatcher \
  --reuse-values \
  --set webhook.url="PASTE-YOUR-POWER-AUTOMATE-URL-HERE"
```

Expected output:
```
Release "podwatcher" has been upgraded. Happy Helming!
NAME: podwatcher
STATUS: deployed
```

Confirm the new URL is active:
```bash
helm get values podwatcher | grep webhook
```

Expected output:
```
webhook:
  url: https://prod-xx.westus.logic.azure.com:443/workflows/...
```

---

## Step 6 — Validate end-to-end

### 6.1 — Create a test pod that crashes immediately

```bash
kubectl run pw-test --image=busybox --restart=Always -- /bin/sh -c "exit 1"
```

Watch it crash:
```bash
kubectl get pod pw-test -w
```

Expected output (wait about 60–90 seconds):
```
NAME      READY   STATUS             RESTARTS   AGE
pw-test   0/1     Error              0          3s
pw-test   0/1     CrashLoopBackOff   1          6s
pw-test   0/1     Error              2          20s
pw-test   0/1     CrashLoopBackOff   3          30s   ← PodWatcher fires here
```

Press **Ctrl+C** to stop watching.

### 6.2 — Verify in Teams

1. Open your Teams channel — an alert card should appear within 1–2 minutes
2. Click the **podwatcher** tab — a new row should appear with:
   - Namespace: `default`
   - Pod: `pw-test`
   - Total Restarts: `3` (or higher)
   - Original Reason Value: `CrashLoopBackOff`
   - Status: `Active`
   - Priority: `P2`

### 6.3 — Check Power Automate run history (optional)

1. Go to **https://make.powerautomate.com**
2. Open the `PodWatcher Alert to List` flow
3. Scroll down to **28 day run history**
4. You should see a run with status **Succeeded**

If you see **Failed** — click the run, expand the **Create item** step, check the **Inputs** tab for the error. See Troubleshooting below.

### 6.4 — Clean up the test pod

```bash
kubectl delete pod pw-test
```

---

## Step 7 — Using the triage dashboard

Once alerts are flowing, the SRE team manages incidents directly in the Teams tab.

### Column guide for SREs

| Column | Filled by | Purpose |
|---|---|---|
| Title | Flow (auto) | Pod name that failed |
| Status | SRE (manual) | Active / Investigating / Resolved |
| Priority | SRE (manual) | P1 = critical, P2 = warning |
| Alert Time | Flow (auto) | UTC timestamp when alert fired |
| Original Reason Value | Flow (auto) | CrashLoopBackOff, OOMKilled, Error etc. |
| Namespace | Flow (auto) | Kubernetes namespace |
| Workload | Flow (auto) | Deployment / StatefulSet / DaemonSet |
| Pod | Flow (auto) | Full pod name |
| Node | Flow (auto) | Kubernetes node |
| Pod Age | Flow (auto) | How long the pod had been running |
| Total Restarts | Flow (auto) | Restart count |
| Operational Environment | Flow (auto) | Cluster name |
| Details | Flow (auto) | Alert summary |
| Runtime Evidence | Flow (auto) | Last log lines from the container |
| Incident Opened | SRE (manual) | When the SRE picked it up |
| Time to Resolve | SRE (manual) | Duration from open to resolution |

### SRE triage workflow

When a new alert fires the row appears with **Status = Active** automatically.

1. Open the row → set **Status** to `Investigating`
2. Set **Priority** to `P1` if service is down, leave `P2` otherwise
3. Fill **Incident Opened** with the current time
4. Investigate using the Namespace, Workload, Pod, and Runtime Evidence columns
5. Fix the issue
6. Set **Status** to `Resolved`
7. Fill **Time to Resolve** (e.g. `45 mins`)

---

## Step 8 — Set up automatic list cleanup (90-day retention)

**Why:** Alert rows accumulate daily. Without cleanup the list grows indefinitely.
90 days covers a full quarter for post-mortems — older rows have no operational value.

**Cost:** Zero. This uses a scheduled Power Automate flow on your existing M365 licence.

**How it works:**
```
[Every Sunday at midnight UTC]
        ↓
[Get all podwatcher rows older than 90 days]
        ↓
[Apply to each — Delete item]
```

### 8.1 — Create the cleanup flow

1. Go to **https://make.powerautomate.com**
2. Click **+ Create** → **Scheduled cloud flow**
3. Fill in:
   - **Flow name:** `PodWatcher List Cleanup`
   - **Repeat every:** `1` **Week**
   - **On these days:** check **Sunday** only
4. Click **Create**

### 8.2 — Add the "Get items" action

1. Click **+ New step** → search `SharePoint Get items` → select **SharePoint — Get items**
2. Fill in:
   - **Site Address:** your SharePoint site
   - **List Name:** `podwatcher`
3. Click **Show advanced options**
4. In the **Filter Query** box paste:
```
Created lt '@{addDays(utcNow(), -90)}'
```
5. In **Top Count** type `5000`

### 8.3 — Add the "Apply to each" delete loop

1. Click **+ New step** → search `Apply to each` → select **Apply to each**
2. In **Select an output from previous steps** click **value** from Get items
3. Click **Add an action** inside the loop
4. Search `SharePoint Delete item` → select **SharePoint — Delete item**
5. Fill in:
   - **Site Address:** your SharePoint site
   - **List Name:** `podwatcher`
   - **Id:** Dynamic content → **ID** (from Get items)

### 8.4 — Save and turn on

1. Click **Save**
2. Confirm flow status shows **On**

Expected flow structure:
```
✓ Recurrence (Weekly, Sunday)
  └─ ✓ Get items (podwatcher, Created lt 90 days ago)
       └─ ✓ Apply to each [value]
                └─ ✓ Delete item (podwatcher, ID)
```

### Retention policy summary

| Period | What happens |
|---|---|
| 0–90 days | Row stays in the list — visible in Teams tab |
| After 90 days | Automatically deleted every Sunday night |
| Quarterly review | Export to Excel before day 90 to archive |

> **To export before deletion:** In the Teams podwatcher tab click
> **Export to Excel** (top toolbar) at any time to save a snapshot.

---

## Troubleshooting

### Teams card appears but no list row

The flow ran but Create item failed.

1. Power Automate → your flow → **Run history** → click the **Failed** run
2. Expand **Create item** → click **Inputs** tab

Common causes:

| Error message | Fix |
|---|---|
| `int() cannot convert` | Total Restarts field — remove `int()`, use `coalesce(..., '0')` |
| `Required field Title is empty` | Title expression returned null — use `coalesce(..., 'unknown')` |
| `Column does not exist` | Column name in expression does not match SharePoint exactly |
| `Access denied to SharePoint` | Flow connection account needs Member access to the site |
| `InvalidTemplate` | Create item is outside the loop — move it inside the Apply to each grey box |

### No Teams card and no list row

PodWatcher has not fired yet or cannot reach the webhook URL.

```bash
kubectl logs -l app=podwatcher --tail=50
```

Look for lines containing `webhook` or `error`. Connection refused or 404 means the webhook URL is wrong.

### Script error: `Could not resolve site ID`

The `--site` URL is wrong. Use only the base site URL:

```
# Wrong
--site https://contoso.sharepoint.com/sites/ITOps/Lists/podwatcher

# Correct
--site https://contoso.sharepoint.com/sites/ITOps
```

### Script error: `Device flow failed`

Your account does not have consent for the Microsoft Graph Command Line Tools app.
Ask your Microsoft 365 administrator to grant `Sites.Manage.All` consent, or run
the script as a user with SharePoint admin rights.

### Expression saves as plain text in the list

You pasted into the **Dynamic content** tab instead of the **`fx`** (Expression) tab.
Clear the field, click `fx`, paste the expression, click **OK**.

---

## Reference — All 16 columns

| Column | Type | Filled by | Description |
|---|---|---|---|
| Title | Text (built-in) | Flow | Pod name — list item title |
| Operational Environment | Text | Flow | Cluster / environment name |
| Alert Time | Text | Flow | UTC timestamp when alert fired |
| Namespace | Text | Flow | Kubernetes namespace |
| Workload | Text | Flow | Deployment / StatefulSet / DaemonSet name |
| Pod | Text | Flow | Full pod name |
| Node | Text | Flow | Kubernetes node the pod ran on |
| Pod Age | Text | Flow | How long the pod had been running |
| Total Restarts | Text | Flow | Restart count — text type to avoid int() errors |
| Original Reason Value | Text | Flow | CrashLoopBackOff, OOMKilled, Error etc. |
| Details | Multiline Text | Flow | Alert summary paragraph |
| Runtime Evidence | Multiline Text | Flow | Last log lines from the crashing container |
| Incident Opened | Text | Manual | When the SRE acknowledged the incident |
| Time to Resolve | Text | Manual | Duration from open to resolution — SLA tracking |
| Status | Choice | Manual | Active / Investigating / Resolved — defaults to Active |
| Priority | Choice | Manual | P1 / P2 — defaults to P2 |
