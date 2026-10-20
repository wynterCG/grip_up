"""Index accepted baseline runs while retaining invocation errors as evidence."""
import json
from pathlib import Path
from project_config import ROOT

base = ROOT / 'docs/validation/auto_tuning'
accepted, errors = [], []
for name in ('reference', 'reference_addendum'):
    path = base/name/'attempt_001/results.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    for row in data['runs']:
        entry = {**row, 'receipt': path.relative_to(base).as_posix()}
        if row['passed']:
            accepted.append(entry)
        else:
            assert row['suite'] in {'safety_and_reaction', 'ground_walk'}, 'Unexpected baseline failure requires review'
            entry['classification'] = 'ROOT_INVOCATION_ERROR'
            entry['reason'] = ('Called nonexistent test_safety_and_reaction.gd; reaction checks are in test_intent_reversal.gd'
                               if row['suite'] == 'safety_and_reaction' else
                               'Called nonexistent test_ground_walk.gd; corrected to test_ground_locomotion.gd')
            errors.append(entry)
report = {'scope': 'Unchanged A0 production regression and preserved A1/B2 diagnostic outcomes; not candidate or human validation',
          'accepted_runs': accepted, 'invocation_errors': errors,
          'checks': sum(x['checks'] for x in accepted), 'accepted_execution_count': len(accepted),
          'technical_failures_in_executed_checks': sum(x['failures'] for x in accepted),
          'all_requested_invocations_passed': not errors, 'human_sessions': 0}
(base/'reference_index.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(report['checks'], 'checks in', len(accepted), 'accepted executions;', len(errors), 'invocation errors preserved')
