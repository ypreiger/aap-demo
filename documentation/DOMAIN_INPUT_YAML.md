# Domain input YAML (firewall · F5 · Blue Coat)

Workshop artefacts live under **`projects/<name>/domain/*.yaml`** (committed next to BOM `bom/` folders).

Controllers map Git changes beneath those directories to **`domain_firewall`**, **`domain_f5`**, **`domain_bluecoat`** flags in **`workshop/git-webhook-bridge`**, skipping automation when untouched.

## Firewall (`FirewallRuleIntentList`)

| Path | Requirement |
|------|---------------|
| `spec.rules[].name` | Unique within file |
| `spec.rules[].action` | `permit`, `deny`, `observe` |
| `spec.rules[].layer` | `ingress`, `egress`, `transit` |
| `spec.rules[].sources` / `destinations` | Structured `cidr`, `subnet`, `labelSelector`, or `fqdn` |
| `spec.rules[].services` | `{proto,ports[]}` |

## F5 (`F5DeclarativeSnippet`)

Minimal AS3-aligned payload for mocks or future **`f5networks.f5_modules`** bridging.

## Blue Coat (`BluecoatProxyHints`)

High-level bundles only—real deployments still require vendor APIs/partner content.
