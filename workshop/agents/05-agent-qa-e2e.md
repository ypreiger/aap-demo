# Agent: QA / E2E verification

## Minimum bar

1. `oc apply -k workshop/openshift/mock-infra` → pods ready, Route returns JSON files with `curl -k`.  
2. `bash workshop/scripts/run-e2e-multi-domain-workflow.sh` ends **exit 0** (auto-approve path).  
3. Namespace chosen by survey shows **NetworkPolicy** + optional workshop annotation.  
4. Controller **Project Update** log includes **install_collections** when requirements change.

## Escalation data pack

When filing issues attach: workflow job id, failing node name, stdout snippet, `oc get vm -n <project>` (if virt stage), `curl -k $MOCK/f5_pool.json`.
