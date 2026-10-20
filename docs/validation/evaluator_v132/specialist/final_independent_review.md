# v1.3.2 — revisão física independente após a paragem antecipada

Data: 2026-10-20. Decisão: **EVALUATOR_NOT_READY / NO_GO** para qualificar o pipeline completo ou voltar à otimização.

Esta revisão lê os ficheiros já produzidos. Não executou Godot, não modificou código, tapes, parâmetros, geometria ou critérios e não reclassifica retroativamente tentativas rejeitadas. O resultado negativo é da qualificação do avaliador; não demonstra uma regressão do jogo nem uma falha causal do Jolt.

## Identidade e denominadores

- Fonte qualificada tentada: `a06a882bbedbb30c4dd2fe3a795504361eb388de`.
- Baseline protegido: `0f1a4bf7c6c74c381301475bfcbc18f686e094aa`.
- Conferência independente de `builds/eval_v132/baseline/freeze.json`: **815/815 ficheiros protegidos com SHA-256 inalterado** nesta revisão.
- A matriz primária foi interrompida após **19 processos**, dos quais 18 aceites pelo transporte e um rejeitado pelo pós-validador. Não foram concluídas as 48 células planeadas.
- Acrescentam-se **duas capturas de referência** (120/60 Hz) e **quatro diagnósticos diretos autorizados**. Total revisto: 25 processos, não 25 repetições qualificadas da mesma condição.
- Os diagnósticos consumiram o limite de quatro. Não se recomenda continuar a matriz ou corrigir iterativamente a fonte nesta versão congelada.

Localizações dos recibos, relativas à raiz do projeto:

| Grupo | Caminho |
|---|---|
| Referências | `builds/eval_v132/capture_r1/attempts/` |
| Matriz primária interrompida | `builds/eval_v132/catch_r1/attempts/` |
| Quatro diagnósticos | `builds/eval_v132/input_diagnostics_r1/attempts/` |
| Fonte congelada | `docs/validation/evaluator_v132/evidence/source_a06a882.zip` |

Hashes conferidos da fonte corrente:

| Ficheiro | SHA-256 |
|---|---|
| `features/evaluator_qualification/scripts/qualification_driver.gd` | `f42e6a80483afa33af56813159234ee2f100298c51560fb5d3de2eadbbbf3678` |
| `features/evaluator_qualification/fixtures/qualification_fixture.gd` | `be9b1dd8688bde5c02e9c98f79ee17b4291418d0de9eb6309cd79022031f5e97` |
| `features/evaluator_qualification/resources/benchmark_eval_v132.json` | `653589d834b89a205fabb2a0b2473f9e92fe43fa38465598095ad57d16d2d88b` |

## O que os resultados realmente demonstram

Os 18 processos primários aceites são todos a 120 Hz: seis A headless, seis R0 headless e seis A renderizados, repartidos entre execução isolada e sequência. Todos registam captura real, carga admitida no destino, libertação da mão de origem e retenção no mesmo contacto de destino durante pelo menos 0,6 s após a libertação. O contexto anterior das sequências é explicitamente **A_CONTEXT**, não uma qualificação R0 desse contexto.

O primeiro R0 renderizado a 120 Hz também executou uma captura real e a retenção requerida, mas **não passou a fidelidade do replay**. Não deve ser somado às repetições R0 qualificadas. Um dos A renderizados contactou no tick 478, enquanto os outros cinco contactaram no 438. Isso já impede descrever A como uma fita física idêntica ou como uma distribuição temporal invariável.

| Condição | Contacto | Origem FREE | Primeira retenção requerida | Resultado físico / resultado do contrato |
|---|---:|---:|---:|---|
| Referência H120 | 438 | 453 | 525 | Captura e retenção / referência |
| Referência H60 | 213 | 221 | 257 | Captura e retenção / referência |
| Primeiro R0 render120, `b1fa9d76` | 439 | 453 | 525 | Captura e retenção / rejeitado |
| Diagnóstico120, trace OFF / observer ON | 437 | 453 | 525 | Captura e retenção / rejeitado |
| Diagnóstico120, trace ON / observer OFF | 438 | 453 | 525 | Captura e retenção / rejeitado |
| Diagnóstico120, ambos OFF | 437 | 453 | 525 | Captura e retenção / rejeitado |
| Diagnóstico60, ambos ON | nenhum | sem cadeia de sucesso | nenhuma | Sem contacto direito / rejeitado |

