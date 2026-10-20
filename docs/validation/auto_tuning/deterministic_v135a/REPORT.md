# GRIP UP v1.3.5a — redução determinística e recertificação

**Decisão final: `BASELINE_NO_GO`. Mantém-se A0.**

O contrato aritmético foi corrigido e certificado. O preflight passou,
incluindo a avaliação completa de A0, persistência em SQLite e readback.
A nova baseline foi interrompida no segundo processo: o replay renderizado
a 120 Hz excedeu o guarda existente de intervalo entre ticks e ficou
incompleto, antes de adquirir qualquer pega. A pesquisa não começou.

Esta é uma conclusão de qualificação da ferramenta. Não demonstra uma
regressão da física, uma melhoria de feel, nem que o auto-tuning não possa
funcionar. Os resultados históricos R4 permanecem fechados e inalterados.
As verificações de segurança do jogo passaram separadamente.

| Âmbito | Resultado efetivamente observado |
|---|---|
| Contrato binary64 | CERTIFIED_METRIC_CONTRACT |
| Preflight físico | 6/6 RUN_VALID; A0_END_TO_END_PASS |
| Baseline nova | 2/24 processos executados; 1 válido, 1 inválido; 22 não executados |
| Comparações exigidas na baseline | 0/12 pares H/R; 0/16 comparações dentro do modo |
| Novos negativos/canários | NOT_RUN_EARLY_STOP |
| Contrato de qualidade novo | Não congelado: baseline insuficiente |
| Pesquisa / propostas / processos de candidatos | Não iniciada / 0 / 0 |
| Finalistas / holdouts / sessões humanas | 0 / não abertos / 0 |
| Regressões do jogo | 34/34 processos; 1.146 verificações passaram |
| Arranque, MCP Pro e export | Passaram no âmbito descrito abaixo |
| Alteração de parâmetros predefinidos | Nenhuma |

Os recibos computáveis principais são [final_decision.json](final_decision.json),
[mb2_gate.json](mb2_gate.json), [source_identity.json](source_identity.json)
e [final_protection_audit.json](final_protection_audit.json).

## 1. Identidade congelada e recuperação

| Identificador | Valor |
|---|---|
| Campanha | `minimal_v135a_r1` |
| Branch | `feature/v1.3.5a-deterministic-metrics` |
| Commit medido | `fccd68b47696f78f8eee6b3cb3291dc8375f2259` |
| Snapshot de fontes e helpers | `f81b0b58f966b99ff79415edf856d6c2439c5826ccb9127cdf69246c9f8dd270` |
| Fontes / helpers vinculados | 320 / 9 |
| Tag de recuperação anterior à alteração | `baseline/pre-v1.3.5a-deterministic-metrics` |
| Commit dessa tag | `20ab3431fd76c9518ceeeb907d1f191cf798d40d` |
| Motor | Godot `4.7.2.stable.steam.ed1daf0bf`, Jolt integrado |
| SHA256 do motor | `12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38` |
| Python da campanha | `C:\Users\Wynter\grip_up\tools\auto_tuning\.venv\Scripts\python.exe`, 3.13.13 |
| Dependências principais | Optuna 5.0.0; Matplotlib 3.10.8; lock existente preservado |
| Fingerprint do ambiente | `93880dfde2cb42fd3ab0fcd6b96b964d3dcc237b37d25f9e01e2f86976cb82f5` |
| Contrato do reducer | `ordered_binary64_sequential_v1` |
| SHA256 do reducer | `8264957f3acc818256055f61f6c94aa28d4fc85490713e430982948e730f7342` |

O fingerprint inclui os executáveis da venv e do CPython subjacente, hashes,
versão completa, pacotes instalados, lock, locale, plataforma, arquitetura,
formato float, SQLite e implementação do reducer. Os manifests reais
vinculam essa identidade; uma mudança de ambiente ou fonte recusa a retoma.
Python 3.11.15 foi usado apenas como comparação offline adicional.

Antes de editar, a árvore canónica estava limpa. Criaram-se branch e tag e
registaram-se os bytes originais em [baseline_audit.json](baseline_audit.json).
O projeto canónico continua em `E:\Godot Games\grip_up`; execução e raw em
`C:\Users\Wynter\grip_up`. Não se afirma que o novo commit seja a fonte R4.

O plano [run_plan.json](run_plan.json) foi registado antes dos resultados.
As tapes de treino R4 foram copiadas byte a byte, com hash da fonte de captura
e delta explícito para a fonte nova. Não foram recapturadas ou reescritas.
Catálogos, geometria, relógios, limites físicos e fórmula Godot mantiveram-se.

