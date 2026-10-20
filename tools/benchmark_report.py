"""Publish the stopped v133 campaign without launching or reclassifying worlds."""
from pathlib import Path
import csv
import gzip
import json
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'tools'), str(ROOT / 'tools/auto_tuning')]
from common import DEST, atomic_json, read_json, file_hash, source_hashes, engine_identity
import virtual_cursor_report as archives

DOC = ROOT / 'docs/validation/auto_tuning/benchmark_v133'
BASE = ROOT / 'builds/eval_virtual_cursor/benchmark_v133_r1'

def write(name, content):
    target = DOC / name
    assert not target.exists(), target
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content.strip() + '\n', encoding='utf-8', newline='\n')

def table(name, rows):
    with (DOC / name).open('x', encoding='utf-8', newline='') as handle:
        writer = csv.DictWriter(handle, list(rows[0]))
        writer.writeheader(); writer.writerows(rows)

def mcp(name):
    return json.JSONDecoder().raw_decode((BASE / 'native' / name).read_text(encoding='utf-8-sig'))[0]

def main():
    assert not (DOC / 'verification.json').exists()
    baseline = read_json(DOC / 'baseline_manifest.json')
    frozen = read_json(BASE / 'source_identity.json')
    plan = read_json(DOC / 'run_plan.json')
    preflight = read_json(BASE / 'preflight_session.json')
    diagnostics = read_json(BASE / 'diagnostics_session.json')
    assert not preflight['pass'] and len(preflight['runs']) == 1
    first = preflight['runs'][0]
    assert first['result']['actual_size'] == [64, 64] and first['exit_code'] == 1
    assert first['result']['gameplay_bodies_created'] == 0
    assert len(diagnostics['runs']) == 4 and all(r['exit_code'] == 0 and r['result']['gameplay_bodies_created'] == 0 for r in diagnostics['runs'])
    assert not (BASE / 'reference_session.json').exists() and not (BASE / 'domains_session.json').exists()
    assert source_hashes() == source_hashes(DEST) == frozen['source_hashes']
    assert engine_identity() == frozen['engine_identity']
    assert all(file_hash(DEST / p) == h for p, h in baseline['historical_tracked_evidence'].items())
    assert all(file_hash(ROOT / p) == h for p, h in baseline['historical_raw_evidence'].items())
    assert all(file_hash(Path(p)) == h for p, h in baseline['protected_external'].items())
    regressions = [r for name in ['benchmark_reference', 'benchmark_live_reference'] for r in read_json(DOC / name / 'attempt_001/results.json')['runs']]
    assert len(regressions) == 34 and sum(r['checks'] for r in regressions) == 1146 and all(r['passed'] and r['exit_code'] == 0 for r in regressions)
    normal = read_json(BASE / 'safety/normal_runtime.json')
    assert normal['normal'] == read_json(ROOT / 'docs/validation/evaluator_v132/baseline/normal_runtime.json')
    native = json.loads(mcp('normal_runtime_response.json')['output'][0])
    assert all(native[k] == v for k, v in normal['normal'].items())
    assert native['projection_probe_absent'] and native['provider_disabled'] and not native['camera_virtual'] and native['source_kind'] == 'LIVE'
    assert mcp('errors_after_response.json')['count'] == 0
    assert all(read_json(BASE / 'native/restoration.json')[k] for k in ['project_C_restored', 'project_E_restored', 'owned_editor_closed'])
    pack = read_json(BASE / 'safety/export_pack_check.json')
    assert len(pack['excluded']) == 10 and all(pack['excluded'].values())
    assert pack['profile'] == 2 and pack['provider_disabled'] and not pack['camera_virtual']
    for name in ['export', 'export_smoke', 'export_pack_inspection_isolated']:
        receipt = read_json(BASE / 'safety' / (name + '_receipt.json'))
        assert receipt['exit_code'] == 0 and not receipt['script_errors']

    catalog = read_json(ROOT / 'features/evaluator_virtual_cursor/resources/benchmark_eval_v133.json')
    catalog.update(qualification_status='NOT_QUALIFIED_BQ1_STOP', ranking_enabled=False,
                   source_catalog_sha256=file_hash(ROOT / 'features/evaluator_virtual_cursor/resources/benchmark_eval_v133.json'),
                   dataset_partitions={'benchmark_qualification': 'PUBLIC_UNSCORED_DEFINITIONS_NO_NEW_OUTCOMES',
                                       'future_training': 'UNASSIGNED_NOT_AUTHORIZED',
                                       'public_validation': 'RESERVED_NOT_POPULATED',
                                       'private_holdout': 'UNOPENED_NO_OUTCOMES_ACCESSED',
                                       'human_playtests': 'SEPARATE_PROTOCOL_NO_SESSIONS'})
    atomic_json(DOC / 'benchmark_catalog_v133.json', catalog)
    matrix = []
    for definition in catalog['scenarios']:
        for hz in [120, 60]:
            matrix.append({'scenario_id': definition['id'], 'hz': hz, 'backing': [1024,576],
                           'modes': ['headless','rendered_scripted'], 'seed':101,
                           'source_commit': frozen['repository_commit'], 'policy_revision': definition['input_policy_revision'],
                           'tape_sha256': None, 'onset_tick': None, 'task_succeeded': None,
                           'metric_status': None, 'availability':'NOT_RUN_EARLY_STOP',
                           'eligibility':'MISSING_COVERAGE', 'ranking_eligible':False,
                           'fixed_pairs_required':3, 'fixed_pairs_planned':3 if definition['kind']=='progress' and not definition['require_foot_load'] else 1,
                           'fixed_pairs_observed':0, 'reason':'BQ1_CANONICAL_ENVIRONMENT_REJECTED',
                           'provisional_policy':'DIAGNOSTIC_ONLY_IF_VALID_N1' if definition['require_foot_load'] or definition['kind']=='release_stop' else 'PRIMARY_N3_AT_BOTH_HZ_REQUIRED'})
    atomic_json(DOC / 'eligibility_matrix.json', {'decision':'NO_GO_BENCHMARK', 'cells':matrix,
               'all_eligible_domains':[], 'remaining_primary_process_cells':plan['reference_cells']+plan['new_domain_cells'],
               'cross_hz_pooling':False, 'human_approved':False})
    metric_names = ['signed_progress_m','latency_to_useful_motion_s','directional_efficiency','overshoot_after_release_m','stop_path_3d_m','settling_time_s','brake_fraction_reached','reversal_time_s','catch_success','retention_s','foot_load_contribution','twist_rms_rad','hard_physical_violations']
    metric_rows = []
    for c in plan['new_domain_cells']:
        for metric in metric_names:
            metric_rows.append({'scenario':c['scenario'],'hz':c['hz'],'backing':'1024x576','mode':c['mode'],'repeat':c['repeat'],'input_lane':c['lane'],'source_commit':frozen['repository_commit'],'seed':101,'policy':'benchmark_v133_preparation_r1','tape_sha256':'','onset_tick':'','task_succeeded':'','metric':metric,'metric_status':'','value':'','availability':'NOT_RUN_EARLY_STOP','reason':'BQ1_CANONICAL_ENVIRONMENT_REJECTED'})
    table('scenario_metrics.csv', metric_rows)
    pairs = []
    for scenario in ['swing_catch_train']+[d['id'] for d in catalog['scenarios']]:
        for hz in [120,60]:
            repeats = [1,2,3] if scenario=='swing_catch_train' or scenario in [d['id'] for d in catalog['scenarios'][:4]] else [1]
            for repeat in repeats:
                pairs.append({'scenario':scenario,'hz':hz,'backing':'1024x576','modes':'headless/rendered_scripted','repeat':repeat,'source_commit':frozen['repository_commit'],'seed':101,'tape_sha256':plan['reference_tapes'][str(hz)]['sha256'] if scenario=='swing_catch_train' else '', 'status':'NOT_RUN_EARLY_STOP','first_tick':'','first_layer':'','reason':'BQ1_CANONICAL_ENVIRONMENT_REJECTED'})
    assert len(pairs)==34
    table('replay_comparison.csv', pairs)
    divergence = {'decision':'NO_GO_BENCHMARK','first_failure_kind':'ENVIRONMENT_ADMISSION','stage':'BQ1_PURE_PREFLIGHT','mode':'headless','hz':120,'before_gameplay_world':True,'gameplay_bodies_created':0,'scenario_tick':None,'phase':'BEFORE_CLOCK_AND_WORLD_BRANCH','requested_backing':[1024,576],'observed_backing':[64,64],'observed_mode':1,'observed_screen':-1,'process_exit_code':1,'typed_status':'ENVIRONMENT_NOT_COMPARABLE','reason':'BACKING_SIZE','source_commit':frozen['repository_commit'],'no_input_camera_raycast_anchor_physics_divergence_observed':True,'evidence':str(Path(first['directory']).relative_to(ROOT)),'diagnostics_explain_but_do_not_replace_primary':True}
    atomic_json(DOC / 'first_divergences.json', divergence)
    controls = {'new_physical_negative_processes':0,'wrong_backing_negative':'NOT_RUN_EARLY_STOP','pure_contracts':read_json(BASE/'contracts/BQpure_measurement_review_frozen.json'),'diagnostics':diagnostics,'external_hardware_interference':'NOT_RUN_IN_V133','focus_alt_tab':'NOT_RUN_IN_V133','previous_evidence':'Historical v132a/v132b records preserved; not fresh v133 passes.','no_stale_evidence_fills_new_cells':True}
    atomic_json(DOC / 'negative_controls.json', controls)
    for r in [first]+diagnostics['runs']:
        directory = Path(r['directory']); target=DOC/'runs'/directory.name
        target.mkdir(parents=True,exist_ok=False)
        for p in directory.iterdir():
            if p.is_file():shutil.copy2(p,target/p.name)
        with gzip.open(target/'trace.json.gz','wb') as handle:
            handle.write(json.dumps({'status':'NOT_APPLICABLE_NO_GAMEPLAY_WORLD','frames':[],'ticks':[],'reason':'Environment preflight/diagnostic only; no simulated trace exists.'}).encode())
    shutil.copy2(BASE/'native/ordinary_main.png',DOC/'ordinary_main.png')
    atomic_json(DOC/'source_identity.json',frozen)
    verification = {'decision':'NO_GO_BENCHMARK','measured_source_commit':frozen['repository_commit'],
        'baseline_commit':baseline['baseline_commit'],'engine':frozen['engine_identity'],
        'protection':{'historical_tracked_files_verified':len(baseline['historical_tracked_evidence']),'historical_raw_files_verified':len(baseline['historical_raw_evidence']),'C_E_source_parity':True,'public_source_files':len(frozen['source_hashes']),'normal_project_janga_rollback_export_preset_unchanged':True,'gameplay_physics_camera_controls_source_unchanged':True},
        'preflight':{'planned_positive':12,'attempted':1,'accepted':0,'rejected_setup':1,'aborted':0,'positive_not_run_early_stop':11,'negative_planned':1,'negative_attempted':0,'gameplay_worlds':0},
        'qualification':{'primary_planned':84,'primary_attempted':0,'primary_valid':0,'primary_invalid':0,'primary_aborted':0,'primary_not_run_early_stop':84,'new_domain_planned':72,'catch_reference_planned':12,'negative_allotment':8,'negative_attempted':0,'issue_diagnostic_allotment':4,'issue_diagnostics_attempted':4,'issue_diagnostic_gameplay_worlds':0,'max_physics_processes':96,'qualification_physics_processes_used':0},
        'ordinary_regressions':{'processes':34,'checks':1146,'passed':True,'separate_budget_by_user':True},
        'new_pure_python_contracts':34,'normal_headless_startup':'PASS','native_mcp':'PASS_DEFAULT_SAFETY_ONLY','native_fresh_errors':0,'native_preexisting_nested_project_warning':1,
        'export':{'release_export_and_plain_release_smoke':'PASS','isolated_debug_engine_pack_inspection':'PASS','excluded_paths':10,'inspection_is_release_template':pack['release_template'],'identity':read_json(BASE/'safety/export_identity.json')},
        'human_playtest_sessions':0,'private_outcomes_accessed':0,'optimizer_RL_Jev_processes':0,'new_climbing_outcomes':0,
        'no_automatic_rerun':True,'recommended_next_action':'Explicitly initialize and observe backing before world creation in a separately approved, versioned admission correction; then redo BQ1 before BQ2. No tuning.'}
    atomic_json(DOC/'verification.json',verification)
    write('human_protocol_reference.md','''# Human evaluation remains separate

No human session occurred in v133. MCP inspection and screenshots verify ordinary startup only. A future qualified candidate still needs blind or counterbalanced A/B comparison for clarity, responsiveness, reach predictability, precision, stopping, swing mastery and desire to replay. Keep candidate identity, order, device, display, frame rate, route and subjective answers separate from fixed-replay scores. No optimizer or scripted agent may issue a human-feel approval. No candidate exists from this campaign.
''')
    write('dataset_migration.md','''# Dataset and legacy quarantine

`benchmark_eval_v133` revision1 is a public qualification catalog, currently NOT_QUALIFIED. None of its domain/Hz cells contains a new climbing outcome. Qualification evidence, adaptive capture sources, fixed tapes and human sessions are distinct data types. Future training and public validation remain unassigned; private holdout outcomes stay unopened. No test split is silently reused as validation or holdout.

Keep the old unequal-window replays quarantined under their original IDs, first-divergence records and source maps. The v132b same-backing finding remains limited to its two old catch tapes and observed repetitions. A1 asymmetrical/diagonal regressions and B2 localized outcomes remain unchanged; no aggregate can turn an absent weakest cell into success. The fresh missing-cell canary verifies this without running A1 or changing the default. A0/B1 stays the experimental reference and profile2/LIVE stays normal startup.

The original 036 catch tape bytes and capture source identity were hash-verified, not recaptured, rewritten or called new v133 evidence. Their planned runtime source delta was reviewed explicitly. No reference replay was launched after the BQ1 stop.
''')
    write('decision.md',f'''# GRIP UP v1.3.3 — Benchmark Qualification Decision

- Baseline preserved: PASS. Starting commit `{baseline['baseline_commit']}`; baseline tag `baseline/pre-v133-benchmark`.
- Canonical backing and clock: FAIL at first pure headless120 preflight, actual64×64 instead of1024×576; main clock branch and gameplay world were not entered.
- Swing & Catch reference: NOT_RUN_EARLY_STOP, 0/12 processes and0/6 pairs.
- Vertical / asymmetric / clean lateral left / clean lateral right: MISSING_COVERAGE at60 and120Hz.
- Foot-supported step: NOT_RUN; provisionally diagnostic and excluded from ranking because the plan contains only n1 pair/Hz.
- Two-hand stopping: NOT_RUN; same n1 exclusion. No stopping/braking improvement can be ranked.
- Cross-mode coverage: 0 new pairs. No input, cursor, camera, raycast, material-anchor or physics mismatch was measured; setup failed earlier.
- 60Hz qualification: NOT_RUN. One-hand60Hz: OPEN.
- New physical invariant violations: not evaluated, zero new gameplay worlds. Ordinary regressions1146/1146 pass separately.
- Private outcomes / Optuna / RL / Jev / human sessions: 0 each.
- Final verdict: **NO_GO_BENCHMARK**.
- Scope: benchmark launch admission failed; this is not evidence that gameplay or Jolt failed. Static contracts and release safety do not qualify movement cells.
- Next permitted action: report and freeze this campaign. A separately approved, versioned launch correction can initialize backing explicitly before bodies and re-execute BQ1; no automatic reliability chain, search or default promotion.
''')
    write('result_report.md',f'''# GRIP UP v1.3.3 — relatório de qualificação

**Resultado: NO_GO_BENCHMARK.** O primeiro preflight headless120 recusou o ambiente antes de criar qualquer corpo de gameplay. A linha de comando pediu1024×576, mas `Window.size` devolveu64×64. O guard interrompeu corretamente a campanha; não houve novos ensaios de escalada, replays de referência ou métricas físicas nesta versão.

## O que foi implementado

Foi congelada uma extensão limitada do driver existente, com ambiente observado, catálogo público de seis tarefas, preparação através dos inputs/raycast reais, certificados de onset POST, comparador de canais publicados e métricas com seis estados tipados. Reutiliza provider, scheduler V0, câmara, controller e Jolt; não escreve ATTACHED nem pose/velocidade do boneco. As quatro mudanças em infraestrutura existente são hooks de catálogo/fixture/benchmark, identificação do cenário/posição no probe e teste de compatibilidade com fonte histórica congelada. Nenhum ficheiro do gameplay físico, câmara normal, input normal, tuning ou geometria original mudou.

Fonte medida: `{frozen['repository_commit']}`, branch `feature/v1.3.3-benchmark-qualification`;292 fontes públicas congeladas. Motor4.7.2-stable Steam, revisão`ed1daf0bf001b61586d9930840f2f1394092c079`, Jolt integrado, SHA`{frozen['engine_identity']['sha256']}`. Fontes C/E coincidem. O catálogo preparado não é um benchmark qualificado.

## Admissão e primeiro bloqueio

O comando efetivamente executado encontra-se em `runs/headless_120_1_positive/manifest.json`. O processo terminou com1 e `ENVIRONMENT_NOT_COMPARABLE / BACKING_SIZE`, modo1, screen−1, posição0,0. `gameplay_bodies_created=0`. A condição falhou antes do ramo que aguarda o relógio. Não existe tick de cenário, PRE/POST físico ou primeiro desvio de raycast/âncora para este processo. O trace vazio está explicitamente marcado como não aplicável; não é um trace simulado reconstruído.

O plano previa12 preflights positivos e1 negativo sem corpos. Foram tentados1 positivo, aceite0, rejeitado1, abortado0; os outros11 positivos e o negativo ficaram NOT_RUN_EARLY_STOP. O catálogo de84 processos primários permanece visivelmente não executado:12 referências e72 tentativas de domínio, incluindo12 capturas adaptativas. Uma captura adaptativa nunca contaria como réplica fixa.

## Quatro diagnósticos permitidos

| Diagnóstico puro | Hz | Modo | Inicialização explícita | Backing inicial → final | Viewport final | Relógio observado |
|---|---:|---|---|---|---|---|
| D1 |120|headless|não|64×64 →64×64|1920×1920|2 callbacks1/120|
| D2 |120|rendered|não|1024×576 →1024×576|1920×1080|2 callbacks1/120|
| D3 |120|headless|`root.size` antes do relógio|64×64 →1024×576|1920×1080|2 callbacks1/120|
| D4 |60|headless|`root.size` antes do relógio|64×64 →1024×576|1920×1080|2 callbacks1/60|

Todos tiveram0 corpos e0 outcomes de gameplay. D1 mostra que esperar pelo relógio não corrige o backing. D2 observa screen0 e posição real2400,80, apesar do pedido80,80: posição de ecrã é evidência observada, não uma promessa do CLI. D3/D4 isolam uma possível correção de inicialização pré-mundo. Não modificaram a fonte congelada nem repetiram BQ1 e não provam igualdade física, V0 ativo ou compatibilidade de picking. Modo de janela/headless e valores de display indisponíveis não são artificialmente igualados.

## Cobertura e elegibilidade

| Domínio |60Hz H/R|120Hz H/R|Pares fixos observados|Elegibilidade|
|---|---|---|---:|---|
| Swing & Catch referência |não executado|não executado|0|NOT_RUN|
| Vertical clean |não executado|não executado|0|MISSING_COVERAGE|
| Asymmetric clean |não executado|não executado|0|MISSING_COVERAGE|
| Lateral clean left |não executado|não executado|0|MISSING_COVERAGE|
| Lateral clean right |não executado|não executado|0|MISSING_COVERAGE|
| Foot-supported step |não executado|não executado|0|excluído de ranking; n1 planeado|
| Two-hand release-stop |não executado|não executado|0|excluído de ranking; n1 planeado|

O critério GO exige, entre outros gates, vertical/assimétrico/laterais com n3 pares em cada Hz. Nem esses nem os28 pares novos e6 pares de referência foram medidos. Não há latência, eficiência, progresso, pé carregado, travagem, settle ou twist novo para preencher. As células de CSV mantêm ausência e motivo; nenhum null virou zero. Ficam também abertos counter-swing, braking/reversal, one-hand60, outros offsets,1440×810, seeds, hardware e generalização. Não se reutilizam resultados históricos como passes novos.

## Contratos de medição e revisão

Os34 testes Python novos passaram:27 métricas,4 comparador e3 admissão de tapes. Cobrem sinal do progresso, direção espelhada, onset realmente carregado e quieto, alteração de ground/hybrid/âncora, horizonte interrompido, velocidade dirigida de stop, path3D até confirmação, settle pelo início da janela quieta, força de mão pendente, caps e weakest-cell ausente. Uma velocidade útil já presente antes do onset produz `ALREADY_MOVING_BEFORE_ONSET`, latência null; não recebe crédito de resposta instantânea. Isso preserva o progresso raw como observação distinta. Estes são testes de contratos, não de performance física do catálogo.

A revisão física independente fechou cinco achados antes do freeze: identidade de domínio/tape, safety global independente do onset, recertificação do onset no replay, guard de fresh e latência herdada. O reviewer de medição escreveu os seus módulos e declara esse limite de independência; o especialista físico fez auditoria sem escrever o atuador ou executar o motor. Ambos recomendam NO_GO após ler os recibos. Os pareceres preservam aprovação estática separada de cobertura runtime inexistente.

## Preservação, regressões e release

Passaram34 processos das suites antigas a60/120Hz,1146 checks. Estão fora do teto de qualificação por confirmação expressa do utilizador. A inspeção normal headless corresponde exatamente ao snapshot anterior. Godot MCP Pro abriu o main no monitor de índice0 e confirmou profile2/LIVE, hold, provider desligado, câmara virtual desligada, probe ausente, massa12kg, alcance0.65708m, parâmetros[0.25,0.12,0.24,0.9] e bindings originais. Houve1 warning já presente de projeto aninhado antes de play e0 erros frescos depois; screenshot inspecionado. Não foi playtest humano.

O export release e o seu arranque plain headless passaram. Uma inspeção isolada com o motor debug carregou o pack exportado e confirmou10 caminhos experimentais ausentes, incluindo novos scripts/catálogo. Essa inspeção tem `release_template=false`; não é confundida com a smoke real do executável release. Identidade/bytes estão em `verification.json`. Configurações C/E foram restauradas byte a byte; editor próprio encerrado.

Foram verificados{len(baseline['historical_tracked_evidence'])} ficheiros históricos versionados e{len(baseline['historical_raw_evidence'])} ficheiros raw históricos sem mudanças, bem como Janga, rollback, project e export preset. Os limites360N mãos,180/120N pés,20Nm assistência e150Nm combinados não mudaram. A qualificação nova não observou nenhum desses limites em gameplay porque não criou corpos; as suites preservam apenas o seu âmbito original.

## Contabilidade e integridade

Processos físicos novos de qualificação:0/96. Primários:0 tentados,0 válidos,0 inválidos,0 abortados,84 não executados. Negativos físicos:0/8. Diagnósticos específicos:4/4 slots, todos puros e contabilizados separadamente de mundos físicos. Admissão pura:1 tentativa rejeitada. Os5 lançamentos de ambiente e todos os insucessos estão arquivados com scripts, stdout/stderr, manifest, resultado e hashes. Não houve retry oculto, tolerância nova ou realocação dos slots não usados.

Não existe comparação causal de overhead em gameplay nesta campanha: os observadores e contadores estão implementados, mas os componentes de tick, picks, POST, serialização, render e escrita ficam NOT_MEASURED nesta qualificação. O controlo ON/OFF novo não correu. Arquivos ZIP têm CRC e SHA de cada membro verificados; a versão congelada e a fonte baseline estão guardadas separadamente. Partições, canaries e quarentena de dados estão em `dataset_migration.md`.

## Próximo passo permitido

Corrigir, numa campanha explicitamente autorizada e com nova identidade, a inicialização observada do backing antes de qualquer corpo; repetir BQ1 e só depois avançar para BQ2. Nesta campanha fica congelado NO_GO_BENCHMARK. Não foi lançada pesquisa Optuna/RL/Jev, não foram consultados outcomes privados, não houve promoção de defaults e não se iniciou M7.
''')
    write('README.md','''# Benchmark qualification v1.3.3

**NO_GO_BENCHMARK — BQ1 canonical environment admission failed before gameplay.**

- [Full report](result_report.md) and [decision](decision.md).
- [Observed eligibility](eligibility_matrix.json), [planned run budget](run_plan.json), [first failure](first_divergences.json).
- [Metric contract](measurement_contract.md), [environment contract](environment_contract.md), [catalog](benchmark_catalog_v133.json), [dataset migration](dataset_migration.md).
- [Physics review](physics_specialist_review.md), [measurement review](specialist/BQ_measurement_review.md).
- [Verification](verification.json), [negative/control coverage](negative_controls.json), [evidence index](evidence_manifest.json).

The environment contract describes planned positive conditions; only one of12 positive preflights was attempted,11 and the wrong-size negative were NOT_RUN. No new catch/domain gameplay world was launched. Four pure diagnostics explain the launch-size failure without requalifying it. Normal startup,1146 old regression checks and release safety passed separately.

Executed commands: `python tools/benchmark_preflight.py` (rejects setup); `python tools/benchmark_diagnose.py` (four bounded diagnostics); `python tools/benchmark_safety.py export`; `python tools/benchmark_safety.py inspect-pack`; `python tools/benchmark_native.py start/inspect/runtime/restore` (each stage separately). These campaign paths are immutable; rerunning commands against used paths is intentionally rejected. Full commands and raw output are archived. No next campaign starts automatically.
''')
    archives.DOC=DOC
    index={}
    archives.source_archive('frozen_qualification_source',frozen['repository_commit'],frozen['source_hashes'],index)
    archives.source_archive('preserved_pre_v133_source',baseline['baseline_commit'],baseline['source_hashes'],index)
    files=[p for p in BASE.rglob('*') if p.is_file() and p.suffix.lower()!='.exe']
    files += list((ROOT/'tools').glob('benchmark*.py'))
    archives.archive('all_new_raw_receipts',files,index)
    atomic_json(DOC/'evidence_manifest.json',{'archives':index,'raw_release_executable':read_json(BASE/'safety/export_identity.json'),'release_executable_path':str(BASE/'safety/GripUp-v133-benchmark-safe.exe'),'source_commit':frozen['repository_commit'],'raw_preservation_verified':True})
    print('Published NO_GO_BENCHMARK: zero new gameplay worlds; all five environment launches retained.')

if __name__=='__main__':
    main()