Os ticks são locais ao episódio e só se comparam diretamente dentro da mesma frequência. As referências a 60 Hz não substituem a matriz R0/A a 60 Hz que ficou por executar.

## Adjudicação da falha R0

Recibo primário: `catch_rendered_scripted_120_R0_isolated_r1_t1o1_b1fa9d76`.

O transporte escreve `failed_runtime`, razão `REQUEST_MISMATCH:EMITTED_CURSOR`; o motor escreve `completed` e produziu os 534 ticks. Portanto, o rótulo não significa crash ou erro de execução da física: é a rejeição do resultado pelo contrato de fidelidade.

1. **Primeira quebra de estado de entrada:** no tick 13, o cursor pedido é `[0,0]`, não há gesto, nenhuma mão está premida e o comando locomotor aceite é zero. O estado observado passa para `[960,540]`, o centro do viewport 1920×1080. Os quatro diagnósticos reproduzem esta quebra: tick 13 a 120 Hz e tick 14 a 60 Hz.
2. **Não foi demonstrada uma emissão perdida:** naquele tick não existe evento de rato pedido para emitir. É um estado de cursor não solicitado/divergente, suficiente para reprovar o contrato congelado, mas não prova que um gesto tenha sido descartado. O histórico profile2 capturado → profile4 visível e os eventos da janela são uma hipótese plausível de origem; os recibos não identificam a origem do evento.
3. **Comandos lógicos não são o mesmo que excitação física:** em `b1fa9d76`, os 534 registos de `accepted_input`, `hand_held`, `input_owner` e `blocked` coincidem com a referência. Mesmo assim, no primeiro gesto real, tick 55, a seleção no collider `source` produz um ponto material diferente em **1,2566 mm**. O replay R0 usa os píxeis congelados com a câmara corrente; não corrige a mira para forçar o antigo ponto mundial. A partir daí já não há garantia de forças excitadas pelo mesmo contacto.
4. **Ordem observada das divergências de corpo:** neste par, diferenças normais superiores a `1e-6` surgem primeiro na velocidade angular no tick 92, velocidade linear no 94 e COM no 125. Esse epsilon serve apenas para localizar diferenças no relatório; não é uma margem física de aprovação. A diferença de contacto antecede estas diferenças do corpo, sem provar uma causa única.
5. **Precisão adicional do transporte:** no primeiro gesto existe também uma diferença de cerca de um ULP float32 entre `cursor_after_px` da referência e os píxeis do gesto congelado, aproximadamente `6,10e-5` / `3,05e-5` px. É distinta da deslocação de 960/540 px. Não se alterou a tolerância para tornar o replay aprovado.

Conclusão: **hard failure de fidelidade R0; full-route NOT_COMPARABLE / QUARANTINED**. Não é uma demonstração de “mesmos comandos e mesmos contactos, mas resposta nativa diferente”. A integridade lógica parcial observada não autoriza remover o guard de cursor ou certificar equivalência do pipeline completo.

### Diagnóstico a 60 Hz

O handshake registou 15 deltas de 1/120 s **sem mundo**, seguidos de dois deltas consecutivos corretos de 1/60 s. O mundo foi criado no post-boundary, a árvore antiga estava ausente e todos os deltas medidos do episódio são 1/60 s. O problema anterior de misturar o delta antigo com um mundo já criado não aparece neste recibo.

No tick 142, o pedido direito atinge realmente o collider `catch`, mas a referência seleciona a face inferior, normal `[0,-1,0]`, e o diagnóstico seleciona a face frontal, normal `[0,0,1]`. Os pontos materiais diferem **0,109669 m**. O alvo diagnóstico é inicialmente distante, continua em REACHING, não adquire carga e regista uma janela obstruída; não existe contacto direito. A libertação da origem é depois uma ação da fita, não uma passagem bem-sucedida de suporte.

Esta é uma diferença física de alvo importante, não apenas uma variação microscópica do COM. Não prova que o cursor centrado tenha causado a seleção diferente ou o miss. Também não permite atribuir o miss ao Jolt, à frequência isoladamente ou a um defeito de força do jogo.

## Segurança e limites da evidência física

Foram lidos **12 844 snapshots post-control de catch**, abrangendo as 25 execuções referidas. Não se encontrou força não nula de mão em estado REACHING no audit efetivo. Os flags reportados de pending support force, autoridade indevida no ar, parâmetros protegidos, nonfinite, captura não física, conflito de ownership, mutação direta do corpo e orçamento de força permanecem falsos.

