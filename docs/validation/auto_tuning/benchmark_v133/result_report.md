# GRIP UP v1.3.3 — relatório de qualificação

**Resultado: NO_GO_BENCHMARK.** O primeiro preflight headless120 recusou o ambiente antes de criar qualquer corpo de gameplay. A linha de comando pediu1024×576, mas `Window.size` devolveu64×64. O guard interrompeu corretamente a campanha; não houve novos ensaios de escalada, replays de referência ou métricas físicas nesta versão.

## O que foi implementado

Foi congelada uma extensão limitada do driver existente, com ambiente observado, catálogo público de seis tarefas, preparação através dos inputs/raycast reais, certificados de onset POST, comparador de canais publicados e métricas com seis estados tipados. Reutiliza provider, scheduler V0, câmara, controller e Jolt; não escreve ATTACHED nem pose/velocidade do boneco. As quatro mudanças em infraestrutura existente são hooks de catálogo/fixture/benchmark, identificação do cenário/posição no probe e teste de compatibilidade com fonte histórica congelada. Nenhum ficheiro do gameplay físico, câmara normal, input normal, tuning ou geometria original mudou.

Fonte medida: `3c888c70a0b5a8bc427e3b68058ac744ba002db6`, branch `feature/v1.3.3-benchmark-qualification`;292 fontes públicas congeladas. Motor4.7.2-stable Steam, revisão`ed1daf0bf001b61586d9930840f2f1394092c079`, Jolt integrado, SHA`12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38`. Fontes C/E coincidem. O catálogo preparado não é um benchmark qualificado.

## Admissão e primeiro bloqueio

O comando efetivamente executado encontra-se em `runs/headless_120_1_positive/manifest.json`. O processo terminou com1 e `ENVIRONMENT_NOT_COMPARABLE / BACKING_SIZE`, modo1, screen−1, posição0,0. `gameplay_bodies_created=0`. A condição falhou antes do ramo que aguarda o relógio. Não existe tick de cenário, PRE/POST físico ou primeiro desvio de raycast/âncora para este processo. O trace vazio está explicitamente marcado como não aplicável; não é um trace simulado reconstruído.

O plano previa12 preflights positivos e1 negativo sem corpos. Foram tentados1 positivo, aceite0, rejeitado1, abortado0; os outros11 positivos e o negativo ficaram NOT_RUN_EARLY_STOP. O catálogo de84 processos primários permanece visivelmente não executado:12 referências e72 tentativas de domínio, incluindo12 capturas adaptativas. Uma captura adaptativa nunca contaria como réplica fixa.

## Quatro diagnósticos permitidos

| Diagnóstico puro | Hz | Modo | Inicialização explícita | Backing inicial → final | Viewport final | Relógio observado |
|---|---:|---|---|---|---|---|
| D1 |120|headless|não|64×64 →64×64|1920×1920|2 callbacks1/120|
| D2 |120|rendered|não|1024×576 →1024×576|1920×1080|2 callbacks1/120|
| D3 |120|headless|`root.size` antes do relógio|64×64 →1024×576|1920×1080|2 callbacks1/120|
| D4 |60|headless|`root.size` antes do relógio|64×64 →1024×576|1920×1080|2 callbacks1/60|

Todos tiveram0 corpos e0 outcomes de gameplay. D1 mostra que esperar pelo relógio não corrige o backing. D2 observa screen0 e posição real2400,80, apesar do pedido80,80: posição de ecrã é evidência observada, não uma promessa do CLI. D3/D4 isolam uma possível correção de inicialização pré-mundo. Não modificaram a fonte congelada nem repetiram BQ1 e não provam igualdade física, V0 ativo ou compatibilidade de picking. Modo de janela/headless e valores de display indisponíveis não são artificialmente igualados.

## Cobertura e elegibilidade

| Domínio |60Hz H/R|120Hz H/R|Pares fixos observados|Elegibilidade|
|---|---|---|---:|---|
| Swing & Catch referência |não executado|não executado|0|NOT_RUN|
| Vertical clean |não executado|não executado|0|MISSING_COVERAGE|
| Asymmetric clean |não executado|não executado|0|MISSING_COVERAGE|
| Lateral clean left |não executado|não executado|0|MISSING_COVERAGE|
| Lateral clean right |não executado|não executado|0|MISSING_COVERAGE|
| Foot-supported step |não executado|não executado|0|excluído de ranking; n1 planeado|
| Two-hand release-stop |não executado|não executado|0|excluído de ranking; n1 planeado|

