"""Read-only evidence publication for the newly authorized replay campaign."""
from pathlib import Path
import json,sys,math,shutil
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'tools/auto_tuning/virtual_cursor'),str(ROOT/'tools/auto_tuning')]
from common import atomic_json,read_json,file_hash,source_hashes,engine_identity
from run import first_difference
import virtual_cursor_report as archives
DOC=ROOT/'docs/validation/virtual_cursor_requalification_v132a'
BASE=ROOT/'builds/eval_virtual_cursor/requal_20261020_r1'
DEST=Path(r'E:\Godot Games\grip_up')
def write(name,text):
    path=DOC/name;assert not path.exists(),path
    path.write_text(text.strip()+'\n',encoding='utf-8',newline='\n')
def one(stage):return next((BASE/stage/'attempts').glob('*/engine_result.json'))
def inspect_divergence(hz,actual_path):
    tape=read_json(BASE/'capture/tapes'/f'catch_{hz}.json');audit=read_json(actual_path.parent/'virtual_audit.json')
    layers=read_json(actual_path.parent/'layered_comparison.json')
    first_ray=layers['first_by_layer']['raycast'];index=first_ray['tick']-1
    expected=tape['reference_ticks'][index];actual=audit['ticks'][index]
    e=expected['target']['picks'][0];a=actual['target']['picks'][0]
    norm=lambda x,y:math.sqrt(sum((u-v)**2 for u,v in zip(x,y)))
    first_node_camera=None
    for i,(x,y) in enumerate(zip(tape['reference_ticks'],audit['ticks'])):
        difference=first_difference(x['camera']['pose'],y['camera']['pose'])
        if difference:first_node_camera={'tick':i+1,'difference':difference};break
    return {'physics_hz':hz,'run_id':actual_path.parent.name,'first_by_layer':layers['first_by_layer'],'first_node_camera_transform_difference':first_node_camera,'first_ray_tick':index+1,'ray_direction_delta_norm':norm(e['audit']['rays'][0]['direction'],a['audit']['rays'][0]['direction']),'material_point_delta_m':norm(e['audit']['winner']['local_point_m'],a['audit']['winner']['local_point_m']),'node_camera_pose_at_first_ray_exact':e['camera_pose']==a['camera_pose'],'projection_at_first_ray_exact':e['camera_projection']==a['camera_projection'],'ray_origin_exact':e['audit']['rays'][0]['origin_m']==a['audit']['rays'][0]['origin_m'],'pixel_exact':e['pointer']==a['pointer'],'winner':{'expected':e['audit']['winner'],'actual':a['audit']['winner']},'capture':read_json(actual_path)['scenarios'][0]['catch_native'],'environment':{'headless':tape['initial'],'rendered':audit['environment']},'no_tolerance_added':True,'causality':'first observed API ray divergence; underlying projection/cache/viewport-rounding cause not proven; no Jolt-cause attribution'}
