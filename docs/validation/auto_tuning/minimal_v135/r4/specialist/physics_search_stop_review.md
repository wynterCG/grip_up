# R4 — revisão física independente da paragem do piloto

**Decisão do estudo: NO_GO_MINIMAL_BENCHMARK. Paragem correta; nenhuma violação física observada nos três processos executados.** O motivo global é a falha do contrato de consistência aritmética, não uma evidência de divergência Jolt. Não reinterpretar o processo inválido como candidato elegível nem retomar a pesquisa com uma tolerância posterior.

Este documento novo preserva o [signoff físico inicial](physics_signoff.json) e a [revisão de admissão](physics_review.md). A baseline passou os gates físicos que então foram auditados; isso não garantia que todo o pipeline de ranking fosse robusto para resultados de candidatos não observados. O stop posterior é evidência nova, sem reescrever os resultados anteriores.

## Identidade e contagem

- Snapshot congelado: `cbe93f29aa2f6e47e4aa3fd784bbc1055cfa36bacaa385f7e07baa2bc262d54d`.
- Commit da fonte: `7d56a6db9f467df92cd002aee8494e98ae6399ee`.
- Evidência: `builds/eval_virtual_cursor/minimal_v135_r4/optimizer/pilot_report.json` e os três attempts identificados abaixo.
- Duas propostas de sensibilidade; quatro processos/episódios reservados, **três realmente lançados**. Right da segunda proposta não foi lançado. Não há random, TPE, finalista, validação de transferência ou sessão humana deste piloto.

A revisão foi apenas leitura/análise offline. Não executei Godot, não alterei fontes, fixtures, tuning, tapes, comparação ou os recibos históricos, nem usei Git/sync. Conferi novamente os 324 hashes públicos de fonte/helpers: zero drift. O relatório do piloto mantém `global_stop=true`, shortlist vazia, holdout não acedido e promoção NONE.

## Resultados por processo

| Proposta | Processo | Resultado físico/medição | Disposição |
|---|---|---|---|
| speed 0.22, outros A0 | `vertical_pull_clean_v134_r2_120_headless_r1_0ddeb21a` | Motor completed; frozen onset não recertificado | RUN_VALID, PRECONDITION_NOT_MET; rejeitar candidato |
| speed 0.22, outros A0 | `lateral_clean_right_v134_r2_120_headless_r2_066e78ef` | Motor completed; frozen onset não recertificado | RUN_VALID, PRECONDITION_NOT_MET; rejeitar candidato |
| speed 0.28, outros A0 | `vertical_pull_clean_v134_r2_120_headless_r3_ff1cc7a7` | Motor completed, janela física completa; recomputação Python difere 1 ULP no path | RUN_INVALID; STOP global antes de Right |

Nas duas execuções speed0.22, o POST425 observado tem ambas as mãos ATTACHED, clearance CLEAR, chão sem autoridade e velocidades pequenas. Contudo, o contrato não verifica só o instante de onset: exige a janela quiet anterior completa. Os ticks394–409 ainda excedem o limite angular de 0.2 rad/s. A falta de recertificação é, portanto, compatível com a cláusula de história quiet fixa, sem ser necessário supor falha de contacto ou força. Manter progresso oficial null; não mover o onset para uma janela posterior nem preencher zero como progresso físico.

Na execução speed0.28, os 121 POST425–545 mantêm duas mesmas âncoras/pontos materiais, suporte válido, ausência de autoridade do chão/hybrid e `CLEAR_QUERIED_SEGMENT`. O deslocamento COM assinado observado é 0.21730303764343262 m. Este número é evidência física raw de uma execução que falhou o contrato de ranking: não é um ganho aprovado, não forma um par de tarefas completo e não recebe score válido.

## Auditoria dos esforços e autoridade

Reli os **1 635 POST** dos três processos, incluindo a preparação. Máximos:

| Campo | Máximo observado |
|---|---:|
| Soma de magnitudes das mãos | 247.160629272 N |
| Pés total | 61.384691238 N |
| Um pé | 31.940052375 N |
| Assistência angular | 17.590723174 N·m |
| Momento combinado | 51.854039874 N·m |
| Distância ombro/contacto com mão presa | 0.605418563 m |

Todos ficam dentro dos limites congelados. Massa12 kg e alcance0.65708 m permanecem iguais; os quatro knobs efetivos correspondem exatamente aos mapas propostos em todos os POST. Não encontrei não finitos ou invariantes runtime true.

