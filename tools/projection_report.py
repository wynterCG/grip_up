"""Offline publication only; never starts an engine or opens holdouts."""
import json,math,sys,shutil,subprocess,statistics,hashlib,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'tools/auto_tuning'),str(ROOT/'tools/auto_tuning/virtual_cursor')]
from common import read_json,atomic_json,file_hash,source_hashes,engine_identity,DEST
from projection_comparison import pair,load_picks,norm
from layered_comparison import compare_layers
import virtual_cursor_report as archive
DOC=ROOT/'docs/validation/auto_tuning/projection_v132b'
BASE=ROOT/'builds/eval_virtual_cursor/projection_v132b_r2'
archive.DOC=DOC

def write(name,text):
    p=DOC/name
    if p.exists():raise FileExistsError(p)
    p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text.strip()+'\n',encoding='utf-8')

def trajectory(a,b,hz):
    aa=read_json(Path(a)/'virtual_audit.json')['ticks'];bb=read_json(Path(b)/'virtual_audit.json')['ticks']
    assert len(aa)==len(bb)
    result={'ticks':len(aa),'interval_seconds':[1/hz,len(aa)/hz],'phase':'POST_CONTROL_BEFORE_NEXT_INTEGRATION','no_time_warp_or_event_alignment':True}
    getters={'com_m':lambda t:t['body']['com_m'],'linear_velocity_m_s':lambda t:t['body']['linear_velocity_m_s'],'angular_velocity_rad_s':lambda t:t['body']['angular_velocity_rad_s'],'left_force_n':lambda t:t['hands'][0]['force_n'],'right_force_n':lambda t:t['hands'][1]['force_n'],'combined_moment_nm':lambda t:t['force_budget']['combined_nm']}
    for name,get in getters.items():
        values=[norm(get(x),get(y)) for x,y in zip(aa,bb)];maximum=max(values);first=next((i+1 for i,v in enumerate(values) if v!=0),None)
        result[name]={'first_difference_tick':first,'max_delta':maximum,'rms_delta':math.sqrt(sum(v*v for v in values)/len(values)),'max_tick':values.index(maximum)+1 if maximum else None}
    result['different_hand_state_ticks']=sum(any(x['hands'][h]['state']!=y['hands'][h]['state'] for h in [0,1]) for x,y in zip(aa,bb))
    return result

