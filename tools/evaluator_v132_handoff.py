"""Publish the bounded NO_GO evidence; never runs physics or alters gameplay."""
from __future__ import annotations
from collections import defaultdict,Counter
from itertools import product
from pathlib import Path
import hashlib
import json
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/"tools"),str(ROOT/"tools/auto_tuning/evaluator_qualification"),str(ROOT/"tools/auto_tuning")]
from common import atomic_json,digest,file_hash,read_json,source_hashes,engine_identity,DEST
from reliability import audit_baseline
from run import audit_protected
from evaluator_v132_report import table,display,span

BASE=ROOT/"builds/eval_v132"
DOCS=ROOT/"docs/validation/evaluator_v132"


def write(name,text):
    path=DOCS/name
    if path.exists():raise FileExistsError("do not overwrite published handoff: "+str(path))
    path.write_text(text.strip()+"\n",encoding="utf-8",newline="\n")


def archive_paths(label,paths,index):
    files=sorted(set(p for base in paths for p in (base.rglob("*") if base.is_dir() else [base]) if p.is_file()))
    chunks=[];current=[];size=0
    for path in files:
        if current and size+path.stat().st_size>64*1024*1024:chunks.append(current);current=[];size=0
        current.append(path);size+=path.stat().st_size
    if current:chunks.append(current)
    for n,chunk in enumerate(chunks,1):
        path=DOCS/"evidence"/f"{label}_{n:02}.zip"
        members={}
        with zipfile.ZipFile(path,"x",compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
            for source in chunk:
                key=source.relative_to(ROOT).as_posix();data=source.read_bytes()
                members[key]={"sha256":hashlib.sha256(data).hexdigest(),"bytes":len(data)}
                z.writestr(key,data)
        with zipfile.ZipFile(path) as z:
            assert z.testzip() is None
            for name,expected in members.items():assert hashlib.sha256(z.read(name)).hexdigest()==expected["sha256"]
        index[path.name]={"sha256":file_hash(path),"bytes":path.stat().st_size,"members":members,"verified_raw_bytes_roundtrip":True}


def native_summary():
    p=BASE/"native"
    def response(name):return json.JSONDecoder().raw_decode((p/name).read_text(encoding="utf-8-sig"))[0]
    runtime=json.loads(response("normal_runtime_response.json")["output"][0])
    errors=response("errors_after_main_response.json")
    result=read_json(p/"review_001/engine_result.json")
    return {"plugin":"Godot MCP Pro 1.17.1","scope":"SUPPLEMENTARY_ONLY_TEMP_PLUGIN_PROJECT","manifest_sha256":file_hash(p/"manifest_review.json"),"provenance":read_json(p/"native_provenance.json"),"status":result["status"],"catch":result["scenarios"][0]["catch_native"],"screenshots":read_json(p/"review_001/screenshot_index.json"),"ordinary_runtime":runtime,"fresh_editor_error_count":errors["count"],"restoration":read_json(p/"restoration_receipt.json")}


def main():
    data=read_json(BASE/"analysis_r1.json")
    native=native_summary()
    first=next(c for c in data["comparisons"] if c["run_id"].endswith("b1fa9d76"))
    diag=first["diagnostic_localization"]
    regression=read_json(DOCS/"qualification_regression/attempt_001/results.json")
    assert data["processes"]==25 and len(data["integrity_failures"])==5
    assert data["independent_metric_scenarios"]==9 and data["independent_metric_failures"]==0
    assert native["fresh_editor_error_count"]==0 and native["restoration"]["project_restored_byte_for_byte"]
    assert regression["all_passed"] and sum(x["checks"] for x in regression["runs"])==884
    # Protect original identity in both copies before archiving or reporting.
    protection={"v132":audit_protected(),"historical_v131":audit_baseline()}
    frozen=read_json(DOCS/"evidence/source_identity.json")
    assert frozen["source_hashes"]==source_hashes(ROOT)==source_hashes(DEST)
    assert read_json(DOCS/"baseline/normal_runtime.json")==read_json(BASE/"native/normal_runtime_restored.json")
    atomic_json(DOCS/"analysis.json",data)
    atomic_json(DOCS/"native_verification.json",native)

    rows=[]
    by={(c["mode"],c["hz"],c["lane"],c["context"]):c for c in data["catch_cells"]}
    for mode,hz,lane,context in product(("headless","rendered_scripted"),(120,60),("A","R0"),("isolated","sequence")):
        c=by.get((mode,hz,lane,context))
        rows.append([mode,hz,lane,context,c["n"] if c else 0,f"{c['contact']}/{c['n']}" if c else "NOT_RUN",f"{c['retained']}/{c['n']}" if c else "NOT_RUN",c["contact_tick"] if c else None,str(c["comparison_status_counts"]) if c else "MISSING_COVERAGE / EARLY_STOP"])
    catch_table=table(["Modo","Hz","Lane","Contexto","n/3","Contacto","Retenção","Tick contacto","Comparação"],rows)
    diagnostics=[]
    for c in data["comparisons"]:
        if c["suite"]!="input_diagnostics_r1":continue
        d=c["diagnostic_localization"]
        diagnostics.append([c["run_id"],c["hz"],d["first_observed_cursor_mismatch"]["tick"],d["accepted_logical_prefix"],d["first_target_mismatch"]["tick"]])
    diagnostic_table=table(["Diagnóstico","Hz","1.º cursor diferente","Prefixo lógico aceite","1.º alvo diferente"],diagnostics)
    write("catch_replay_report.md",f"""
# Swing & Catch — replay e robustez

**Resultado: R0 QUARANTINED; A DIAGNOSTIC_ONLY; decisão global NO_GO.**
Foram executados 19 dos 48 processos primários previstos. Os primeiros18 terminaram
sem rejeição de integridade. O19.º terminou no motor, adquiriu o destino e reteve-o,
mas foi rejeitado pelo validador de fidelidade do cursor. A matriz parou nesse ponto;
os29 processos restantes não foram usados para acumular resultados positivos.
Só seguiram os quatro diagnósticos do gate previstos no orçamento.

## Referências e significado da captura

As primeiras referências headless A0/B1, sem seleção best-of, passaram a120 e60Hz.
Contacto direito:438/213; origem FREE:453/221; primeira confirmação de .6s com a
mesma âncora e origem livre:525/257. Distância ao alvo no pedido:.811911/.805061m,
alcance anatómico:.65708m. O destino correto é o collider `catch`, com carga real
admitida e retenção ainda válida no fim. Não se reaproveitou ATTACHED como comando.

Os episódios completos incluem ground e B1:163/97 ticks grounded e26/24 ticks com
pelo menos um pé carregado nas referências120/60. Estas contagens incluem preparação;
não localizam, por si, ground no instante de captura. Nenhum resultado é arm-only.

## Matriz executada e ausências

{catch_table}

A120 teve6/6 contactos e retenções em headless e6/6 em rendered, divididos entre
isolado e sequência, n3 por célula. São resultados da mesma política adaptativa
versionada, não uma certificação de comandos ou trajetórias iguais. O R0 headless120
teve6/6 capturas; os três isolados coincidiram com a referência nos534ticks de inputs
aceites e estado nativo. Na sequência, o comparador congelado recusou o setup por
um nome automático de shape; o detalhe está no relatório cross-mode.

## Primeira rejeição R0 renderizada

Run `catch_rendered_scripted_120_R0_isolated_r1_t1o1_b1fa9d76`:

- Tick13: pedido `[0,0]`; cursor observado `[960,540]`, viewport1920×1080, sem gesto
  pedido nesse tick. A fidelidade completa termina antes desse desvio. Isto não
  demonstra uma emissão perdida: não havia evento pedido para emitir nesse tick.
- Todos os534 comandos locomotores/holds/owner/blocked aceites coincidem com a
  referência. Esse hash igual não prova o mesmo estado de cursor ou contacto.
- Tick55: primeiro alvo material no collider `source` difere1.256634mm. A fita
  envia píxeis pelo Input normal e a câmara corrente faz o raycast; não corrigimos
  a mira para forçar o ponto histórico.
- Primeiras diferenças nativas acima do epsilon de localização1e-6: spin92,
  velocidade94, COM125. O contacto diferente antecede-as; não há prova de causa única.
- Contacto direito439, origem FREE453, retenção525. O motor devolveu `completed`;
  o transporte `failed_runtime / REQUEST_MISMATCH:EMITTED_CURSOR` é uma rejeição
  de fidelidade, não um crash do motor nem uma violação física.

Há ainda uma diferença de cerca de um ULP float32 entre coordenadas do gesto e
cursor observado no primeiro gesto. Não se aumentou a tolerância para aprovar.

## Diagnósticos após a paragem

{diagnostic_table}

Os três toggles120 conservaram contacto/retenção, com contacto437/438/437 e
retenção525, mas todos reprovaram a fidelidade no tick13. No diagnóstico60 o
desvio inicial surge14; o pedido direito142 seleciona a face frontal+Z de `catch`,
enquanto a referência seleciona a face inferior−Y. A distância material é109.669mm.
Não houve contacto direito; o estado REACHING não adquiriu força. A libertação da
origem foi apenas a ação agendada na fita, não uma transferência bem-sucedida.

Não se atribui o miss exclusivamente ao cursor, ao Jolt, à frequência ou ao custo
do recorder. A transição histórica profile2 capturado→profile4 visível é uma
hipótese de origem do cursor central, sustentada pelo código, sem identificação
do evento de origem. Os dados não qualificam equivalência física após o desvio.
""")

    write("one_hand_60hz_report.md","""
# Uma mão / 60 Hz

**ONE_HAND_60HZ_UNQUALIFIED / MISSING_COVERAGE.** Zero screens finais dos24
previstos e zero células de qualificação de uma mão a60Hz foram executados.
Esta ausência resulta da paragem no gateR0 antes da fase de preparação; não é
uma taxa de insucesso0/0, nem uma demonstração de falha do movimento do personagem.

## Implementação entregue

`preparation_registry_v132_r1.json` congela três scripts de inputs existentes:

1. P0_DIRECT_R1: adquirir a mão retida; W1.5s; neutral.15s.
2. P1_DUAL_NEUTRAL_RELEASE_R1: adquirir as duas; W1.75s; neutral.25s; largar a outra
   com botão real e verificar no máximo.3s; neutral.5s.
3. P2_DUAL_LOADED_RELEASE_R1: adquirir as duas; W2.5s; largar a outra mantendoW,
   verificar no máximo.3s; W.35s; neutral.25s.

Os contactos são os pontos reais da parede; a mão complementar tem de estarFREE,
sem âncora e com força zero. O mesmo torso e Resource originais permanecem em uso.
Não se escreve pose, velocidade, reach, massa ou força para preparar o corpo.

Quiet: norma completa da velocidade≤.10m/s e spin≤.20rad/s durante.25s decorridos,
máximo5s. Stop/brake/reverse: velocidade dirigida.15–.50m/s, máximo2s de preparação.
As bandas são novamente verificadas no tick realmente aceite. Ground e autoridade
nativa de caminhada invalidam o onset; B1 é medido, não omitido.

Cada screen planeado teria uma janela quiet.25s seguida do sufixo fixo de drive≤2s
e um tick neutral aceite. Quiet e motion seriam selecionados separadamente por
modo/Hz/lado; motion exige também quiet válido. A escolha seria o primeiro script
elegível, nunca o melhor score. Nenhuma seleção final foi produzida ou adotada.

## Evidência disponível, sem a promover

No desenvolvimento não certificado, a120Hz headless/lado esquerdo:
P0 para stop não entrou na condição dirigida; a mão retida estavaATTACHED, a outra
FREE/força0, groundfalse e queryCLEAR. P1 eP2 entraram no screen low-energy;
P1 não confirmou uma nova estabilidade em toda a curta janela observada e foi
CENSORED; P2 confirmou settling0 com path0 após a confirmação futura exigida.
São duas tentativas low-energy de desenvolvimento, de fonte anterior ao freeze;
não são repetições finais, cobertura bilateral ou prova a60Hz.

O novo domínio é parede/B1 com geometry symmetric_clearance_r1. Mesmo que se
qualificasse, não repararia retroativamente o antigo Hang/underside: a v131 teve
24/24 preparações relevantes60Hz com PRECONDITION_NOT_MET. Esse histórico permanece
intacto. Não se alteraram bandas nem scripts depois da paragem para obter umPASS.
""")

    write("lateral_mirror_report.md","""
# Fixture lateral simétrico

**Construção e contratos DIAGNOSTIC_ONLY; qualificação MISSING_COVERAGE.**
O catálogo entrega clean/counter left/right e controles two-hand/one-hand em uma
geometria nova e nomeada. Nenhuma célula lateral final foi executada após a
paragem do gateR0; não há números positivos inventados nem simetria física certificada.

## Geometria declarada antes dos ensaios

`qualification_mirror_v1` e `qualification_onehand_v1` partilham
`symmetric_clearance_r1`: spawn existente(0,1.17,.4); parede4.8×6.8×.4m centrada
em(0,2.1,−.2); contactos(−.24,2.1,0)/(+.24,2.1,0); quatro ledges iguais em
x±.15/±.45, topo.59; pequeno pad inicial x±.24, z.32–.80, topo.25;
piso de segurança com topo−1.25. Câmara inicial yaw0, elevation−.06, distance6;
o follow normal continua. Não existe escala negativa de rigidbody.

A substituição do nível exige controller step/time0, mãosFREE, velocidadeszero,
spawn exato e ausência de ownership híbrido. Nem uma pose inicial é reescrita:
o fixture usa arena8 porque já nasce no spawn pretendido. O pad permanece no
mundo; não é retirado quando o corpo sobe. Recursos físicos e colliders do corpo
continuam originais. A construção não se declara um contacto/clearance nativo.

## Clearance e referência espelhada

O audit observa as proxies reais cápsula/esfera/box, overlaps iniciais/finais e
casts de translação, subdivididos até2cm/2graus, limite128. Uma margem de query
conservadora cobre o arco rotacional; não altera o collider físico. São consultados
pad/ground layer1, sem fingir que a parede/footholds também foram declarados livres.
POSSIBLE_GROUND_INTERSECTION produz CLEARANCE_NOT_CERTIFIED, não uma alegação de
contacto real. Os canais de ground-motor e pares nativos, quando reportados,
permanecem separados.

O max_contacts_reported original pode ser0 e não foi aumentado. Uma lista nativa
vazia com reporting desligado é UNKNOWN; queryCLEAR não prova ausência universal
de manifold/contact skin. Este limite impede uma certificação que exigisse isso.

Uma comparação bilateral correta usaria o referencial local da parede e reflexão
X dos pontos/velocidades, troca das mãos e a transformação axial correta do spin
(detR·Rω), mantendo Y/Z e as identidades de suporte. Apenas trocar o sinal de
world-X não certifica duas histórias iguais. Como a matriz não correu, essa
comparação bilateral não foi declarada medida.

Treze checks puros passaram: dados simétricos, IDs novos, bandas, orçamento,
bounds das proxies e recusa de construção depois de avançar a física. No smoke
de desenvolvimento, two-hand release obteve queryCLEAR e observação válida;
isso não substitui clean/counter left/right com n3 em ambos modos/rates.
Os 12 counter-left históricos v131 interrompidos por ground continuam visíveis e
não são reclassificados como sucesso deste novo fixture.
""")

    metric_rows=[]
    context_groups=defaultdict(list)
    for p in (BASE/"catch_r1/attempts").glob("*/typed_metrics.json"):
        m=read_json(p.parent/"manifest.json")
        for sid,v in read_json(p).get("v132_crosschecks",{}).items():context_groups[(m["engine_mode"],m["physics_hz"],sid)].append(v["independent_python"])
    for (mode,hz,sid),values in sorted(context_groups.items()):
        metric_rows.append([mode,hz,sid,len(values),span([v["stop_path_m"]["value"] for v in values]),span([v["settling_time_s"]["value"] for v in values])])
    stop_table=table(["Modo","Hz","Caso de contexto","n","3D stop path m","Settling s"],metric_rows)
    write("stopping_braking_report.md",f"""
# Stop / brake / reverse e métricas

**Novos domínios de qualificação MISSING_COVERAGE; observações existentes DIAGNOSTIC_ONLY.**
A matriz de controles novos não foi executada por causa da paragem antecipada.
Existem9 controles two-hand release do cenário histórico público, usados como
episódio anterior da sequência catch antes do gate. Esses9, a120Hz, tiveram
recomputação independente a partir do trace POST e comparação com o GDScript
runtime:9/9 pass, diferença permitida de transporte1e-6, sem diferença observada
acima desse limite. Não são uma distribuição R0 de stop ou cobertura60Hz.

{stop_table}

## Fórmulas e estados

Settling exige norma completa de velocidade≤.10m/s e spin≤.20rad/s por.25s
decorridos. O tempo reportado é o início do intervalo, reconhecido só depois da
confirmação. Zero pode ser uma medição válida; null indica não medido.
Stop path integra a trajetória3D do COM até esse início confirmado, separada
de drift assinado, deslocamento final ou excursão relativamente ao onset.
O zero de referência de overshoot não é um alvo escolhido pelo jogador.

`v132_full_norm_settle_directed_brake_v1` requer COMMON_STATIC_WORLD. Um suporte
móvel/sem frame fica INVALID_MEASUREMENT; não substituímos velocidade desconhecida
porzero. Ground/ownership/âncora perdida/clearance não certificado interrompem a
janela; um milestone anterior válido é preservado, sem crédito após interrupção.

Os novos brake50/10 usam **velocidade dirigida inicial**, apenas durante comando
oposto realmente aceite. A v131 usava norma completa para essas frações; o parser
e os resultados antigos continuam sob o ID antigo. Não se reescreveu a fórmula
histórica nem se tratou settling passivo como sucesso de brake ativo.

Os quatro campos novos nos9 controles de contexto produzem18MEASURED e18NOT_APPLICABLE
(brake não pedido). Os nove campos legacy por cenário produzem72MEASURED e9NOT_APPLICABLE.
Isso não significa que outros estados não existam: PRE/INTERRUPTED/CENSORED/INVALID
são cobertos pelos contratos sintéticos e por recibos de desenvolvimento, mas não
ganham denominadores físicos finais inexistentes.

Um two-hand brake de desenvolvimento120Hz mediu frações dirigidas50% em.191667s
e10% em.241667s, com settling1.416667s e path.274310m. Não foi promovido a
comparador qualificado. Release/brake/reverse/low-energy one-hand60 continuam sem
cobertura. O R0 implementado aceita apenas catch e o seu A_CONTEXT explícito;
fitas R0 de stop/brake/reverse **não foram implementadas/qualificadas nesta entrega**.
Pedidos R0 de outros cenários são recusados, sem fallback silencioso paraA.
""")

    probe_rows=[]
    for p in data["probe_runs"]:
        if p["suite"]=="input_diagnostics_r1" or (p["suite"]=="catch_r1" and p["lane"]=="R0" and p["context"]=="isolated"):
            probe_rows.append([p["mode"],p["hz"],"ON" if p["trace"] else "OFF","ON" if p["observer"] else "OFF",p["pre_mean_ms"],p["post_mean_ms"],p["wall_s"],p["tick_wall_gap_max_ms"],p["catch_retained"]])
    write("probe_isolation_report.md",f"""
# Instrumentação / isolamento

**DIAGNOSTIC_ONLY, não equivalência qualificada.** A matriz planeada de três
repetições por combinação foi interrompida. Os quatro diagnósticos diretamente
ligados ao gate não a substituem. A120Hz rendered há um ON/ON primário e um run
para cada um dos três toggles; n1 é descritivo, não demonstra invariância.

{table(["Modo","Hz","Trace","Observer","PRE médio ms","POST médio ms","Wall s","Gap tick máximo ms","Retido"],probe_rows)}

PRE mede reader/pre-snapshot, emissão de inputs e serialização PRE. POST usa o
contador original, que inclui snapshot/event derivation/serialização POST antes
da continuação. Custo do controller/solver/observador original não é isolado por
esses contadores. Wall inclui processo e postprocessamento, não a compactação
lossless posterior. Render cadence máxima, frames e dt real estão em analysis.json
e nos resultados brutos. A backlog/pending steps não é exposta pela API usada;
max_physics_steps_per_frame não é uma medição dessa backlog.

TraceOFF não desliga o reader. ObserverOFF desliga a observação diagnóstica
original, mantendo monitor de segurança e audit compacto. Mesmo ambosOFF não é
simulação sem instrumentação; não retiramos segurança para melhorar o tempo.

Nos três toggles120, o desvio do cursor continuou no tick13; contacto437/438/437
e retenção525. Desligar estes componentes não eliminou o gate. Os tempos menores
de hook com traceOFF demonstram custo local, não a causa do alvo diferente nem
equivalência de inputs/contactos. O diagnóstico60 ON/ON falhou o contacto direito,
com alvo efetivo diferente e clock válido. Não há atribuição causal ao scheduler
do sistema operativo, à capturaPNG ou à frequência isoladamente.
""")

    write("cross_mode_qualification.md",f"""
# Qualificação entre modos e frequências

**NO_GO / EVALUATOR_NOT_READY. Nenhum envelope contínuo aprovado.**

| Célula | Cobertura real antes/depois da paragem | Elegibilidade |
|---|---|---|
| Headless120 | A6, R0 6, referênciaA1 | Diagnóstico positivo; R0 isolado repete534ticks, sequência tem barreira cosmética no comparador |
| Rendered120 | A6; R0 primário1 rejeitado; três toggles diagnósticos | R0QUARANTINED; A DIAGNOSTIC_ONLY |
| Headless60 | ReferênciaA1 | MISSING_COVERAGE para a matriz n3 |
| Rendered60 | Um R0 diagnóstico rejeitado sem contacto direito | QUARANTINED / MISSING_COVERAGE; não é n3 |

NativeMCP_A120 é suplemento com plugin temporário e snapshots PNG; não preenche
uma célula desta matriz nem permite misturar a sua distribuição com a referência.

## O que é igual e o que não foi certificado

Hashes de tape/engine/source e a grade dt/phase são verificados separadamente dos
hashes de comandos aceites. Os três R0 isolados H120 coincidem com a referência
nos534ticks, incluindo native COM/v/spin. Uma repetição exata neste domínio é
evidência local; não estabelece um envelope para rendered,60Hz ou outras tarefas.

Em R0 rendered120 os534 comandos lógicos coincidem, mas cursor13 e materialpoint55
divergem. A equivalência do pipeline completo fica bloqueada; não se publica
SAME_ACCEPTED_COMMANDS_DIFFERENT_NATIVE_RESPONSE como diagnóstico de solver.

## Barreira cosmética de setup

O comparador congelado devolve SETUP_MISMATCH em sequências porque o nome automático
`body.shapes[2].name` muda de `@CollisionShape3D@457` para `@CollisionShape3D@889`.
O especialista verificou offline que, retirando apenas esse nome, os restantes
campos de shapes são exatamente iguais. É uma limitação do comparador, não uma
prova de geometria diferente. A rejeição original foi preservada; o relatório não
reescreve resultados nem altera a normalização depois de observar outcomes.

## Envelopes e incerteza

A prospectiva aprovou apenas identidades e epsilon1e-6 de **localização**, não uma
margem física. n3 por célula é piloto, não garantia de falhas raras. Com gateR0
reprovado e células ausentes, nenhuma faixa COM/velocidade/path/tempo de contacto
pode ser congelada para ranking. Não foi usado um intervalo global15cm nem os
ranges da v131 como tolerâncias. Frequências60/120 não são alinhadas pelo mesmo
tick nem têm de produzir trajetórias idênticas.

Os comparadores de setup/cursor e a cobertura em falta são razões separadas do
estado do controlador jogável. A regraearly-stop foi mantida; não se repetiu uma
matriz inteira para procurar um lote mais favorável.
""")

    eligibility={"schema_version":"1.3.2","benchmark_id":"benchmark_eval_v132","revision":1,"decision":"NO_GO","score_formula_id":"DISABLED_NO_AGGREGATE_SCORE_v1","score_formula_sha256":hashlib.sha256(b"DISABLED_NO_AGGREGATE_SCORE_v1").hexdigest(),"candidate_scoring_enabled":False,"metrics":{"catch_R0_full_pipeline":"QUARANTINED","catch_A120_binary":"DIAGNOSTIC_ONLY","catch_continuous":"QUARANTINED","one_hand_60":"MISSING_COVERAGE","mirrored_lateral":"MISSING_COVERAGE","stop_brake_reverse_new_domain":"MISSING_COVERAGE","two_hand_release_context120":"DIAGNOSTIC_ONLY","probe_isolation":"DIAGNOSTIC_ONLY"},"qualified_continuous_metrics":[],"approved_equivalence_envelopes":[],"private_holdout_outcomes_accessed":False,"new_optimization_trials":0,"rl_trials":0,"human_gameplay_ratings":None}
    atomic_json(DOCS/"metric_eligibility.json",eligibility)

    write("decision.md",f"""
# GRIP UP v1.3.2 — decisão

**NO_GO / EVALUATOR_NOT_READY.** A qualificação parou no primeiro gate de
fidelidadeR0 rendered; os quatro diagnósticos previstos confirmaram o bloqueio.

- Baseline:0f1a4bf7c6c74c381301475bfcbc18f686e094aa.
- Fonte medida:a06a882bbedbb30c4dd2fe3a795504361eb388de,270 hashes públicos.
- Gameplay A0/B1:sem alterações;815 ficheiros históricos protegidos intactos.
- R0:534 comandos lógicos iguais no primeiro render120, mas cursor13 e ponto
  material55 diferentes. R0completo QUARANTINED; R1 UNSUPPORTED_SEAM.
- A120:12/12 capturas/retenções reais no piloto; DIAGNOSTIC_ONLY, sem envelope contínuo.
- Diagnóstico60:clock correto e alvo numa face diferente; sem contacto direito.
- Uma mão60, novo lateral espelhado e stop/brake/reverseR0: MISSING_COVERAGE.
  Não foram declarados concluídos por testes sintéticos ou desenvolvimento.
- Probes:quatro combinações120 observadas com n1 rendered; diagnóstico apenas.
- Regressões:24 execuções,884checks PASS; Python35novos/75existentes PASS;
  Godot22novos/43existentes checks puros PASS.
- GodotMCPPro:reviewA120 com captura real,2PNG, monitor0; main normal confirmado,
  erros novos0, config reposta byte a byte, profile2/120Hz/A0/bindings originais.
- Benchmark:benchmark_eval_v132 r1; scoring desativado, zero métricas contínuas elegíveis.
- Holdouts:fechados. Random/TPE/CMA/RL/Jev/promotions/M7:zero.
- Feel humano:não avaliado por esta automação.

Nenhuma pesquisa nova é autorizada por esta entrega. A próxima decisão é de produto:
testar o gameplay com pessoas e decidir a prioridade de jogabilidade/M7, ou autorizar
separadamente uma correção pontual do pipeline de input/target e da normalização de
IDs. Não se iniciou outra revisão de fiabilidade nem se mudou a física para obterPASS.
""")

    write("report.md",f"""
# GRIP UP — relatório de qualificação do avaliador v1.3.2

Data:20 outubro2026. **Decisão final:NO_GO / EVALUATOR_NOT_READY.**
O sistema jogável A0/B1 foi preservado. Esta entrega acrescenta replay fixo,
auditoria de três camadas de input, fixtures de preparação/clearance e contratos
de métricas, mas não certifica o avaliador para otimização. O motivo determinante
é uma divergência real do pipeline cursor/câmara/alvo em R0; há também uma barreira
cosmética de IDs no comparador e cobertura física final em falta.

## O que mudou

LaneR0 envia eventos reais de rato/botões e ações pelo Input normal, em ticks
inteiros. Mantém os píxeis gravados, sem reprojetar um alvo mundial com o estado
corrente e sem forçar ATTACHED. LaneA conserva a política adaptativa histórica,
incluindo angular_phase_threshold−.04. AContext de sequência é explicitamente
adaptativo; não é rotulado replay. R0 de cenários não suportados é recusado.

Cada tape tem hash canónico e de ficheiro, trace/manifest/source/engine/scenario
de origem, bindings, focus/gates, cursor, câmara/ray/materialtarget, accepted e
effective actions. Requested permanece separado de emitted_observed. A janela
de comparação termina no primeiro desvio, mesmo com hash de fita igual.

R1 ficouUNSUPPORTED_SEAM: nenhum seam existente foi demonstrado que permitisse
injetar intent aceite sem alterar a produção ou contornar regras físicas.
O clock só cria corpos depois de observar dois deltas corretos sem mundo. O
teardown desliga subárvores/RIDs sincronamente. PRE−100 ePOST+100 são fases nomeadas,
não uma alegação de post-solver. A física continua a ser o rigidbody original/Jolt.

O fixture novo usa geometria simétrica e o spawn existente, sem escrever pose ou
velocidade do corpo. Três scripts reais de preparação e queries conservadoras das
proxies físicas foram congelados. O novo catálogo distingue settling full-norm,
path3D e brake de velocidade dirigida; as fórmulas v131 permanecem intactas.

## Orçamento e execução efetiva

O orçamento foi declarado antes das medições finais:8 launches físicos de
desenvolvimento;24 screens de preparação;2 referências;48 processos catch;
36 controles extra de probe;12 processos de controles, n3 por célula primária;
após gate duro, no máximo4 diagnósticos diretamente relacionados.

Execução congelada:a06a882,25 processos =2 referências +19 primários +4 diagnósticos.
O19.º primário reprovou fidelidade; os29 catch restantes e as matrizes de preparação,
probes completos e novos controles foram cancelados. Esta paragem é intencional e
exigida pela spec. Testes de baseline/restauração são verificação de preservação,
não continuação da qualificação de score.

Falhas de desenvolvimento ficaram guardadas:rejeição correta de tape após mudança
de fonte, transporte JSON de handID corrigido, parse de um teste de fixture corrigido,
expectativa sintética na fronteira float corrigida e ambiente Python sem dependência
seguido de execução no venv pinado. Um prelaunch0f111bf não lançou motor porque
override.cfg opcional estava ausente; a06a882 registaABSENT sem criar/mudar config.
Nenhuma dessas tentativas é rebatizada como referência final.

## Resultado de catch e primeiro desvio

{catch_table}

As duas referências reais passaram. A120 passou6/6 em cada modo, R0headless120
passou6/6. Contudo, o primeiroR0render120 tinha cursor[960,540] quando a tape pedia
[0,0] no tick13, sem gesto pedido nesse instante. Os534 comandos lógicos coincidiram;
o primeiro ponto de contacto diferiu1.256634mm no tick55. Spin/velocidade/COM
divergiram mais tarde92/94/125. Logo, não se provou 'mesma excitação/contacto e
resposta Jolt diferente'.

Os quatro diagnósticos repetiram a quebra; no de60Hz o destino142 foi selecionado
na frente+Z em vez da face inferior−Y, distância material109.669mm, e nunca ficou
ATTACHED. O clock60 estava correto antes da criação. Não se atribui a falha a uma
causa única nem se aumentou reach/força/tolerância para resgatar a captura.

Uma falha adicional do comparador é o nome automático de CollisionShape3D em
sequência. Os restantes campos de shapes são iguais offline, mas o resultado
originalSETUP_MISMATCH permanece publicado. Nenhuma destas conclusões permite
qualificação contínua ou uma tolerância global15cm.

## Paragem, pernas, apoios e cobertura

Os nove two-hand release A_CONTEXT anteriores ao gate foram recomputados do trace:
9/9 cenários coincidem com o runtime nos novos campos. Há18valoresMEASURED e18NA;
no parser legacy72MEASURED/9NA. É evidência120Hz de contexto, não a matriz nova.

{stop_table}

Uma mão60 e bilateralidade nova continuamMISSING_COVERAGE. Desenvolvimento120
com P1/P2 mostrou preparação low-energy possível na parede/B1; P0stop não atingiu
velocidade dirigida. Não se transforma esse smoke em qualificação60Hz, de Hang
ou de stop/brake/reverse. Os controlosR0 fora de catch ainda são não suportados.
Queries de clearance podem rejeitar conservadoramente; não são prova de contacto
nativo. max_contacts_reported0 original limita alegações sobre ausência de manifold.

## Custo e segurança

TraceOFF reduziu os hooks locais, mantendo reader/monitor. Os quatro toggles120
rendered têm apenas n1 cada e todos mantêm a falha do cursor. Não há prova causal
de que overhead origine as divergências, nem uma distribuição de simulação sem
instrumentação. Wall, PRE/POST, render cadence e tick gaps ficam nos recibos;
backlog nativa não está disponível pela API utilizada.

O especialista leu12844 snapshots de catch nos25 processos congelados: nenhum
REACHING ganhou força. Picos reportados:mãos253.384N,pés69.498N,assist20.0000022Nm
(arredondamento float),momento76.767Nm. Todos os flags de invariante permaneceram
falsos. Isto verifica os canais publicados e a implementação auditada, não todos
os wrenches internos do solver. Catch inclui ground/B1; nunca foi chamadoarm-only.

## Verificação e reposição

24 regressões a120/60Hz passaram884checks:physics,pending_contact,intent integration/
reversal,ground locomotion,frame signs,FirstAscent público,hybrid mantle,vault
resilience/restore,allocation eintentfeet. Passaram35 testes Python novos,75 antigos
no ambiente pinado,13 checks de fixture,9 de driver e43 contratos antigos Godot.

GodotMCPPro1.17.1 executou um reviewA120 no monitor0:contacto455,origemFREE470,
retenção542,doisPNG. O plugin/PNG altera a condição de instrumentação; esse run é
SUPPLEMENTARY_ONLY e não preenche a matriz. Depois foi aberto o main normal e
confirmado profile2,120Hz,A0.25/.12/.24/.9,massa12,reach.65708,holdtrue,feetfalse,
observer/capturefalse ebindingsoriginais. O MCP devolveu0 erros novos.

O editor foi fechado antes de repor project.godot byte a byte. O arranque CLI
ordinary voltou a passar. Os815 ficheiros históricos, fonte pública C/E, Janga,
rollback e configuração original foram verificados novamente. Não foi criado ou
promovido novo build distribuível; o baseline jogável fica preservado.

## Elegibilidade e decisão de produto

benchmark_eval_v132 r1 mantém scoringdesativado. R0completo/catchcontínuo estão
QUARANTINED; A120 eprobes sãoDIAGNOSTIC_ONLY; novos domínios em falta são
MISSING_COVERAGE. Nenhuma métrica contínua recebeu envelope aprovado pelo
especialista. Privateholdouts ficaram fechados; zero novas tentativas de
Random/TPE/CMA/sensitivity/RL/Jev,promoções ouM7. Feel humano não foi avaliado.

A próxima decisão deve ser de produto:playtests humanos e prioridade de gameplay/
M7, ou autorização separada de uma correção pontual de replay/normalização.
Não se iniciou automaticamente outra cadeia de versões de fiabilidade.

## Documentos e evidência

Ver baseline_audit,replay_contract,catch_replay_report,one_hand_60hz_report,
lateral_mirror_report,stopping_braking_report,probe_isolation_report,
cross_mode_qualification,benchmark_migration,metric_eligibility e decisão.
O parecer independente está em specialist/final_independent_review.md.
verification.json e evidence/archive_index.json ligam hashes, fontes e os recibos
completos, incluindo falhas. As fontes e tapes são recuperáveis; outputs antigos
não foram sobrescritos. Os arquivos foram verificados contra os bytes originais.
""")

    index={}
    archive_paths("development",[p for p in BASE.glob("dev*")]+[BASE/"contracts",BASE/"preparation_r1"],index)
    archive_paths("capture",[BASE/"capture_r1"],index)
    archive_paths("catch",[BASE/"catch_r1"],index)
    archive_paths("input_diagnostics",[BASE/"input_diagnostics_r1"],index)
    archive_paths("native_mcp",[BASE/"native"],index)
    source_zip=DOCS/"evidence/source_a06a882.zip"
    with zipfile.ZipFile(source_zip) as z:
        assert z.testzip() is None
        for name,expected in frozen["source_hashes"].items():assert hashlib.sha256(z.read(name)).hexdigest()==expected
    index[source_zip.name]={"sha256":file_hash(source_zip),"bytes":source_zip.stat().st_size,"public_source_files":len(frozen["source_hashes"]),"verified_raw_bytes_roundtrip":True}
    atomic_json(DOCS/"evidence/archive_index.json",{"schema_version":"1.3.2","archives":index,"path_scope":"Members are workspace-relative; extract into a NEW directory to inspect, never overwrite immutable original runs. Source snapshot contains exact raw public code/resource bytes; normal Git assets remain in repository.","archive_member_checksums_verified":True})
    write("evidence/README.md","""
# Evidence

`archive_index.json` gives SHA256/size for every ZIP and raw checksum for each
member. ZIP CRC and SHA256 roundtrips were verified. Extraction is for inspection
in a new directory; do not overwrite old runs. Member paths are workspace-relative.
Absolute paths in original manifests intentionally preserve the measured machine.
`source_a06a882.zip` preserves the exact270 public source bytes and identity map;
the baseline/recoverable Git tags preserve normal assets and earlier state.

Capture contains both first source tapes, canonical internal hashes, file hashes,
manifests, phases, PRE/POST/events and native outcome. Catch contains all19 primary
receipts including the fidelity rejection. Input diagnostics contains exactly the
four permitted after-stop runs. Development includes failures and prelaunch-only
sessions. Native includes raw MCP request/responses, plugin/config provenance,
helper code, PNGs, runtime/default and exact configuration restoration receipts.

No ZIP is a new gameplay candidate or private holdout run. No failed transport
receipt was edited into a pass; later descriptive localization is separately
identified as diagnostic-only in analysis.json and the independent review.
""")

    verification={"schema_version":"1.3.2","decision":"NO_GO","measured_commit":frozen["commit"]["repository_commit"],"public_source_hashes":frozen["source_hashes"],"public_source_files":270,"protection":protection,"engine":engine_identity(),"normal_startup_before_equals_after":True,"native_mcp":native,"matrix":{"references":2,"primary_executed":19,"primary_planned":48,"primary_transport_valid":18,"first_rejection":"REQUEST_MISMATCH:EMITTED_CURSOR","remaining_primary_cancelled":29,"direct_diagnostics":4,"all_four_rejected_fidelity":True,"one_hand_screens_final":0,"controls_final":0,"full_probe_matrix_executed":False},"regression":{"runs":24,"checks":884,"pass":True},"pure_contracts":{"python_new":35,"python_existing":75,"godot_fixture_new":13,"godot_driver_new":9,"godot_existing":43,"pass":True},"independent_metric_recomputations":{"scenarios":9,"mismatches":0,"physical_scope":"A_CONTEXT two-hand release at120Hz before early stop; not new control qualification"},"benchmark":eligibility,"archives_sha256":{k:v["sha256"] for k,v in index.items()},"private_holdout_outcomes_accessed":False,"new_optimizer_physical_trials":0,"new_rl_trials":0,"human_ratings":None,"report_tools_sha256":{str(p.relative_to(ROOT)).replace('\\','/'):file_hash(p) for p in (ROOT/'tools/evaluator_v132_report.py',Path(__file__))},"specialist_review_sha256":file_hash(DOCS/'specialist/final_independent_review.md'),"remaining_implementation_limits":["R0 control tapes outside catch unsupported","full native cursor/camera/target replay fidelity unqualified","generated shape-name normalization remains overly strict","new one-hand60 and mirrored qualification not measured after early stop","no qualified scoring envelopes"]}
    atomic_json(DOCS/"verification.json",verification)
    print(json.dumps({"decision":"NO_GO","archives":len(index),"archive_megabytes":sum(v["bytes"] for v in index.values())/1024**2,"protected":protection,"metric_checks":9}))


if __name__=="__main__":main()
