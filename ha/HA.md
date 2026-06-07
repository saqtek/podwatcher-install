# PodWatcher — High Availability Deployment

By default PodWatcher runs as a single replica. This is sufficient for most
clusters — the load test confirmed it handles 100 simultaneous pod crashes at
under 17% memory and 11% CPU.

Run two replicas when your cluster requires zero-downtime monitoring and you
cannot tolerate a missed alert during a pod restart (e.g. node eviction,
rolling node upgrade, or OOMKill of the PodWatcher pod itself).


## How it works

When `replicaCount: 2` is set, leader election must be enabled. Both replicas
run, but only the leader processes events and fires alerts. The standby watches
the same Kubernetes Lease object and promotes itself within 30 seconds if the
leader stops renewing.

The Lease is created in the PodWatcher release namespace and requires the
`coordination.k8s.io/leases` RBAC permission — already present in every
install, scoped to the release namespace only.


## Scale up to 2 replicas

```bash
bash ha-scale-up.sh
```

This enables leader election and increases the replica count to 2 in a single
atomic Helm upgrade. If the upgrade fails it rolls back automatically.

Verify both replicas are running and one has acquired the leader lease:

```bash
kubectl get pods -n podwatcher
kubectl logs -n podwatcher -l app.kubernetes.io/name=podwatcher | grep "is_leader"
```

Expected output — one pod logs `is_leader=true`, the other `is_leader=false`.


## Scale back to 1 replica

```bash
bash ha-scale-down.sh
```

This disables leader election and reduces to a single replica. The Lease object
remains in the namespace but is ignored at runtime.


## Resource considerations

Two replicas double the memory and CPU reservation:

| Replicas | Memory reserved | CPU reserved |
|---|---|---|
| 1 | 512Mi | 400m |
| 2 | 1Gi | 800m |

Peak observed usage per replica is 87Mi / 45m (load test, 100 simultaneous
crashes) — the reservation headroom is intentional.


## Choosing between 1 and 2 replicas

| Scenario | Recommendation |
|---|---|
| Standard production cluster | 1 replica |
| Cluster with uptime SLA for alerting | 2 replicas |
| Air-gapped or resource-constrained cluster | 1 replica |
| Mission-critical / financial / healthcare | 2 replicas |
