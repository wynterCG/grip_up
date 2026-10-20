# GRIP UP — v1.3.3 R3 Preflight and Benchmark Qualification

| Campo | Resultado |
|---|---|
| Preflight | **CERTIFIED** |
| Primary benchmark | **NO_GO_BENCHMARK** |
| Playable A0/B1 | **PRESERVED** nas verificações efetuadas |
| Preflight replay processes | **4 / 12**; três candidatos distintos |
| Primary qualification processes | **61 / 96** |
| Regression processes | **34 / 34**, separados; **1.146 checks PASS** |
| Primary reference pairs | **120 Hz 3/3; 60 Hz 3/3 — STRICT_MATCH** |
| Qualified scoring domains | **nenhum** |
| Optimization executed | **NO** |
| Human feel approved nesta campanha | **NO — não testado** |

A infraestrutura corrigida conseguiu transportar o manifesto JSON real, preparar o backing headless e reproduzir Swing & Catch em ambos os modos e frequências. Isso permitiu executar a qualificação primária. Os cenários obrigatórios, contudo, não forneceram cobertura física válida em ambas as frequências. Mais tarde, o primeiro controlo negativo revelou uma falha de contagem no validador de registos de picking e acionou a paragem definitiva da campanha. Nenhum resultado foi corrigido retroativamente para passar.

## 1. Identidade e limites desta conclusão

Fonte medida: `7a578995915d56ade2fa447f3adfdd6e19dc0218`, branch `feature/v1.3.3-r3-certification`. Snapshot certificado composto: `a6bd333c5f4fc8f8571d5c907db09f858da9429852befc20e2777f9dc9b36986`. O certificado foi emitido após PC0–PC2 e revisões independentes, antes das regressões e da matriz primária.

O snapshot composto cobre 295 ficheiros públicos e cinco helpers de execução. O campo `source_snapshot_sha256` de cada manifesto cobre apenas o mapa público de fontes; tem âmbito diferente de `source_hash` no certificado, que inclui também os cinco helpers. Esta diferença não representa alteração de fonte. Os mapas completos estão em [certified_source.json](certified_source.json), e os helpers estão preservados no arquivo de fonte medida.

Motor observado: Godot `4.7.2.stable.steam.ed1daf0bf`, Jolt, binário `C:\Users\Wynter\WrapRush\tools\godot.exe`, SHA256 `12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38`. Backing de qualificação efetivo 1024×576; viewport lógico 1920×1080; seed 101; profile 4/A0/B1, V0. O teste normal LIVE é uma verificação separada, profile 2, e pode abrir a 1440×810.

Raiz bruta: `builds/eval_virtual_cursor/benchmark_v133_r3/`. A matriz primária está em `primary/benchmark_v133_r3/`; os candidatos estão em `candidate_preflight/benchmark_v133_r3_candidate_001..003/`. Cada processo tem diretório novo, manifesto, comando, stdout/stderr e recibo. Os arquivos versionados mantêm estes caminhos relativos.

Não foram alterados controlador físico jogável, geometria, alcance, massas, forças, limites, bindings ou defaults para resgatar tarefas. Não foram executados Optuna, ML, RL, Jev ou M7; não foram consultados resultados privados de holdout.

## 2. Implementação de infraestrutura concluída

`benchmark_backing.gd` fornece uma fronteira numérica partilhada para as dimensões. Exige objeto/chave/forma corretos, números finitos, integralidade exata, limites positivos e dimensões esperadas. Aceita 1024 e 1024.0 após JSON; recusa frações, strings, bool, null, formas incorretas e valores não finitos. A canonicalização não é aplicada a pixels de mira, raios, âncoras, poses, velocidades ou forças.

O mesmo `campaign.build_manifest` gera os manifestos dos testes de transporte e da execução real. Python escreve JSON em disco, Godot lê esses bytes e chama a admissão original. O backing headless só é configurado no caminho opt-in do evaluator, antes de clock e corpos. Em modo renderizado, o driver observa o tamanho real e recusa um ambiente errado. O hook do benchmark não volta a redimensionar silenciosamente uma janela entre admissão e criação do mundo.

O comparador conserva o scalar JSON original, a representação float32 nativa de `Vector2` e os bits correspondentes. Compara exatamente os campos com a mesma semântica tipada. O diagnóstico legado de scalar64 versus `Vector2` permanece disponível em cada comparação; não é apresentado como divergência física entre H/R. Não foi introduzida tolerância para aproximar raios, materiais ou trajetórias.