## 2. Correção aritmética e evidência exata

A implementação partilhada está em `tools/auto_tuning/metric_binary64.py`.
O [contrato detalhado](METRIC_CONTRACT.md) inventaria todos os consumidores
de ranking, hard gates e comparação atualmente usados. Normas e produtos
escalares também têm ordem explícita; a correção não se limita ao último
`sum()` do percurso.

A fonte Godot continua a calcular diferenças double dos componentes COM
Vector3 nativos, `sqrt(((dx*dx)+(dy*dy))+(dz*dz))`, e a adicionar os segmentos
em ordem crescente a um acumulador double inicializado a +0. Não se mudou
essa fórmula. O produto escalar conserva a expressão de três termos, sem
um zero inicial extra. Impulsos e distâncias de paragem conservam as suas
recorrências e endpoints próprios. Inteiros/bools de contagens continuam
contagens, não reduções float.

O golden vem do raw autêntico do ensaio R4
`vertical_pull_clean_v134_r2_120_headless_r3_ff1cc7a7`, e não de decimais
copiados do relatório. Contém os 121 COM dos ticks 425–545, os 120 segmentos,
bits, `float.hex()`, ordem, fase e proveniência. O stream little-endian original
mantém o hash:

`2ef81c7306f293e5d7e22a7d9ad72c30997b9959920dca024e759ba20e8ca104`.

| Cálculo sobre os mesmos 120 segmentos | Valor / bits |
|---|---|
| Godot publicado | 0.2245515785359135; `3fccbe1b2b09d8a6` |
| Redução explícita Python 3.11 e 3.13 | Mesmo resultado, todos os 64 bits iguais |
| `sum()` legado Python 3.11 | `0x1.cbe1b2b09d8a6p-3` |
| `sum()` legado Python 3.13 | `0x1.cbe1b2b09d8a7p-3` |
| Diferença histórica | 2.7755575615628914e-17 m, um ULP |

A primeira diferença de prefixo offline termina em 439. Não é o primeiro
tick de divergência física ou entre modos. Os segmentos individuais eram
iguais; o agregado legado era diferente. A nova redução foi também aplicada
offline a 38 raw históricos aplicáveis: todos conferiram exatamente, incluindo
os casos sem onset e parciais. Essa reauditoria não altera a decisão R4.

Os testes finais preservados em [offline_r2](offline_r2/receipt.json) passaram:

- 8 testes focados do contrato em cada um dos dois Python instalados;
- 50 testes de benchmark/comparação/admissão;
- 95 testes de tooling, incluindo a integração nova;
- 39 testes existentes do minimal benchmark.

São contagens de suites com sobreposição; não representam amostras físicas
independentes. Os casos incluem JSON aninhado real, idempotência, cancelamento,
ordem, dinâmica de magnitudes, sinais de zero, overflow, alteração de um bit,
ticks repetidos/em falta, fase PRE misturada, unidades erradas, schema/reducer
desconhecidos, fonte/proveniência alterada e parcial apresentado como zero.
O contrato de paragem de cinco segundos é exercitado a 60 e 120 Hz.

As tentativas de desenvolvimento foram preservadas em `offline/`: um teste
antigo revelou um processo filho do redirector Windows da venv que conservava
um log aberto após timeout. A terminação passou a reaproveitar a árvore owned
e a executar sempre o fallback kill/wait, falhando explicitamente se o cleanup
não for certificado. Outra execução apanhou dois testes de integração durante
a atualização do scheduler. As suites finais passaram; não se ocultaram essas
falhas, nem se criaram mundos físicos de desenvolvimento.

## 3. Preflight real, relógios e SQLite

A admissão Python→JSON→Godot passou 135 checks usando os manifests reais.
Seis processos adicionais sem corpos verificaram backing/viewport/clock em
headless e renderizado a 60/120 Hz, incluindo dois ambientes negativos.
O backing efetivo foi 1024×576, viewport lógico 1920×1080, com dois ticks
corretos antes da construção do mundo. A resolução não foi corrigida após
iniciar corpos.

Depois executaram-se seis processos físicos novos: Catch protegido a cada
frequência e as quatro células A0 de treino, todos headless. Todos RUN_VALID,
com restauro de Resource/pointers, limpeza do provider e limites verificados.
Catch teve aquisição e retenção reais: 120 Hz contacto 440 / mão de origem
livre 455 / retenção 527; 60 Hz contacto 215 / mão de origem livre 223 /
retenção 259. Estes contactos não são recompensas do
otimizador.

