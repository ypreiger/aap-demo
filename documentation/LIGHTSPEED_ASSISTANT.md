# Ansible Lightspeed Intelligent Assistant — troubleshooting

The assistant icon appears when **`AnsibleLightspeed`** is reconciled and the gateway can reach **`demo-aap-lightspeed-chatbot-api`**. **No reply in the chat** usually means the **LLM backend is misconfigured or unreachable**, not the UI.

---

## 1. Supply a real LLM credential

The chatbot reads **`Secret/demo-aap-lightspeed-chatbot-config`** in **`aap`** (keys **`chatbot_model`**, **`chatbot_url`**, **`chatbot_token`**, **`chatbot_llm_provider_type`**).

If **`chatbot_token`** is still a placeholder (for example **`REPLACE_ME_SET_REAL_LLM_TOKEN`**), inference fails. OpenAI keys normally start with **`sk-`** and are much longer than placeholder text.

**`chatbot_model`:** set this to a model your API account can call ([OpenAI models](https://platform.openai.com/docs/models)). This repo’s examples default to **`gpt-4o-mini`** (low cost, current small multimodal). **`gpt-4.1-mini`** is an alternative if your org prefers that tier.

If OpenAI returns **quota exceeded** for **multiple** models, your **account/org monthly or tier limit** is usually the blocker—increase **billing / limits** in the OpenAI dashboard. Changing the model string only helps when **another** model still has allowance.

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

## 2. Confirm logs (symptoms map to causes)

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

## 3. Egress

Pods in **`aap`** must reach **`chatbot_url`** (for OpenAI: **`https://api.openai.com`**). Deny-all **`NetworkPolicy`** or cluster egress restrictions cause timeouts or failures after you fix the token.

---

## 4. Reference

- Template for the Secret (do not commit real keys): **`aap-yamls/secrets/aap-demo-lightspeed-chatbot-config.secret.example.yaml`**
- Product procedure: [Deploying Ansible Lightspeed on OpenShift](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/installing_on_openshift_container_platform/deploying-chatbot-operator)