Os runners verificam fontes, helpers, motor, tapes originais, clock, inputs pedidos/efetivos, phase, backing, restauração e limites físicos. A comparação ordena as diferenças por tick e camada e distingue a primeira discrepância publicada de uma eventual divergência física posterior. O publicador deste relatório é pós-processamento; não executa o motor nem participa da identidade medida.

## 3. Pré-certificação: candidatos e resultado

| Candidato | Transporte | Ambiente | Replays físicos | Decisão |
|---|---|---|---:|---|
| 001 | Um contrato negativo falhou a expectativa de reason | Não executado | 0 | NOT_CERTIFIED |
| 002 | Mesmo contrato revelou alias interno restante | Não executado | 0 | NOT_CERTIFIED |
| 003 | 41 casos JSON reais / 135 assertions PASS | 7 processos PASS | 4 | CERTIFIED após revisão |

Nos candidatos 001/002, a mutação negativa do mapa de hashes partilhava referências Python que não devia partilhar. A admissão recusou o caso, mas por um guard/reason diferente do esperado. Não houve alteração de ficheiros de gameplay nem simulação desses candidatos. A fábrica final separa tanto o registo externo como os dois mapas internos independentes. Os resultados falhados e as exceções foram preservados.

Os snapshots dos três candidatos contêm os 300 membros com os hashes registados. Para dois ficheiros das versões ainda não commitadas de 001/002, foi necessário reconstruir os bytes das alterações conhecidas; só foram aceites quando o SHA coincidia exatamente com o registo original. Os recibos dos arquivos declaram este método. Não foram reconstruídos ou inventados resultados antigos.

PC1 verificou H/R a 60/120 Hz e rejeições de backing renderizado errado, declaração headless errada e opt-in ausente. Os positivos observaram dois callbacks corretos antes de criar corpos. PC0 também verificou clock sem confirmação, viewport errado, idempotência e alteração de backing entre etapas, além de tape/source e input duplicado, ausente e fora de ordem. Os testes puros não contam como processos físicos.

| Replay PC2 | POST | Contacto real | Origem FREE | Retenção destino | Par H/R |
|---|---:|---:|---:|---:|---|
| H120 e R120, cada | 536 | 440 | 455 | 527 | STRICT_MATCH |
| H60 e R60, cada | 263 | 215 | 223 | 259 | STRICT_MATCH |

Estes quatro processos novos deram zero crédito à matriz primária. O [relatório de contratos](preflight_contract_report.md), a [matriz PC2](preflight_hz_mode_matrix.json) e os sign-offs de [física](specialist/preflight_physics_review.md) e [medição](specialist/measurement_certification_review.md) documentam a certificação limitada a essa fonte e ambiente. Os 49 contratos Python finais passaram; reexecuções de desenvolvimento não aumentam a cobertura única.

## 4. Execução primária e contas separadas

| Ledger | Executado | Limite/requisito | Resultado |
|---|---:|---:|---|
| Preflight físico | 4 | 12 | Certificado no candidato 003 |
| Referências primárias | 12 | 12 | 6 pares H/R STRICT_MATCH |
| Domínios primários, incluindo capturas | 48 | 72 | Dados válidos e falhas tipadas; cobertura insuficiente |
| Negativos físicos primários | 1 | 8 | RUN_INVALID; hard stop |
| Diagnósticos físicos pós-falha | 0 | 4 | Causa explicada offline |
| Total primário | 61 | 96 | Fechado, NO_GO |
| Regressões separadas | 34 | 34 | 1.146 checks PASS |

Os 48 processos de domínio incluem 12 capturas adaptativas e 36 replays fixos. Uma captura nunca é contada como réplica fixa. Os 24 slots de domínio omitidos foram bloqueados por precondições de onset; os sete slots negativos restantes ficaram por executar após o hard stop; os quatro diagnósticos não foram necessários. São 35 slots não usados, sem transferência entre grupos.

A alocação original de 72 foi preservada prospectivamente: quatro domínios obrigatórios × dois Hz × (uma captura + seis replays fixos) = 56; foot-step e stop × dois Hz × (uma captura + um par H/R + um probe OFF) = 16. Assim, foot-step e stop ficam explicitamente n=1/diagnóstico, mesmo se a tarefa resultar. Esta resolução da alocação consta do plano congelado antes de qualquer resultado.

Separadamente, BQ1 executou 13 processos sem corpos: três positivos por modo/frequência e um negativo de tamanho. Os três batches puros de transporte da certificação, sete ambientes PC1 e quatro verificações de compilação de desenvolvimento constam do ledger puro. O erro de chamada Python `StudyLock` sem diretório aconteceu antes de lançar o motor e foi preservado como diagnóstico de orquestração; não ocupa nem oculta um processo físico.