As quatro medições A0 do **preflight**, que não substituem a baseline, foram:

| Domínio / Hz | Progresso assinado (m) | Percurso 3D (m) | Eficiência | Latência (s) |
|---|---:|---:|---:|---|
| Vertical 120 | 0.20630919933319092 | 0.2136800913483687 | 0.9655050128036458 | 0.09166666666666666 |
| Right 120 | 0.1453312337398529 | 0.14608498335184178 | 0.9948403347510847 | null: ALREADY_MOVING_BEFORE_ONSET |
| Vertical 60 | 0.20952165126800537 | 0.21443387475428338 | 0.9770921292547324 | 0.08333333333333333 |
| Right 60 | 0.1435103751718998 | 0.1444232995560727 | 0.9936788289217943 | null: ALREADY_MOVING_BEFORE_ONSET |

Progresso e percurso publicados/recalculados conferem bit a bit nas quatro
células. As janelas foram 425–545 e 236–296, respetivamente. Twist sem frame
válido continua NOT_APPLICABLE, sem zero inventado. As sidecars derivadas
`metric_binary64_segments.json` conservam todos os valores/bits dos segmentos,
com hashes iguais aos recibos produzidos durante cada ensaio.

O dry-run A0 percorreu Godot → auditor → quatro células → score → SQLite →
readback → relatório → cleanup. Há exatamente um trial COMPLETE na base
`dry_run/study.sqlite3`, identificado como **A0_PIPELINE_ONLY**. Não é uma
proposta de otimização, um finalista ou uma aprovação da baseline. Os PRAGMA
reais e o hash da base foram registados. O estudo R4 foi aberto apenas em
modo read-only para capturar as suas propriedades; os dois FAIL históricos
e a base anterior permanecem inalterados.

## 4. Baseline nova: falha obrigatória e primeiro limite observado

O desenho exigia três pares H/R por domínio e frequência: 24 processos.

| Domínio / Hz | Headless: executados / previstos | Renderizado: executados / previstos |
|---|---|---|
| Vertical 120 | 1/3, RUN_VALID | 1/3, RUN_INVALID |
| Right 120 | 0/3, NOT_RUN | 0/3, NOT_RUN |
| Vertical 60 | 0/3, NOT_RUN | 0/3, NOT_RUN |
| Right 60 | 0/3, NOT_RUN | 0/3, NOT_RUN |

O headless válido foi `vertical_pull_clean_v134_r2_120_headless_r1_edaa4afc`.
O inválido foi
`vertical_pull_clean_v134_r2_120_rendered_scripted_r2_deb07f25`.

No segundo processo, o relógio pré-mundo tinha confirmado 120 Hz e a projeção
canónica estava preparada. Durante o replay ocorreu um intervalo wall-clock
de **257.360 µs**, acima dos **250.000 µs** do guarda original em
`virtual_cursor_driver.gd`. O scenario registou
`RUNTIME_SUSPENDED:TICK_GAP`; o provider passou ACTIVE→INVALID. A posterior
validação do stream incompleto produziu o motivo de topo
`PICK_CONTRACT_FAILURE:INCOMPLETE_PICK_STREAM`.

Há 11 observações POST e 10 frames de input. No tick 11 o novo frame não foi
instalado; os campos efetivos conservam sequência/tick 10. A análise independente
do prefixo disponível encontrou a primeira desigualdade de INPUT e câmara/PICK
no tick 11. Não encontrou desigualdade de CONTACT ou PHYSICS nos 11 POST
disponíveis, nem um desvio físico posterior observável. O comparador completo
recusa corretamente `INVALID_SCHEMA:MISSING_TICK`.

Os zero registos de picking correspondem a uma interrupção anterior à aquisição:
as mãos ainda estavam FREE, sem picks ou âncora material adquirida. Não há
raycast/material-anchor divergente para atribuir a esta tentativa, nem onset,
janela completa ou valor de métrica auditável. O receipt de cleanup virtual
ficou vazio; não se converteu isso num PASS. O restauro dos Resources foi
registado como verdadeiro e os oito invariantes publicados não dispararam.
O processo terminou; o ensaio não foi reaproveitado.

Não houve evento de perda de foco registado nem hardware rejeitado nesta
tentativa. Isso não identifica a causa do atraso: não se demonstrou se foi
shader, carga do sistema ou outra origem. Não se aumentou o limite temporal.

Uma comparação suplementar do preflight H120 com o primeiro H120 da baseline
é STRICT_MATCH. É evidência de repetição nesse modo, não um dos 12 pares H/R
ou das 16 comparações exigidas dentro da baseline nova.

