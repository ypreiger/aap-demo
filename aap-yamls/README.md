# OpenShift / AAP 2.6 manifests

Kubernetes/OpenShift objects for a **bundle** `AnsibleAutomationPlatform` deployment (gateway **Route**, Controller, Hub, **EDA**, **MCP**, optional **Lightspeed** off by default) plus **Tech Preview** `tower.ansible.com` CRs for the [aap-demo](https://github.com/ypreiger/aap-demo) job / workflow chain.

References: [Installing AAP on OpenShift 2.6](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/installing_on_openshift_container_platform/index).

## Apply order

1. **Subscription / operator** (already done in your workshop): `ansible-automation-platform-operator` in namespace `aap`.

2. **Platform instance** (run from the **repository root**, next to the `aap-yamls/` directory)

   ```bash
   oc apply -k aap-yamls/
   ```

   Wait until routes and pods are healthy:

   ```bash
   oc get ansibleautomationplatform -n aap
   oc get routes,pods -n aap
   ```

   Admin password Secret name follows `{metadata.name}-admin-password` (here `demo-aap-admin-password`).

3. **Controller API Secret** used by Resource Operator CRs (`tower.ansible.com`):

   - Copy `secrets/aap-controller-api-secret.example.yaml`, replace `REPLACE_*` values, apply as `Secret/aap-controller-api`.

   Use the **HTTPS Route** for the automation controller/API (from `oc get route -n aap`) unless you intentionally trust the cluster service CA from the operator pods.

4. **Projects / templates / workflow** (after controller project sync works and `Default` organization + **Demo Inventory** exist — enabled via `controller.create_preload_data: true`)

   ```bash
   oc apply -k aap-yamls/tower/
   ```

## Configuration you may need to change

| File | knob |
|------|------|
| `01-ansibleautomationplatform.yaml` | `hub.file_*` storage class / size (`ocs-external-storagecluster-cephfs` assumes ODF CephFS; change if your cluster differs). |
| same | Uncomment `hostname` to pin the gateway Route host under your `*.apps...` domain. |
| same | Lightspeed is `disabled: true`; enable only with valid IBM/auth secrets per product docs. |

## MCP and Lightspeed

- **MCP** is enabled read-only (`allow_write_operations: false`). See chapter *Deploying an Ansible MCP server* in the install guide.
- **Lightspeed** requires IBM watsonx Code Assistant configuration secrets; enable in the CR after you create those secrets ([install guide — Lightspeed](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/installing_on_openshift_container_platform/index)).

EDA and Controller URLs are wired by the platform operator when deployed from the bundled CR; no standalone `EDA` CR is needed for this layout.

## Repository

This folder is tracked in **[ypreiger/aap-demo](https://github.com/ypreiger/aap-demo)** at path **`aap-yamls/`**. From clone root:

```bash
git add aap-yamls
git commit -m "Update OpenShift AAP bundle manifests"
git push origin main
```
