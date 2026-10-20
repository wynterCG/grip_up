# GRIP UP v1.3.3 R2 — relatório

**NO_GO_BENCHMARK na campanha primária; inicialização corrigida e confirmada em diagnóstico.** O utilizador autorizou repetir a v1.3.3 depois da correção headless. Criámos `benchmark_v133_r2`, com plano/source freeze próprios, mesmo catálogo e teto72+12+8+4=96. A fonte primária é`3ee5fabb6e2709d94dcc0e0663ba990bed8e75e3`; a fonte final apenas diagnóstica é`7a726febcb5257cac2cef23312c3b01d5cddb39b`. O NO_GO anterior e as tentativas de desenvolvimento da inicialização ficam intactos.

## Admissão passou; referência encontrou uma rejeição falsa

Os13 preflights novos passaram:3 processos porHz60/120 e modoH/R, mais1 negativo1440×810 corretamente recusado. Cada positivo observou backing1024×576, viewport1920×1080 e os dois callbacks1/Hz antes de criar gameplay. Nos60Hz, os recibos preservam os callbacks iniciais ainda a120 antes da confirmação; não se fingiu que o relógio já estava pronto. O headless regista a mudança pré-mundo do dummy64×64, pedida explicitamente por `--backing-size`. Renderizado apenas observa o tamanho real.

O primeiro replay H120, `swing_catch_train_120_headless_r1_658b4656`, terminou BLOCKED_SETUP/CANONICAL_BACKING. O seu JSON continha[1024,576], mas a validação nova comparava o array de floats do parser com um literal de inteiros. `backing_initialization={}`, `world_creation_record={}`, audits vazios e custoPRE/POST0 provam que parou antes de janela configurada, clock, corpo, picking ou Jolt da tarefa. Não é um desvio físico, suspensão ou falha de catch. A matriz primária parou:1 tentativa inválida de setup,0 válidas,0 abortadas,83 não executadas (11 referências+72 domínios).

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

Export release e arranque plain passaram. A inspeção isolada do pack com motor debug confirmou11 caminhos experimentais ausentes, incluindo helper novo. `release_template=false` nessa inspeção está distinguido da smoke real do executável release. Os ficheiros históricos versionados(4378) e raw(954), Janga, rollback, project/export preset foram verificados sem alterações. Fontes atuais C/E coincidem. Performance instrumentada existe em recibos por componente, mas nenhum controlo novo ON/OFF foi executado: overhead causal não é qualificado.

## Decisão e integridade

Conservadoramente,5 tentativas ocupam o orçamento96 (1 referência bloqueada+4 diagnósticos), com2 mundos físicos novos;13 preflights são puros e contam à parte. Todos os insucessos, intermediários, stderr, manifests e versões estão arquivados com CRC/SHA por membro. BQ1 passou; BQ2 primário foi rejeitado antes de simular; BQ3–BQ5 runtime não qualificados. Especialistas independentes preservam essa distinção e recomendam NO_GO primário.

Optuna/RL/Jev, outcomes privados, playtests humanos e novas promoções de defaults:0. A correção final fica disponível, mas não iniciámos R3 automaticamente. Uma nova campanha autorizada terá de voltar a medir a referência primária com a fonte corrigida, antes de expandir para os domínios.