Aplicou-se a condição de paragem no primeiro baseline inválido. Os 22 processos
restantes, oito negativos/canários, quality freeze e pesquisa não foram
executados. Os resultados válidos R4 não foram usados para preencher essas
células.

## 5. Segurança física e pareceres

O corpo continua único, com 12 kg e alcance 0.65708 m. Preservaram-se 360 N
partilhados pelas mãos, 180 N nos pés/120 N por pé, assistência 20 Nm,
momento combinado 150 Nm, mola 6000 N/m e amortecimento 220 Ns/m. Os picos
observados no preflight ficaram dentro dos monitores existentes; não se
alterou qualquer cap ou tolerância de auditoria. Não houve força em mão
FREE/REACHING observada nessa amostra.

Os novos canários N1, Asym60, Left60 e de degradação estão NOT_RUN_EARLY_STOP.
As interrupções históricas dessas fixtures não se tornaram sucessos. Os
contratos JSON/sidecars offline e o restauro do preflight são evidência
separada dessa cobertura física não executada.

A revisão de medição está em
[finalmeasurement_baseline_stop_review.md](specialist/finalmeasurement_baseline_stop_review.md),
com valores exatos e primeira diferença no JSON adjacente. O
[signoff de medição](specialist/measurement_signoff.json) é
REJECTED_BASELINE_NO_GO. A revisão física e o respetivo signoff acompanham
o mesmo diretório `specialist`: [revisão física](specialist/physics_baseline_stop_review.md)
e [signoff físico](specialist/physics_signoff.json), também
REJECTED_BASELINE_NO_GO. Os pareceres estáticos anteriores autorizavam
recertificação, não a pesquisa. O gate final é NO_GO.

## 6. Orçamento, pesquisa e etapas não alcançadas

| Conta física | Máximo pré-declarado | Executado |
|---|---:|---:|
| Preflight | 8 | 6 |
| Baseline | 24 | 2 |
| Negativos/canários | 8 | 0 |
| Pesquisa | 40 processos / até 5 propostas neste plano | 0 / 0 |
| Finalista | 24, máximo um finalista | 0 |
| Desenvolvimento físico | 2 | 0 |
| Regressões | 34 | 34 |
| Segurança auxiliar | 4 | 4 |
| Total com corpos, todas estas contas | 144 | 46 |

Admissão/ambiente (sete processos) e inventário do pack (um) não criam corpos.
Consultas `--version`, export/import e o editor são utilitários sem mundo de
gameplay; não são trials nem slots físicos de candidatos. Falhas offline
continuam registadas à parte.

O scheduler congelado teria quatro propostas de sensibilidade, uma por
campo, e uma aleatória: cinco × quatro células = 20 processos. Reservava
mais 20 para completar três pares H/R de um único candidato, reaproveitando
apenas quatro headless de identidade exatamente vinculada. Total máximo 40,
24 replays do candidato confirmado e 28 comparações, antes de shortlist.
TPE ficava NOT_REACHED_BY_PREREGISTERED_BUDGET. Esse plano foi exercitado
apenas por testes sintéticos, sem motor nem holdouts.

Na campanha real não foi criado `optimizer/study.sqlite3`, nem propostas,
objetivos de candidatos, Pareto ou shortlist. Não existe um novo ponto A0
qualificado para desenhar uma fronteira: o dry-run A0 não é esse ponto.
Apenas a arquitetura e os testes demonstram a inclusão de A0 no arquivo
caso um estudo fosse legitimamente iniciado.

O vetor histórico 0.28 não foi adotado nem reexecutado como proposta aprovada.
Nenhum raw ganho inválido foi transformado em score. Não houve finalistas,
acesso privado, First Ascent de finalista ou A/B humano. One-hand60, o wrapper
certificado de uma mão e um Right de início independente continuam cobertura
em falta. O Vertical independente histórico não estabelece Right.

## 7. Jogo normal, MCP Pro, export e proteção de bytes

As 34 regressões novas passaram 1.146 verificações: 24 processos/884 checks
de física, pending, intenção/inversão, chão, frames, First Ascent, hybrid,
restauro e pés; mais dez processos/262 checks de input drag/contextual/
independent/distant/capture. Os relatórios completos estão em `regressions/`.
Essa segurança de gameplay não certifica o benchmark interrompido.