def derive():
    state=read_json(BASE/'session_state.json');assert not state['hard_stop'],state['hard_stop']
    assert len(state['runs'])==36 and len(state['pairs'])==18
    results=[]
    for row in state['pairs']:
        if row['id'].startswith('CONTROL'):continue
        d=read_json(BASE/'comparisons'/f"{row['id']}.json")
        d['trajectory']=trajectory(row['left'],row['right'],row['hz'])
        d.update(pair_id=row['id'],hz=row['hz'],repeat=row['repeat'],left_run=Path(row['left']).name,right_run=Path(row['right']).name)
        results.append(d)
    p4=[];repeats=[]
    for hz in [120,60]:
        for index,mode in enumerate(['headless','rendered_scripted']):
            def select(p,r):return next(x for x in state['pairs'] if x.get('p')==p and x['hz']==hz and x['repeat']==r)[['left','right'][index]]
            d=pair(select(2,1),select(3,1));d.update(hz=hz,mode=mode,id=f'P4_{mode}_{hz}',derived_not_independent_replicate=True,trajectory=trajectory(select(2,1),select(3,1),hz));p4.append(d)
            for p in [2,3]:
                for r in [2,3]:
                    d=pair(select(p,1),select(p,r));repeats.append({'hz':hz,'mode':mode,'size_case':p,'reference_repeat':1,'repeat':r,'status':d['status'],'first_by_stage':d['first_by_stage'],'physics':d['published_layers']['first_by_layer']['physics']})
    observations=[];pending_zero=0;total_ticks=0;caps={'hands_n':0,'feet_n':0,'per_foot_n':0,'assist_nm':0,'combined_nm':0};traces=[]
    for r in state['runs']:
        directory=Path(r['directory']);manifest=read_json(directory/'manifest.json');result=r['engine_result'];audit=read_json(directory/'virtual_audit.json');ticks=audit['ticks'];total_ticks+=len(ticks)
        assert r['status']=='completed' and not any(result['scenarios'][0]['invariants'].values())
        assert result['projection_setup']['before_world'] and result['projection_setup']['actual_size']==r['size']
        assert all(t['body']['mass_kg']==12 and all(h['reach_m']==.65708 for h in t['hands']) for t in ticks)
        for t in ticks:
            f=t['force_budget'];caps['hands_n']=max(caps['hands_n'],f['hands_n']);caps['feet_n']=max(caps['feet_n'],f['feet_n']);caps['assist_nm']=max(caps['assist_nm'],norm(f['assist_nm'],[0,0,0]));caps['combined_nm']=max(caps['combined_nm'],norm(f['combined_nm'],[0,0,0]));caps['per_foot_n']=max(caps['per_foot_n'],*(norm(foot['force_n'],[0,0,0]) for foot in t['feet']))
            for h in t['hands']:
                if h['state'] in ['FREE','REACHING','RELEASED']:
                    assert norm(h['force_n'],[0,0,0])==0;pending_zero+=1
        if r['probe_enabled']:
            picks=load_picks(directory);traces.extend(picks)
            for pick in picks:
                assert pick['environment']['window']['size']==r['size']
                assert pick['environment']['viewport']['visible_rect']['size']==[1920,1080]
        observations.append({'run_id':r['run_id'],'source_commit':manifest['code_commit'],'mode':r['mode'],'physical_hz':r['hz'],'condition':r['condition'],'repeat':r['repeat'],'probe_enabled':r['probe_enabled'],'requested_window':r['size'],'effective_setup':result['projection_setup'],'tape_sha256':manifest['virtual_tape_sha256'],'engine_identity':manifest['engine_identity'],'runtime_status':result['status'],'strict_comparison_to_original_036_capture':r['comparison'],'catch':result['scenarios'][0]['catch_native'],'invariants':result['scenarios'][0]['invariants'],'source_compatibility':manifest['projection_source_compatibility'],'projection_probe':result['projection_probe'],'maximum_tick_wall_gap_usec':result['virtual_input']['maximum_tick_wall_gap_usec']})
    atomic_json(DOC/'observations/runs.json',observations)
    atomic_json(DOC/'ray_pipeline_diff.json',{'cross_mode_pairs':results,'P4_within_mode_derived':p4,'same_mode_repeat_comparisons':repeats,'observer_controls':[x for x in state['pairs'] if x['id'].startswith('CONTROL')],'post_snapshots':total_ticks,'force_free_pending_checks':pending_zero,'max_observed_budgets':caps,'point_of_call_records':len(traces),'actual_executed_rays':sum(len(x['rays']) for x in traces),'policy':'No tolerances. Strict point-of-call float bits, exact published POST numeric fields. Matching does not certify unpublished Jolt state.'})
    assert all(r['status']=='STRICT_MATCH' for r in results if not r['pair_id'].startswith('P1'))
    assert all(r['status']=='STRICT_MATCH' for r in repeats)
    assert all(read_json(BASE/'comparisons'/f"control_{m}_{h}.json")['first_by_layer'][k] is None for m in ['headless','rendered_scripted'] for h in [120,60] for k in ['input','cursor','camera','raycast','material_anchor','physics'])
    atomic_json(DOC/'campaign_summary.json',{'decision_recommendation':'GO_LIMITED_PROJECTION','source_commit':observations[0]['source_commit'],'r2_runs':36,'r1_rejected_setup':1,'global_process_attempts':37,'diagnostic_runs_after_hard_gate':0,'max_global':40,'same_size_cross_mode_pairs':12,'same_size_strict_matches':12,'historical_size_pairs':2,'historical_size_strict_mismatches':2,'independent_new_observer_pairs':4,'observer_pairs_exact_all_published_layers':4,'same_mode_derived_repeat_comparisons':16,'P4_derived_ablation_comparisons':4,'post_snapshots':total_ticks,'probe_picks':len(traces),'force_free_pending_checks':pending_zero,'max_observed_budgets':caps,'optimizer':'OFF'})
    tables=[]
    for row in state['pairs']:
        if not row['id'].startswith('CONTROL'):tables.append(f"| {row['id']} | {row['status']} |")
    historic=[d for d in results if d['pair_id'].startswith('P1')]
    cause=[]
    for d in historic:
        first=d['first_by_stage']['local_ray'];mag=next(x for x in d['ray_magnitudes'] if x['tick']==first['tick'])
        cause.append(f"| {d['hz']} | {first['tick']} | {mag['local_delta']:.12g} | {mag['world_delta']:.12g} | {d['first_by_stage']['material_anchor']['distance_um']:.9g} |")
    write('window_ablation_report.md',f'''# GRIP UP — projeção e viewport v1.3.2b

**Recomendação: GO_LIMITED_PROJECTION apenas para os dois replays Swing & Catch, na mesma frequência e com backing window igual verificado.** Os tamanhos históricos diferentes continuam STRICT_MISMATCH. Nenhuma tolerância ou correção de gameplay foi introduzida. Otimizadores, scoring e outros domínios permanecem bloqueados.

Foram executados 36 processos reais em R2, fonte `{observations[0]['source_commit']}`, mais uma tentativa R1 rejeitada pela sintaxe CLI antes de arrancar o motor. R1 está encerrada e arquivada; R2 tem plano e revisão próprios. Total37/40 do limite global, sem diagnósticos físicos pós-falha. Uma instância física de cada vez. Seeds101; tapes originais036 preservadas,536 ticks a120Hz/263 a60Hz, sem recaptura ou alteração de comandos.

## Efeito medido

| Hz | Primeiro desvio local/world/query/material, tick | Norma do desvio local | Norma do desvio mundial | Separação material µm |
|---|---:|---:|---:|---:|
{chr(10).join(cause)}

Em P1, cursor, pose global e efetiva da câmara e projeção coincidem no primeiro desvio. O raio **local** já difere, antes de aplicar a base mundial. A consulta recebeu exatamente o vetor registado; o hit e o ponto material provêm da única consulta original. As leituras auxiliares adjacentes devolvem o mesmo world-normal. Não são uma captura dos temporários internos dessa chamada anterior.

P2:1024×576 em ambos modos. P3:1440×810 em ambos modos. Cada tamanho/frequência tem três pares em processos novos,12 pares correspondentes no total. Todos coincidem exatamente nos inputs/cursor, nas observações de câmara, raios locais/mundiais, queries/hits/âncoras e nos campos físicos POST publicados. Dezasseis comparações derivadas dentro de cada modo entre repetições também coincidem; não são16 ensaios adicionais.

P4 deriva small→large de P2/P3 dentro de cada modo. A mesma divergência reaparece no mesmo tick/magnitude em headless e renderizado. A60Hz, o contacto destino é215 no backing pequeno e210 no grande em ambos modos. A120Hz, é440 em ambos tamanhos. Retenção destino ocorre259 a60Hz e527 a120Hz. As três repetições de cada célula repetem esses valores, sem dispersão observada.

Isto identifica um efeito causal do conjunto backing-size/stretch numérico neste ambiente e nestas duas tapes. Alterar o tamanho headless reproduz o renderizado grande; alterar o renderizado para pequeno reproduz o headless pequeno. Não é evidência de defeito Jolt. A operação interna exata que introduz arredondamento continua por observar; não foi compilado nem substituído o motor.

## Comparações estritas

| Par | Resultado |
|---|---|
{chr(10).join(tables)}

## Janela, fonte e limitações

Todos os tamanhos pedidos foram confirmados antes do mundo e em cada pick. Viewport lógico1920×1080, canvas/global canvas identidade, FOV56, near≈.08, keep-aspect1, content_scale_mode1/aspect4/factor1/stretch0. Backing pequeno tem stretch/final≈.5333333611488342; grande .75. `observations/runs.json` conserva configurações reais, renderer, fonte/engine/tape e resultados de CADA execução. Headless mantém displayserverheadless/mode1/screen−1; renderizado Windows/mode0 com DPI/escala observados. Estes modos não são visualmente equivalentes; a comparação é do picking e dos campos físicos declarados. A escala e as dimensões variam juntas: a aritmética interna específica não foi isolada como variável adicional.

Fonte C++ da revisão exata do binário: [camera_3d.cpp](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/scene/3d/camera_3d.cpp#L406) encadeia local→base efetiva→normalização. [viewport.cpp](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/scene/main/viewport.cpp#L3705) transforma o pixel por stretch×global-canvas e utiliza size. Estes helpers não são APIs públicas; os campos internos estão UNAVAILABLE_PUBLIC_API. As linhas antigas do branch4.7 não são a identidade do binário; os downloads e SHA exatos estão arquivados. Não foi usada projeção artesanal para selecionar um alvo.

Os quatro controlos SAME-mode/Hz a1024×576 variam só a nova sonda; o observador físico antigo mantém-se ligado. ON/OFF coincidem em todos os campos publicados. probe_usec mede begin→end por pick, incluindo seleção/sidecar, mas exclui escrita final e restantes loggers. É uma medição parcial, não uma garantia de latência nula.

## Física, segurança e comparabilidade

Todas as36 execuções terminaram com contacto material real e retenção, sem violação do monitor original. Foram observados {total_ticks} POST e {pending_zero} estados FREE/REACHING/RELEASED sem força. Mass12kg, reach.65708m, recursos originais e A0/B1 mantidos. Máximos observados em campaign_summary.json; limites não aumentados. B1 e contribuições normais dos pés/chão não foram removidos nem ocultados.

As séries completas são comparadas em ticks/intervalos temporais iguais, sem alinhar pelo evento de contacto. ray_pipeline_diff.json apresenta primeiras diferenças, máximos/RMS COM/velocidades/forças/momento e ticks com estados diferentes. Os pares históricos diferentes mantêm dados contínuos QUARANTINED; contacto/retensão final comuns não recebem FUNCTIONAL_MATCH_WITH_NUMERIC_DRIFT. Não se definiu envelope geométrico ou contínuo usando a falha que se pretendia aprovar.

A política limitada é **igualdade estrita sob backing igual**, não uma tolerância numérica. Não há ensaio de outros pontos perto de bordas, outras tapes, hardware, plataformas, FPS render ou cenas. Não há qualificação geral de determinismo Jolt nem de todos os sete offsets: a ordem original permanece, mas os picks destas tapes vencem no offset0, duas queries reais por replay. Novas superfícies/condições exigem nova qualificação.

As regressões frescas incluem24 processos físicos/locomoção(884checks) e10 de inputLIVE(262checks),1146 no total. Contratos24GDinput+18GDprojeção+25Python; os ensaios negativos físicos antigos N1–N4 não foram reexecutados como células desta matriz. A revisão nativa MCP e o export/smoke têm recibos separados e não são playtest humano nem confirmação de feel.
''')