Verifiquei 435 samples de mãos FREE e 247 REACHING com força exatamente zero. Pés não aplicam força fora dos estados SUPPORTING/SLIDING; não foi observada compressão negativa além do guarda existente. Nos contactos presos, a mão coincide com o endpoint material publicado. Força/reação das mãos soma zero nos vetores publicados. Isto não demonstra conservação angular exata de todo o modelo virtual nem cobertura de apoios móveis.

Os três resultados registam cópias instaladas pré-tick, originais intactos, ponteiro restaurado, relógio e perfil de startup preservados e source unchanged. O processo upper inválido também fez o restauro. Os booleans de fonte/restauro são concordantes com a identidade hash e os valores efetivos relidos; não são um detector universal de writes de corpo.

O limite de reporting de contacto nativo permanece uma limitação da fixture. Clearance é uma query conservadora de elegibilidade e a autoridade do chão publicada é observável; não inferir ausência de todo o impulso nativo nem uma falha Jolt a partir da query ou do path agregado.

## Consistência escalar: o que a evidência permite concluir

A fonte de maior precisão para o valor Godot é `benchmark_runtime.json`, não o `engine_result.json` serializado com menos dígitos. Valores lidos:

| Agregação do mesmo path425–545 | Valor decimal | Binary64 hexadecimal |
|---|---|---|
| Godot publicado | 0.2245515785359135 m | `3fccbe1b2b09d8a6` |
| Python3.13 do processo de auditoria | 0.22455157853591354 m | `3fccbe1b2b09d8a7` |

Diferença: `2.7755575615628914e-17 m`, exatamente um ULP nesse valor. A comparação congelada exige igualdade; por isso a rejeição `INDEPENDENT_METRIC_RECOMPUTE:path3d_onset_to_end` é a disposição correta, independentemente da pequenez do resíduo.

Li também os diagnósticos offline `diagnostics/py311.json` e `py313.json`. Ambos usam o mesmo ficheiro COM capturado; não há nova simulação. Não encontram diferença em qualquer norma de segmento. A soma ordenada por left-fold corresponde ao Godot em ambos os intérpretes; o `sum()` externo do Python3.13 produz o último bit diferente. O primeiro prefixo de acumulação divergente termina no tick439. Recalculei offline o left-fold da mesma sequência e confirmei os bits Godot. A versão do Python usada nesta leitura offline não substitui o ambiente congelado do estudo.

Esta evidência localiza a inconsistência observada na agregação aritmética de dados já capturados. Não exige uma divergência de input, raycast, contacto ou corpo para a explicar. **Não houve comparação H/R do candidato upper**: portanto não se pode elevar esta observação a prova de equivalência entre modos para esse candidato. Os valores oficiais e o RUN_INVALID mantêm-se; não apliquei quantização, epsilon ou correção ao resultado.

## Consequência

O piloto cumpriu o mecanismo de proteção: rejeitou o primeiro candidato sem onset fixo, parou globalmente na primeira falha de integridade de métrica e não lançou a tarefa seguinte nem consumiu a pesquisa restante. A0 continua a única referência elegível preservada. Não há candidato vencedor, efeito geral demonstrado, teste humano ou default autorizado.

O veredicto final NO_GO refere-se à continuação deste estudo/pipeline após a falha. Não significa que os três processos violaram física, que o motor divergiu, ou que os gates baseline previamente aprovados falharam retroativamente. Qualquer correção futura do contrato aritmético precisaria de autorização/identidade e qualificação novas; este documento não a implementa nem autoriza novos ensaios.

## Hashes da evidência principal

| Artefacto | SHA256 |
|---|---|
| `optimizer/pilot_report.json` | `067a76d85afb3141e140f3809c7d1798aef3e43ab604a51c117238c82b2a5af5` |
| upper `receipt.json` | `48b4f0a56a182c60b90c002f9be307f96bdb1ed45e432cf59c30fad62f12f42f` |
| upper `benchmark_runtime.json` | `77776d2b1dddf19d934386805a15e1a979f1e40f5e6910bd8ee9840cece9afc6` |
| upper `scenario_metrics_raw.json` | `9aa8f055b419b95a0f838fcf4a6f2b71d9d91e1b0b4db7cb34e0dd8c5b4c86e5` |
