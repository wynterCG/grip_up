# GRIP UP — relatório final de fiabilidade do avaliador v1.3.1

Data: 20 de outubro de 2026. Decisão: **`EVALUATOR_NOT_READY` / `NO_GO` para nova pesquisa de parâmetros**.

A revisão de diagnóstico está implementada e validada até aos limites descritos abaixo. O avaliador passou a revelar diferenças de input, contacto, suporte e preparação que anteriormente eram difíceis de distinguir. A física jogável A0/B1 foi preservada. Os resultados ainda não sustentam comparar pontuações contínuas entre modos nem uma cobertura completa com uma mão a 60 Hz.

## Identidade e preservação

| Elemento | Identidade / resultado |
|---|---|
| Branch | `feature/v1.3.1-evaluator-reliability` |
| Checkpoint histórico preservado | `baseline/v1.3-study-frozen` → `afa04c9c322864dd75a32a1fcc6a87e6c9225864` |
| Código medido na qualificação final | `24b18d760604fffe3455c5b4c9b8b72f37577b4d` |
| Primeira matriz, preservada com falha | `e13a8465ca7bc023dfdf35996ead37b55bdd7573` |
| Driver histórico reproduzido | `1b0a86272a2939452dbe14130df25cde40278a82` |
| Godot observado | `4.7.2.stable.steam.ed1daf0bf`, Jolt |
| SHA256 do executável | `12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38` |
| Benchmark novo | `benchmark_eval_v131`, catálogo revisão 3 |
| Fórmula de métricas | `benchmark_eval_v131_stop_v1` |

O [manifesto de preservação](baseline_manifest.json) e a [verificação final](final_verification.json) confirmam 594 ficheiros históricos intactos, em ambas as cópias C:/E:, mais o engine, o grabber protegido do Janga e o executável de rollback. O `project.godot` normal foi reposto byte a byte após a ativação local temporária do MCP. O código de produção, a geometria, os alcances, as massas, os materiais, as forças e os parâmetros de locomoção não foram alterados.

Os quatro valores A0 continuam em 0,25 m/s, 0,12 s, 0,24 e 0,9. A fábrica de referência utiliza o Resource original e verifica a sua identidade/valores antes do primeiro passo; não duplica nem instala overrides. Os cenários de referência usam perfil 4, A0/B1. O arranque normal permanece no perfil 2, com o estado original dos seus toggles; não se confunde esse arranque com a configuração experimental.

Foram conservadas **89 execuções de avaliação e 406 linhas de cenário**, contando história, desenvolvimento, matrizes finais e a demonstração MCP. São 87 processos de avaliação concluídos, uma rejeição `BLOCKED_TRACE` e uma rejeição `failed_runtime` por alteração de fonte durante desenvolvimento. “Concluído” significa que o avaliador terminou; não significa que todas as metas físicas foram cumpridas. As duas auditorias de ficheiros, os testes sintéticos e as regressões originais são contados separadamente.

## O que foi implementado

O driver comum aos modos headless/renderizado coloca pedidos de input numa fila, emite-os antes dos callbacks de gameplay e lê o estado depois desses callbacks. Regista o pedido e o comando efetivamente aceite separadamente. `post_control` significa depois do controlador, antes da integração seguinte; não é apresentado como um snapshot post-solver.

O leitor expõe COM e velocidades do estado físico direto, configurações dos corpos, âncoras e alvos materiais, estados das mãos, cargas admitidas, pés carregados, autoridade do chão, ownership híbrido e câmara/raycast. Um alvo escolhido, uma mão em alcance e um contacto com carga são eventos diferentes. Apoios estáticos só recebem velocidade zero quando essa condição é demonstrada; frames mistos desconhecidos não recebem zeros inventados.

O recorder guarda rastos PRE/POST limitados e eventos ordenados em diretórios únicos, com hashes e finalização atómica. Deltas reais incorretos invalidam a execução. Há confirmação do relógio antes de criar o mundo e remoção síncrona dos corpos antigos antes do cenário seguinte. O comparador verifica identidade e fase, localiza divergências e separa diferenças físicas de diferenças de comando/contacto. Não atribui certificação automática a uma diferença pequena.