O critério GO exige, entre outros gates, vertical/assimétrico/laterais com n3 pares em cada Hz. Nem esses nem os28 pares novos e6 pares de referência foram medidos. Não há latência, eficiência, progresso, pé carregado, travagem, settle ou twist novo para preencher. As células de CSV mantêm ausência e motivo; nenhum null virou zero. Ficam também abertos counter-swing, braking/reversal, one-hand60, outros offsets,1440×810, seeds, hardware e generalização. Não se reutilizam resultados históricos como passes novos.

## Contratos de medição e revisão

Os34 testes Python novos passaram:27 métricas,4 comparador e3 admissão de tapes. Cobrem sinal do progresso, direção espelhada, onset realmente carregado e quieto, alteração de ground/hybrid/âncora, horizonte interrompido, velocidade dirigida de stop, path3D até confirmação, settle pelo início da janela quieta, força de mão pendente, caps e weakest-cell ausente. Uma velocidade útil já presente antes do onset produz `ALREADY_MOVING_BEFORE_ONSET`, latência null; não recebe crédito de resposta instantânea. Isso preserva o progresso raw como observação distinta. Estes são testes de contratos, não de performance física do catálogo.

A revisão física independente fechou cinco achados antes do freeze: identidade de domínio/tape, safety global independente do onset, recertificação do onset no replay, guard de fresh e latência herdada. O reviewer de medição escreveu os seus módulos e declara esse limite de independência; o especialista físico fez auditoria sem escrever o atuador ou executar o motor. Ambos recomendam NO_GO após ler os recibos. Os pareceres preservam aprovação estática separada de cobertura runtime inexistente.

## Preservação, regressões e release

Passaram34 processos das suites antigas a60/120Hz,1146 checks. Estão fora do teto de qualificação por confirmação expressa do utilizador. A inspeção normal headless corresponde exatamente ao snapshot anterior. Godot MCP Pro abriu o main no monitor de índice0 e confirmou profile2/LIVE, hold, provider desligado, câmara virtual desligada, probe ausente, massa12kg, alcance0.65708m, parâmetros[0.25,0.12,0.24,0.9] e bindings originais. Houve1 warning já presente de projeto aninhado antes de play e0 erros frescos depois; screenshot inspecionado. Não foi playtest humano.

O export release e o seu arranque plain headless passaram. Uma inspeção isolada com o motor debug carregou o pack exportado e confirmou10 caminhos experimentais ausentes, incluindo novos scripts/catálogo. Essa inspeção tem `release_template=false`; não é confundida com a smoke real do executável release. Identidade/bytes estão em `verification.json`. Configurações C/E foram restauradas byte a byte; editor próprio encerrado.

Foram verificados4249 ficheiros históricos versionados e749 ficheiros raw históricos sem mudanças, bem como Janga, rollback, project e export preset. Os limites360N mãos,180/120N pés,20Nm assistência e150Nm combinados não mudaram. A qualificação nova não observou nenhum desses limites em gameplay porque não criou corpos; as suites preservam apenas o seu âmbito original.

## Contabilidade e integridade

Processos físicos novos de qualificação:0/96. Primários:0 tentados,0 válidos,0 inválidos,0 abortados,84 não executados. Negativos físicos:0/8. Diagnósticos específicos:4/4 slots, todos puros e contabilizados separadamente de mundos físicos. Admissão pura:1 tentativa rejeitada. Os5 lançamentos de ambiente e todos os insucessos estão arquivados com scripts, stdout/stderr, manifest, resultado e hashes. Não houve retry oculto, tolerância nova ou realocação dos slots não usados.

Não existe comparação causal de overhead em gameplay nesta campanha: os observadores e contadores estão implementados, mas os componentes de tick, picks, POST, serialização, render e escrita ficam NOT_MEASURED nesta qualificação. O controlo ON/OFF novo não correu. Arquivos ZIP têm CRC e SHA de cada membro verificados; a versão congelada e a fonte baseline estão guardadas separadamente. Partições, canaries e quarentena de dados estão em `dataset_migration.md`.

## Próximo passo permitido

Corrigir, numa campanha explicitamente autorizada e com nova identidade, a inicialização observada do backing antes de qualquer corpo; repetir BQ1 e só depois avançar para BQ2. Nesta campanha fica congelado NO_GO_BENCHMARK. Não foi lançada pesquisa Optuna/RL/Jev, não foram consultados outcomes privados, não houve promoção de defaults e não se iniciou M7.