def package():
    index={}
    for p in (DOC/'evidence').glob('source_r1_*.zip'):
        with zipfile.ZipFile(p) as z:members={n:{'sha256':hashlib.sha256(z.read(n)).hexdigest(),'bytes':len(z.read(n))} for n in z.namelist()}
        index[p.name]={'sha256':file_hash(p),'members':members,'verified_roundtrip':True}
    commit=read_json(BASE/'session_manifest.json')['identity']['repository_commit']
    archive.source_archive('source_r2_'+commit[:7],commit,read_json(BASE/'session_manifest.json')['source_hashes'],index)
    files=[p for base in [BASE,ROOT/'builds/eval_virtual_cursor/projection_v132b_r1'] for p in base.rglob('*') if p.is_file() and p.suffix.lower() not in ['.exe','.tmp']]
    # Include the immutable tapes directly; preserve original bytes and IDs.
    files += [ROOT/f'builds/eval_virtual_cursor/requal_20261020_r1/capture/tapes/catch_{h}.json' for h in [120,60]]
    files += [ROOT/'tools'/name for name in ['projection_report.py','projection_finalize.py','projection_native.py','projection_safety.py','virtual_cursor_report.py','virtual_cursor_native_safety.py','project.py','project_config.py','check_virtual_cursor.py','run_contextual_vault.py']]
    archive.archive('raw_projection',files,index)
    archive.archive('final_documents',[p for p in DOC.rglob('*') if p.is_file() and 'evidence' not in p.relative_to(DOC).parts and p.name!='evidence_manifest.json'],index)
    atomic_json(DOC/'evidence_manifest.json',{'archives':index,'documents':{p.relative_to(DOC).as_posix():file_hash(p) for p in DOC.rglob('*') if p.is_file() and 'evidence' not in p.relative_to(DOC).parts and p.name!='evidence_manifest.json'},'helper_sha256':{str(p.relative_to(ROOT)):file_hash(p) for p in files if p.parent==ROOT/'tools'},'binary_excluded_from_zip':'Fresh release executable identified separately by SHA; old rollback preserved; ZIP members roundtrip verified.'})

if __name__=='__main__':
    if sys.argv[1]=='derive':derive()
    elif sys.argv[1]=='package':package()