As métricas novas distinguem `MEASURED`, `CENSORED_TIMEOUT`, `INTERRUPTED`, `PRECONDITION_NOT_MET`, `INVALID_MEASUREMENT` e `NOT_APPLICABLE`. Cada valor não medido conserva razão e contexto. Stop path, drift assinado, settling, frações de travagem, reversão e horizontes fixos não são substituídos por uma única penalização. Uma reversão confirmada antes de tocar no chão pode conservar o seu valor; o progresso posterior fica interrompido.

## Captura: reprodução e causa observável

A [investigação completa](catch_investigation.md) preserva a reprodução histórica: headless 3/3 isolado e 3/3 em sequência; renderizado 2/3 isolado e 0/3 em sequência, a 120 Hz. Os hashes públicos e o engine coincidiram. O estado preparado já diferia antes da captura, mas o driver antigo não registava inputs aceites por tick. Não se atribui retroativamente uma causa única ao Jolt.

A primeira matriz nova parou na execução 25: o cenário renderizado pedido a 60 Hz já tinha um corpo durante 15 ticks efetivos a 120 Hz. O guard rejeitou o rasto. Essa execução não conta como falha física válida do A0; as sete condições seguintes não foram executadas nessa tentativa. Também foi identificada uma diferença de criação entre o primeiro mundo e os seguintes.

A revisão final confirma o passo físico antes de construir corpos e cria todos os mundos na mesma fronteira. Nos oito processos renderizados de 60 Hz, os 15 callbacks de arranque obsoletos foram observados **sem Lab**, seguidos de dois callbacks corretos antes da criação. Nenhum tick físico medido foi reetiquetado ou ignorado para fazer passar o ensaio.

`catch_002` concluiu **32/32 contactos e retenções reais**: três isolados, três em sequência, um trace OFF e um observer antigo OFF em cada modo/frequência. A revisão independente encontrou 6836 amostras de mãos pendentes com força admitida exatamente zero. Restauro, limites e cleanup não apresentaram violações dos monitores.

Contudo, o resultado contínuo varia. Em dois outliers renderizados de 120 Hz, o feedback escolheu W+D no tick 419 onde o headless escolheu W+A. O contacto atrasou 438→478, a libertação da fonte 453→493 e a retenção 510→550. O progresso ficou perto de 0,4506 m, contra 0,5342 m; o maior desvio de COM num par atingiu aproximadamente 0,1505 m. A [comparação entre modos](cross_mode_report.md) mostra que estas não são tapes efetivas iguais. Não se inventou uma tolerância de 15 cm para as declarar equivalentes.

O outcome binário novo é repetível neste orçamento. Isso não certifica a pontuação. Pés B1 e contacto transitório com chão contribuem: `destination_alone` significa mão fonte largada, não suspensão exclusivamente pelo braço de destino.

## Deslocação lateral e suporte

A matriz final teve **12 execuções × 12 casos = 144 observações**, com três repetições por modo/frequência. As tabelas completas, valores por repetição e gráficos estão em [control_analysis_002](reports/control_analysis_002/controls.md) e no seu [JSON](reports/control_analysis_002/control_summary.json).

| Família | Resultado observado |
|---|---|
| Clean lateral, esquerda/direita | 24/24 observações válidas, com progresso assinado positivo |
| Counter-swing direito | 12/12 observações completas válidas |
| Counter-swing esquerdo | 12/12 interrompidas por chão; reversão anterior continua mensurável |
| Release, brake, reverse e baixa energia com uma mão, a 60 Hz | 24/24 sem pré-condição cumprida, em ambos os modos |
| Total de estados de cenário | 84 válidos, 36 interrompidos, 24 sem pré-condição |

As entradas clean exigem velocidade lateral ≤0,10 m/s e spin ≤0,20 rad/s durante 0,25 s decorridos. Counter-swing exige velocidade real oposta em [−0,50; −0,02] m/s. Os apoios têm de ser reais, sem autoridade nativa do chão. A preparação usa os comandos existentes; não congela o corpo nem escreve velocidades.

