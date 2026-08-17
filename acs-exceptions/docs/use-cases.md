# Customer Use Cases — Delivery Assessment on AAP 2.6

Temporary ACS policy exceptions via Ansible Automation Platform. Session assistant document converted from the delivery-assessment source, with presenter steps aligned to this demo.

This demo is self-service, time-bounded **RHACS policy exclusions** driven by **AAP 2.6**. Policies are **never disabled or deleted**. Validation is **fail-closed**: any doubt in RBAC, allowlist, duration, or ACS reachability is a rejection, not a pass. The survey is convenience; the workflow is the control.

For each customer use case: what can be delivered with AAP 2.6, what should be reconsidered to avoid platform limitations, and (where the source had one) the related best practice. Short by design — supporting material for the session, not the full working document.

**Related:** [demo-runbook.md](demo-runbook.md) (20-minute script) · [acs-exception-architecture.md](acs-exception-architecture.md) · [environment.md](environment.md)

## Demo facts (this cluster)

| Item | Value |
|------|-------|
| Workflow | `WF-Temporary-ACS-Policy-Exception` |
| Portal Create Task | `Temporary ACS Policy Exception` (job template; the portal catalogs AAP **job templates**, not workflows. This launcher starts the workflow and returns immediately so SRE approval is not blocked in the form.) |
| AAP gateway | `https://demo-aap-aap.apps.ocp.7hrxw.sandbox880.opentlc.com` |
| Self-service portal | `https://aap-portal-rhaap-portal-aap.apps.ocp.7hrxw.sandbox880.opentlc.com/` |
| ACS Central | `https://central-acs.apps.ocp.7hrxw.sandbox880.opentlc.com` |
| Namespaces | `demo-app` (alice is Admin), `demo-restricted` (no demo Admin) |
| Allowlisted policies | `Kubernetes Actions: Exec into Pod`, `Privileged Container` |
| Duration list | 5 / 10 / 15 / 30 / 60 minutes |
| Requesters (Execute) | `alice`, `bob`, `carol` |
| Approver | `sre-approver` (AAP local user; team `SRE-Approvers`; Approve on this workflow only). Approvals: `{AAP_URL}/#/workflow_approvals` — not the portal. Passwords: `acs-exceptions/.env`. |

Identity on this cluster: OpenShift OAuth is OpenID (`rhbk`), not htpasswd. Matching **AAP local users** share the same usernames so JT-01 RBAC is authoritative. Verification can also use `oc --as=<user>`.

---

## UC-1 — Self-Service Exception Request

**Customer use case.** A namespace administrator opens a request with namespace, policy, duration and business justification through the AAP self-service portal.

### Deliverables

What can be delivered (AAP 2.6) — and what this demo built:

- A workflow template with a survey: namespace, policy, duration from the closed list (5/10/15/30/60 min), mandatory justification, optional ticket number. Required fields enforced at submission.
- Access controlled by AAP RBAC — only authorized users can launch the request.
- A request summary (namespace, duration, expected window, justification) shown to the approver.
- **Built here:** survey on `WF-Temporary-ACS-Policy-Exception` (`aap-config/workflows.yml`). Portal **Create Task** lists job template `Temporary ACS Policy Exception`, which launches that workflow via `playbooks/portal-launch-workflow.yml` and returns so the form is not blocked on SRE approval. Execute role is granted to `alice` / `bob` / `carol`.

### Limitations

To reconsider (avoiding limitations):

- AAP survey fields are static — the form cannot build a per-user namespace list at render time. Keep the namespace field as a choice list refreshed periodically by a small scheduled job (or free text), and treat the form as convenience: the authoritative checks run inside the workflow (UC-2).
- Free-text duration is excluded by design: the survey offers only the closed list, and the workflow re-validates it.

**This demo:** JT-00 (`JT-00-Refresh-Survey`) re-applies the **closed** namespace list `demo-app` / `demo-restricted` (it does not dump every cluster namespace). JT-01 decides eligibility. The portal does **not** query OpenShift live per user.

