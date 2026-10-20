# GRIP UP — projeção e viewport v1.3.2b

**Recomendação: GO_LIMITED_PROJECTION apenas para os dois replays Swing & Catch, na mesma frequência e com backing window igual verificado.** Os tamanhos históricos diferentes continuam STRICT_MISMATCH. Nenhuma tolerância ou correção de gameplay foi introduzida. Otimizadores, scoring e outros domínios permanecem bloqueados.

Foram executados 36 processos reais em R2, fonte `da7ed73d3cb9832319eda9c78ae6393a01f34f76`, mais uma tentativa R1 rejeitada pela sintaxe CLI antes de arrancar o motor. R1 está encerrada e arquivada; R2 tem plano e revisão próprios. Total37/40 do limite global, sem diagnósticos físicos pós-falha. Uma instância física de cada vez. Seeds101; tapes originais036 preservadas,536 ticks a120Hz/263 a60Hz, sem recaptura ou alteração de comandos.

## Efeito medido

| Hz | Primeiro desvio local/world/query/material, tick | Norma do desvio local | Norma do desvio mundial | Separação material µm |
|---|---:|---:|---:|---:|
| 120 | 282 | 1.11758708954e-07 | 1.54318773577e-07 | 0.810710818 |
| 60 | 28 | 3.72529029846e-08 | 2.98023223877e-08 | 1.47453748 |

Em P1, cursor, pose global e efetiva da câmara e projeção coincidem no primeiro desvio. O raio **local** já difere, antes de aplicar a base mundial. A consulta recebeu exatamente o vetor registado; o hit e o ponto material provêm da única consulta original. As leituras auxiliares adjacentes devolvem o mesmo world-normal. Não são uma captura dos temporários internos dessa chamada anterior.

P2:1024×576 em ambos modos. P3:1440×810 em ambos modos. Cada tamanho/frequência tem três pares em processos novos,12 pares correspondentes no total. Todos coincidem exatamente nos inputs/cursor, nas observações de câmara, raios locais/mundiais, queries/hits/âncoras e nos campos físicos POST publicados. Dezasseis comparações derivadas dentro de cada modo entre repetições também coincidem; não são16 ensaios adicionais.

P4 deriva small→large de P2/P3 dentro de cada modo. A mesma divergência reaparece no mesmo tick/magnitude em headless e renderizado. A comparação headless mantém screen−1/mode1; a renderizada muda screen0→1 e fica NOT_ISOLATED para atribuição causal isolada. A comparação headless mantém screen−1/mode1; a renderizada muda screen0→1 e fica NOT_ISOLATED para atribuição causal isolada. A60Hz, o contacto destino é215 no backing pequeno e210 no grande em ambos modos. A120Hz, é440 em ambos tamanhos. Retenção destino ocorre259 a60Hz e527 a120Hz. As três repetições de cada célula repetem esses valores, sem dispersão observada.

A intervenção dentro de headless identifica um efeito causal do conjunto backing-size/stretch numérico neste ambiente e nestas duas tapes. A comparação renderizada é consistente com esse efeito mas tem o monitor como fator associado. Alterar o tamanho headless reproduz o renderizado grande; alterar o renderizado para pequeno reproduz o headless pequeno. Não é evidência de defeito Jolt. A operação interna exata que introduz arredondamento continua por observar; não foi compilado nem substituído o motor.

## Comparações estritas

| Par | Resultado |
|---|---|
| P1_120_r1 | STRICT_MISMATCH |
| P2_120_r1 | STRICT_MATCH |
| P3_120_r1 | STRICT_MATCH |
| P1_60_r1 | STRICT_MISMATCH |
| P2_60_r1 | STRICT_MATCH |
| P3_60_r1 | STRICT_MATCH |
| P2_120_r2 | STRICT_MATCH |
| P2_120_r3 | STRICT_MATCH |
| P3_120_r2 | STRICT_MATCH |
| P3_120_r3 | STRICT_MATCH |
| P2_60_r2 | STRICT_MATCH |
| P2_60_r3 | STRICT_MATCH |
| P3_60_r2 | STRICT_MATCH |
| P3_60_r3 | STRICT_MATCH |

## Janela, fonte e limitações