A [matriz completa de 96 slots](r3_primary_test_matrix.json) separa tentativa, estado runtime, estado da medição e sucesso da tarefa. [budget_ledgers.json](budget_ledgers.json) contém as três contas. Não se interpreta `RUN_VALID` como sucesso do movimento.

## 5. Swing & Catch e repetibilidade

As 12 referências primárias são processos novos, posteriores à certificação. Os três pares a 120 Hz têm 536 POST cada, e os três a 60 Hz têm 263 POST cada. Todos retêm contacto, libertação da origem, retenção da mesma âncora material e correspondência exata na cadeia publicada INPUT/PICK/CONTACT/PHYSICS/TASK.

Além dos seis pares H/R, oito comparações independentes dentro do mesmo modo verificam as três repetições: H1–H2, H1–H3, R1–R2 e R1–R3 em cada frequência. Todas deram `STRICT_MATCH`. As comparações adicionais dos grupos de domínio com n=3 também foram efetuadas separadamente pelo revisor de medição.

Os 17 pares H/R de domínio e os dois controlos de projection probe OFF do stop coincidem nos canais comparáveis. Igualdade entre modos pode reproduzir exatamente uma tarefa interrompida; não a torna elegível. Não foi exigida nem alegada identidade de ticks entre 60 e 120 Hz.

Há um único seed e ambiente. Estas observações não demonstram determinismo universal de Jolt, generalização para outra máquina, imunidade a rato/foco externos ou repetibilidade estatística de uma política adaptativa. As capturas adaptativas serviram apenas para produzir as tapes fixas declaradas.

## 6. Resultados físicos e métricas por domínio

| Domínio | 120 Hz | 60 Hz | Elegibilidade global |
|---|---|---|---|
| vertical_pull_clean | Onset 268; janela interrompida no tick 275 | Onset não certificado | EXCLUDED |
| asymmetric_pull_clean | QUIET_ONSET_NOT_REACHED | QUIET_ONSET_NOT_REACHED | EXCLUDED |
| lateral_clean_left | +0,149168 m; n=3 H/R; janela completa | Interrompido no tick 200 | EXCLUDED; célula 120 útil para diagnóstico |
| lateral_clean_right | +0,149263 m; n=3 H/R; janela completa | Interrompido no tick 200 | EXCLUDED; célula 120 útil para diagnóstico |
| foot_supported_step | QUIET_ONSET_NOT_REACHED | QUIET_ONSET_NOT_REACHED | DIAGNOSTIC_ONLY, sem onset |
| two_hand_release_stop | Stop medido; apenas n=1 | Interrompido no tick 200 | DIAGNOSTIC_ONLY |

**Vertical 120.** O onset é aceite no tick 268 e a certificação de clearance perde-se no 275, junto à aresta do SpawnPad. A consulta conservadora `OVERLAP_OR_ROTATION_BOUND` envolve FootBase, com margem aproximada de 0,766 mm. Não houve nesse tick `SWEPT_GROUND_INTERSECTION` nem `END_OVERLAP`. Ground motor/força/torque são zero; os contactos nativos permanecem desconhecidos porque o limite de reporte é zero. A geometria está muito próxima do pad e não permite declarar automaticamente falso positivo. Não há subida demonstrada antes da interrupção: progresso bruto 0, path aproximadamente 2,07×10⁻⁷ m. Progresso e latência oficiais ficam `INTERRUPTED/null`, não zero útil nem falha comprovada do solver.

**Assimétrico e foot-step.** Os critérios compostos de início válido não se completaram no prazo. `QUIET_ONSET_NOT_REACHED` não significa necessariamente apenas excesso de rotação: inclui suporte, clearance, velocidade e carga relevantes. No foot-step 120 existe carga B1 real observada; isso não satisfaz automaticamente o onset nonground exigido. As métricas dependentes do onset ficam `PRECONDITION_NOT_MET/null`.

**Laterais 120.** Esquerda e direita atingem aproximadamente 14,92 cm de progresso dirigido, com path 3D de 0,216283 e 0,216671 m e eficiência 0,689690 e 0,688892. A latência é 0,141667 s: onset 348, primeiro tick da resposta sustentada 365 e confirmação 371. O horizonte autorizado de um segundo completa-se, com n=3 de replays fixos por modo. São células úteis, mas não qualificam o domínio em ambas as frequências nem autorizam ranking após o hard stop.

