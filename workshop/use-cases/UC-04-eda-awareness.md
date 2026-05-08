# UC-04 — EDA awareness (Event-Driven Ansible)

## Workshop stance

The bundled **EDA** instance exposes an external Route even when the UI is disabled. Controllers can still **emit webhooks** (approvals, job failures) that an event bus could fan out—`email-plugin` already demonstrates HTTP ingress.

## Prerequisites

**`../PLAN.md`**; optional Hub browse path **[`../../documentation/HUB_COLLECTIONS.md`](../../documentation/HUB_COLLECTIONS.md)**.

## Exercises

1. Run `bash workshop/scripts/verify-eda-route.sh` for a live smoke check.
2. Read `workshop/rulebooks/README.md` for a sample **ansible-rulebook** skeleton.
3. Discuss how **Rulebook Activations** would call the same job templates without a human hitting “Launch”.

## Out of scope (for this repo)

Fully configuring authenticated activations against production Kafka/webhooks—cluster credentials vary.
