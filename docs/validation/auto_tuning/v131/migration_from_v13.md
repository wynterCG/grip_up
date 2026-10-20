# Migração do avaliador v1.3 para v1.3.1

Esta revisão diagnostica o avaliador. Não altera a locomoção A0/B1 nem cria uma nova pontuação de otimização. Os scores de `stage1_r1` não são comparáveis numericamente com estas medições.

| Evidência antiga | Nova utilização / fixture | Equivalência |
|---|---|---|
| `train_tape_r2`, lateral | Histórico contaminado por caminhada; nunca usado como ganho de escalada | `CONTAMINATED_HISTORICAL` |
| `train_tape_r3`, lateral | Resultado negativo válido para a sua preparação pendular; preservado | `HISTORICAL_COUNTER_SWING_CONFOUNDED` |
| `lateral_traverse_train` | `lateral_clean_left_v1` / `lateral_clean_right_v1`: entrada com velocidade lateral e angular baixa sustentada | `NON_EQUIVALENT`: precondição e pergunta novas |
| `lateral_traverse_train` | `lateral_counter_swing_left_v1` / `lateral_counter_swing_right_v1`: velocidade inicial oposta medida | `NON_EQUIVALENT`: reversão explicitamente separada |
| `swing_catch_train`, driver original | Reprodução do commit histórico, isolado e na posição 5 da sequência de sete episódios | Mesma fonte pública verificada; contexto e modo reportados individualmente; inputs por tick antigos não foram registados |
| `swing_catch_train`, novo driver | Mesma geometria/política pública, emissão e continuação ordenadas em ticks físicos | `NON_EQUIVALENT` no contrato temporal; não substituir os resultados históricos |
| `stop_distance_m=null` | `stop_release_v1`, `brake_counter_v1`, `reverse_command_v1`, `stop_low_energy_control_v1` e variantes de uma mão | `NON_EQUIVALENT`: novas fitas e estados tipados |
| `overshoot_m` antigo | Excursão do corredor durante comando ainda mantido | Só diagnóstico histórico; não confundir com overshoot depois do pedido de paragem |
| Ausência de reversão | Estado explícito `NOT_APPLICABLE`, censura ou invalidação conforme a fita/evidência | Não converter ausência em zero |
| First Ascent e demais holdouts | Permanecem fechados durante a reparação | Sem novos resultados reservados |

Os ficheiros antigos, incluindo JSON/CSV/PNG/SQLite e falhas, estão protegidos por `baseline_manifest.json`. As definições públicas novas ficam em `features/evaluator_reliability/resources/benchmark_eval_v131.json`, com o contrato de execução em `tools/auto_tuning/configs/reliability_v131.json`. Uma alteração de preparação, limiar ou semântica depois de observar resultados exige nova revisão e novos recibos; nunca reetiquetar a experiência anterior.

O manifesto do processo é escrito antes da execução. O estado físico inicial só existe depois de criar o mundo: os seus campos reais ficam no recibo de runtime, ligado pelo SHA256 ao manifesto anterior. O hash do setup declarado não deve ser apresentado como hash de um estado físico já observado.

Os inputs automatizados são classificados como `automated_headless` ou `automated_rendered_scripted`. Observar uma demonstração no monitor não a transforma num playtest humano.

## Revisões internas do novo benchmark

| Revisão / código | Utilização | Limite |
|---|---|---|
| Catálogo 1, desenvolvimento | Identificar falhas de preparação e testar integração dos estados tipados | Stop podia começar dentro da banda de paragem; baixa energia de uma mão podia ocultar velocidade vertical |
| Catálogo 2, commit `e13a846` | Mínimo dirigido de 0,15 m/s; baixa energia pela norma completa; primeira matriz de captura | `catch_001` interrompida por delta de arranque inválido em renderizado 60 Hz; não constitui qualificação completa |
| Catálogo 3, commit `24b18d7` | Preparação com 0,25 s decorridos e verificação da baixa energia no comando aceite; relógio confirmado em mundo vazio e cleanup síncrono | Resultados próprios em `catch_002` e `lateral_stop_001`; não reprocessar ou substituir recibos de revisões anteriores |

As mudanças de relógio, fase de input, identidade do Resource e lifecycle do mundo são mudanças do avaliador. Mesmo com quatro valores de afinação iguais, os scores antigos não podem ser usados como controlo numérico para afirmar melhoria da locomoção. O novo `completed` de uma fixture de controlo significa observação válida, enquanto o `completed` dos sete episódios históricos significa objetivo cumprido.

Nos hashes de estado inicial preservam-se os campos reais. Nomes automáticos de nós e IDs de processo podem diferir sem constituir mudança física; a revisão física tem de justificar qualquer exclusão desses identificadores e continuar a comparar dimensões, transforms, propriedades e alvos materiais. Nenhuma diferença discreta de contacto pode ser apagada com uma tolerância numérica.