**Best practice.** Re-validate every survey input server-side in the first workflow step — never trust the form alone.

**Optional enhancement (Phase 2).** A front-end portal in front of AAP removes the static-form compromise: it can query OpenShift live per user, display only the namespaces the requester administers and only allowlisted policies, then launch the workflow via the Controller API. Options: a thin self-developed web app (maximum flexibility — but a new customer-owned component with its own hosting, security and maintenance), a ServiceNow catalog item (out of Phase 1 scope by the customer's own spec), or the AAP self-service automation portal / Red Hat Developer Hub (evaluate maturity in the customer's version). In all cases the workflow-side validation (UC-2) remains the authoritative security control — the portal only improves the experience.

This cluster already has the Ansible automation portal. It catalogs job templates and launches the workflow; it does **not** filter namespaces per user at render time.

### How to demonstrate

1. Open the self-service portal as **alice** → **Create Task** → **Temporary ACS Policy Exception**.
2. Show the form: namespace (`demo-app` / `demo-restricted`), policy (two allowlisted names only), duration `5/10/15/30/60`, mandatory justification (**minimum 10 characters**), optional ticket.
3. Optionally show the same survey on the AAP gateway under workflow **WF-Temporary-ACS-Policy-Exception**.
4. Say: *"The form is convenience; the workflow is the control."*

---

## UC-2 — Namespace Eligibility Validation

**Customer use case.** Before approval or execution, verify the requester holds Admin-level permission for the selected namespace; view/edit-only users must be stopped.

### Deliverables

- A validation job (JT-01) as the first workflow node: it takes the authenticated launching user from AAP, and checks live OpenShift RBAC (RoleBindings, ClusterRoleBindings, LDAP/AD-synced groups) via SubjectAccessReview.
- Non-eligible requests stop before the approval step: no approval email, no ACS change, requester notified, attempt logged.
- **Built here:** `playbooks/jt01-validate-namespace-rbac.yml`. Admin-level roles are `admin`, `project-admin`, `cluster-admin` (`vars/admin_roles.yml`). Fixtures: **alice** is `admin` on `demo-app`; **bob** is `view` on `demo-app`. Failure status `rejected_rbac`; no ACS mutation.

### Limitations

- Identity mapping is the prerequisite: AAP 2.6 (platform gateway) and OpenShift must authenticate against the same directory so usernames match one-to-one.
- Group-based permissions are only as fresh as the LDAP → OpenShift group sync — confirm its cadence.
- Agree the definitive list of roles that count as “Admin-level” (admin, project-admin, named organization roles).

**This demo:** the cluster IdP is OpenID (`rhbk`), not a shared LDAP/htpasswd. AAP **local users** `alice` / `bob` / `carol` match OpenShift `User` objects. Group sync cadence is not demonstrated. Fail closed: any doubt in the RBAC evaluation is a rejection, not a pass.

**Best practice.** Fail closed: any doubt in the RBAC evaluation is a rejection, not a pass.

### How to demonstrate

1. As **bob**, launch **Temporary ACS Policy Exception** (portal or workflow) for namespace `demo-app`, policy `Kubernetes Actions: Exec into Pod`, duration 5, a justification of 10+ characters.
2. JT-01 fails before the approval node. Message: `User bob is not authorized for namespace demo-app: Admin-level permission required.`
3. Show audit status `rejected_rbac` under `acs-exceptions/audit/`. Confirm ACS exclusions are unchanged.
4. Optionally: as **alice**, request `demo-restricted` — same RBAC rejection (alice is not Admin there).

---

## UC-3 — No Eligible Namespace Handling

**Customer use case.** A user with no Admin-level namespace must be blocked from opening a request, with a clear message.

### Deliverables

- The same validation step detects the user has no eligible namespace, stops the workflow, and returns the customer's exact message: “No namespaces with Admin permissions were found. An ACS policy exception request cannot be opened.”
- The failed attempt is written to the audit record.
- **Built here:** JT-01 UC-3 path (`rejected_no_eligible_namespace`). Persona **carol** has no Admin RoleBinding.