def main():
    frozen=read_json(BASE/'source_identity.json');current=source_hashes(ROOT)
    assert current==frozen['source_hashes']==source_hashes(DEST)
    old=read_json(ROOT/'docs/validation/virtual_cursor_v132a/verification.json')
    delta={p for p,h in old['source_hashes'].items() if current.get(p)!=h}
    assert delta=={'features/evaluator_virtual_cursor/scripts/replay_input_provider.gd','features/evaluator_virtual_cursor/scripts/virtual_cursor_driver.gd','tools/auto_tuning/virtual_cursor/run.py'},delta
    oldmanifest=read_json(ROOT/'docs/validation/virtual_cursor_v132a/evidence_manifest.json')
    assert all(file_hash(base/'docs/validation/virtual_cursor_v132a/evidence'/p)==v['sha256'] for base in (ROOT,DEST) for p,v in oldmanifest['archives'].items())
    assert all(file_hash(base/'docs/validation/virtual_cursor_v132a'/p)==h for base in (ROOT,DEST) for p,h in oldmanifest['handoff_document_sha256'].items())
    assert file_hash(ROOT/'project.godot')==file_hash(DEST/'project.godot')==old['protection']['project_exact_sha256']
    baseline=read_json(BASE/'baseline/session_state.json')['runs'];attempted=[r for r in baseline if r.get('run_id')]
    assert len(attempted)==7 and sum(r['status']=='completed' for r in attempted)==6
    render120=Path(next(r['directory'] for r in attempted if r['condition']=='V0-R'))/'engine_result.json'
    render60=one('diagnostic_quiet60')
    divergent=[inspect_divergence(120,render120),inspect_divergence(60,render60)]
    atomic_json(DOC/'first_divergence.json',{'decision':'NO_GO_INPUT_REPLAY','per_hz':divergent,'phase_note':'The API request/ray values originate in PRE and are carried into POST audit snapshots. POST is post-control before next integration, not post-solver.'})
    matrix=[{k:r.get(k) for k in ['condition','hz','repeat','status','reason','run_id']} for r in baseline]
    matrix.extend({'condition':condition,'hz':hz,'repeat':repeat,'status':'NOT_RUN_EARLY_STOP','reason':'First rendered120 ray/material gate failed; human attempts are separate diagnostics'} for condition in ['V0-M','V0-F'] for hz in [120,60] for repeat in [1,2,3])
    assert len(matrix)==24
    atomic_json(DOC/'test_matrix.json',{'campaign':'requal_20261020_r1','qualification':matrix,'qualification_attempted':7,'qualification_passed':6,'qualification_rejected':1,'qualification_not_run_early_stop':17,'diagnostic_stages':['human120','quiet60','human60','mouse120'],'diagnostics_fill_no_qualification_cells':True})
    pairs=read_json(BASE/'paired_summary.json')
    assert len(pairs['comparisons'])==3 and all(r['status']=='PASS_PICKING_REPLAY' and all(x is None for x in r['first_by_layer'].values()) for r in pairs['comparisons'])
    atomic_json(DOC/'paired_rendered_summary.json',pairs)
    human=[]
    for stage in ['diagnostic_human120','diagnostic_human60','diagnostic_mouse120']:
        path=one(stage);r=read_json(path);v=r['virtual_input'];ticks=read_json(path.parent/'virtual_audit.json')['ticks']
        first_unfocused=next((i+1 for i,t in enumerate(ticks) if not t['command_accepted']['window_has_focus']),None)
        human.append({'stage':stage,'run_id':path.parent.name,'physics_hz':r['physics_hz'],'ticks':len(ticks),'focus_events':v['focus_events'],'rejection_counts':v['rejection_counts'],'maximum_tick_gap_usec':v['maximum_tick_wall_gap_usec'],'first_unfocused_post_tick':first_unfocused,'unfocused_post_ticks':sum(not t['command_accepted']['window_has_focus'] for t in ticks),'distinct_hardware_positions':len({tuple(t['canonical_input']['hardware_aim_px']) for t in ticks}),'runtime_status':r['status'],'runtime_reason':r.get('reason',''),'focus_return_observed':any(e['focused'] and e['tick']>=1 for e in v['focus_events']),'synthetic_events_injected':False})
    observation=read_json(BASE/'human_observation.json')
    atomic_json(DOC/'human_interference.json',{'observations':human,'user_attestation':observation,'outside_click_attribution':'Not independently confirmed; clicks delivered to game and separate focus loss were measured.','runtime_suspension_observed':False,'focus_recovery_observed':False})
    h60=next(r for r in human if r['physics_hz']==60);mouse=human[2]
    assert h60['first_unfocused_post_tick']==133 and h60['unfocused_post_ticks']==131 and not h60['focus_return_observed']
    assert mouse['rejection_counts']['InputEventMouseMotion']==220 and mouse['rejection_counts']['InputEventMouseButton']==2
    all_paths=list(BASE.glob('**/attempts/*/engine_result.json'))
    assert len(all_paths)==13
    assert all(read_json(p)['status']=='completed' and read_json(p)['scenarios'][0]['catch_native']['real_contact'] and read_json(p)['scenarios'][0]['catch_native']['retained_at_end'] for p in all_paths)
    audits=[read_json(p.parent/'virtual_audit.json') for p in all_paths]
    assert sum(len(a['ticks']) for a in audits)==5330
    assert all(not any(s.get('invariants',{}).values()) for p in all_paths for s in read_json(p)['scenarios'])
    native=json.JSONDecoder().raw_decode((BASE/'native/normal_runtime_response.json').read_text(encoding='utf-8-sig'))[0]
    normal=json.loads(native['output'][0]);assert normal['provider_disabled'] and not normal['camera_virtual'] and normal['source_kind']=='LIVE' and normal['profile']==2
    assert all(normal[k]==v for k,v in read_json(ROOT/'docs/validation/evaluator_v132/baseline/normal_runtime.json').items())
    errors=json.JSONDecoder().raw_decode((BASE/'native/errors_after_response.json').read_text(encoding='utf-8-sig'))[0];assert errors['count']==0
    assert all(read_json(BASE/'native/restoration.json')[k] for k in ['project_C_restored','project_E_restored','owned_editor_closed'])
    shutil.copy2(BASE/'native/ordinary_main.png',DOC/'ordinary_main.png')
    atomic_json(DOC/'verification.json',{'campaign':'requal_20261020_r1','decision':'NO_GO_INPUT_REPLAY','source_identity':frozen,'engine':engine_identity(),'new_godot_contract_checks':24,'new_python_contract_tests':18,'new_physical_worlds':13,'new_post_snapshots':5330,'qualification':{'planned':24,'executed':7,'pass':6,'rejected':1,'not_run_early_stop':17},'direct_diagnostics':4,'json_admission_all_replays_passed':True,'all_effective_inputs_and_cursor_exact':True,'headless_same_hz_replays_exact_in_all_compared_fields':True,'paired_rendered_human_replays_exact_in_all_compared_fields':True,'cross_mode_ray_material_gate_pass':False,'human_focus_return_observed':False,'session_suspension_observed':False,'native_main_profile':2,'native_main_provider':'DISABLED','native_main_input':'LIVE','native_fresh_errors':0,'normal_snapshot_exact_equal_previous_baseline':True,'production_gameplay_physics_camera_tuning_source_unchanged_since_a8c1172':True,'approved_existing_test_infrastructure_diffs':sorted(delta),'old_reports_archives_unchanged':True,'new_optimizer_trials':0,'new_rl_trials':0,'private_holdout_outcomes_accessed':False,'current_source_hashes':current})
    table='\n'.join(f"| {d['physics_hz']} | {d['first_ray_tick']} | {d['ray_direction_delta_norm']:.9g} | {d['material_point_delta_m']*1e6:.6f} µm | {d['capture']['contact_tick']} | {d['capture']['retained_tick']} |" for d in divergent)
    write('report.md',f'''
# GRIP UP — Requalificação do cursor virtual / JSON corrigido

**Resultado: a admissão JSON passou; o input virtual resistiu à interferência observada; a equivalência estrita headless↔renderizado continua NO_GO_INPUT_REPLAY.** A primeira divergência passa agora pelo raycast e pela âncora material, com input/cursor exatos. A revisão independente e os recibos acompanham este relatório. Não foram iniciados ML/Optuna/RL nem alteradas forças, geometria ou locomoção.

## Campanha e proveniência

Nova campanha `requal_20261020_r1`, pedida explicitamente pelo utilizador após o relatório anterior; fonte congelada036a9dc, diretório novo `builds/eval_virtual_cursor/requal_20261020_r1`. As tapes120/60 são **capturas novas da fonte corrigida**. Não se reutilizou como qualificação a tape derivada diagnostic-only anterior. Os resultados e o NO_GO da campanha anterior permanecem intactos.

Orçamento: até8 processos de desenvolvimento,24 células de qualificação H/R/M/F×60/120×n3 e4 diagnósticos diretamente relacionados. Executados2 mundos de captura,7 tentativas de qualificação e4 diagnósticos:13 mundos físicos /5330 snapshots POST. O MCP normal é suplemento de segurança. Uma única instância do motor executou os testes de cada vez.

Só três ficheiros de infraestrutura existentes mudaram: runner Python, driver de teste e provider de replay; acrescentaram-se comparador/testes e wrappers. O gameplay, solver, câmara normal, materiais, recursos de tuning e Janga ficaram preservados. Mantêm-se12kg, alcance0.65708m,360N mãos partilhados,180N pés/120N por pé,20Nm assistência e150Nm resultante.

## Admissão JSON e replay sem intervenção

A antiga falha `INPUT_BUTTON_EDGE` não voltou: as11 execuções de replay leram/validaram a tape pelo parser real do Godot antes de construir o cenário; as13 execuções, contando capturas, terminaram no motor com contacto e retenção reais. Isso não equivale a aprovação de fidelidade: os validadores rejeitam os casos renderizados que divergem do referencial headless.

Headless120:3/3 replays coincidem com a captura da mesma frequência em todos os campos comparados. Headless60:3/3, igualmente sem primeira divergência. Comparam-se input efetivo, cursor, pose de câmara, raios, collider/face, sequência de âncoras materiais e campos físicos publicados (COM/pose/v/omega/massa/forças). Não significa comparação bitwise entre frequências ou de todo o estado interno de Jolt/pés.

No primeiro renderizado120 surgiu uma diferença estrita de ray/material. A matriz parou:6 passes headless,1 rejeição renderizada e17 NOT_RUN_EARLY_STOP. Os casos seguintes são os diagnósticos explicitamente pedidos, sem preencher as células paradas ou acumular uma pontuação positiva.

## Primeiro ponto de divergência

| Hz | Primeiro ray/material diferente | Norma Δ direção do raio | Distância material | Contacto renderizado | Retenção renderizada |
|---|---:|---:|---:|---:|---:|
{table}

A120, no tick282, os inputs efetivos, a validade/posição do cursor, a origem do raio, offset0, pose de câmara registada no pedido e matriz de projeção4×4 são exatos. A primeira diferença aparece no **resultado de `project_ray_normal`**, seguido do ponto material. O collider é `catch`, shape0 e face−Y em ambos. Não é o antigo desvio de viewport-center nem a troca para a face+Z. As primeiras diferenças seguintes são força440, velocidade/omega442 e COM449. O contacto continua440, origem FREE455 e primeira retenção527 em ambos.

A60, o primeiro pedido na superfície `source`, tick28, já apresenta a diferença de raio/material, igualmente com pose/matriz registadas exatas, offset0 e face−Y. Seguem-se força46, velocidade/omega48 e COM65. O renderizado captura o destino no tick210, contra215 no headless; ambos libertam a origem223 e confirmam retenção259. A diferença microscópica inicial não autoriza declarar a trajetória inteira equivalente.

Os ambientes físicos de apresentação são diferentes: headless window1024×576/final transform≈0.533333; renderizado1440×810/0.75. O viewport lógico é1920×1080 e a canvas identity em ambos. Esses dados são contexto para investigar projeção/rounding/cache/transformação efetiva; **a causa interna ainda não está provada**. Não se atribui a falha ao Jolt, ao utilizador ou a uma força escondida. Não se adicionou tolerância de pixels/contacto nem correção de ponto para fazer passar o teste.

`first_divergence.json` guarda as primeiras diferenças de cada camada, os valores do vencedor e o primeiro desvio do transform de câmara separadamente da pose física de origem. Os `layered_comparison.json` preservam uma janela limitada de contexto. Os valores de input/picking são produzidos em PRE e transportados para o audit POST; POST significa depois dos callbacks de controlo e antes da próxima integração, não post-solver.

## Interferência humana efetivamente observada

Houve8 segundos de aviso antes de existir mundo/provider. Ações durante esse aviso não contam como atividade no replay. A amostra de foco inicial tick0 também não conta como transição de foco.

1. **Primeiro humano120:** iniciou já sem foco e processou536 ticks. Não recebeu eventos nem transições duranteACTIVE. Demonstra execução em segundo plano neste caso; não demonstra um Alt+Tab durante a reprodução.
2. **Foco60:** iniciou com foco e recebeu callback de perda após o frame132. O primeiro POST sem foco é133; continuou até263, com131 POST sem foco,1 evento de teclado rejeitado e maior intervalo entre ticks34.469ms. O input efetivo/cursor mantiveram-se exatos. Não houve RUNTIME_SUSPENDED, tick perdido ou invalidação ambiental. O utilizador confirmou: **“n voltei a tempo”**. Não houve recuperação de foco antes do fim e não se afirma tê-la testado.
3. **Rato120:** registou220 eventos de movimento e2 eventos de botão rejeitados;474 posições distintas do cursor físico nos snapshots. O cursor virtual e os comandos da tape não mudaram. Maior intervalo34.728ms, sem perda de foco neste episódio. O stream detalhado é limitado a64 rejeições, mas os contadores por tipo cobrem todo o processo.

Os cliques recebidos pelo jogo e a perda de foco separada estão medidos. Não se prova independentemente que a perda de foco foi causada por um clique noutra janela em vez de Alt+Tab, nem que houve clique exterior e retorno durante o replay. Não foi usado input sintético nestes testes humanos.

## Comparação pareada para separar interferência de modo de execução

As três execuções humanas foram também comparadas com o renderizado sem intervenção **da mesma frequência e da mesma tape congelada**. Não se gerou uma nova sequência adaptativa ou âncora:

| Comparação | Input/cursor/câmara/raycast/material | Campos físicos publicados |
|---|---|---|
| Humano120, iniciado sem foco ↔ renderizado120 quieto | Exatos | Exatos |
| Foco60, perda duranteACTIVE ↔ renderizado60 quieto | Exatos | Exatos |
| Rato120 ↔ renderizado120 quieto | Exatos | Exatos |

Não aparece primeira divergência em nenhuma dessas comparações pareadas. Portanto, **nestas amostras**, o rato/cliques entregues ao jogo e a perda de foco observada não alteraram a reprodução renderizada. As rejeições estritas face à referência headless permanecem todas preservadas; não são reclassificadas como passes de qualificação.

## Sessão interrompida versus perda de foco

A perda de foco medida é uma continuação válida de ticks, não uma sessão interrompida. Todos os11 replays terminaram no motor; não se observou suspensão, pausa, alteração inesperada de viewport ou gap>250ms. O guard existente invalida esses casos como RUNTIME_SUSPENDED/ENVIRONMENT_NOT_COMPARABLE e não preenche ticks em falta. **A rejeição de uma suspensão real não foi exercitada nesta campanha**, pelo que não se certifica esse ramo por comparação com uma amostra que continuou normalmente. Também não se certifica o ciclo completo perder→recuperar foco.

## Revisão física e segurança

A revisão independente leu5330 POST:1874 estadosREACHING tinham força0. Mantêm-se12kg/profile4/sem hybrid. Picos observados: mãos254.948N, pés45.471N, assistência20.0000014Nm (arredondamento float), momento76.761Nm; |T|/N máximo≈0.4370 abaixo deμ0.85. Os limites de força e o alcance não foram aumentados. Não foi encontrado bypass de contacto/âncora/corpo.

Nesta campanha passaram24 checks Godot e18 testes Python, incluindo roundtrip JSON e comparação de cadeias materiais com IDs de processo normalizados. Os1146 checks de regressão da fase anterior são evidência anterior preservada, não uma contagem de novos testes nesta campanha.

Godot MCP Pro1.17.1 confirmou de novo o main normal no monitor0: profile2, inputLIVE, providerDISABLED, câmara virtualfalse, massa/alcance/bindings/flags iguais à base anterior;0 erros na consulta fresca. O screenshot `ordinary_main.png` foi inspecionado. O aviso inicial sobre um projeto antigo dentro de builds foi preservado. O editor iniciado por esta tarefa foi fechado e project.godot restaurado byte a byte. Nenhuma opção de teste foi persistida no jogo normal.

## Decisão e próximos limites

**NO_GO_INPUT_REPLAY** para a equivalência estrita do benchmark entre headless e renderizado. A admissão JSON está resolvida e a não-interferência está demonstrada nas amostras pareadas descritas, sem certificar todas as condições do orçamento original.

O próximo diagnóstico pertinente é observar a transformação efetiva usada pela API de projeção e as dimensões de backing viewport no instante do raio, com o mapping físico controlado, para explicar a diferença antes de qualquer ajuste. Isso é uma recomendação de investigação, não trabalho ou otimização iniciado neste relatório. Recuperação de foco, suspensão real, repetição humana n3 porHz, outros cenários/one-hand/lateral/envelopes contínuos/holdouts continuam abertos. ML/Optuna/Jev/RL permanecem OFF.

Entregáveis: `test_matrix.json`, `first_divergence.json`, `human_interference.json`, `paired_rendered_summary.json`, `verification.json`, revisões specialist e `evidence_manifest.json`. As archives incluem os recibos rejeitados, tapes novas, audits, traces e a fonte congelada. Cada membro e arquivo tem SHA256 verificado. Extraia para um diretório novo; não sobreponha os estudos anteriores.
''')
    archives.DOC=DOC
    index={}
    archives.source_archive('source_036a9dc','036a9dc',current,index)
    for label,stage in [('captures','capture'),('qualification','baseline'),('human120','diagnostic_human120'),('render60','diagnostic_quiet60'),('focus60','diagnostic_human60'),('mouse120','diagnostic_mouse120'),('native_mcp','native')]:archives.archive(label,(BASE/stage).rglob('*'),index)
    archives.archive('campaign_metadata',[p for p in BASE.iterdir() if p.is_file()],index)
    atomic_json(DOC/'evidence_manifest.json',{'campaign':'requal_20261020_r1','decision':'NO_GO_INPUT_REPLAY','archives':index,'archive_raw_roundtrip_verified':True,'document_sha256':{p.relative_to(DOC).as_posix():file_hash(p) for p in DOC.rglob('*') if p.is_file() and 'evidence' not in p.parts},'report_tools_sha256':{p.name:file_hash(p) for p in [Path(__file__),ROOT/'tools/virtual_cursor_requalification.py',ROOT/'tools/run_virtual_cursor_requalification_diagnostic.py',ROOT/'tools/virtual_cursor_requalification_pairs.py',ROOT/'tools/virtual_cursor_requalification_native.py']},'private_holdout_outcomes_accessed':False,'new_optimizer_trials':0})
    print('Published new report,13 worlds,5330 POST, JSON admitted, paired interaction exact, strict cross-mode NO_GO; archives',len(index))
if __name__=='__main__':main()
