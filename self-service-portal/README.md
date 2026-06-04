# Ansible automation portal (self-service) — GitOps on OpenShift

Deploy the **Ansible automation portal** (self-service automation UI) into the **`aap`** namespace using **OpenShift GitOps (Argo CD)** and the certified Helm chart **`redhat-rhaap-portal`** from [charts.openshift.io](https://charts.openshift.io/).

| Item | Value (this demo cluster) |
|------|---------------------------|
| Helm chart | `redhat-rhaap-portal` **2.2.0** |
| Helm release name | `aap-portal` |
| Target namespace | `aap` |
| Argo CD Application | `aap-self-service-portal` in `openshift-gitops` |
| Portal URL (after sync) | `https://aap-portal-rhaap-portal-aap.apps.<cluster-domain>/` |
| Argo CD UI | `https://openshift-gitops-server-openshift-gitops.apps.<cluster-domain>/` |

## Repository layout

```
self-service-portal/
├── README.md                 # This guide
├── argocd/
│   └── application.yaml      # Argo CD Application (multi-source: chart + Git values)
├── helm/
│   ├── values.yaml           # Cluster-specific values (safe to commit — no secrets)
│   └── values.example.yaml   # Template for other clusters
├── catalog/
│   └── openshift-virtualization-location.yaml  # Red Hat OCP Virt scaffolder templates
├── openshift/
│   ├── secrets-rhaap-portal.example.yaml
│   └── dynamic-plugins-registry-auth.example.yaml
└── scripts/
    ├── bootstrap-secrets.sh           # Create secrets in aap (required)
    ├── create-aap-oauth-and-token.sh  # Optional: auto-create OAuth + token
    ├── deploy-gitops.sh               # Apply Application and print URLs
    ├── label-virt-workflow-templates.sh  # API labels on virt workflows
    └── refresh-aap-catalog-sync.sh    # Nudge job-template + Hub collection sync
```

## OpenShift Virtualization templates

Two template sources appear in the portal after sync:

### 1. AAP Controller workflows (recommended for this demo)

Survey-driven **workflow job templates** from [`aap-yamls/tower/`](../aap-yamls/tower/) sync into **Self-Service → Create Task** when `jobTemplates.enabled` is true (chart default):

| Template | Purpose |
|----------|---------|
| `bom-project-deploy` | BOM foundation → approval → Fedora VMs on OpenShift Virtualization |
| `workshop-multi-domain` | Virt + approval + mock F5/VMware/BlueCoat integrations |

Virt-related **job** templates use tower CR `spec.labels`. **Workflow** templates need API labels (WorkflowTemplate CR does not accept label arrays):

```bash
oc apply -k aap-yamls/tower/
chmod +x self-service-portal/scripts/label-virt-workflow-templates.sh
./self-service-portal/scripts/label-virt-workflow-templates.sh
./self-service-portal/scripts/refresh-aap-catalog-sync.sh
```

Survey field reference: [documentation/09_VIRT_WORKFLOW_SURVEY.md](../documentation/09_VIRT_WORKFLOW_SURVEY.md).

### 2. Red Hat RHEL 9 VM scaffolder templates (GitOps)

Reference templates from [rh-mad-workshop/coolstore-software-templates](https://github.com/rh-mad-workshop/coolstore-software-templates/tree/demo-vm/scaffolder-templates) are registered via [`catalog/openshift-virtualization-location.yaml`](catalog/openshift-virtualization-location.yaml) and `helm/values.yaml` catalog locations:

- **RHEL9 VM Medium** / **RHEL9 VM Large** — KubeVirt VM + GitOps repo flow
- **Tomcat VM** — legacy app on RHEL VM (workshop pattern)

These use `publish:gitlab` and `argocd:create-resources` actions. For a full create flow you need GitLab OAuth in `secrets-scm` and Argo CD integration; otherwise use the AAP workflows above.

## Automation Hub collections

**Self-Service → Collections** lists Ansible collections synced from **Automation Hub** repositories on your AAP gateway. The chart ships with `pahCollections` **disabled**; this demo enables it in [`helm/values.yaml`](helm/values.yaml) for:

| Hub repository | Content |
|----------------|---------|
| **community** | 13 collections mirrored from [`collections/requirements.yml`](../collections/requirements.yml) (`kubernetes.core`, `community.kubevirt`, `f5networks.f5_modules`, …) |
| **published** | Red Hat certified collections synced into Hub |

If Hub **Collections** is empty, mirror community content first:

```bash
# From repo root — see documentation/02_COLLECTION_HUB.md
./scripts/hub-sync-community-from-requirements.sh
```

After GitOps sync (or Helm upgrade), trigger a catalog refresh:

```bash
./self-service-portal/scripts/refresh-aap-catalog-sync.sh
```

**Helm merge note:** enable `pahCollections` under the chart’s templated environment key — `'{{- include "catalog.providers.env" . }}':` — **not** a duplicate bare `production:` block (that breaks merged `app-config` and can CrashLoop `backstage-backend`).

Collection discovery uses `ansible.rhaap.baseUrl` / `aap-token` from `secrets-rhaap-portal` (same as job-template sync). See [Red Hat: collection discovery sources](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/html/develop-proc_configure_github_app_ee_builder#configure-collection-discovery-sources).

## Prerequisites

1. **OpenShift GitOps** operator installed (`ArgoCD` instance `openshift-gitops` in `openshift-gitops`).
2. **Ansible Automation Platform** running in namespace `aap` (gateway route, e.g. `demo-aap`).
3. **Registry access** to `registry.redhat.io` (cluster pull secret is enough for the OCI plugin init container).
4. **Helm chart compatibility**: AAP **2.7** with portal chart **2.2.0** and `imageTagInfo: "2.2"` (see [lifecycle documentation](https://access.redhat.com/support/policy/updates/ansible-automation-platform)).
5. Git repo **`https://github.com/ypreiger/aap-demo`** reachable from the cluster (public repo, or register credentials in Argo CD).

## Quick deploy (bullet-proof order)

```bash
cd self-service-portal
chmod +x scripts/*.sh

# 1) Edit helm/values.yaml — set global.clusterRouterBase to YOUR apps domain:
#    oc get ingresscontroller cluster -o jsonpath='{.status.domain}{"\n"}'
#    Example: apps.cluster-jx4b7.dynamic.redhatworkshops.io

# 2) Secrets (choose A or B)
# A — Manual: create OAuth app in AAP UI, then:
export AAP_HOST_URL='https://demo-aap-aap.apps.<cluster>'
export OAUTH_CLIENT_ID='...'
export OAUTH_CLIENT_SECRET='...'
export AAP_TOKEN='...'   # Gateway personal access token (read+)
./scripts/bootstrap-secrets.sh

# B — Automated (cluster admin password in demo-aap-admin-password):
eval "$(./scripts/create-aap-oauth-and-token.sh)"
./scripts/bootstrap-secrets.sh

# 3) Push this directory to GitHub (main branch) so Argo can load values.yaml

# 4) GitOps deploy
./scripts/deploy-gitops.sh
```

## AAP configuration (required)

1. **OAuth application** (Platform gateway → Applications):
   - **Redirect URI** (exact):  
     `https://aap-portal-rhaap-portal-aap.<your-apps-domain>/api/auth/rhaap/handler/frame`
   - Use the client ID/secret in `secrets-rhaap-portal`.

2. **Allow external users to create OAuth2 tokens**  
   Settings → Platform gateway → **Enabled**  
   (or `PUT /api/gateway/v1/settings/oauth2_provider/` with `ALLOW_OAUTH2_FOR_EXTERNAL_USERS: true`).

3. **Personal access token** for catalog sync (`aap-token` in `secrets-rhaap-portal`): create under the admin user in the gateway; **read** scope minimum.

4. **Organization**: chart default is `Default` (`catalog.providers.rhaap` in chart values). Override `pahCollections` only via the templated `'{{- include "catalog.providers.env" . }}':` key in `values.yaml` — not a bare `production:` block.

## Secrets (exact names)

| Secret | Keys | Purpose |
|--------|------|---------|
| `secrets-rhaap-portal` | `aap-host-url`, `oauth-client-id`, `oauth-client-secret`, `aap-token` | AAP auth for portal |
| `aap-portal-dynamic-plugins-registry-auth` | `auth.json` | Pull OCI plugins from `registry.redhat.io` when `pluginMode: oci` |

Optional: `secrets-scm` (`github-token`, `gitlab-token`) for SCM templates — not required for basic portal login.

## Argo CD Application

Multi-source pattern:

- **Source 1**: Helm chart `redhat-rhaap-portal` @ `https://charts.openshift.io` (version `2.2.0`).
- **Source 2**: Git `ref: values` → `self-service-portal/helm/values.yaml`.

Apply manually:

```bash
oc apply -f argocd/application.yaml
```

Verify:

```bash
oc get application aap-self-service-portal -n openshift-gitops
oc get pods -n aap -l app.kubernetes.io/instance=aap-portal
oc get route aap-portal-rhaap-portal -n aap
```

## Helm values (important fields)

```yaml
redhat-developer-hub:
  global:
    clusterRouterBase: apps.<cluster-domain>   # REQUIRED — not apps.example.com
    pluginMode: oci                            # recommended
    imageTagInfo: "2.2"                        # must match chart 2.2.0 lifecycle
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Argo **Unknown** revision / cannot clone Git | Push `self-service-portal/` to `main`; check repo URL in `application.yaml`. |
| Init container **ImagePullBackOff** on plugins | Recreate `aap-portal-dynamic-plugins-registry-auth` (`bootstrap-secrets.sh`). |
| Portal login fails | OAuth redirect URI must match Route host; enable external OAuth2 tokens. |
| Catalog empty | Check `aap-token` and `orgs` in values; gateway URL in `aap-host-url`. |
| Collections empty | Hub **community** repo populated (`hub-sync-community-from-requirements.sh`); `pahCollections.enabled: true` in values; run `refresh-aap-catalog-sync.sh`. |
| Backend **password authentication failed for user postgres** | PostgreSQL started after the first backend attempt. Delete `data-aap-portal-postgresql-0` PVC and portal pods; Argo resync recreates a clean DB. |
| Init container **Evicted** (ephemeral-storage) | Scale portal deployment to 1 replica during install; avoid parallel rollouts on small nodes. |
| `clusterRouterBase` validation error | Use full apps domain from `ingresscontroller cluster`. |

## Uninstall

```bash
oc delete application aap-self-service-portal -n openshift-gitops
# Optional: remove secrets and release resources
oc delete secret secrets-rhaap-portal aap-portal-dynamic-plugins-registry-auth -n aap
```

## References

- [Install Ansible automation portal Helm chart (AAP 2.7)](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/extend-assembly_self_service_helm_install)
- [OCI container delivery](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/extend-proc_self_service_oci_container_delivery)
- Chart: `redhat-rhaap-portal` on [OpenShift Helm charts](https://charts.openshift.io/)