### Limitations

- The spec places this block at the form; with static surveys it happens one step later, at validation — same business outcome (the user can never proceed), same message, plus an audit entry the form-level block would not produce.

### How to demonstrate

1. As **carol**, launch **Temporary ACS Policy Exception** for `demo-app` (any allowlisted policy).
2. JT-01 fails with the exact message: `No namespaces with Admin permissions were found. An ACS policy exception request cannot be opened.`
3. Show the audit record for that request. No approval node, no ACS change.

---

## UC-4 — Temporary Terminal Access Exception

**Customer use case.** During an incident, a namespace admin needs terminal access that ACS blocks; a temporary, namespace-scoped exception is requested.

### Deliverables

- The full workflow (validate → approve → apply → scheduled rollback) with the Terminal Access policy — in ACS terms typically “Kubernetes Actions: Exec into Pod”.
- The exception is a namespace-scoped exclusion on that policy only; enforcement for every other namespace is untouched; exec is blocked again the moment the exception expires.
- **Built here:** end-to-end on this cluster. Exclusion name `AAPEX-<date>-<hex> <namespace>`. Runtime enforcement `FAIL_KUBE_REQUEST_ENFORCEMENT` is enabled by fixtures (original enforcement on this Central was `[]`).

### Limitations

- Confirm the exact policy name and its enforcement mode in the customer's Central before delivery — the demoable effect (exec blocked / allowed / blocked) requires runtime enforcement to be enabled.

**This demo (ACS 4.11.2):** namespace-scoped kube-event exclusions must use empty `deployment.scope.cluster`. Setting `cluster: ocp-sandbox880` did not unblock `oc exec`. JT-02 writes `cluster: ""` plus the target namespace so the customer outcome (namespace-scoped exception) still holds. See [environment.md](environment.md) and [manual-steps.md](manual-steps.md).

**Best practice.** Runtime policies restore cleanly: sessions are point-in-time, so rollback needs no cleanup for this use case.

### How to demonstrate

Incident story: production issue in `demo-app`; namespace admin needs `oc exec` to collect logs.

1. Show ACS policy **Kubernetes Actions: Exec into Pod** with `FAIL_KUBE_REQUEST_ENFORCEMENT`.
2. `oc exec -n demo-app deploy/nginx -- date` is **blocked** (webhook `k8sevents.stackrox.io`).
3. As **alice**, launch **Temporary ACS Policy Exception**: namespace `demo-app`, policy `Kubernetes Actions: Exec into Pod`, duration **5**, justification filled.
4. As **sre-approver**, open AAP Approvals (`#/workflow_approvals`) and **Approve**.
5. ACS shows exclusion `AAPEX-… demo-app` with empty `deployment.scope.cluster` and namespace `demo-app`. `oc exec` in `demo-app` **succeeds**. In `demo-restricted` it stays **blocked**.
6. Wait for expiry (~5 minutes). Schedule `AAPEX-rollback-<id>` fires; exclusion gone; exec blocked again.

---

## UC-5 — Temporary Privileged Container Exception

**Customer use case.** A namespace admin needs to run a privileged container for approved maintenance; ACS blocks the deployment.

### Deliverables

- The same workflow with “Privileged Container” as a second allowlisted policy, added after technical validation as the customer document requires.
- Admission/deploy-time enforcement is lifted for the namespace only, and restored automatically at expiry.
- **Built here:** policy is allowlisted; fixtures enable `FAIL_DEPLOYMENT_CREATE_ENFORCEMENT`. JT-03 queries residual ACS alerts for the namespace and records them on the audit / notification (not auto-delete).

### Limitations

- Enforcement restoration is not retroactive: a privileged workload deployed during the window keeps running after expiry. Add a residual-violation report at rollback (what now violates the policy) to the completion notification, so SRE gets an explicit follow-up list.
- Automated deletion of such workloads is possible but destructive — recommended to keep it out of Phase 1.