**Laterais 60.** Onset 179, último tick autorizado 199; no 200, `grounded/support` passa a EQ132SpawnPad. O motivo publicado é `NATIVE_GROUND_AUTHORITY_CHANGED_TASK`. Nesse instante, força/torque de chão e `motor_authority` são zero: não se afirma que um impulso de marcha causou o progresso anterior. A entrada do estado de apoio já interrompe o contrato hanging. Progresso e eficiência ficam `INTERRUPTED/null`. A latência anterior de 0,15 s continua `MEASURED`, pois a resposta foi confirmada antes da interrupção; isto não dá sucesso à tarefa completa.

**Stop 120.** Onset 386. O path até à paragem confirmada é 0,116284 m; o início do repouso sustentado é tick 484, confirmado em 514, pelo que settling é 0,816667 s. A janela completa termina em 986. Não se deve confundir esse stop path com o path dos cinco segundos completos, 0,168328 m, nem com a deriva dirigida final, 0,003122 m. O stop 60 inicia em 199 e é interrompido em 200: distância e settling ficam `INTERRUPTED/null`, nunca 0 m/0 s.

Todos os valores tipados, razões, onset/end, unidade, proveniência, tape e fonte estão em [r3_metrics.csv](r3_metrics.csv). As capturas são identificadas como tal. Os 48 processos de domínio dividem-se em 18 observações MEASURED, 25 INTERRUPTED e cinco PRECONDITION_NOT_MET; estas contagens incluem capturas e controlos, não representam 48 tarefas independentes aprovadas.

## 7. Primeiro hard stop: controlo negativo N1

Run: `swing_catch_train_120_headless_r1_e0310d17`. Fonte e ambiente certificados; tape negativa derivada, registada e marcada `diagnostic_only`. Só os quatro primeiros frames alteram validade/posição de mira e edges da mão esquerda. As tapes originais permanecem intactas; esta derivação nunca é um baseline positivo.

O motor completou 536 POST e os nove checks internos negativos deram PASS. Cleanup desarmou provider, grips, router e câmara virtual. O catch posterior teve contacto 440, origem FREE 455 e retenção 527. Ainda assim, o recibo integral é **RUN_INVALID / MISSING_REAL_PICK_RECORDS**, porque falhou um guard do runner congelado.

A primeira discrepância semântica é no tick 1: `target.picks` contém `{hand:0, reason:INVALID_AIM_NO_NEW_TARGET}`, uma entrada lógica que declara ausência de query. O validador soma indiscriminadamente quatro entradas lógicas e espera quatro registos de raycast. O sidecar contém corretamente três chamadas reais: tick 3, mira válida no canto e sete raios MISS; tick 55, origem; tick 282, destino. A diferença é de contagem/semântica de instrumentação, não prova de um raycast perdido, âncora trocada ou desvio físico H/R.

Os especialistas verificaram a causa offline. A fonte não foi reparada e o recibo não foi promovido. Os cinco processos de controlo físico seguintes registados ficaram `NOT_RUN_EARLY_STOP`; existem sete slots negativos não usados no teto de oito. Não foram gastos diagnósticos físicos. [first_divergence.json](first_divergence.json) separa esta falha pós-run de uma divergência de física, que não foi demonstrada.

As rejeições puras de backing, tape/source e sequência existem nos contratos PC0/PC1 e BQ1, com o seu âmbito declarado. Não substituem os controlos físicos restantes. A campanha não completou um novo negativo físico de contacto nativo inválido, abort held a ambos Hz, nem uma medição humana de interferência/Alt+Tab. [negative_controls.json](negative_controls.json) mantém essas lacunas.

## 8. Segurança, instrumentação e preservação

A revisão física auditou 26.111 POST das referências/domínios, mais o negativo N1. Não encontrou violações nos canais verificados de massa, alcance, força FREE/REACHING, clock/phase, finitude de vetores, invariantes declarados ou restauração. Picos observados nas referências/domínios: mãos 254,948 N, pés 71,228 N, assistência 20,0000014 Nm e momento combinado 76,760712 Nm. O pequeno arredondamento float da assistência segue a convenção publicada de 0,001; nenhum limite foi ampliado. Isto não equivale a cobertura de todos os contactos dinâmicos possíveis.

Os 34 processos de regressão são novos e posteriores à certificação: 24/884 checks nas suites físicas, intenção, ground, First Ascent, mantle, recovery e pés; 10/262 nas suites de input/LIVE. [regression_index.json](regression_index.json) indexa todos os resultados.

