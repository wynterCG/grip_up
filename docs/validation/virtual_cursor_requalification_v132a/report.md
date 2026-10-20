# GRIP UP — Requalificação do cursor virtual / JSON corrigido

**Resultado: a admissão JSON passou; o input virtual resistiu à interferência observada; a equivalência estrita headless↔renderizado continua NO_GO_INPUT_REPLAY.** A primeira divergência passa agora pelo raycast e pela âncora material, com input/cursor exatos. A revisão independente e os recibos acompanham este relatório. Não foram iniciados ML/Optuna/RL nem alteradas forças, geometria ou locomoção.

## Campanha e proveniência

Nova campanha `requal_20261020_r1`, pedida explicitamente pelo utilizador após o relatório anterior; fonte congelada036a9dc, diretório novo `builds/eval_virtual_cursor/requal_20261020_r1`. As tapes120/60 são **capturas novas da fonte corrigida**. Não se reutilizou como qualificação a tape derivada diagnostic-only anterior. Os resultados e o NO_GO da campanha anterior permanecem intactos.

Orçamento: até8 processos de desenvolvimento,24 células de qualificação H/R/M/F×60/120×n3 e4 diagnósticos diretamente relacionados. Executados2 mundos de captura,7 tentativas de qualificação e4 diagnósticos:13 mundos físicos /5330 snapshots POST. O MCP normal é suplemento de segurança. Uma única instância do motor executou os testes de cada vez.

Só três ficheiros de infraestrutura existentes mudaram: runner Python, driver de teste e provider de replay; acrescentaram-se comparador/testes e wrappers. O gameplay, solver, câmara normal, materiais, recursos de tuning e Janga ficaram preservados. Mantêm-se12kg, alcance0.65708m,360N mãos partilhados,180N pés/120N por pé,20Nm assistência e150Nm resultante.

## Admissão JSON e replay sem intervenção

A antiga falha `INPUT_BUTTON_EDGE` não voltou: as11 execuções de replay leram/validaram a tape pelo parser real do Godot antes de construir o cenário; as13 execuções, contando capturas, terminaram no motor com contacto e retenção reais. Isso não equivale a aprovação de fidelidade: os validadores rejeitam os casos renderizados que divergem do referencial headless.

Headless120:3/3 replays coincidem com a captura da mesma frequência em todos os campos comparados. Headless60:3/3, igualmente sem primeira divergência. Comparam-se input efetivo, cursor, pose de câmara, raios, collider/face, sequência de âncoras materiais e campos físicos publicados (COM/pose/v/omega/massa/forças). Não significa comparação bitwise entre frequências ou de todo o estado interno de Jolt/pés.

No primeiro renderizado120 surgiu uma diferença estrita de ray/material. A matriz parou:6 passes headless,1 rejeição renderizada e17 NOT_RUN_EARLY_STOP. Os casos seguintes são os diagnósticos explicitamente pedidos, sem preencher as células paradas ou acumular uma pontuação positiva.

## Primeiro ponto de divergência

| Hz | Primeiro ray/material diferente | Norma Δ direção do raio | Distância material | Contacto renderizado | Retenção renderizada |
|---|---:|---:|---:|---:|---:|
| 120 | 282 | 1.54318774e-07 | 0.810711 µm | 440 | 527 |
| 60 | 28 | 2.9802322e-08 | 1.474537 µm | 210 | 259 |

A120, no tick282, os inputs efetivos, a validade/posição do cursor, a origem do raio, offset0, pose de câmara registada no pedido e matriz de projeção4×4 são exatos. A primeira diferença aparece no **resultado de `project_ray_normal`**, seguido do ponto material. O collider é `catch`, shape0 e face−Y em ambos. Não é o antigo desvio de viewport-center nem a troca para a face+Z. As primeiras diferenças seguintes são força440, velocidade/omega442 e COM449. O contacto continua440, origem FREE455 e primeira retenção527 em ambos.

A60, o primeiro pedido na superfície `source`, tick28, já apresenta a diferença de raio/material, igualmente com pose/matriz registadas exatas, offset0 e face−Y. Seguem-se força46, velocidade/omega48 e COM65. O renderizado captura o destino no tick210, contra215 no headless; ambos libertam a origem223 e confirmam retenção259. A diferença microscópica inicial não autoriza declarar a trajetória inteira equivalente.

Os ambientes físicos de apresentação são diferentes: headless window1024×576/final transform≈0.533333; renderizado1440×810/0.75. O viewport lógico é1920×1080 e a canvas identity em ambos. Esses dados são contexto para investigar projeção/rounding/cache/transformação efetiva; **a causa interna ainda não está provada**. Não se atribui a falha ao Jolt, ao utilizador ou a uma força escondida. Não se adicionou tolerância de pixels/contacto nem correção de ponto para fazer passar o teste.

`first_divergence.json` guarda as primeiras diferenças de cada camada, os valores do vencedor e o primeiro desvio do transform de câmara separadamente da pose física de origem. Os `layered_comparison.json` preservam uma janela limitada de contexto. Os valores de input/picking são produzidos em PRE e transportados para o audit POST; POST significa depois dos callbacks de controlo e antes da próxima integração, não post-solver.

## Interferência humana efetivamente observada

Houve8 segundos de aviso antes de existir mundo/provider. Ações durante esse aviso não contam como atividade no replay. A amostra de foco inicial tick0 também não conta como transição de foco.