**This demo:** residual report is best-effort (`playbooks/jt03-rollback-acs-exception.yml`). Workloads are **not** auto-deleted. On this cluster, raw Pod create was not always denied by ACS (PSS also warns); the live block/unblock proof used in verification is the exec policy (UC-4). Prefer `oc apply -f demo/privileged-deploy.yaml` as the intended admission story, and fall back to the exec path if admission does not deny.

### How to demonstrate

1. `oc apply -f demo/privileged-deploy.yaml` — expected: admission **blocked** (or PSS warn if ACS does not deny the raw Pod on this cluster).
2. As **alice**, run the same request with policy **Privileged Container**, duration 10. **sre-approver** Approves.
3. Re-apply the manifest → pod runs in `demo-app`.
4. After expiry, a **new** apply is blocked; the pod started during the window is still running. Show JT-03 residual list. Optionally delete the pod as SRE follow-up (`oc delete pod privileged-demo -n demo-app`).

---

## UC-6 — Approval Workflow

**Customer use case.** After validation, the request is routed to the SRE department for approval; approved continues, rejected stops, timeout cancels.

### Deliverables

- An AAP workflow approval node: the SRE team receives an email with requester, namespace, policy, duration and justification, and a direct link to approve or deny; every decision is recorded with actor and timestamp.
- Timeout is configurable on the node: expired approvals cancel the request and notify the requester, exactly as specified.
- **Built here:** node `Approval-Node-SRE`, timeout **3600** seconds. Team `SRE-Approvers` has Approve on this workflow only. Deny/timeout writes audit `rejected_approval`. Deep link: `{AAP_URL}/#/workflow_approvals`.

### Limitations

- The approve/deny action is performed in AAP by an authenticated user holding the Approve role — there is no anonymous one-click approval from the email itself. Approvers therefore need AAP accounts (one team, Approve role on this workflow only). Position this as a strength: every approval is authenticated and auditable.
- Agree the timeout value in session (it also defines how long a request may wait before the window can start).

**This demo:** notifications on this cluster append to `audit/notifications.log` when SMTP is unset (see UC-10). There is no mailto approve link.

**Best practice.** Keep the Approve role on the SRE team only, scoped to this one workflow.

### How to demonstrate

1. As **alice**, submit a valid `demo-app` request and stop at the approval node.
2. As **sre-approver**, open `https://demo-aap-aap.apps.ocp.7hrxw.sandbox880.opentlc.com/#/workflow_approvals`. Show namespace, policy, duration, justification in context.
3. **Deny** one request → ACS unchanged; audit `rejected_approval`.
4. Submit again and **Approve** → JT-02 runs. Mention the 1-hour node timeout (do not wait it out in a short demo).

---

## UC-7 — Apply the ACS Namespace Exception

**Customer use case.** After approval, AAP performs the change in ACS, limited strictly to the selected namespace.

### Deliverables

- An apply job (JT-02) using a managed AAP credential for the ACS API: it verifies the policy is on the approved allowlist, appends a single exclusion entry scoped to cluster + namespace and named after the Request ID, then reads the policy back to verify before reporting success.
- Global disablement is unreachable: the job can only add/remove its own exclusion entry — it never disables a policy and never touches other namespaces.
- **Built here:** `roles/acs_exception` GET / append / verify. Request ID in the exclusion name (`AAPEX-…`). Allowlist in `vars/policy_allowlist.yml`.

### Limitations

- ACS has no native expiring exception for policy enforcement — the expiry is owned end-to-end by AAP (UC-8). An exception without a scheduled end is structurally impossible in this design.
- If any allowlisted policy is managed as code (GitOps / policy CRs), reconciliation would silently revert the exclusion — confirm these policies are API-managed before delivery.
- Never snapshot-and-restore whole policy objects; add/remove only the request-tagged entry, so concurrent exceptions on the same policy stay independent.

**This demo:** both demo policies are `IMPERATIVE` (API-managed). Exclusion scope uses empty `cluster` + namespace (UC-4 note). Fixtures never disable or delete policies.

**Best practice.** The Request ID inside the exclusion name is what makes every ACS-side change traceable to a request, approval and audit record.