O counter esquerdo toca no chão aproximadamente entre 1,68–1,91 s, mantendo as duas âncoras agarradas nos casos auditados. Não é uma falha de parser ou simplesmente perda da pega. Não se credita a deslocação depois desse contacto como escalada válida. Os pés contribuem significativamente mesmo nas observações sem chão; uma mão agarrada não equivale a um ensaio só de braços.

## Paragem, travagem e reversão

As condições de entrada foram revistas antes da qualificação: stop/brake/reverse começam com velocidade dirigida de 0,15–0,50 m/s, fora da banda de paragem de 0,10 m/s. Baixa energia usa a norma completa da velocidade e do spin, novamente verificada no comando aceite. Revisões anteriores e as suas falhas continuam preservadas.

| Release | Distância de paragem observada | Settling observado |
|---|---:|---:|
| Duas mãos, headless 120 Hz | 0,115432 m | 1,075000 s |
| Duas mãos, renderizado 120 Hz | 0,115507–0,115767 m | ≈1,075000 s |
| Duas mãos, headless 60 Hz | 0,116056 m | 0,850000 s |
| Duas mãos, renderizado 60 Hz | 0,116055–0,116621 m | 0,850000–0,866667 s |
| Uma mão, headless 120 Hz | 0,288948 m | 1,316667 s |
| Uma mão, renderizado 120 Hz | 0,286048–0,365543 m | 1,316667–2,116667 s |
| Uma mão, 60 Hz | Sem medição: pré-condição falhada | Sem medição |

São caminhos 3D até confirmar o critério, não apenas deslocação final. Um drift final pequeno pode coexistir com oscilação e caminho grande. A variação de 0,8 s e cerca de 0,0795 m no release renderizado de uma mão é material e permanece visível.

O controlo de baixa energia com duas mãos produziu `MEASURED` nos dois modos/frequências. Com uma mão, isso foi demonstrado a 120 Hz, mas não a 60 Hz. `settling_time=0` é legítimo nesses controlos: o início do intervalo estável é o onset e a confirmação só ocorre após observar mais 0,25 s. A auditoria recalculou caminhos a partir do trace e verificou as bandas durante os intervalos de confirmação.

A travagem de duas mãos atingiu a fração de 50% da velocidade durante a janela ativa. A fração de 10% ficou interrompida pelo fim dessa janela, mesmo quando houve settling posterior. Não se apresenta amortecimento posterior como travagem ativa concluída. Overshoot usa o COM no onset como referência espacial declarada de medição; não mede precisão de um alvo escolhido pelo jogador.

| Família de métricas | MEASURED | NOT_APPLICABLE | INTERRUPTED | PRECONDITION_NOT_MET |
|---|---:|---:|---:|---:|
| Principais | 462 | 600 | 90 | 144 |
| Frações de travagem | 24 | 480 | 48 | 24 |
| Horizontes fixos | 462 | 0 | 66 | 120 |

Não houve `CENSORED_TIMEOUT` ou `INVALID_MEASUREMENT` reais nesta matriz. Os ramos de censura, trace incompleto, chatter e reversão não observada foram exercitados por testes sintéticos, sem os renomear como dados nativos. As contagens vêm de cada `metric.status`; mensagens genéricas de fallback em `observation` não contam como censura. Em pré-condições falhadas, o resumo final distingue último estado de preparação de onset aceite inexistente. O relatório de análise 001 e o script anterior foram preservados após corrigir essa rotulagem no 002; os recibos físicos e as fórmulas não foram alterados.

## Verificação, MCP e custo

Os [75 testes Python](contracts/attempt_002/python.txt) e os [43 checks Godot de contrato](contracts/attempt_003/godot_tick_contract.txt) passaram. Incluem estados tipados, alinhamento de fases, timestamps, isolamento de input, confirmação do relógio e teardown. São testes de contrato, não demonstrações de feel.

As [24 regressões originais](reliability_regression/attempt_001/results.json) passaram a 60/120 Hz, com **884 verificações**. Cobrem física, pending/contacto, input/frame, chão, intenção/reversão, pés/alocação e mantle/vault/restauro. A regressão pública First Ascent não chamou o split privado do tuning lab nem forneceu resultados de holdout a uma pesquisa.