1. **Primeiro humano120:** iniciou já sem foco e processou536 ticks. Não recebeu eventos nem transições duranteACTIVE. Demonstra execução em segundo plano neste caso; não demonstra um Alt+Tab durante a reprodução.
2. **Foco60:** iniciou com foco e recebeu callback de perda após o frame132. O primeiro POST sem foco é133; continuou até263, com131 POST sem foco,1 evento de teclado rejeitado e maior intervalo entre ticks34.469ms. O input efetivo/cursor mantiveram-se exatos. Não houve RUNTIME_SUSPENDED, tick perdido ou invalidação ambiental. O utilizador confirmou: **“n voltei a tempo”**. Não houve recuperação de foco antes do fim e não se afirma tê-la testado.
3. **Rato120:** registou220 eventos de movimento e2 eventos de botão rejeitados;474 posições distintas do cursor físico nos snapshots. O cursor virtual e os comandos da tape não mudaram. Maior intervalo34.728ms, sem perda de foco neste episódio. O stream detalhado é limitado a64 rejeições, mas os contadores por tipo cobrem todo o processo.

Os cliques recebidos pelo jogo e a perda de foco separada estão medidos. Não se prova independentemente que a perda de foco foi causada por um clique noutra janela em vez de Alt+Tab, nem que houve clique exterior e retorno durante o replay. Não foi usado input sintético nestes testes humanos.

## Comparação pareada para separar interferência de modo de execução

As três execuções humanas foram também comparadas com o renderizado sem intervenção **da mesma frequência e da mesma tape congelada**. Não se gerou uma nova sequência adaptativa ou âncora:

| Comparação | Input/cursor/câmara/raycast/material | Campos físicos publicados |
|---|---|---|
| Humano120, iniciado sem foco ↔ renderizado120 quieto | Exatos | Exatos |
| Foco60, perda duranteACTIVE ↔ renderizado60 quieto | Exatos | Exatos |
| Rato120 ↔ renderizado120 quieto | Exatos | Exatos |

Não aparece primeira divergência em nenhuma dessas comparações pareadas. Portanto, **nestas amostras**, o rato/cliques entregues ao jogo e a perda de foco observada não alteraram a reprodução renderizada. As rejeições estritas face à referência headless permanecem todas preservadas; não são reclassificadas como passes de qualificação.

## Sessão interrompida versus perda de foco

A perda de foco medida é uma continuação válida de ticks, não uma sessão interrompida. Todos os11 replays terminaram no motor; não se observou suspensão, pausa, alteração inesperada de viewport ou gap>250ms. O guard existente invalida esses casos como RUNTIME_SUSPENDED/ENVIRONMENT_NOT_COMPARABLE e não preenche ticks em falta. **A rejeição de uma suspensão real não foi exercitada nesta campanha**, pelo que não se certifica esse ramo por comparação com uma amostra que continuou normalmente. Também não se certifica o ciclo completo perder→recuperar foco.

## Revisão física e segurança

A revisão independente leu5330 POST:1874 estadosREACHING tinham força0. Mantêm-se12kg/profile4/sem hybrid. Picos observados: mãos254.948N, pés45.471N, assistência20.0000014Nm (arredondamento float), momento76.761Nm; |T|/N máximo≈0.4370 abaixo deμ0.85. Os limites de força e o alcance não foram aumentados. Não foi encontrado bypass de contacto/âncora/corpo.

Nesta campanha passaram24 checks Godot e18 testes Python, incluindo roundtrip JSON e comparação de cadeias materiais com IDs de processo normalizados. Os1146 checks de regressão da fase anterior são evidência anterior preservada, não uma contagem de novos testes nesta campanha.

Godot MCP Pro1.17.1 confirmou de novo o main normal no monitor0: profile2, inputLIVE, providerDISABLED, câmara virtualfalse, massa/alcance/bindings/flags iguais à base anterior;0 erros na consulta fresca. O screenshot `ordinary_main.png` foi inspecionado. O aviso inicial sobre um projeto antigo dentro de builds foi preservado. O editor iniciado por esta tarefa foi fechado e project.godot restaurado byte a byte. Nenhuma opção de teste foi persistida no jogo normal.

## Decisão e próximos limites

**NO_GO_INPUT_REPLAY** para a equivalência estrita do benchmark entre headless e renderizado. A admissão JSON está resolvida e a não-interferência está demonstrada nas amostras pareadas descritas, sem certificar todas as condições do orçamento original.

O próximo diagnóstico pertinente é observar a transformação efetiva usada pela API de projeção e as dimensões de backing viewport no instante do raio, com o mapping físico controlado, para explicar a diferença antes de qualquer ajuste. Isso é uma recomendação de investigação, não trabalho ou otimização iniciado neste relatório. Recuperação de foco, suspensão real, repetição humana n3 porHz, outros cenários/one-hand/lateral/envelopes contínuos/holdouts continuam abertos. ML/Optuna/Jev/RL permanecem OFF.

Entregáveis: `test_matrix.json`, `first_divergence.json`, `human_interference.json`, `paired_rendered_summary.json`, `verification.json`, revisões specialist e `evidence_manifest.json`. As archives incluem os recibos rejeitados, tapes novas, audits, traces e a fonte congelada. Cada membro e arquivo tem SHA256 verificado. Extraia para um diretório novo; não sobreponha os estudos anteriores.
