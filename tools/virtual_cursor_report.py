"""Publish observed v132a results and raw evidence; never launches the engine."""
from pathlib import Path
import json,hashlib,subprocess,zipfile,sys,shutil,itertools
ROOT=Path(__file__).resolve().parents[1];DEST=Path(r'E:\Godot Games\grip_up')
sys.path.insert(0,str(ROOT/'tools/auto_tuning'))
from common import source_hashes,file_hash,read_json,atomic_json,engine_identity
DOC=ROOT/'docs/validation/virtual_cursor_v132a';BASE=ROOT/'builds/eval_virtual_cursor'
def write(name,value):
    path=DOC/name
    assert not path.exists(),path
    text=value.strip()
    if name.endswith('.md'):
        text='\n'.join('- '+line[1:] if line.startswith('-') and not line.startswith(('- ','---')) else line for line in text.splitlines())
    path.write_text(text+'\n',encoding='utf-8',newline='\n')
def archive(label,files,index):
    files=sorted(set(p for p in files if p.is_file()))
    groups=[];group=[];size=0
    for path in files:
        if group and size+path.stat().st_size>40*1024*1024:groups.append(group);group=[];size=0
        group.append(path);size+=path.stat().st_size
    if group:groups.append(group)
    for i,group in enumerate(groups,1):
        destination=DOC/'evidence'/f'{label}_{i:02}.zip';destination.parent.mkdir(parents=True,exist_ok=True)
        members={}
        with zipfile.ZipFile(destination,'x',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
            for path in group:
                key=path.relative_to(ROOT).as_posix();data=path.read_bytes();z.writestr(key,data)
                members[key]={'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)}
        with zipfile.ZipFile(destination) as z:
            assert z.testzip() is None
            for key,expected in members.items():assert hashlib.sha256(z.read(key)).hexdigest()==expected['sha256']
        index[destination.name]={'sha256':file_hash(destination),'bytes':destination.stat().st_size,'members':members,'verified_roundtrip':True}
def source_archive(label,commit,hashes,index):
    destination=DOC/'evidence'/f'{label}.zip';destination.parent.mkdir(exist_ok=True)
    members={}
    with zipfile.ZipFile(destination,'x',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for path,expected in hashes.items():
            current=(ROOT/path).read_bytes()
            if hashlib.sha256(current).hexdigest()!=expected:
                blob=subprocess.check_output(['git','show',f'{commit}:{path}'],cwd=DEST)
                candidates=[blob,blob.replace(b'\r\n',b'\n'),blob.replace(b'\r\n',b'\n').replace(b'\n',b'\r\n')]
                current=next(data for data in candidates if hashlib.sha256(data).hexdigest()==expected)
            key=path;z.writestr(key,current);members[key]={'sha256':expected,'bytes':len(current)}
    with zipfile.ZipFile(destination) as z:
        assert z.testzip() is None
        for key,expected in members.items():assert hashlib.sha256(z.read(key)).hexdigest()==expected['sha256']
    index[destination.name]={'sha256':file_hash(destination),'bytes':destination.stat().st_size,'members':members,'verified_roundtrip':True,'commit':commit}
def main():
    freeze=read_json(DOC/'baseline.json')
    allowed={'export_presets.cfg','features/grip_up/scripts/climbing_camera.gd','features/grip_up/scripts/climbing_input_router.gd','features/grip_up/scripts/grip_targeting.gd','features/grip_up/scripts/grip_up_lab.gd'}
    changed={}
    for base in [ROOT,DEST]:
        observed={p for p,h in freeze['files'].items() if not (base/p).is_file() or file_hash(base/p)!=h}
        assert observed==allowed,observed
        changed[str(base)]=sorted(observed)
    current=source_hashes(ROOT);assert current==source_hashes(DEST)
    assert file_hash(DEST.parent/'janga_proto/runtime/physics_grabber.gd')==freeze['janga_sha256']
    assert file_hash(ROOT/'project.godot')==freeze['files']['project.godot']==file_hash(DEST/'project.godot')
    rollback=ROOT/'builds/GripUp-v1.2-pre-v1.3.exe'
    assert file_hash(rollback)=='fb018cfbf8ac57dac83c43af6590f2107bede466d56053e1218583f03564e33d'
    assert file_hash(DEST/'builds/GripUp-v1.2-pre-v1.3.exe')==file_hash(rollback)
    regression=read_json(DOC/'virtual_cursor_regression/attempt_001/results.json')
    assert len(regression['runs'])==24 and sum(x['checks'] for x in regression['runs'])==884 and all(x['passed'] for x in regression['runs'])
    captures=read_json(BASE/'frozen_capture_r1/session_state.json')['runs'];q=read_json(BASE/'qualification_r1/session_state.json')['runs'];diag=read_json(BASE/'direct_diagnostic_r2/session_state.json')['runs'][0]
    assert len(q)==24 and q[0]['status']=='failed_runtime' and q[0]['reason']=='INPUT_BUTTON_EDGE' and all(x['status']=='NOT_RUN_EARLY_STOP' for x in q[1:])
    assert diag['status']=='completed' and len(diag['engine_result']['negative_checks'])==9 and all(x['pass'] for x in diag['engine_result']['negative_checks'])
    normal=read_json(BASE/'safety/normal_runtime.json');assert normal['normal']==read_json(ROOT/'docs/validation/evaluator_v132/baseline/normal_runtime.json')
    native=json.JSONDecoder().raw_decode((BASE/'native/normal_runtime_response.json').read_text(encoding='utf-8-sig'))[0]
    native_value=json.loads(native['output'][0]);assert all(native_value[k]==v for k,v in normal['normal'].items())
    assert native_value['virtual_provider_disabled'] and not native_value['camera_virtual'] and native_value['source_kind']=='LIVE'
    errors=json.JSONDecoder().raw_decode((BASE/'native/errors_after_response.json').read_text(encoding='utf-8-sig'))[0];assert errors['count']==0
    pack=read_json(BASE/'safety/export_pack_check.json');assert all(pack['excluded'].values()) and pack['provider_disabled'] and pack['profile']==2
    shutil.copy2(BASE/'native/normal_main.png',DOC/'normal_main.png')
    matrix=[{k:row[k] for k in ['condition','hz','repeat','status'] if k in row}|{'reason':row.get('reason',''),'run_id':row.get('run_id'),'phase':'TAPE_ADMISSION_NO_WORLD' if i==0 else 'NOT_RUN'} for i,row in enumerate(q)]
    atomic_json(DOC/'test_matrix.json',{'benchmark':'benchmark_eval_virtual_cursor_v1','runs':matrix,'human_interference_measured':False,'negatives':{'N1':'DIAGNOSTIC_ONLY_PASS_9_CHECKS','N2':'NOT_RUN_EARLY_STOP','N3':'NOT_RUN_EARLY_STOP','N4':'NOT_RUN_EARLY_STOP'}})
    atomic_json(DOC/'first_divergence.json',{'decision':'NO_GO_INPUT_REPLAY','run_id':q[0]['run_id'],'status':'INPUT_SOURCE_MISMATCH','substatus':'INPUT_BUTTON_EDGE','phase':'TAPE_ADMISSION_BEFORE_WORLD','physics_tick':None,'first_bad_tape_tick':55,'field':'button_edges[0].hand','serialized_value':0,'parsed_godot_type':'float','expected_semantic_type':'integral numeric hand identifier 0 or 1','root_cause':'Godot Array membership distinguished JSON float 0.0 from integer entries [0,1]','no_physical_mismatch_measured':True,'no_world_created':True,'no_pre_post_window':'Not applicable: setup rejected before world creation. Complete rejected receipt archived.','correction_commit':'d13fd0c','direct_diagnostic':diag['run_id'],'corrected_qualification_repeated':False,'historical_v132_cursor_cause':'UNPROVEN; old cursor-center/absent-pointer and contact differences unchanged historical records'})
    protection={'baseline_tracked_files':len(freeze['files']),'existing_files_unchanged':len(freeze['files'])-len(allowed),'approved_existing_file_diffs':changed,'all_old_evaluator_sources_reports_tapes_unchanged':True,'public_source_files':len(current),'C_E_public_source_parity':True,'project_exact_sha256':file_hash(ROOT/'project.godot'),'janga_unchanged':True,'rollback_unchanged':True}
    atomic_json(DOC/'verification.json',{'decision':'NO_GO_INPUT_REPLAY','baseline_commit':freeze['commit'],'first_measured_commit':'5c9d6441c416044046c49d627faebb78e0249f3f','corrected_diagnostic_commit':'d13fd0c','engine':engine_identity(),'protection':protection,'qualification':{'planned':24,'attempted':1,'pre_world_rejected':1,'physics_episodes':0,'remaining_not_run_early_stop':23},'development_physical_captures':3,'direct_physical_diagnostics':1,'remaining_diagnostic_budget_used':0,'regression':{'processes':24,'checks':884,'pass':True},'final_pure_contracts':{'godot':24,'python':11,'pass':True},'normal_baseline_exact_equal':True,'native_mcp':{'version':'1.17.1','monitor':0,'fresh_errors':0,'scope':'SUPPLEMENTARY_LIVE_SAFETY_ONLY'},'release_export':{'smoke_pass':True,'pack_exclusions_verified_in_isolated_engine_process':True,'exclusion_probe_is_release_template':False},'human_V0_M_F_measured':False,'new_optimizer_trials':0,'private_holdout_outcomes_accessed':False,'new_rl_trials':0,'scoring_approved':False,'source_hashes':current})
    capture_rows='\n'.join(f"| {r['hz']} | {r['engine_result']['scenarios'][0]['catch_native']['contact_tick']} | {r['engine_result']['scenarios'][0]['catch_native']['source_free_tick']} | {r['engine_result']['scenarios'][0]['catch_native']['retained_tick']} | {r['engine_result']['scenarios'][0]['catch_native']['request_distance_m']:.6f} m | −Y |" for r in captures)
    write('virtual_cursor_qualification.md',f'''
# GRIP UP — Virtual Cursor Isolation v1.3.2a

**Decisão: NO_GO_INPUT_REPLAY.** Implementação isolada e diagnóstico direto concluídos; a matriz congelada foi interrompida na admissão da primeira tape, antes de criar o mundo físico. A correção passou o diagnóstico permitido. Isso não substitui os ensaios de replay renderizado, input físico externo e mudanças de foco que ficaram por executar. Nenhuma otimização foi iniciada.

## O que foi implementado

`GripInputFrame` é um valor por tick, com cópia defensiva no construtor e nos getters. Distingue validade da mira, coordenadas viewport, movimento, estados de botões, edges ordenadas, WASD, órbita/dolly, identidade, sequência e foco. A representação armazena held/pressed/released semanticamente em `strengths` + `button_edges`, sem inferir validade a partir de `(0,0)`. As coordenadas não são arredondadas nem recentradas. Não há warp nem hook global do rato.

`LiveInputProvider` fornece o snapshot físico normal; `ReplayInputProvider` é opt-in, apenas com flag explícita `--virtual-cursor-evaluator` e build de desenvolvimento. O caminho LIVE mantém os eventos imediatos anteriores; não foi transformado num replay de edges quantizado por tick. Os snapshots LIVE não são tapes qualificadas. O controlador físico, motor de chão, hybrid/v0.8, recursos físicos, materiais e geometria ficaram byte-iguais à base.

O provider virtual tem DISABLED→ARMING→ACTIVE→FINISHING→DISABLED, com INVALID para falhas. Valida clock, sequência, frame único por tick real do motor, viewport/transformações, window mode/size, owner da câmara, FOV, bindings e identidade world/body/controller. Um estado pausado invalida a sessão. Hardware, eventos de UI e callbacks de foco são bloqueados no caminho virtual; foco real é metadata independente. Não foi comprovada ainda a eficácia destes guards contra interferência humana. Há stream limitado de rejeições, sem autoridade física.

Os pontos virtuais entram no `request_hand` normal. O seletor continua a executar os mesmos sete raios ordenados, máscara3, distância70m e exclusão do corpo, parando no primeiro hit elegível. O audit copia os resultados desses mesmos queries e o offset vencedor; preview visual posterior não pode substituir o audit do pedido. O solver continua a decidir REACHING/ATTACHED, contacto, força e âncora material. Não há body teleport, estado ATTACHED escrito pelo teste, novo apoio ou mudança de alcance.

## Câmara e ordem real

V0 usa o contrato novo `V0_PHYSICS_FOLLOW`: mesmas equações, órbita/dolly e raycast de obstrução; pose atual não interpolada do corpo; um update antes do picking e nenhum segundo follow no render. LIVE conserva `_process`50 e a pose interpolada. Esta mudança de sampling tem identidade própria e impede atribuir qualquer melhoria exclusivamente ao cursor ou explicar retroativamente o R0 antigo.

Ordem: PRE−100 carrega/commita o frame e aplica câmara/pedido; ground−10 continua a usar o move_intent guardado no Lab anterior; Lab0 guarda a intenção atual; callbacks originais do controlador aplicam os actuadores; POST+100 observa o estado pós-controle antes da próxima integração. Não é chamado post-solver. Um tick invalidado não é qualificado; callbacks separados podem consumir a intenção anterior até cleanup/teardown, sem reescrever o timing do solver.

O escopo suportado é profile4 / A0 / B1 / Swing & Catch. Profile diferente, hybrid e v0.8 são recusados antes de armar; os seus leitores globais inalterados não são anunciados como isolados. Startup normal continua profile2.

## Capturas novas, distintas dos dados v1.3.2

Foram executadas três capturas de desenvolvimento: uma inicial120 antes dos últimos guards e duas congeladas120/60 no commit5c9d644. Não são réplicas de qualificação, não são somadas a32/32 históricos nem usadas para reward. Nas duas congeladas houve contacto físico, destino carregado, origem FREE e retenção da mesma âncora. O pedido foi além do alcance estático0.65708m, com a margem original0.02m do cenário. Ambos selecionaram a face inferior−Y real de `catch`.

| Hz | Contacto destino | Origem FREE | Primeira retenção ≥0.6s | Distância no pedido | Face real |
|---|---:|---:|---:|---:|---|
{capture_rows}

Isto documenta diretamente a face60Hz nesta captura nova. Não resolve o caso antigo de+Z por decreto, não prova imunidade ao rato e não qualifica trajetórias contínuas. Os episódios incluem as contribuições B1/chão; não são arm-only.

## Primeira falha e paragem

O primeiro dos24 processos, `{q[0]['run_id']}`, devolveu `BLOCKED_SETUP / INPUT_BUTTON_EDGE`. A tape continha mão0 inteira em JSON; o parser Godot devolveu0.0 e a validação por membership numa lista de inteiros recusou-a. O primeiro edge na tape era tick55, mas **nenhum tick de cenário foi executado**. Não existe desvio físico, de câmara ou de material medido nesta tentativa. `first_divergence.json` separa admissão de tape de mismatch durante uma simulação.

A captura construía Dictionary com inteiros; por isso o erro só surgiu no roundtrip JSON. A correção d13fd0c aceita valores numéricos integralmente iguais a0/1 e passos de roda−1/+1; rejeita mão fracionária, sem arredondar pixels. Os testes agora incluem roundtrip real JSON e mão0.5. A matriz não foi repetida:1 tentativa rejeitada,23 NOT_RUN_EARLY_STOP. V0-H/R/M/F×60/120×n3 continua **não qualificado**.

## Diagnóstico permitido depois da paragem

A proposta inicial de executar os quatro negativos foi restringida pela revisão independente. Só N1 era diretamente relacionado com o gate JSON; N2/N3/N4 continuam NOT_RUN_EARLY_STOP. A proposta e a adjudicação ficam preservadas separadamente.

N1 executou uma vez a120Hz em fonte corrigida. Utilizou uma tape derivada `diagnostic_only`, mantendo frames/referências/manifest SHA e `capture_source_hashes` originais, e declarando o novo mapa do replay + quatro diffs aprovados. Python e GDScript recusam esta tape fora de um caso negativo. Não é recaptura, substituição da tape congelada ou resultado qualificado. Os primeiros quatro frames têm as alterações negativas explícitas no harness.

Os9 checks passaram: rejeição de source, viewport, câmara, tick duplicado e tick em falta; validade sem mira preserva semântica held; pressão com mira inválida não cria novo target; `(0,0)` explicitamente válido é aceite e executa o targeting real. Houve depois contacto440, origem FREE455 e retenção527, face−Y, como observação diagnóstica. Não foram executados os casos de mouse/wheel externo, Alt+Tab humano, UI adversarial, silhouette de um pixel ou abort a meio. A implementação desses hooks não é prova de que passaram.

## Revisão física independente

Foram inspecionados1335 snapshots POST das duas capturas congeladas e N1. Nos474 estados-mão REACHING a força foi zero; também zero fora de ATTACHED/SLIPPING. Todos têm12kg/profile4/sem ownership hybrid. Picos observados: mãos254.948N, pés45.471N, por pé45.471N, assistência20.0000014Nm (arredondamento float), momento combinado76.761Nm. Mantêm-se360N partilhados,180N pés/120N por pé,20Nm assistência e150Nm resultante. Nenhum limite foi aumentado. Detalhes e limites estão no parecer independente.

N1 coincide pontualmente com a captura120 nos COM/v/omega e force budgets publicados. Isso não cria envelope contínuo nem aprovação de Jolt/replay entre processos ou Hz. A retenção verificada está ligada à mesma âncora material real. Nenhuma conclusão de causalidade sobre a interferência antiga do sistema operativo foi tirada.

## Segurança do projeto

-24 processos de regressão: **884 checks passaram**, cobrindo pegas/forças, pending, intenção, inversão, chão, frames, First Ascent, mantle/hybrid, recovery e pés.
-Contratos finais: **24 checks Godot +11 testes Python passaram**; não somamos reexecuções de desenvolvimento como cobertura nova.
-Godot MCP Pro1.17.1, monitor0: main ordinary profile2, input LIVE, provider DISABLED, câmara virtual false, flags/pesos/alcance/bindings iguais à base. Screenshot `normal_main.png`, inspecionado visualmente. O scanner inicial assinalou apenas um projeto antigo dentro de builds; consulta fresca após main:0 erros.
-Após fechar apenas o editor iniciado nesta tarefa, project.godot foi restaurado byte a byte. Um novo processo headless confirmou o snapshot normal exatamente igual ao guardado na v1.3.2.
-Export release Windows e startup smoke passaram. A inspeção do pack com o motor num diretório isolado confirmou a ausência dos drivers/providers de teste e startup profile2/DISABLED. Essa inspeção usa a build de ferramentas, não pretende medir `OS.is_debug_build` da template. A tentativa de script externo na template release expirou40s e foi preservada; a primeira inspeção sem diretório isolado foi descartada por fallback a fontes locais. Os recibos não foram ocultados.
-Dos{len(freeze['files'])} ficheiros anteriores,{len(freeze['files'])-5} estão byte-iguais em C e E. Só quatro scripts de input/câmara/diagnóstico e a exclusão de export têm diffs aprovados. Todo o evaluator antigo, relatórios, tapes, controller, tuning, Janga e rollback permanecem iguais. Paridade dos{len(current)} ficheiros públicos de fonte verificada.

## Entregáveis e utilização

`test_matrix.json`, `first_divergence.json`, `verification.json`, auditoria/revisões specialist, protocolo original e adjudicação, e `evidence_manifest.json` acompanham este relatório. Os ZIP têm SHA256 por arquivo e por membro e foram relidos para validar os bytes. Extraia para uma pasta nova; não sobreponha os estudos históricos.

O projeto de utilização continua em `E:\\Godot Games\\grip_up`. Recuperação: tag `baseline/pre-v1.3.2a-virtual-cursor`, commit0be1667; fonte inicial5c9d644, correção diagnóstica d13fd0c. O ficheiro de rollback pré-v1.3 foi preservado, sem substituir a build anterior.

## O que continua por fazer

A infraestrutura permanece disponível mas **não autorizada para scoring**. Uma nova qualificação deve ter orçamento/identidade próprios e começar com o roundtrip corrigido, antes de render/humanos, câmara/silhouette e abort/foco. Este relatório não reabre essa campanha. One-hand60, lateral mirror, envelopes contínuos e holdouts da v1.3.2 continuam abertos. Optuna/ML/Jev/RL/M7 continuam OFF. Sem avaliação de gamepad ou novo playtest de feel nesta fase; código/bindings LIVE preservados e regressões disponíveis passaram.

## Referências de API

As APIs foram consultadas na documentação oficial e exercitadas no motor instalado4.7.2, sem assumir que a página stable descreve a ordem específica deste projeto: [Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html), [Input](https://docs.godotengine.org/en/stable/classes/class_input.html), [Viewport](https://docs.godotengine.org/en/stable/classes/class_viewport.html), [coordenadas do rato](https://docs.godotengine.org/en/stable/tutorials/inputs/mouse_and_input_coordinates.html). O código e os traces deste projeto definem a ordem medida.
''')
    write('benchmark_eval_virtual_cursor_v1.json',json.dumps({'benchmark':'benchmark_eval_virtual_cursor_v1','protocol_sha256':file_hash(DOC/'protocol.md'),'scenario':'swing_catch_train','physics_hz':[120,60],'conditions':['V0-H','V0-R','V0-M','V0-F'],'repeats':3,'clock':'physics ticks, no invented steps','camera_mode':'V0_PHYSICS_FOLLOW','input_schema':'grip_input_frame_v1','decision':'NO_GO_INPUT_REPLAY','metadata_only_not_a_new_runtime_benchmark_revision':True},indent=2))
    archives={}
    source_archive('source_frozen_5c9d644','5c9d644',read_json(BASE/'frozen_capture_r1/tapes/catch_120.json')['source_hashes'],archives)
    source_archive('source_diagnostic_d13fd0c','d13fd0c',current,archives)
    for label,folder in [('development','development_capture_r1'),('frozen_capture','frozen_capture_r1'),('qualification','qualification_r1'),('direct_diagnostic','direct_diagnostic_r2'),('diagnostic_tapes','diagnostic_tapes_r2'),('contracts','contracts'),('native_mcp','native')]:archive(label,(BASE/folder).rglob('*'),archives)
    archive('safety',[p for p in (BASE/'safety').rglob('*') if p.suffix in ['.json','.txt','.gd'] and 'isolated_pack_qa' not in p.parts],archives)
    atomic_json(DOC/'evidence_manifest.json',{'decision':'NO_GO_INPUT_REPLAY','archives':archives,'all_archive_members_verified_sha256':True,'paths':'workspace-relative; extract to a NEW folder','excluded_large_executable':read_json(BASE/'safety/export_identity.json'),'rollback_sha256':file_hash(rollback),'normal_screenshot_sha256':file_hash(DOC/'normal_main.png'),'source_snapshots_raw_bytes_reconstructed_and_verified':True,'report_tools_sha256':{p.name:file_hash(p) for p in [Path(__file__),ROOT/'tools/virtual_cursor_native_safety.py',ROOT/'tools/virtual_cursor_safety_checks.py',ROOT/'tools/virtual_cursor_diagnostic_tapes.py',ROOT/'tools/run_virtual_cursor_direct_diagnostic.py']}})
    print('Published NO_GO_INPUT_REPLAY; archives',len(archives),'public sources',len(current),'protected unchanged',len(freeze['files'])-5)
if __name__=='__main__':main()