O [MCP Pro](native_mcp_report.md) executou uma captura renderizada suplementar no monitor 1, com duas imagens indexadas por tick/tempo e resultado válido. A configuração local do plugin foi ativada temporariamente e tem proveniência própria; essa execução não entra como 33.ª repetição qualificada entre modos. Foram preservados cinco avisos estáticos da cena de laboratório: quatro herdados e um novo nome local `ready` que sombreia o sinal de Node. Não houve exceção de runtime observada. A sessão principal normal seguinte reportou zero erros, sem driver de investigação, observer ou recorder, com os quatro valores originais. Depois, o editor foi fechado, a configuração original reposta byte a byte e o main voltou a arrancar durante 180 frames sem erros reportados.

O custo do probe POST é parcial e explicitamente separado do custo total do processo. Nos isolados headless ficou perto de 1,17–1,19 ms/chamada com trace ON e 0,27 ms com trace OFF. Recorder OFF e observer OFF são controlos diferentes; o leitor novo continua ativo. Os controlos OFF têm n=1 por célula, pelo que não estabelecem uma equivalência estatística ou instrumentação nula. Os [dados completos de custo](reports/catch_002/summary.json) permanecem por modo/frequência/contexto.

Não foi criado um novo executável do jogo. Os presets excluem o laboratório novo, o antigo, ferramentas, docs e builds; foi feita auditoria estática dessas exclusões, sem alegar inspeção de um pacote novo que não foi exportado. O rollback anterior permanece intacto.

## Gates e decisão

| Gate | Estado final | Fundamento |
|---|---|---|
| ER0 — Freeze/auditoria | PASS | Fontes, engine, cópias, rollback e Janga verificados; defaults restaurados |
| ER1 — Rastos | PASS na revisão final | Contratos e relógio/cleanup validados; falha anterior preservada |
| ER2 — Captura | PASS limitado / causa histórica não fechada | 32/32 outcomes novos; divergência histórica única não demonstrada |
| ER3 — Laterais | PARTIAL | Clean e counter direito válidos; counter esquerdo interrompe por chão |
| ER4 — Stop/reversal | PARTIAL, medições honestas | Pipeline real demonstrado; uma mão a 60 Hz não entra em medição |
| ER5 — Equivalência | `BLOCKED_EQUIVALENCE` | Divergência efetiva de comandos e variabilidade contínua; sem tolerância aprovada para pontuar candidatos |
| ER6 — Benchmark | PARTIAL congelado | Revisão 3 publicada; migração explícita; regressões verdes; sem ranking candidato-ready |
| ER7 — Handoff | CONCLUÍDO: `NO_GO` | Relatório, revisão independente e evidência íntegra; nova pesquisa bloqueada |

O resultado útil desta fase é um avaliador que expõe os seus limites. O próximo trabalho de fiabilidade deve resolver ou excluir explicitamente os ensaios que não oferecem comparação justa, antes de discutir nova afinação. Não é necessário alterar a física para transformar estas observações em passes.

**Novos trials Random/TPE: 0. Treino RL: 0. Promoções: 0. Outcomes privados consultados: 0. Sessões humanas: 0. M7: não iniciado.** Não é proposta uma nova pesquisa nesta decisão.

## Entrega e reprodução

O [índice de evidência](evidence/README.md) contém arquivos com hashes, verificação de recuperação e fontes públicas brutas dos commits medidos. Os arquivos resolvem também diferenças de CRLF/LF que um checkout Git pode introduzir. O código final medido tem 254 ficheiros públicos no seu mapa; os holdouts ficam fora desse snapshot.

Para reproduzir, usar um checkout isolado do commit medido, assets correspondentes, o engine com SHA indicado e os bytes públicos do snapshot respetivo. Os manifestos originais conservam caminhos absolutos desta máquina; qualquer novo ensaio precisa de diretório/manifesto novo e dos seus próprios hashes. Não retomar nem sobrescrever `stage1_r1`, `catch_001`, `catch_002` ou os seus recibos.

Ver também a [migração de benchmark](migration_from_v13.md), o [contrato de métricas](movement_metrics.md), a [revisão física independente](physical_review.md), o [manifesto de alterações](changed_files.json) e a [decisão compacta](decision.md).