### How to demonstrate

1. After an approved UC-4 request, open ACS Central → policy **Kubernetes Actions: Exec into Pod** → exclusions.
2. Point to `AAPEX-<date>-<hex> demo-app` only. Show `demo-restricted` still enforced (`oc exec -n demo-restricted deploy/nginx -- date` denied).
3. State: the job never disables the policy and never edits other namespaces' exclusions.

---

## UC-8 — Automatic Rollback

**Customer use case.** When the approved duration ends, the exception is removed automatically, original behavior restored and verified.

### Deliverables

- At apply time, a one-time AAP schedule is created for the expiry moment, carrying the Request ID (no long-running “sleep” job — exactly as the customer document requires).
- The rollback job (JT-03) removes only its own exclusion entry, verifies restoration by reading the policy back, updates the audit record, and notifies requester and approver.
- On rollback failure: automatic retries, immediate operations alert, and a visible failed status in the audit — never silent.
- **Built here:** JT-04 creates one-shot schedule `AAPEX-rollback-<request_id>`. JT-03 removes only that tagged exclusion and verifies absent. JT-06 (`JT-06-reconcile-every-5-min`) is the AC-08 safety net.

### Limitations

- Schedule granularity is one minute and a run can be delayed if the controller is busy or down — so a single timer is not a guarantee. Add a small reconciler job (every ~5 minutes) that force-removes any exception past its expiry and alerts operations. This is what makes “no uncontrolled exception left active” (AC-08) provable.
- Expect ±1 minute accuracy; on a 5-minute window that is visible — the audit record stores the actual timestamps, which are the compliance truth.
- The window starts when the exception is applied (after approval), not at submission — otherwise slow approvals consume the window.

**Best practice.** Schedule + reconciler is the standard pattern; Event-Driven Ansible (included in AAP 2.6) is an optional future alternative, not needed for Phase 1.

### How to demonstrate

1. After an approved 5-minute exception, show Controller schedule `AAPEX-rollback-<id>` (not a sleeping job).
2. Wait until expiry. JT-03 runs; ACS exclusion gone; `oc exec` blocked again. Audit `status=completed`, history includes `rollback_completed`.
3. **AC-08 (optional):** JT-06 (`JT-06-reconcile-every-5-min`) removes `AAPEX-*` exclusions whose `expiration` is in the past. It will **not** delete an unexpired window. To show the safety net, wait until after expiry with the rollback schedule deleted.

---

## UC-9 — Audit Trail and Compliance Record

**Customer use case.** Every request, approval, execution and rollback is recorded persistently for security and compliance review.

### Deliverables

- An audit job (JT-05) called at every lifecycle event, writing all specified fields: Request ID, requester, approver, namespace, policy, start/end time, justification, statuses, failure reason.
- Backend per the customer's choice: Git repository (immutable, timestamped history — simplest for the pilot) or a database; ServiceNow/CMDB later.
- **Built here:** JSON is printed in the AAP job output (the live demo artifact). A best-effort ConfigMap is written in namespace `aap-demo` (`oc get cm -n aap-demo -l aapex=audit`) when the OpenShift credential is attached. Git push of `acs-exceptions/audit/` happens only when `GIT_TOKEN` is set. AAP job workspaces are ephemeral — do not present `git log -- audit/` unless that token is configured.

### Limitations

- AAP job logs rotate and are not compliance storage — they stay supplementary, as the customer document itself states. The dedicated audit store must be chosen (and retention defined) before build, because the rollback reconciler also reads it as its state.

**This demo:** Git-backed `audit/` is optional (`GIT_TOKEN`). The system of record you can show live is the job output JSON and, when present, ConfigMaps in `aap-demo`.

### How to demonstrate

1. Open the JT-02 or JT-05 job output after a full UC-4 run and show the printed `audit_record` JSON.
2. Show fields: requester, namespace, policy, window, justification, ticket, `status`, `history[]`.
3. Optional: `oc get cm -n aap-demo -l aapex=audit`. `git log -- acs-exceptions/audit/` only if `GIT_TOKEN` pushed those files.