O arranque headless normal reproduziu exatamente o snapshot baseline. Godot MCP Pro 1.17.1 abriu o projeto canónico no monitor 0 e verificou profile2, input LIVE, replay/provider desligado, câmara virtual false, valores A0 e bindings originais. A primeira consulta suplementar tentou ler `app.projection_probe`, propriedade inexistente; esse erro e os logs foram preservados. Uma nova inspeção corrigiu apenas a consulta, obteve o snapshot completo e zero erros frescos. A única advertência inicial recorrente era um `project.godot` antigo numa pasta de builds. Screenshot final inspecionado visualmente; não houve avaliação humana de feel.

Ambos os editores iniciados para inspeção foram fechados; `project.godot` foi restaurado byte a byte em C e E. O export release Windows e o startup smoke passaram. A inspeção do pack num diretório isolado confirmou os 11 paths de evaluator ausentes e defaults profile2/replay OFF. Esta inspeção usa o motor de ferramentas debug; o seu `release_template=false` não contradiz a identidade release do executável exportado. O executável novo fica localmente preservado por path, tamanho e SHA; o rollback anterior não foi substituído.

Foram novamente verificados os hashes de 4.493 ficheiros históricos versionados e 1.104 ficheiros brutos históricos, além de project/export presets, grabber Janga e rollback. A fonte medida e helpers têm paridade C/E após restauração. Os relatórios e dados R1/R2 não foram reescritos.

Os contadores locais de probe permanecem nos recibos: somam 56.614 µs/38 queries em H120 e 39.988 µs/26 em R120; 46.636 µs/32 em H60 e 29.330 µs/20 em R60, excluindo o negativo. Estes totais cobrem tarefas e durações diferentes. Os pares n=1 probe OFF do stop mantêm recorder/audit; não medem o custo total do observador nem autorizam causalidade sobre determinismo. Os novos controlos OFF de Swing & Catch ficaram bloqueados pelo hard stop. Não se publica uma alegação de performance ON/OFF qualificada.

## 9. Decisão e continuidade permitida

**PREFLIGHT_CERTIFIED permanece válido para a fonte e ambiente registados. NO_GO_BENCHMARK é a decisão primária.** Faltam vertical, assimétrico e laterais utilizáveis nas duas frequências, além de existir o hard stop de instrumentação do negativo. Nenhum domínio é promovido para scoring ou treino. A repetibilidade útil das laterais 120 e as referências Swing & Catch ficam preservadas como evidência limitada.

Não faz sentido propor já um piloto de afinação automática com este benchmark. Antes disso, um novo esforço autorizado teria de corrigir a semântica de contagem de queries, rever a preparação/clearance dos fixtures sem alterar o jogo para melhorar scores, certificar a nova fonte e executar uma nova campanha delimitada. Os contactos nativos não observáveis devem continuar marcados UNKNOWN até existir instrumentação adequada. A presente R3 não será retomada nem preenchida com resultados de uma revisão futura.

[domain_eligibility.json](domain_eligibility.json) contém a decisão por célula. [dataset_partitions.json](dataset_partitions.json) congela referências, capturas, replays fixos e negativos em partições distintas; o conjunto elegível de treino é vazio. Human playtest e aprovação do designer permanecem independentes desta conclusão técnica.

## 10. Entregáveis e auditoria

- [Certificação e contratos](preflight_contract_report.md), [matriz PC2](preflight_hz_mode_matrix.json), [certificado](certified_source.json).
- [Matriz primária completa](r3_primary_test_matrix.json), [métricas tipadas CSV](r3_metrics.csv), [elegibilidade](domain_eligibility.json).
- [Comparações H/R e dentro do modo](replay_comparison.json), [primeira falha](first_divergence.json), [negativos](negative_controls.json).
- [Três ledgers](budget_ledgers.json), [regressões](regression_index.json), [verificação de fontes, LIVE e export](verification.json).
- [Revisão física primária](specialist/primary_physics_review.md), [revisão de medição primária](specialist/primary_measurement_review.md).
- [Manifesto de arquivos](archive_manifest.json): candidatos falhados, fonte exata, manifestos, logs, traces, comparações e safety em ZIPs limitados, com CRC e SHA de cada membro verificados após leitura.
- [Baseline imutável](baseline_manifest.json) e [plano congelado](run_plan.json). O relatório R2 permanece em [benchmark_v133_r2](../benchmark_v133_r2/), com a sua decisão histórica independente; a campanha original está em [benchmark_v133](../benchmark_v133/).

Os arquivos incluem dados brutos completos; não se inventa uma janela PRE/POST de divergência física para uma falha que só ocorreu na contagem pós-run. O código publicador pode regenerar tabelas a partir destes dados sem lançar Godot. Os recibos originais conservam a identidade medida; o commit de publicação posterior não substitui essa identidade.
