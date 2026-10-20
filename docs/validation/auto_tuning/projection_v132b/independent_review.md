# PV6 — parecer independente final de projeção e autoridade física

Data: 2026-10-20. Revisor: especialista de física/replay. **Recomendação: GO_LIMITED_PROJECTION**, exclusivamente para as duas tapes baseline Swing & Catch desta campanha, comparadas na mesma frequência e com backing/viewport e cadeia de APIs efetivamente verificados. **Não autoriza otimização, scoring entre tamanhos diferentes ou equivalência funcional com drift.**

## O que foi verificado independentemente

Revisão offline, sem lançar Godot, alterar fontes, fazer Git, sincronizar E ou executar novos ensaios. Foram lidos `session_state.json`, os manifests/resultados/audits dos 36 processos R2, as observações de picks, os 18 pares, os relatórios derivados e os receipts de rollback/native/export. Foram recalculadas as comparações de 14 pares de projeção com o comparador congelado e dos quatro controlos com o comparador de camadas, em vez de aceitar apenas os estados do relatório agregado.

Foi feita varredura própria de todos os **14 382 POST** para estados/forças das mãos, budgets, massa/perfil, forças/estados dos pés e cadeia final de retenção. Foi também comparada a informação completa dos pés entre os pares matched/control, removendo apenas IDs de processo: não apareceram diferenças. A frequência não foi alinhada por evento nem reamostrada.

Todos os 36 manifests têm a mesma identidade de 285 fontes e commit `da7ed73d3cb9832319eda9c78ae6393a01f34f76`; os bytes atuais dessas 285 fontes correspondiam aos hashes no momento desta revisão. As tapes preservadas mantêm SHA `d09f2569cbbafb4db2d3571b806dc804622fe4efda3c6ba9d8790a51bdb2991b` (120 Hz) e `a711b9cb2792890fddd3782db0705a003fdccae4fad67fa3085f895c0a2a2e9d` (60 Hz). `project.godot` mantém `6ae2782544aa70dfb6a099260ead68de0b0bb7007093ef846bbb2dabfc6a86c9`.

## Contagem, resultados e não interferência

| Evidência | Resultado observado |
|---|---|
| R1 | Um processo rejeitado pelo argumento CLI antes do boot; preservado, sem mundo PV |
| R2 | 36 processos completados; 18 pares; nenhum hard stop |
| P2/P3 mesmo backing, ambos Hz | 12/12 pares STRICT_MATCH, três pares novos por célula |
| P1 backing histórico diferente | 2/2 pares STRICT_MISMATCH, preservados |
| Controlos do novo probe | 4/4 pares ON/OFF sem diferença em nenhuma das seis camadas publicadas |
| Repetições dentro de cada modo | 16 comparações derivadas STRICT_MATCH, não 16 processos adicionais |
| P4 pequeno→grande | Dois contrastes headless isolam backing/stretch; os dois rendered reproduzem o padrão, mas têm confound de monitor |
| Orçamento global | 37/40 processos: 1 R1 + 36 R2; zero diagnósticos pós-gate |

O controlo OFF desliga **apenas o novo projection probe**. O observador físico antigo e o audit necessário permanecem ON. A evidência suporta não interferência observada nestes quatro pares e campos, não custo zero nem ausência universal de efeito de instrumentação. O tempo do probe continua uma medida parcial por pick, não custo total do logger.

Nos pares de backing igual, coincidem os inputs aceites, cursor, observações de câmara, local/world-ray, query real, hits/material e campos físicos POST publicados. O trace de pick preserva os bits dos escalares; a física publicada usa a comparação numérica exata existente. Isso não certifica igualdade de estados privados Jolt, caches de rendering ou todo o conteúdo não publicado do motor.

## Causalidade sustentada

As referências corrigidas da fonte bruta e os SHA estão em `PV2_preliminary_causal_review.md`; as linhas anteriores obtidas pelo browser não devem ser usadas como referência dos bytes locais. Não foi usado um motor instrumentado nem substituída a projeção Godot por uma fórmula própria.

O primeiro desvio de P1 ocorre no **local-ray**, antes de aplicar a basis mundial:

| Hz | Tick | Norma Δ local-ray | Norma Δ world-ray | Distância material |
|---:|---:|---:|---:|---:|
| 120 | 282 | 1.1175870895385742e−7 | 1.543187735766767e−7 | 0.8107108180961278 µm |
| 60 | 28 | 3.725290298461914e−8 | 2.9802322387695312e−8 | 1.4745374771181323 µm |

No primeiro desvio, os inputs/pixel, transformação efetiva de câmara e matriz de projeção coincidem. O visible rect mantém 1920×1080. O backing pequeno tem 1024×576 e stretch/final diagonal `0.5333333611488342`; o grande tem 1440×810 e `0.75`. Os mesmos valores de raio/material agrupam-se por tamanho dentro de **ambos os modos**: H grande reproduz R grande; R pequeno reproduz H pequeno. Os pares matched e as repetições confirmam o padrão sem dispersão observada nas células medidas.

