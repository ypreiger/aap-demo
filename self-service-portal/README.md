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
├── openshift/
│   ├── secrets-rhaap-portal.example.yaml
│   └── dynamic-plugins-registry-auth.example.yaml
└── scripts/
    ├── bootstrap-secrets.sh           # Create secrets in aap (required)
    ├── create-aap-oauth-and-token.sh  # Optional: auto-create OAuth + token
    └── deploy-gitops.sh               # Apply Application and print URLs
```

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

4. **Organization**: default `Default` in `helm/values.yaml` (`catalog.providers.rhaap.production.orgs`).

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
