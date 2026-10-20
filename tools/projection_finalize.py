"""Finalize reviewed documents; raw trials and historical evidence stay immutable."""
from pathlib import Path
import sys,json,shutil
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/auto_tuning'))
from common import read_json,atomic_json,file_hash
DOC=ROOT/'docs/validation/auto_tuning/projection_v132b'
BASE=ROOT/'builds/eval_virtual_cursor/projection_v132b_r2'

def main():
    review=DOC/'specialist/PV6_independent_review.md'
    assert file_hash(review)=='f9fe44d753fefd1fbe2a27ea00948d955e65998d31264e88ef203f57249609e8'
    p=DOC/'window_ablation_report.md';s=p.read_text(encoding='utf-8')
    s=s[:s.index('\n## Ampl')]
    s=s.replace('A mesma divergência reaparece no mesmo tick/magnitude em headless e renderizado.','A mesma divergência reaparece no mesmo tick/magnitude em headless e renderizado. A comparação headless mantém screen−1/mode1; a renderizada muda screen0→1 e fica NOT_ISOLATED para atribuição causal isolada.')
    s=s.replace('Isto identifica um efeito causal do conjunto backing-size/stretch numérico neste ambiente e nestas duas tapes.','A intervenção dentro de headless identifica um efeito causal do conjunto backing-size/stretch numérico neste ambiente e nestas duas tapes. A comparação renderizada é consistente com esse efeito mas tem o monitor como fator associado.')
    s=s.replace('renderizado Windows/mode0 com DPI/escala observados.','renderizado Windows/mode0:1024×576 em screen0(10execuções),1440×810 em screen1(8execuções), ambos DPI120 e OSscale1.0, apesar de --screen0 pedido. CLI também usava --position80,80. Headless pequeno12execuções e grande6 permanecem screen−1.')
    s=s.replace('renderizado Windows/mode0:1024?576 em screen0(10execu??es),1440?810 em screen1(8execu??es), ambos DPI120 e OSscale1.0, apesar de --screen0 pedido. CLI tamb?m usava --position80,80. Headless pequeno12execu??es e grande6 permanecem screen?1.','renderizado Windows/mode0:1024×576 em screen0(10execuções),1440×810 em screen1(8execuções), ambos DPI120 e OSscale1.0, apesar de --screen0 pedido. CLI também usava --position80,80. Headless pequeno12execuções e grande6 permanecem screen−1.')
    s=s.replace('A escala e as dimensões variam juntas: a aritmética interna específica não foi isolada como variável adicional.','A escala e as dimensões variam juntas; na ablação renderizada também varia o índice de monitor. A aritmética interna específica não foi isolada como variável adicional. O GO limitado aplica-se apenas aos perfis efetivos observados, sem equivalência geral entre monitores.')
    s+='''
## Amplificação e apoio transitório — leitura independente

A120Hz, P1 atinge separação máxima COM8.1752936446e-7m e delta máximo de força direita.00366136595N. A60Hz, o COM diverge até.171978737774m(tick263), velocidade linear.8990039425m/s e força esquerda127.530879931N(tick181); existem5ticks com estados de mão diferentes. Não se aprovou um envelope que absorva estes efeitos.

Depois de sourceFREE e antes de terminar a retenção, o chão nativo contribui transitoriamente:2POST por execução120Hz,11 por execução60Hz/pequena e0 a60Hz/grande,157POST no conjunto. Não há pés carregados nesse intervalo. No primeiro instante que satisfaz retenção e daí até ao fim, grounded é false e os pés não aplicam força em todas as36 execuções. Portanto a sequência inteira não é declarada arm-only; esta assistência normal B1 fica publicada e não foi criada pela sonda.

O máximo de assistência medido é20.0000013954Nm. O monitor original inalterado usa limites de relatório20.001/150.001Nm e360.001/180.001/120.001N (optimization_trial_driver.gd152/172); isto cobre representação float32, sem aumento de budgets nem tolerância de raios/contactos. Máximos mãos254.947982788N, pés45.470653534N, momento combinado76.7607120563Nm.
'''
    p.write_text(s,encoding='utf-8')
    (DOC/'native_review.md').write_text('''# Revisão nativa e segurança do export

Godot MCP Pro1.17.1 foi usado no editor E:, monitor0 pedido e observado no main. `runtime exec` confirmou perfil2, LIVE, replay disabled, virtual camera false e projection probe null; restantes valores coincidem exatamente com a baseline. A captura ordinary_main.png foi inspecionada visualmente: cena normal STATIC CLIMB, personagem e HUD visíveis. Não houve interação de escalada ou playtest humano neste suplemento.

`errors_before`: um aviso preexistente sobre builds/reference_v13_reliability/project.godot. `errors_after`:0. Requests/responses e PID próprio estão arquivados. O editor próprio foi encerrado e os bytes originais de project.godot C/E restaurados (SHA6ae2782544aa70dfb6a099260ead68de0b0bb7007093ef846bbb2dabfc6a86c9). Não restaram motores Godot desta campanha.

O arranque headless normal coincide exatamente com a baseline anterior. Export RELEASE novo e smoke headless de180frames terminam0, sem script errors; isso é startup smoke, não playthrough. A inspeção de recursos usa o motor debug stock com --main-pack num diretório isolado, para não procurar scripts no projeto de origem. Confirma ausência de ProjectionProbe/provider/driver/runner/qualification/optimization e arranque perfil2/providerdisabled/câmaravirtualfalse. Não se apresenta essa inspeção como executada pelo template release. O executável novo está em builds/eval_virtual_cursor/projection_v132b_r2/safety, com SHA/bytes próprios; a rollback anterior não foi substituída.

Os replays de qualificação são outra atividade: o monitor efetivo foi screen0 para janela pequena e screen1 para grande, apesar do CLI --screen0. Ambos reportam DPI120/scale1.0. Esse fator está explicitamente declarado NOT_ISOLATED na ablação renderizada; não se alteraram nem repetiram os dados para ocultá-lo.
''',encoding='utf-8')
    shutil.copy2(review,DOC/'independent_review.md')
    (DOC/'decision.md').write_text('''# Decisão PV6 — GO_LIMITED_PROJECTION

O problema de picking foi localizado a montante da base mundial: o raio local já difere quando muda backing-size/stretch. Em headless, a intervenção mantém o ambiente restante observado e reproduz o efeito; a ablação renderizada muda também de monitor e fica NOT_ISOLATED. A operação numérica interna exata permanece por observar. Não foi necessário construir um motor instrumentado nem alterar o algoritmo de picking.

Política autorizada: igualdade estrita para estas duas tapes Swing & Catch, nesta fonte/engine/renderer, perfil4/A0/B1/V0_PHYSICS_FOLLOW e **mesma frequência com mesmo backing efetivo**. Os ambientes renderizados efetivamente medidos são1024×576/screen0 e1440×810/screen1, mode0/DPI120/scale1.0; headless screen−1/mode1. O viewport lógico é1920×1080. Confirmar tamanho, ambiente, owner e fase antes do mundo e em cada pick. Não se aprovam combinações de monitor/tamanho que não foram medidas.

12/12 pares correspondentes com três repetições por célula passaram input/cursor/câmara/ray/query/material/POST publicados estritos.4/4 controlos da nova sonda não alteraram esses campos. Todos36 replays completaram contacto/retensão real sem violações físicas do monitor.37/40 tentativas globais, incluindo1R1 rejeitada antes de boot; nenhum diagnóstico físico adicional.

| Domínio | Estado |
|---|---|
| Inputs/cursor das tapes medidas | STRICT_MATCH |
| Picking/âncoras/POST publicados sob backing e Hz correspondentes | STRICT_MATCH no domínio observado |
| Tamanhos históricos diferentes | STRICT_MISMATCH; contínuo QUARANTINED |
| FUNCTIONAL_MATCH_WITH_NUMERIC_DRIFT | NÃO QUALIFICADO; nenhum envelope aprovado |
| Operação float interna exata | NÃO OBSERVADA; sem engine instrumentado |
| One-hand60, lateral, stop/braking, holdouts | NÃO QUALIFICADOS |
| LIVE vs V0 / outros inputs, cenas, hardware, DPI e monitores | NÃO QUALIFICADOS por esta campanha |
| Feel humano | NÃO AVALIADO |
| OPTUNA / RANDOM / TPE / CMA / RL / JEV / M7 | OFF / SEM AUTORIZAÇÃO |

Nenhuma correção de locomoção, câmara LIVE, geometria, força ou contacto foi feita. Só hooks de leitura, auditoria exata da query, configuração de janela dos ensaios e ferramentas de diagnóstico. O erro de transporte CLI deR1 foi corrigido sob revisão/freezeR2; R1 e os NO_GO históricos permanecem preservados. A única conclusão de equivalência contínua é dos campos publicados estritos nas células correspondentes; não é determinismo geral do solver.

Esta fase termina aqui. O próximo passo possível exige tratar separadamente os outros domínios em quarentena; não há lançamento automático de tuning.
''',encoding='utf-8')
    verification=read_json(DOC/'verification.json');verification.pop('decision_pending_independent_signoff',None)
    verification.update(decision='GO_LIMITED_PROJECTION',independent_review_sha256=file_hash(review),rendered_size_ablation='NOT_ISOLATED_BACKING_AND_SCREEN',measured_rendered_profiles=[{'size':[1024,576],'screen':0,'dpi':120,'os_scale':1.0},{'size':[1440,810],'screen':1,'dpi':120,'os_scale':1.0}],no_general_monitor_equivalence=True,post_source_free_ground_contribution={'total_post':157,'per_120_run':2,'per_60_small_run':11,'per_60_large_run':0,'at_and_after_first_retained':'groundedfalse,feetforce0 in all36'},old_physics_reporting_tolerances_unchanged={'hands_n':.001,'feet_total_n':.001,'per_foot_n':.001,'assist_nm':.001,'combined_nm':.001})
    atomic_json(DOC/'verification.json',verification)
    (DOC/'README.md').write_text('''# GRIP UP — Projection & Viewport Qualification v1.3.2b

**GO_LIMITED_PROJECTION** nas duas tapes e nos perfis efetivos documentados, com backing/Hz correspondentes e comparação estrita. Tamanhos diferentes continuam em quarentena; otimizadores OFF. A locomoção preferida pelo utilizador foi preservada.

- [Relatório completo](window_ablation_report.md)
- [Decisão e limites](decision.md)
- [Revisão independente](independent_review.md)
- [Verificação técnica](verification.json)
- [Diferenças e trajetórias](ray_pipeline_diff.json)
- [Todos os runs/configurações reais](observations/runs.json)
- [MCP Pro / export](native_review.md)
- [Plano R1](test_plan.json), [falha pré-boot preservada](r1_setup_failure.json), [plano corrigido R2](test_plan_r2.json)
- [Identidade de baseline](baseline_identity.json), [compatibilidade de fonte explícita](approved_source_delta_r2.json)
- Evidência ZIP e SHA por membro em evidence_manifest.json.

36 replays novos,12 pares correspondentes estritos,4 controlos ON/OFF,14382POST.34 processos de regressão/1146verificações, mais24+18 contratosGD e25Python. A inspeção MCP é suplementar, não playtest humano; smoke release não é playthrough. Resultados anteriores e tapes originais não foram substituídos.
''',encoding='utf-8')
    print('Final reports and independent scoped decision complete')
if __name__=='__main__':main()
