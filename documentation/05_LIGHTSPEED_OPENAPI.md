# Ansible Lightspeed — OpenAPI-style LLM endpoint, API key, and troubleshooting

The chatbot calls an **HTTPS LLM API** (OpenAI-compatible for **`chatbot_llm_provider_type: openai`**). This document explains **`chatbot_url`** / **`chatbot_token`**, how that differs from the **Controller API** token, and what to check when the assistant is silent.

The assistant icon appears when **`AnsibleLightspeed`** is reconciled and the gateway can reach **`demo-aap-lightspeed-chatbot-api`**. **No reply in the chat** usually means the **LLM backend is misconfigured or unreachable**, not the UI.

---

## 1. `chatbot_url` and `chatbot_token` (LLM “Open API” key)

**Secret:** **`demo-aap-lightspeed-chatbot-config`** in namespace **`aap`** (see example: **`aap-yamls/secrets/aap-demo-lightspeed-chatbot-config.secret.example.yaml`**).

| Key | Role |
|-----|------|
| **`chatbot_url`** | **Base URL** for the LLM provider’s **HTTP API** (for public OpenAI use **`https://api.openai.com/v1`**). The chatbot client appends provider-specific paths (e.g. chat/completions style calls) under this base. |
| **`chatbot_token`** | **API key** (or bearer token) for that LLM endpoint. For OpenAI, keys usually start with **`sk-`**. This is **not** the same value as the Automation Controller **personal access token** used for `aap-controller-api` in [01_INSTALL_OPENSHIFT.md](01_INSTALL_OPENSHIFT.md) Phase 3. |
| **`chatbot_model`** | Model id your account can use on that API ([OpenAI models](https://platform.openai.com/docs/models)). This repo’s examples use **`gpt-4o-mini`**. |
| **`chatbot_llm_provider_type`** | Which wire protocol the client uses: commonly **`openai`**, or **`rhoai_vllm`** / **`rhelai_vllm`** for OpenShift AI / vLLM (set **`chatbot_url`** to your serving route). |

**Do not confuse these credentials:**

| Secret / token | Used for |
|----------------|----------|
| **`demo-aap-lightspeed-chatbot-config`** | **Upstream LLM** (OpenAI, vLLM, etc.) — what this page calls the “**LLM API key**”. |
| **Controller API** token (e.g. **`aap-controller-api`**) | **Red Hat Ansible Automation Platform Controller REST API** only — job templates, projects, webhooks. Never paste this into **`chatbot_token`**. |

If **`chatbot_token`** is still a placeholder (e.g. **`REPLACE_ME_SET_REAL_LLM_TOKEN`**), inference fails.

---

## 2. Examples: patch the Secret

If OpenAI returns **quota exceeded** for **multiple** models, your **account/org monthly or tier limit** is usually the blocker—increase **billing / limits** in the OpenAI dashboard. Changing the model string only helps when **another** model still has allowance.

**HTTP 500** after fixing the token: check **`ansible-chatbot`** logs. If OpenAI returns **`Unsupported parameter: 'max_tokens' … Use 'max_completion_tokens' instead`**, your **`chatbot_model`** (e.g. some **`gpt-5.*`** IDs) uses an API shape the bundled Lightspeed client does not send yet—use **`gpt-4o-mini`** or **`gpt-4.1-mini`** until Red Hat ships a compatible image, or open a support case with the log line.

**Patch** (example — OpenAI):

```bash
oc patch secret demo-aap-lightspeed-chatbot-config -n aap --type merge -p '{
  "stringData": {
    "chatbot_model": "gpt-4o-mini",
    "chatbot_url": "https://api.openai.com/v1",
    "chatbot_token": "<YOUR_OPENAI_API_KEY>",
    "chatbot_llm_provider_type": "openai"
  }
}'
```

For **Red Hat OpenShift AI** / **vLLM**, set **`chatbot_llm_provider_type`** to **`rhoai_vllm`** (or **`rhelai_vllm`** as documented for your stack), **`chatbot_url`** to your serving Route/base URL, and **`chatbot_token`** to whatever that endpoint requires (often still required even if empty for local trust).

**Restart** the chatbot API so it reloads configuration:

```bash
oc rollout restart deployment/demo-aap-lightspeed-chatbot-api -n aap
oc rollout status deployment/demo-aap-lightspeed-chatbot-api -n aap --timeout=180s
```

---

## 3. Confirm logs (symptoms map to causes)

**Lightspeed API** (proxies streaming to the chatbot):

```bash
oc logs deployment/demo-aap-lightspeed-api -n aap --tail=100 | grep -iE 'stream|404|401|error'
```

Typical messages:

| Log pattern | Likely cause |
|-------------|----------------|
| **`Streaming query API returned status code=404`** | Chatbot returns **404** — often **model/provider not found** (bad **`chatbot_model`**, **`chatbot_url`**, or **`chatbot_llm_provider_type`** vs actual endpoint). |
| **`401` / `Invalid API Key`** | Wrong LLM **`chatbot_token`** for the URL you configured, or upstream rejects the key. |
| TLS / connection errors | **`chatbot_url`** unreachable from the cluster (**egress**, DNS, firewall). |
| **`503` / Service Unavailable** | **`deployment/demo-aap-lightspeed-api`** has **no Ready pods** (readiness/liveness **timeouts**, rollout stuck on **Terminating**, **HPA** scaling). Gateway Envoy returns **503** when the Service has **no healthy endpoints**. |

**Chatbot** (talks to the LLM):

```bash
oc logs deployment/demo-aap-lightspeed-chatbot-api -n aap -c ansible-chatbot --tail=100
```

If you see **503**, confirm **`demo-aap-lightspeed-api`** is Ready, then restart if probes were timing out during a rollout:

```bash
oc get pods -n aap | grep demo-aap-lightspeed-api
oc rollout restart deployment/demo-aap-lightspeed-api -n aap
oc rollout status deployment/demo-aap-lightspeed-api -n aap --timeout=300s
```

---

## 4. Egress

Pods in **`aap`** must reach **`chatbot_url`** (for OpenAI: **`https://api.openai.com`**). Deny-all **`NetworkPolicy`** or cluster egress restrictions cause timeouts or failures after you fix the token.

---

## 5. Reference

- Template for the Secret (do not commit real keys): **`aap-yamls/secrets/aap-demo-lightspeed-chatbot-config.secret.example.yaml`**
- Product procedure: [Deploying Ansible Lightspeed on OpenShift](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/installing_on_openshift_container_platform/deploying-chatbot-operator)