Picos observados neste conjunto: mãos **253,384 N**, pés **69,498 N**, assistência **20,0000022 Nm**, momento combinado reportado **76,767 Nm**. A diferença microscópica sobre 20 é arredondamento vetorial float, não evidência de um novo orçamento. Estes valores verificam os canais publicados, não constituem uma medição independente de todos os wrenches internos do solver.

Todos os recibos lidos indicam originais preservados, fonte inalterada, frequência restaurada e criação com a árvore anterior ausente. A ausência de body writes é sustentada pela implementação congelada/auditada e pelos guards disponíveis; não é inferida apenas de um booleano sempre falso. Não houve mudança de massa, limites, ganho, anatomia ou Resource para melhorar estas tentativas.

Este catch **não é arm-only**: as referências têm 163/97 ticks de ground e 26/24 ticks de pé carregado no episódio completo, a 120/60 Hz. Os três diagnósticos120 têm 165–166 ticks de ground e 26 de pé carregado; o diagnóstico60 tem 88/19. São contagens do episódio inteiro, incluindo preparação, não prova de ground no instante da captura. Estes testes também não qualificam conservação em suportes dinâmicos: os colliders desta tarefa são estáticos.

Trace OFF e observer OFF são condições distintas; o audit compacto e o caminho R0 continuam presentes. Reproduzir o mismatch nos três toggles não demonstra zero efeito de toda a instrumentação. Demonstra apenas que remover esses componentes não eliminou a quebra observada a 120 Hz.

## Limitação adicional do comparador congelado

O par referência H120 / R0 headless sequence r1 é classificado `SETUP_MISMATCH` por `body.shapes[2].name`: `@CollisionShape3D@457` versus `@CollisionShape3D@889`. Uma comparação offline dos arrays de shapes retirando **apenas** `name` encontra igualdade exata dos restantes campos publicados: classe, dimensões, transform e disabled. Logo, este motivo específico é cosmético, dependente da identidade automática do processo.

Isto não apaga outros requisitos de comparação, não certifica equivalência total e não autoriza reparar o comparador depois de observar resultados. É uma barreira adicional conhecida na qualificação congelada, a relatar separadamente da falha real de estado de cursor e dos contactos materiais divergentes.

## Decisão por capacidade

| Capacidade | Classificação independente nesta entrega |
|---|---|
| Baseline protegido, relógio e teardown nos recibos revistos | Verificados no âmbito observado; não são aprovação global do avaliador |
| R0 headless120: repetição da cadeia de captura | Evidência limitada positiva nas seis execuções executadas; comparador de setup tem a limitação cosmética acima |
| R0 completo headless/rendered, ambas as frequências | **QUARANTINED**: falha de fidelidade e matriz interrompida |
| A120: captura real e retenção | **DIAGNOSTIC_ONLY** para qualificação comparativa; seis headless e seis rendered positivos não provam input idêntico nem estabilidade contínua |
| EQ3: preparação lawful de uma mão a 60 Hz | **MISSING_COVERAGE**: screens/qualificação final não executados |
| EQ4: novos fixtures simétricos e clearance | Construção, contrato e desenvolvimento **DIAGNOSTIC_ONLY**; qualificação prospetiva **MISSING_COVERAGE** |
| EQ5: métricas stop/brake/reverse/low-energy no novo domínio | **MISSING_COVERAGE**; testes puros e histórico v1.3.1 não substituem os ensaios físicos finais |
| EQ6: isolamento dos probes | **DIAGNOSTIC_ONLY**; diagnóstico limitado não qualifica equivalência de todos os modos |
| Métricas contínuas para ranking/otimização | Nenhum envelope de equivalência aprovado |
| EQ7: decisão independente | **NO_GO / EVALUATOR_NOT_READY** |

Os 13 checks puros dos fixtures e os recibos de desenvolvimento não são rebatizados como domínio físico qualificado. As 24 regressões de segurança do baseline, 884 checks, foram comunicadas pelo orquestrador como PASS e são evidência separada da matriz interrompida. A eventual demonstração MCP e a reposição final são suplementos operacionais; não corrigem retroativamente a fidelidade R0.

Mantêm-se a paragem antecipada, as falhas originais e a baseline jogável. Não há aprovação para pesquisar parâmetros, abrir holdouts, promover um candidato, mudar defaults ou iniciar M7 com base nesta qualificação.