**Confound de ambiente identificado na agregação final:** apesar de a CLI pedir screen 0, todos os picks rendered pequenos foram efetivamente screen 0 e os grandes screen 1. Ambos reportam DPI 120/OS scale 1.0 e mode 0. Headless pequeno e grande mantêm screen −1/mode 1 e DPI/OS scale `UNAVAILABLE_PUBLIC_API`. Estes valores foram confirmados independentemente nos 64 picks. Portanto, os dois contrastes P4-rendered são **NOT_ISOLATED_BACKING_AND_SCREEN**, não experiências que alteram apenas backing. Os dois P4-headless continuam a isolar a intervenção de backing/stretch dentro desse backend. A correspondência rendered é corroborativa, não prova isolada de ausência de efeito do monitor. Esta ressalva substitui a interpretação mais forte de uma variável única em ambos os modos feita na nota preliminar PV2.

Isto sustenta um **efeito causal local da intervenção backing-size/stretch no headless**, e mostra correspondência estrita com os perfis rendered efetivamente observados. Não é necessário atribuir a primeira diferença ao Jolt. Não se provou separadamente que screen/monitor nunca importa no rendered. A operação interna exata que cria o primeiro arredondamento não foi observada: camera-coordinates e camera-rect internos permanecem indisponíveis por API. As leituras de local-ray são adjacentes à query original, não interceções dos seus temporários. A fonte fixada explica a cadeia compatível; não demonstra isoladamente qual multiplicação/divisão/normalização introduziu o bit.

O contacto a 60 Hz acompanha o tamanho: pequeno H/R no tick **215**, grande H/R no **210**, repetido em cada célula. A 120 Hz todos contactam no tick 440. Logo, «o primeiro erro é microscópico» não justifica aceitar dados contínuos de tamanhos diferentes.

## Amplificação e quarentena entre tamanhos

As trajetórias foram comparadas no mesmo intervalo físico amostrado, sem time warp ou alinhamento pelo catch. Os contrastes pequeno→grande dentro de H e R têm os mesmos extremos, embora os de R continuem a misturar backing e screen:

| Grandeza | 120 Hz | 60 Hz |
|---|---:|---:|
| Máxima separação de COM | 8.175293644592619e−7 m | 0.1719787377735813 m |
| Máxima diferença de velocidade linear | 2.636994043619805e−5 m/s | 0.899003942491536 m/s |
| Máxima diferença de velocidade angular | 1.0933732103013397e−4 rad/s | 2.1861727938092503 rad/s |
| Máxima diferença de momento combinado | 0.0013188764128331165 Nm | 30.663567303177786 Nm |
| Ticks com estados de mãos diferentes | 0 | 5 |

A 60 Hz, o primeiro desvio de força/momento aparece no tick 46, velocidades no 48 e COM no 65, a jusante do ray/material diferente no 28. A 120 Hz, momento difere no 440, velocidades no 442 e COM no 449, depois do picking diferente no 282. A ordem e os contrastes de tamanho não provam um defeito do solver; demonstram que já existiam âncoras ligeiramente diferentes a montante.

**Cross-size continuous = QUARANTINED. FUNCTIONAL_MATCH_WITH_NUMERIC_DRIFT = NOT QUALIFIED.** Não se propôs nem aceitou epsilon global de raio, âncora, timing ou COM. Mesmo os dois casos que acabam em catch real não autorizam comparar scores entre tamanhos.

## Contacto real, retenção e autoridade

Em todos os 36 casos foi confirmada a cadeia do destino: normal material DOWN, collider `catch`, alvo originalmente além de R+0.02 m, contacto ATTACHED real, carga efetiva superior a 1 N, mão de origem FREE e mesma âncora/ponto material até ao fim. Não se costuraram retenções de regrips diferentes. A cadeia foi verificada diretamente nos audits, incluindo a igualdade da âncora runtime apenas dentro de cada processo.

| Configuração | Contacto destino | Origem FREE | Primeiro tick de retenção | Tick final | Intervalo origem FREE→fim |
|---|---:|---:|---:|---:|---:|
| 120 Hz, ambos tamanhos | 440 | 455 | 527 | 536 | 0.675 s |
| 60 Hz, pequeno | 215 | 223 | 259 | 263 | 0.6666666667 s |
| 60 Hz, grande | 210 | 223 | 259 | 263 | 0.6666666667 s |

Ressalva importante: **não é uma experiência inteiramente arm-only**. Ao longo dos episódios há 4722 POST grounded e 925 POST com pés carregados. Mesmo depois de a origem ficar FREE, ainda existem dois ticks com chão/força de ground por run a 120 Hz, onze por run a 60 Hz pequeno e zero a 60 Hz grande: **157 POST** no total. Nesse intervalo após source FREE não há pés carregados. No primeiro tick de retenção confirmada e daí até ao fim, todos os casos estão sem chão e sem carga nos pés. A contribuição histórica de chão/B1 deve permanecer explícita; esta prova não isola toda a preparação como suspensão só pelos braços.

