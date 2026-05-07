#!/usr/bin/env bash
# Removes obsolete per-project tower CRs left from earlier commits. Safe to re-run.
# After this, only the generic workflow bom-project-deploy (wjt-bom-project-deploy) should remain for BOM.
set -euo pipefail
NS="${AAP_NAMESPACE:-aap}"

echo "Deleting legacy JobTemplate / WorkflowTemplate CRs in namespace ${NS} (if present)..."
for r in \
  "jobtemplate.tower.ansible.com/jt-proj1-apply-bom" \
  "jobtemplate.tower.ansible.com/jt-proj2-apply-bom" \
  "workflowtemplate.tower.ansible.com/wjt-proj1-apply-workflow" \
  "workflowtemplate.tower.ansible.com/wjt-proj2-apply-workflow"
do
  oc delete -n "${NS}" "$r" --ignore-not-found
done

echo "Done. In Controller UI, old names like proj1-apply-bom-workflow should disappear after reconcile."
echo "Apply current tower CRs: oc apply -k \"$(cd "$(dirname "$0")/.." && pwd)/tower/\""
