# UC-04 — EDA awareness (Event-Driven Ansible)

## Scope

EDA exposes a Route for webhook ingress even when the product UI is disabled. **`email-plugin`** uses similar HTTPS ingress for approvals.

## Prerequisites

**`../workshop/PLAN.md`**. Optional: **[`UC-05-inspect-hub-collections-bluecoat.md`](USECASE_UC05_inspect_hub_collections_bluecoat.md)** for Hub layout.

---

## Instructions (hands-on checks)

### 1. Route smoke script

From repo root:

```bash
bash workshop/scripts/verify-eda-route.sh
```

**What you should see:** **`HTTP 200`** (or documented healthy response body) confirming the Route defined in-rulebook/cluster instructions is reachable — script output explains next steps on failure.

### 2. Read rulebook skeleton

Open **`../workshop/rulebooks/README.md`** in this repository (sample **ansible-rulebook** layout for discussion).

### 3. Classroom discussion prompts

Facilitators lead three points (no mandatory Controller launches here):

| # | Talking point |
|---|----------------|
| 1 | **Rulebook Activations** could trigger the same JT/WF as **`workshop-multi-domain`** **without** a human pressing **Launch** when events arrive from Kafka/http/gateway integrations. |
| 2 | **EDA UI** availability varies on workshop clusters — automation still validates **routing**/`curl`; UI walkthrough optional. |
| 3 | Contrast **`email-plugin`** (Controller webhook → SMTP) vs **EDA** (event backbone) using **`UC-06`** as the human-approval analogue. |

---

## Instructions (Automation Controller UI — optional)

If your cluster exposes **EDA** with UI:

1. Log in via gateway tile **EDA** (if shown).
2. Compare **Activation** lifecycle words (**Enable / Restart / Logs**) against **`rulebooks/README.md`** vocabulary.
3. Do **not** expect this repo’s workshop workflow to launch from EDA by default—the integration is illustrative.

---

## Exercises reference

Original quick list:

1. `bash workshop/scripts/verify-eda-route.sh`
2. Read `workshop/rulebooks/README.md`
3. Discuss **Rulebook Activations** vs manual **Launch**

## Out of scope (for this repo)

Fully configuring authenticated activations against production Kafka/webhooks—cluster credentials vary.

## See also

- **`./EDA_GIT_WEBHOOK.md`** — git-driven controller + EDA bridge pattern.
- **`../CLIENT_RUNBOOK.md`** §7 related references.