Na varredura própria:

- 5041 amostras REACHING têm força exatamente zero.
- 16309 amostras FREE/REACHING/RELEASED têm força exatamente zero; nenhuma força de mão aparece fora de ATTACHED/SLIPPING.
- Não foi observada tração normal negativa dos pés; forças de pés só aparecem em SUPPORTING/SLIDING.
- Máxima distância de braço ATTACHED publicada: 0.654083251953125 m, abaixo do alcance anatómico declarado 0.65708 m.
- Não foram encontrados estados não finitos ou falhas dos invariantes nos resultados; massa 12 kg/perfil 4 foram verificados.

| Pico observado | Valor | Limite físico existente |
|---|---:|---:|
| Mãos, soma de módulos | 254.947982788086 N | 360 N |
| Pés, soma de módulos | 45.4706535339355 N | 180 N |
| Um pé | 45.47065371889396 N | 120 N |
| Assistência | 20.00000139542438 Nm | 20 Nm, diferença de representação float de ~1.4e−6 Nm |
| Momento combinado publicado | 76.7607120562746 Nm | 150 Nm |

A razão máxima publicada |T|/N foi 0.4370198532589552, abaixo do coeficiente existente 0.85. O arredondamento no módulo da assistência não aumenta o budget configurado. Os campos de reação de mão são opostos às forças publicadas. Como estes suportes são estáticos, esta campanha não constitui uma nova prova de conservação de momento de um par dinâmico. A ausência de escritas diretas de corpo é sustentada pelo audit/freeze dos caminhos e fontes protegidas, não por uma variável de trace que magicamente detetasse todas as escritas.

## Preservação e rollback

Foram lidos os receipts de native/main e safety: profile 2, fonte LIVE, A0, massa 12 kg, 120 Hz, valores base `[0.25,0.12,0.24,0.9]`, provider desativado, câmara virtual false, probe ausente, observador/captura/physical-feet/B2 desligados. O MCP Pro apresenta zero erros novos após abrir main; isto é inspeção scripted suplementar, não playtest humano ou avaliação de feel.

Os receipts de export e smoke têm exit 0 e sem script errors. A inspeção do pack em caminho isolado usa o motor debug com `--main-pack` e confirma a exclusão dos seis caminhos experimentais listados; não deve ser descrita como inspeção de scripts pelo template release. O smoke do executável não é um playthrough completo. O hash de projeto C foi recalculado e corresponde ao original; a restauração E e a paridade C/E são registadas nos receipts do coordenador.

`verification.json` regista separadamente 34 processos/1146 checks de regressão e contratos 25 Python, 18 Godot projection e 24 Godot input. Este especialista leu os receipts/verification, mas não executou essas suites. O coordenador regista 4139 ficheiros de evidência anterior e 199 ficheiros raw preservados; essa contagem não é confundida com a varredura física independente de 14 382 POST.

## Decisão e domínio autorizado

**GO_LIMITED_PROJECTION**, com todos os limites seguintes:

1. Somente as duas tapes baseline Swing & Catch preservadas, este engine/binário/renderer e fonte congelados, configuração 4/A0/B1 e fase V0 documentada.
2. Comparação dentro da mesma frequência: 60 com 60, 120 com 120. Não há igualdade entre frequências nem autorização para misturar os seus scores.
3. Backing efetivo igual em cada par, visible rect lógico 1920×1080 e os **perfis de ambiente realmente medidos**: headless screen −1/mode 1 para ambos tamanhos; rendered Windows mode 0/DPI 120/scale 1.0, screen 0 para 1024×576 e screen 1 para 1440×810. Settings/owner/fase devem ser verificados no setup e no pick. «Pedir o mesmo tamanho/screen» sem verificar o estado real não basta. Não se generaliza o resultado para rendered 1440 no screen 0 ou 1024 no screen 1, combinações não medidas.
4. O gate mantém inputs/cursor/câmara/APIs/queries/material e POST publicados estritos. Um futuro desvio não é automaticamente tolerado por este parecer.
5. Nenhuma qualificação genérica de candidatos de tuning, novos pixels/poses, contacto perto de arestas, resize, DPI, viewports aninhados ou outras plataformas. As repetições demonstram as células medidas; não garantem todos os possíveis inputs.

Cross-size continua STRICT_MISMATCH/QUARANTINED; drift funcional não qualificado. One-hand 60 Hz, lateral, stop/brake, holdouts privados e outros benchmark domains continuam sem qualificação. Otimizadores/Random/TPE/CMA/RL/JEV permanecem OFF. Não se demonstrou melhoria de gameplay nem avaliação humana. O resultado fecha a investigação limitada de projeção com backing verificado; não reescreve nenhum NO_GO histórico.
