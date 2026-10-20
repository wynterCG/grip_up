"""Publish the bounded R2 stop and supplementary diagnostics without a restart."""
from pathlib import Path
import csv
import gzip
import json
import shutil
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'tools/auto_tuning')]
from common import DEST,read_json,atomic_json,file_hash,source_hashes
import virtual_cursor_report as archive
BASE=ROOT/'builds/eval_virtual_cursor/benchmark_v133_r2'
DOC=ROOT/'docs/validation/auto_tuning/benchmark_v133_r2'

def text(name,value):
    p=DOC/name;assert not p.exists(),p
    p.write_text(value.strip()+'\n',encoding='utf-8',newline='\n')

def csv_file(name,rows):
    with (DOC/name).open('x',encoding='utf-8',newline='') as h:
        w=csv.DictWriter(h,list(rows[0]));w.writeheader();w.writerows(rows)

def mcp(name):
    return json.JSONDecoder().raw_decode((BASE/'native'/name).read_text(encoding='utf-8-sig'))[0]

def main():
    assert not (DOC/'verification.json').exists()
    original=read_json(BASE/'source_identity.json')
    final=read_json(BASE/'diagnostic_final_source_identity.json')
    baseline=read_json(DOC/'baseline_manifest.json')
    plan=read_json(DOC/'run_plan.json');ref=read_json(BASE/'reference_session.json')
    pre=read_json(BASE/'preflight_session.json');diag=read_json(BASE/'diagnostics_session.json')
    assert pre['pass'] and len(pre['runs'])==13
    assert len(ref['runs'])==1 and not ref['pairs'] and ref['hard_stop']=='ENVIRONMENT_NOT_COMPARABLE:CANONICAL_BACKING'
    failed=ref['runs'][0]
    assert failed['engine_result']['world_creation_record']=={} and failed['engine_result']['backing_initialization']=={}
    assert len(diag['runs'])==4 and [r['status'] for r in diag['runs']]==['PURE_CONTRACT_FAILED','PURE_CONTRACT_PASS','RUN_VALID','RUN_VALID']
    assert source_hashes()==source_hashes(DEST)==final['source_hashes']
    assert all(file_hash(DEST/p)==h for p,h in baseline['historical_tracked_evidence'].items())
    assert all(file_hash(ROOT/p)==h for p,h in baseline['historical_raw_evidence'].items())
    assert all(file_hash(Path(p))==h for p,h in baseline['protected_external'].items())
    regressions=[r for group in ['benchmark_reference','benchmark_live_reference'] for r in read_json(DOC/group/'attempt_001/results.json')['runs']]
    assert len(regressions)==34 and sum(r['checks'] for r in regressions)==1146 and all(r['passed'] for r in regressions)
    pair=read_json(BASE/'diagnostic_pair_120.json')
    assert pair['status']=='STRICT_MATCH' and pair['point_of_call']['status']=='STRICT_MATCH' and pair['ticks']==536
    assert not any(pair['first_by_layer'].values())
    assert pair['legacy_layers']['status']=='CURSOR_OR_CAMERA_MISMATCH'
    catches=[]
    for r in diag['runs'][2:]:
        c=r['engine_result']['scenarios'][0]['catch_native']
        assert all(c[k] for k in ['real_contact','retained_at_end','beyond_static_reach','known_underside_selected'])
        assert [c[k] for k in ['contact_tick','source_free_tick','retained_tick']]==[440,455,527]
        catches.append({'run_id':r['run_id'],'hz':r['hz'],'mode':r['mode'],'lane':'SUPPLEMENTARY_FIXED_REPLAY','source_commit':r['source_commit'],'tape_sha256':r['tape_sha256'],'catch':c,'ranking_eligible':False})
    native=json.loads(mcp('normal_runtime_response.json')['output'][0])
    assert native['profile']==2 and native['source_kind']=='LIVE' and native['provider_disabled'] and native['projection_probe_absent'] and not native['camera_virtual']
    assert mcp('errors_after_response.json')['count']==0
    assert all(read_json(BASE/'native/restoration.json')[k] for k in ['project_C_restored','project_E_restored','owned_editor_closed'])
    pack=read_json(BASE/'safety/export_pack_check.json');assert len(pack['excluded'])==11 and all(pack['excluded'].values())
    for label in ['export','export_smoke','export_pack_inspection_isolated']:
        r=read_json(BASE/'safety'/(label+'_receipt.json'));assert r['exit_code']==0 and not r['script_errors']
    catalog=read_json(ROOT/'features/evaluator_virtual_cursor/resources/benchmark_eval_v133.json')
    catalog.update(qualification_status='NOT_QUALIFIED_R2_ADMISSION_STOP',ranking_enabled=False,
                   qualification_partition='PUBLIC_QUALIFICATION_ONLY',future_training='UNASSIGNED',public_validation='RESERVED',private_holdout='UNOPENED')
    atomic_json(DOC/'benchmark_catalog_v133.json',catalog)
    cells=[{'scenario':d['id'],'hz':hz,'backing':[1024,576],'modes':['headless','rendered_scripted'],'seed':101,
            'source_commit':original['repository_commit'],'policy':d['input_policy_revision'],'onset_tick':None,'task_succeeded':None,'metric_status':None,
            'availability':'NOT_RUN_EARLY_STOP','eligibility':'MISSING_COVERAGE','ranking_eligible':False,'tape_sha256':None,
            'n_fixed_pairs_planned':3 if d in catalog['scenarios'][:4] else 1,'n_fixed_pairs_observed':0} for d in catalog['scenarios'] for hz in [120,60]]
    atomic_json(DOC/'eligibility_matrix.json',{'decision':'NO_GO_BENCHMARK','cells':cells,'eligible_domains':[],'supplementary_catches':catches,'supplementary_does_not_fill_primary':True})
    metric_names=['signed_progress_m','latency_to_useful_motion_s','directional_efficiency','overshoot_after_release_m','stop_path_3d_m','settling_time_s','brake_fraction_reached','reversal_time_s','catch_success','retention_s','foot_load_contribution','twist_rms_rad','hard_physical_violations']
    csv_file('scenario_metrics.csv',[{'scenario':c['scenario'],'hz':c['hz'],'backing':'1024x576','mode':c['mode'],'repeat':c['repeat'],'lane':c['lane'],'source_commit':original['repository_commit'],'seed':101,'policy':'benchmark_v133_preparation_r1','tape_sha256':'','onset_tick':'','task_succeeded':'','metric':metric,'metric_status':'','value':'','availability':'NOT_RUN_EARLY_STOP'} for c in plan['new_domain_cells'] for metric in metric_names])
    comparisons=[]
    for name in ['swing_catch_train']+[d['id'] for d in catalog['scenarios']]:
        for hz in [120,60]:
            for rep in ([1,2,3] if name=='swing_catch_train' or name in [d['id'] for d in catalog['scenarios'][:4]] else [1]):
                comparisons.append({'scenario':name,'hz':hz,'backing':'1024x576','modes':'headless/rendered_scripted','repeat':rep,'source_commit':original['repository_commit'],'seed':101,'status':'INCOMPLETE_REJECTED_SETUP' if name=='swing_catch_train' and hz==120 and rep==1 else 'NOT_RUN_EARLY_STOP','ranking_eligible':False})
    comparisons.append({'scenario':'swing_catch_train','hz':120,'backing':'1024x576','modes':'headless/rendered_scripted','repeat':1,'source_commit':final['repository_commit'],'seed':101,'status':'SUPPLEMENTARY_STRICT_MATCH_PRECISE_CHANNELS','ranking_eligible':False})
    csv_file('replay_comparison.csv',comparisons)
    atomic_json(DOC/'first_divergences.json',{'first_failure':'ENVIRONMENT_ADMISSION_FALSE_REJECTION','run_id':failed['run_id'],'source_commit':original['repository_commit'],'reason':ref['hard_stop'],'phase':'BEFORE_BACKING_INITIALIZATION_CLOCK_AND_WORLD','scenario_tick':None,'worlds':0,'manifest_size':[1024,576],'cause':'Godot JSON float-array versus integer-array equality','reproduced_by_D1_and_D2':True,'postfix_pair':pair,'representation_note':'Legacy cursor raw scalar versus actual float32 Vector2 differs within both processes identically; do not call this a headless/rendered physical mismatch.'})
    atomic_json(DOC/'negative_controls.json',{'preflight_wrong_size':'PASS_REJECTION','pure_JSON_contract_failed_attempt_preserved':diag['runs'][0],'pure_JSON_contract_final':diag['runs'][1],'negative_physical_processes':0,'external_mouse_click_focus':'NOT_RUN_IN_R2; previous evidence preserved separately','A0_A1_missing_cell_canary':'Existing34Pythoncontracts pass; no A1 physics run or default change','new_observer_OFF':'NOT_RUN_EARLY_STOP'})
    for directory in sorted((BASE/'attempts').iterdir()):
        target=DOC/'runs'/directory.name;target.mkdir(parents=True,exist_ok=False)
        for name in ['manifest.json','engine_result.json','result.json','receipt.json','execution.json','stdout.txt','stderr.txt']:
            if (directory/name).exists():shutil.copy2(directory/name,target/name)
        data=(directory/'trace.jsonl').read_bytes() if (directory/'trace.jsonl').exists() else b'{"availability":"NO_GAMEPLAY_WORLD","ticks":[]}'
        (target/'trace.json.gz').write_bytes(gzip.compress(data,mtime=0))
    shutil.copy2(BASE/'native/ordinary_main.png',DOC/'ordinary_main.png')
    shutil.copy2(ROOT/'docs/validation/auto_tuning/benchmark_v133/human_protocol_reference.md',DOC/'human_protocol_reference.md')
    atomic_json(DOC/'verification.json',{'decision':'NO_GO_BENCHMARK','primary_measured_commit':original['repository_commit'],'diagnostic_final_commit':final['repository_commit'],
        'preflight':{'attempted':13,'passed':13,'positive':12,'negative':1,'gameplay_worlds':0},
        'primary':{'planned':84,'attempted':1,'valid':0,'invalid_setup':1,'aborted':0,'early_stop_not_run':83,'gameplay_worlds':0,'reference_remaining':11,'new_domain_remaining':72},
        'diagnostics':{'attempted':4,'pure_contract_failed':1,'pure_contract_passed':1,'physical_valid':2,'gameplay_worlds':2,'hz':[120],'published_precise_pair':'STRICT_MATCH','legacy_result':'CURSOR_OR_CAMERA_MISMATCH_PRESERVED_WITH_REPRESENTATION_SCOPE'},
        'budget':{'max':96,'conservative_attempts_charged':5,'new_physical_worlds':2,'negative_physical':0,'diagnostic_slots_used':4,'no_budget_reallocation':True},
        'regressions':{'processes':34,'checks':1146,'passed':True,'separate_budget':True},'normal_startup':'PASS','MCP_profile2_LIVE':'PASS','MCP_new_errors':0,
        'export':{'release_and_plain_smoke':'PASS','isolated_debug_engine_pack_inspection':'PASS','excluded_test_paths':11,'pack_inspection_is_release_template':pack['release_template'],'identity':read_json(BASE/'safety/export_identity.json')},
        'protection':{'historical_tracked_files':len(baseline['historical_tracked_evidence']),'historical_raw_files':len(baseline['historical_raw_evidence']),'all_verified_unchanged':True,'C_E_source_parity':True,'source_files':len(final['source_hashes']),'gameplay_input_physics_camera_tuning_unchanged':True},
        'optimizer_RL_Jev_runs':0,'private_outcomes_accessed':0,'human_playtests':0,'new_qualified_domains':0,'no_automatic_R3':True})
    text('dataset_migration.md','''# Dataset status

R2 remains public qualification evidence, not training scores. Its six domain/Hz families have no primary outcomes; neither catch diagnostic is a qualified score. Adaptive captures did not run. Future training and public validation are unassigned, private holdout outcomes remain unopened, and human sessions are separate. Keep old unequal-window results, A1 regressions and earlier NO_GOs unchanged. No missing metric becomes zero or a better aggregate. Foot-step and release-stop retain their prospective n1/Hz diagnostic exclusion even if a later campaign runs them; they cannot silently replace n3 primary coverage.
''')
    text('decision.md','''# GRIP UP v1.3.3 R2 — decision

- Baseline/source preservation: PASS;1146 fresh regression checks.
- BQ1 canonical backing/clock: PASS;12 positive processes plus1 correct wrong-size rejection.
- BQ2 primary catch reference: REJECTED_SETUP on first H120;0 qualified pairs,11 reference processes not run.
- Vertical/asymmetric/clean lateral L/R: MISSING_COVERAGE at60/120Hz.
- Foot-step/two-hand stop: NOT_RUN; diagnostic-only n1 plan excludes ranking. One-hand60Hz remains OPEN.
- Cause: JSON float-array compared with integer-array before startup; no primary body/tick existed.
- Correction: exact numeric scalar validation, with nonnumeric dimensions rejected;16-check contract passes.
- Supplementary: one fixed H/R120 pair strictly matches complete published precision channels and retains actual catch. It is diagnostic, n1, no60Hz coverage; legacy scalar/Vector2 representation difference remains explicitly recorded.
- Final verdict: **NO_GO_BENCHMARK** for the frozen R2 primary campaign.
- Private outcomes/search/RL/Jev/human playtests:0. No gameplay defaults promoted.
- Next action: keep source fix and evidence; no automatic R3 or optimizer. A separately authorized fresh campaign must redo primary admission/reference with the corrected source.
''')
    text('result_report.md',f'''# GRIP UP v1.3.3 R2 — relatório

**NO_GO_BENCHMARK na campanha primária; inicialização corrigida e confirmada em diagnóstico.** O utilizador autorizou repetir a v1.3.3 depois da correção headless. Criámos `benchmark_v133_r2`, com plano/source freeze próprios, mesmo catálogo e teto72+12+8+4=96. A fonte primária é`{original['repository_commit']}`; a fonte final apenas diagnóstica é`{final['repository_commit']}`. O NO_GO anterior e as tentativas de desenvolvimento da inicialização ficam intactos.

## Admissão passou; referência encontrou uma rejeição falsa

Os13 preflights novos passaram:3 processos porHz60/120 e modoH/R, mais1 negativo1440×810 corretamente recusado. Cada positivo observou backing1024×576, viewport1920×1080 e os dois callbacks1/Hz antes de criar gameplay. Nos60Hz, os recibos preservam os callbacks iniciais ainda a120 antes da confirmação; não se fingiu que o relógio já estava pronto. O headless regista a mudança pré-mundo do dummy64×64, pedida explicitamente por `--backing-size`. Renderizado apenas observa o tamanho real.

O primeiro replay H120, `{failed['run_id']}`, terminou BLOCKED_SETUP/CANONICAL_BACKING. O seu JSON continha[1024,576], mas a validação nova comparava o array de floats do parser com um literal de inteiros. `backing_initialization={{}}`, `world_creation_record={{}}`, audits vazios e custoPRE/POST0 provam que parou antes de janela configurada, clock, corpo, picking ou Jolt da tarefa. Não é um desvio físico, suspensão ou falha de catch. A matriz primária parou:1 tentativa inválida de setup,0 válidas,0 abortadas,83 não executadas (11 referências+72 domínios).

## Quatro diagnósticos limitados e correção

| Slot | Fonte/escopo | Resultado |
|---|---|---|
| D1 | contrato puro, fonte intermediária | reproduz array JSON diferente;15/16 checks aprovados,1 falha no negativo de dimensão string; erro e stderr preservados |
| D2 | contrato puro, fonte final |16/16; inteiros/floats/JSON/mistos canónicos aceites; fracionários, tamanho trocado, strings, null e forma inválida rejeitados sem arredondar |
| D3 | tape036 original, H120 |RUN_VALID;536POST; contacto440, origemFREE455, retenção527 até536 |
| D4 | mesma tape, R120 |RUN_VALID; mesmos536POST e eventos; comparação de precisão completa STRICT_MATCH |

A correção compara dimensões escalares exatas após verificar tipo numérico. O teste positivo agora inclui o `projection_config` serializado realmente utilizado pelo replay; os19 testes anteriores só exercitavam a admissão positiva sem esse campo. Essa lacuna e o erro introduzido estão explicitamente reconhecidos nos pareceres. Não alterámos física, corpos, limites, controlo, câmara normal ou contactos para fazer testes passar. D1 não foi apagado nem convertido em PASS.

Somente D3/D4 criaram mundos de gameplay:2, ambos suplementares a120Hz. Os quatro slots foram consumidos incluindo os dois testes puros; não se lançou o H60 diagnóstico inicialmente pretendido nem se realocou orçamento. Nenhum catch diagnóstico ocupa uma célula primária. Não existe n3, referência nova60Hz ou domínio primário qualificado.

## Precisão e primeiro ponto de diferença

Os canais completos INPUT/PICK/CONTACT/PHYSICS/TASK coincidem exatamente entre os dois diagnósticos:536ticks,2 pedidos/pick sidecars, mesmos inputs efetivos, cursor API, câmara, raios reais, hits, âncoras materiais, comprimentos/forças/reações, pés, autoridade ground, COM/pose/v/omega. O resultado point-of-call também é STRICT_MATCH. Nenhuma tolerância foi acrescentada.

O comparador legado permanece `CURSOR_OR_CAMERA_MISMATCH` no tick55: escalar solicitadoY480.534973144531 versus Vector2 efetivoY480.53497314453125. Ambos os processos têm os mesmos valores em cada representação; converter o escalar pelo float32 nativo produz exatamente o vetor. O JSON antigo de15 dígitos também imprime o vetor como480.534973144531. Assim, preservar esse resultado distingue comparação entre representações internas de uma diferença H/R. O raw/bits fica arquivado; não se faz uma alegação geral de roundtrip JSON sem perda nem se reclassifica o resultado legado.

O catch diagnóstico é real, face inferior−Y do destino, pedido fora do alcance estático, mesma âncora retida. Os máximos observados são iguais nos dois processos: mãos254.948N, pés45.471N, assistência20.0000014Nm, momento combinado67.24548Nm. A assistência usa a convenção de monitor existente20.001; nenhum cap foi alargado. Força de mão FREE/REACHING foi zero. Ground chegou a168N: estes catches incluem B1/chão e não são arm-only. Contact buffer vazio não é prova de ausência de colisão.

## Cobertura e métricas

Vertical, assimétrico, lateral esquerdo/direito, foot-step e stop ficam MISSING_COVERAGE a60 e120Hz. Nenhuma captura adaptativa ou métrica desses domínios correu. `scenario_metrics.csv` tem936 linhas planeadas72×13, com status/valor ausentes e disponibilidade NOT_RUN; não preenchemos zero. `replay_comparison.csv` distingue os34 pares planeados incompletos/não executados do único par suplementar. A matriz não misturaHz/modos/fontes, e nenhum domínio recebe ranking. Os testes de contrato Python34/34 passaram; D2 acrescenta16 checks reais de admissão JSON, não16 resultados de locomoção.

Continuam por provar progresso/latência/eficiência nos novos domínios, compressão útil dos pés, stop3D/settle/braking, one-hand60Hz, outros offsets, counter-swing, seeds,1440 portátil e hardware/foco novos. Os controlos físicos negativos e observerOFF novos não correram após a paragem. Evidência histórica permanece histórica; não preenche cobertura nova.

## Preservação e distribuição

As34 suites/processos antigos a60/120 passaram1146 checks, fora do teto por autorização expressa. Arranque headless normal coincide com o snapshot anterior. Godot MCP Pro verificou profile2/LIVE, hold, bindings e parâmetros originais, provider desligado, probe ausente, câmara virtual desligada;0 erros novos após play e1 warning anterior conhecido de projeto aninhado. Screenshot foi guardado. Foi inspeção automatizada, não playtest humano. Editor próprio encerrado e settings C/E restaurados byte a byte.

Export release e arranque plain passaram. A inspeção isolada do pack com motor debug confirmou11 caminhos experimentais ausentes, incluindo helper novo. `release_template=false` nessa inspeção está distinguido da smoke real do executável release. Os ficheiros históricos versionados({len(baseline['historical_tracked_evidence'])}) e raw({len(baseline['historical_raw_evidence'])}), Janga, rollback, project/export preset foram verificados sem alterações. Fontes atuais C/E coincidem. Performance instrumentada existe em recibos por componente, mas nenhum controlo novo ON/OFF foi executado: overhead causal não é qualificado.

## Decisão e integridade

Conservadoramente,5 tentativas ocupam o orçamento96 (1 referência bloqueada+4 diagnósticos), com2 mundos físicos novos;13 preflights são puros e contam à parte. Todos os insucessos, intermediários, stderr, manifests e versões estão arquivados com CRC/SHA por membro. BQ1 passou; BQ2 primário foi rejeitado antes de simular; BQ3–BQ5 runtime não qualificados. Especialistas independentes preservam essa distinção e recomendam NO_GO primário.

Optuna/RL/Jev, outcomes privados, playtests humanos e novas promoções de defaults:0. A correção final fica disponível, mas não iniciámos R3 automaticamente. Uma nova campanha autorizada terá de voltar a medir a referência primária com a fonte corrigida, antes de expandir para os domínios.
''')
    text('README.md','''# v1.3.3 R2 qualification repeat

**NO_GO_BENCHMARK primary campaign.** Canonical BQ1 passed; the first reference replay was falsely rejected by a JSON-array type comparison before any world existed. The correction is verified by a16-check contract and one supplementary H/R120 physical pair. These diagnostics do not fill missing primary coverage.

[Report](result_report.md) · [Decision](decision.md) · [Matrix](eligibility_matrix.json) · [Verification](verification.json) · [First failure and raw comparison](first_divergences.json) · [Physics review](specialist/final_physics_review.md) · [Measurement review](specialist/measurement_review.md) · [Evidence](evidence_manifest.json).

Run plan and immutable commands: `python tools/benchmark_repeat.py prepare`, `freeze`, `preflight`, `reference` (separate stages); `domains` was NOT_RUN. `python tools/benchmark_repeat_diagnostics.py` preserved its failed D1, then `--finish` used the three remaining slots. Used paths intentionally reject repetition. No automatic next campaign or optimizer.
''')
    archive.DOC=DOC;index={}
    for label,identity in [('primary',original),('diagnostic_intermediate',read_json(BASE/'diagnostic_source_identity.json')),('diagnostic_final',final)]:
        archive.source_archive(label+'_source',identity['repository_commit'],identity['source_hashes'],index)
    files=[p for p in BASE.rglob('*') if p.is_file() and p.suffix.lower()!='.exe']
    files += [ROOT/'tools/benchmark_repeat.py',ROOT/'tools/benchmark_repeat_diagnostics.py',ROOT/'tools/benchmark_repeat_report.py',ROOT/'tools/benchmark_preflight.py',ROOT/'tools/benchmark_safety.py',ROOT/'tools/check_benchmark_backing.py']
    archive.archive('all_r2_raw_receipts',files,index)
    atomic_json(DOC/'evidence_manifest.json',{'archives':index,'primary_source':original['repository_commit'],'final_diagnostic_source':final['repository_commit'],
        'document_hashes':{p.relative_to(DOC).as_posix():file_hash(p) for p in DOC.rglob('*') if p.is_file() and 'evidence' not in p.relative_to(DOC).parts and p.name!='evidence_manifest.json'},
        'release_executable':read_json(BASE/'safety/export_identity.json'),'all_failed_attempts_preserved':True,'optimizer':'OFF'})
    print('R2 report published: primaryNO_GO;4diagnostics retained; no automatic next campaign.')

if __name__=='__main__':main()