O arranque headless normal produziu um snapshot exatamente igual à baseline
de arranque protegida. Godot MCP Pro 1.17.1 executou o main normal no monitor
de índice 0 e confirmou profile 2/LIVE, provider desativado, virtual arming
false, câmara virtual false, observer/capture false, massa/alcance/bindings
originais e parâmetros `[0.25, 0.12, 0.24, 0.9]`. A screenshot
`normal_main.png` foi inspecionada. A consulta inicial tinha apenas o aviso
conhecido de outro project.godot numa pasta de builds; a consulta fresca
após executar o main tinha zero erros. Fechou-se apenas o editor iniciado
nesta tarefa e restaurou-se `project.godot` byte a byte em C e E.

Export release Windows, startup do executável e inspeção do pack isolado
passaram. O inventário do pack encontrou 178 ficheiros, sem Python/Optuna,
tools, docs ou fontes de evaluator/auto-tuning; as 23 exclusões explícitas
também passaram. A inspeção usa o motor de ferramentas para montar o pack:
o seu `release_template: false` descreve esse host, não a template do
executável exportado. O export real foi invocado com `--export-release`.

O executável de QA tem 110.754.728 bytes e SHA256
`18483a47dd49ee7aa44fa1d026e143357aa94b4eb87dd1bc1420cf2194d37e8f`.
Fica nos builds de QA, fora do Git; não substitui a build de rollback.

A auditoria final confirmou 320 fontes públicas e nove helpers vinculados,
paridade C/E e os 204 ficheiros de gameplay protegidos sem diferenças. Todos
os **4.866 ficheiros históricos** e os três externos protegidos mantêm os
hashes MR0. O Janga grabber original, executáveis de rollback, Resources
originais, projeto e export preset foram preservados.

| Proteção | SHA256 |
|---|---|
| `project.godot` | `6ae2782544aa70dfb6a099260ead68de0b0bb7007093ef846bbb2dabfc6a86c9` |
| `export_presets.cfg` | `d0c195fcc871ec53cee49e87d4486824b36725fbfc205b366475f6224054a4b9` |
| Rollback pré-v1.3 | `fb018cfbf8ac57dac83c43af6590f2107bede466d56053e1218583f03564e33d` |
| Janga original | `8ab923ac1d903e8dcc8ed2a2e4f9f8c5cec326a3217cb4a9d8f00036557e7dad` |

## 8. Reprodução, aceitação e decisão de produto

Com o mirror C, motor e ambiente originais, o comando de entrada é:

```powershell
& 'C:\Users\Wynter\grip_up\tools\auto_tuning\.venv\Scripts\python.exe' tools/minimal_benchmark.py --help
```

O estudo encontra-se fechado NO_GO. Não se deve repetir comandos de execução
nos mesmos diretórios. Os manifests guardam os comandos originais. Extraia os
ZIP para uma pasta nova, compare hashes e use os raw para análise offline.
`reproduce_segments.py` materializa sidecars pela mesma implementação congelada;
não lança o motor, não altera recibos ou scores, e recusa divergências.

O índice de evidências contém SHA256 por ZIP e membro, CRC/readback e o arquivo
de fontes medido. Inclui os ensaios inválidos, stdout/stderr, streams incompletos,
manifests/tapes, SQLite de dry-run, testes, análises, regressões e MCP. O
executável grande fica identificado por hash fora dos ZIP. O protocolo recebido
foi copiado sem alteração para `specification.md`.

| Aceitação da spec | Estado desta campanha |
|---|---|
| A1–A4: golden, dois Python offline, negativos/JSON real | PASS no âmbito descrito |
| A5: preflight físico/ambiente | PASS |
| A6: 24 baseline e comparações completas | FAIL; condição de paragem |
| A7: novos negativos/canários | NOT_RUN_EARLY_STOP; restauro do preflight passou |
| A8: auditor único/recusa de inválidos | Implementado e contratos passaram; otimizador físico não iniciado |
| A9: caps, paragem e preservação R4 | PASS; zero propostas e sem retoma R4 |
| A10: regressões de segurança | PASS na cobertura declarada; não cobre qualificações em falta |
| A11: normal LIVE/default/export | PASS |
| A12: decisão e ausência de falsa validação humana | BASELINE_NO_GO; zero candidatos |

Não existe uma melhoria técnica qualificada para levar a humanos. Mantém-se
A0/B1 como referência e o arranque normal original. Esta tentativa delimitada
termina aqui, sem v1.3.5b automático, ajuste do timeout ou nova pesquisa para
procurar um ganho. O próximo trabalho de produto é avançar na jogabilidade/M7
numa tarefa separada, a partir do feel já aceite, em vez de promover parâmetros
com base numa ferramenta que não completou a sua qualificação.