---

## UC-10 — Notifications

**Customer use case.** Requester, approver and operations are informed at every lifecycle event: submitted, approved, rejected, timed out, applied, removed, rollback failed, ACS unavailable.

### Deliverables

- All listed events, to the recipients listed in the customer document, via the corporate SMTP.
- Approval-pending and job-status notifications through AAP notification templates.
- **Built here:** `playbooks/notify.yml` is included from the jobs. AAP notification template `ACS-Exception-approval-pending` exists as a placeholder (webhook URL is not a live endpoint).

### Limitations

- AAP notification templates fire on job/workflow status only — the richer lifecycle messages (e.g., “exception applied, actual window 14:02–14:32”) are sent as mail tasks inside the jobs. Same content and recipients; different mechanism than the spec may have assumed.
- Notifications never replace audit records (customer's own requirement) — every notified event is also written by UC-9.

**This demo:** `SMTP_HOST` is unset. `playbooks/notify.yml` always appends to `audit/notifications.log` **inside the job workspace** (visible in job output/artifacts). Corporate SMTP is not configured. The AAP notification template `ACS-Exception-approval-pending` is a placeholder, not a live mailbox.

### How to demonstrate

1. After submitted / applied / rollback events, open the job output and find the notification block (`event:`, `request_id`, `namespace`, `policy_name`, `message`, `approvals_url`).
2. Say that SMTP would send the same content if `SMTP_HOST` were set **and** the EE had a mail collection; it does not today.
3. AAP job logs still are not the compliance store — the printed `audit_record` JSON is.

---

## UC-11 — Error Handling

**Customer use case.** ACS unavailable, validation failure, approval timeout or rollback failure must never leave ACS in an unsafe state.

### Deliverables

- An explicit failure path on every workflow node: ACS unavailable → stop, log, alert operations; approval timeout → cancel + notify requester; rollback failure → retry, alert, visible audit status; unauthorized namespace → stop + notify, no ACS change.
- No failure path continues silently — each ends in an audit entry and a notification.
- **Built here:** workflow failure nodes `jt05-fail` / `jt05-deny` / `jt05-acs-fail`. If JT-04 (schedule create) fails after apply, `jt03-compensate` rolls the exclusion back immediately.

### Limitations

- Failure paths must be modeled explicitly in the workflow design (AAP does not add them for you) — and each scenario should be deliberately triggered and evidenced during the pilot acceptance, not assumed.

**Best practice.** Pair every failure with the reconciler (UC-8): even the worst case — rollback failing repeatedly — converges to removal plus an alert.

### How to demonstrate

1. Unauthorized namespace: UC-2 (**bob**) or UC-3 (**carol**) — stop + notify, no ACS change.
2. Approval deny/timeout: UC-6 deny (timeout is 3600s; describe rather than wait).
3. Schedule failure / ACS miss: delete a rollback schedule and wait for JT-06 (UC-8 step 3).
4. Guardrail refusal: `ansible-playbook playbooks/verify-guardrails.yml` (also UC-12).

Do not disable ACS or delete policies to simulate failure.

---

## UC-12 — Security Guardrails

**Customer use case.** Temporary exceptions must not weaken ACS beyond the approved scope: no global disablement, no open-ended or unapproved exceptions, everything logged.

### Deliverables

- The full disallow-list enforced by construction: policy allowlist lives in reviewed code (not in the form); no workflow path reaches ACS without the approval node; every exception carries an expiry; every action is logged with timestamps; all API traffic over TLS.
- AAP RBAC completes the picture: requesters can launch only, approvers approve only, nobody but admins can modify templates or see credentials.
- **Built here:** `vars/policy_allowlist.yml` is the only policy list JT-01/JT-02 accept. Requesters have Execute; `SRE-Approvers` have Approve. ACS token lives in AAP credentials / local `.env`, never in Git.

### Limitations

- The ACS API token able to modify policies is inherently broad. Compensate: keep it only in the AAP credential store, source all automation from Git with peer review, lock down template editing, rotate the token — so the broad permission is exercisable only through the reviewed workflow.

### How to demonstrate

1. Show `vars/policy_allowlist.yml` — only the two demo policies.
2. Run `ansible-playbook playbooks/verify-guardrails.yml` from `acs-exceptions/`. Non-allowlisted name `Fixable CVSS >= 7` is refused (fail-closed).
3. Show workflow topology: JT-01 → **Approval-Node-SRE** → JT-02 (no path to ACS without approval).
4. Remind: demo reset strips `AAPEX-*` exclusions only; it does not delete ACS policies (`ansible-playbook playbooks/demo-reset.yml`).

---

## Summary — Delivery picture at a glance

| UC | Use case | On AAP 2.6 | Adjustment to agree |
|----|----------|------------|---------------------|
| UC-1 | Self-service request | Deliverable | Namespace list refreshed, not per-user filtered (validation decides); optional portal in Phase 2 adds per-user filtering |
| UC-2 | Eligibility validation | Deliverable | Identity mapping + admin-role list as prerequisites |
| UC-3 | No eligible namespace | Deliverable | Block at validation step, same message, plus audit entry |
| UC-4 | Terminal Access exception | Deliverable | Confirm exact policy name and enforcement mode |
| UC-5 | Privileged Container exception | Deliverable | Residual workloads reported at rollback, not auto-deleted |
| UC-6 | Approval workflow | Deliverable | Approval authenticated in AAP; email notifies and links |
| UC-7 | Apply namespace exception | Deliverable | Policies must be API-managed (no GitOps reconciliation) |
| UC-8 | Automatic rollback | Deliverable | ±1 min accuracy; add reconciler as the AC-08 guarantee |
| UC-9 | Audit trail | Deliverable | Choose backend + retention before build |
| UC-10 | Notifications | Deliverable | Lifecycle emails sent from within jobs, not status templates |
| UC-11 | Error handling | Deliverable | Each failure scenario explicitly modeled and tested |
| UC-12 | Security guardrails | Deliverable | Broad ACS token compensated by code review + AAP RBAC |

**Bottom line:** All twelve use cases are deliverable on AAP 2.6 with ACS and OpenShift — no custom components required for Phase 1. The adjustments above are expectation alignments, not gaps: each preserves the customer's business outcome while staying on supported platform behavior. Where extra flexibility is wanted (per-user namespace filtering in the form), an optional front-end portal is a Phase 2 enhancement — it improves the experience while the workflow remains the security control.

---

## Design choices vs platform limits (overall)

These are the cross-cutting alignments from the source and this implementation. Per-use-case limitations above are not repeated here.

1. **Survey refresh + server-side validation (UC-1/2/3).** AAP surveys cannot query per-user RBAC. JT-00 refreshes namespace choices hourly; JT-01 re-validates allowlist, duration, justification, and admin RoleBinding + SubjectAccessReview. The form is convenience; the workflow is the control.
2. **In-AAP approval (UC-6).** There is no anonymous email-link approve. Notifications include a deep link to `{AAP_URL}/#/workflow_approvals`. Every approval is authenticated, RBAC-scoped to `SRE-Approvers`, and timestamped — stronger than a mailto link.
3. **Schedule + reconciler instead of sleep (UC-8).** Customer guidance forbids a long-running sleep job. JT-04 creates a one-shot Controller schedule at `end_time`; JT-06 removes `AAPEX-*` exclusions whose ACS `expiration` is already past.
4. **Audit you can show without Git write access (UC-9).** Job workspaces are ephemeral. Show the printed `audit_record` JSON (and optional ConfigMap). Git push is optional (`GIT_TOKEN`).
5. **Lifecycle mail from jobs (UC-10).** Richer messages are emitted from playbooks (`notify.yml`). On this cluster they land in `audit/notifications.log` because SMTP is unset.
6. **ACS exclusion matching (this Central).** Namespace-scoped kube-event exclusions use empty `cluster` in scope (ACS 4.11.2). The business outcome remains namespace-only; the API field differs from a naive cluster+namespace object.