Todos os tamanhos pedidos foram confirmados antes do mundo e em cada pick. Viewport lógico1920×1080, canvas/global canvas identidade, FOV56, near≈.08, keep-aspect1, content_scale_mode1/aspect4/factor1/stretch0. Backing pequeno tem stretch/final≈.5333333611488342; grande .75. `observations/runs.json` conserva configurações reais, renderer, fonte/engine/tape e resultados de CADA execução. Headless mantém displayserverheadless/mode1/screen−1; renderizado Windows/mode0:1024×576 em screen0(10execuções),1440×810 em screen1(8execuções), ambos DPI120 e OSscale1.0, apesar de --screen0 pedido. CLI também usava --position80,80. Headless pequeno12execuções e grande6 permanecem screen−1. Estes modos não são visualmente equivalentes; a comparação é do picking e dos campos físicos declarados. A escala e as dimensões variam juntas; na ablação renderizada também varia o índice de monitor. A aritmética interna específica não foi isolada como variável adicional. O GO limitado aplica-se apenas aos perfis efetivos observados, sem equivalência geral entre monitores.

Fonte C++ da revisão exata do binário: [camera_3d.cpp](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/scene/3d/camera_3d.cpp#L406) encadeia local→base efetiva→normalização. [viewport.cpp](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/scene/main/viewport.cpp#L3705) transforma o pixel por stretch×global-canvas e utiliza size. Estes helpers não são APIs públicas; os campos internos estão UNAVAILABLE_PUBLIC_API. As linhas antigas do branch4.7 não são a identidade do binário; os downloads e SHA exatos estão arquivados. Não foi usada projeção artesanal para selecionar um alvo.

Os quatro controlos SAME-mode/Hz a1024×576 variam só a nova sonda; o observador físico antigo mantém-se ligado. ON/OFF coincidem em todos os campos publicados. probe_usec mede begin→end por pick, incluindo seleção/sidecar, mas exclui escrita final e restantes loggers. É uma medição parcial, não uma garantia de latência nula.

## Física, segurança e comparabilidade

Todas as36 execuções terminaram com contacto material real e retenção, sem violação do monitor original. Foram observados 14382 POST e 16309 estados FREE/REACHING/RELEASED sem força. Mass12kg, reach.65708m, recursos originais e A0/B1 mantidos. Máximos observados em campaign_summary.json; limites não aumentados. B1 e contribuições normais dos pés/chão não foram removidos nem ocultados.

As séries completas são comparadas em ticks/intervalos temporais iguais, sem alinhar pelo evento de contacto. ray_pipeline_diff.json apresenta primeiras diferenças, máximos/RMS COM/velocidades/forças/momento e ticks com estados diferentes. Os pares históricos diferentes mantêm dados contínuos QUARANTINED; contacto/retensão final comuns não recebem FUNCTIONAL_MATCH_WITH_NUMERIC_DRIFT. Não se definiu envelope geométrico ou contínuo usando a falha que se pretendia aprovar.

A política limitada é **igualdade estrita sob backing igual**, não uma tolerância numérica. Não há ensaio de outros pontos perto de bordas, outras tapes, hardware, plataformas, FPS render ou cenas. Não há qualificação geral de determinismo Jolt nem de todos os sete offsets: a ordem original permanece, mas os picks destas tapes vencem no offset0, duas queries reais por replay. Novas superfícies/condições exigem nova qualificação.

As regressões frescas incluem24 processos físicos/locomoção(884checks) e10 de inputLIVE(262checks),1146 no total. Contratos24GDinput+18GDprojeção+25Python; os ensaios negativos físicos antigos N1–N4 não foram reexecutados como células desta matriz. A revisão nativa MCP e o export/smoke têm recibos separados e não são playtest humano nem confirmação de feel.

## Amplificação e apoio transitório — leitura independente

A120Hz, P1 atinge separação máxima COM8.1752936446e-7m e delta máximo de força direita.00366136595N. A60Hz, o COM diverge até.171978737774m(tick263), velocidade linear.8990039425m/s e força esquerda127.530879931N(tick181); existem5ticks com estados de mão diferentes. Não se aprovou um envelope que absorva estes efeitos.

Depois de sourceFREE e antes de terminar a retenção, o chão nativo contribui transitoriamente:2POST por execução120Hz,11 por execução60Hz/pequena e0 a60Hz/grande,157POST no conjunto. Não há pés carregados nesse intervalo. No primeiro instante que satisfaz retenção e daí até ao fim, grounded é false e os pés não aplicam força em todas as36 execuções. Portanto a sequência inteira não é declarada arm-only; esta assistência normal B1 fica publicada e não foi criada pela sonda.

O máximo de assistência medido é20.0000013954Nm. O monitor original inalterado usa limites de relatório20.001/150.001Nm e360.001/180.001/120.001N (optimization_trial_driver.gd152/172); isto cobre representação float32, sem aumento de budgets nem tolerância de raios/contactos. Máximos mãos254.947982788N, pés45.470653534N, momento combinado76.7607120563Nm.
