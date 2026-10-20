# GRIP UP v1.3.5 — relatório do benchmark mínimo

**Decisão final: `NO_GO_MINIMAL_BENCHMARK`. Manter A0/B1. Nenhum parâmetro do jogo foi promovido ou alterado.**

A baseline das duas tarefas passou a qualificação física e as comparações headless/renderizado. Os dois especialistas autorizaram uma pesquisa limitada. O estudo real parou na segunda proposta porque a soma do caminho 3D em Python 3.13 não coincidiu bit a bit com o resultado do Godot. A diferença é de **1 ULP de binary64**, isolada offline no somatório; não demonstra uma divergência da simulação Jolt.

Esta conclusão mantém o GO histórico de MB2 como evidência da qualificação executada e recusa estendê-lo ao pipeline de otimização com o outro interpretador. Não foi mudada a tolerância, reabilitado o candidato ou repetido o estudo depois da falha. O jogo continua com os mesmos valores e controlos.

## 1. Identidade e preservação

| Elemento | Identidade |
|---|---|
| Projeto canónico | `E:\Godot Games\grip_up` |
| Espelho de execução | `C:\Users\Wynter\grip_up` |
| Baseline anterior | `bc619a6bc3fae5f9105077fd34625e0ef9040fd1`, árvore limpa |
| Tag anterior às alterações | `baseline/pre-v1.3.5-minimal-tuning` |
| Branch | `feature/v1.3.5-minimal-tuning` |
| Commit dos bytes medidos | `7d56a6d` — hash completo no manifesto |
| Snapshot final R4 | `cbe93f29aa2f6e47e4aa3fd784bbc1055cfa36bacaa385f7e07baa2bc262d54d` |
| Godot | `4.7.2.stable.steam.ed1daf0bf`, Jolt integrado |
| SHA-256 do executável | `12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38` |
| Orquestração da qualificação | Python **3.11.15** |
| Ambiente do estudo | Python **3.13.13**, Optuna **5.0.0**, SQLite |

O [manifesto dos bytes medidos](r4/source_identity.json), o [plano congelado](r4/run_plan.json), a [auditoria original](baseline_audit.json) e o [registo dos dois ambientes Python](r4/orchestration_environment.json) preservam as identidades completas. O ambiente Optuna já estava instalado; não foram acrescentadas dependências para esta experiência.

Foram conferidos **317 ficheiros públicos de fonte e sete helpers**, com paridade C/E, e **204 ficheiros protegidos de gameplay/projeto**. A auditoria final confirmou **3.127 ficheiros históricos distintos** sem alteração, incluindo os 1.873 ficheiros R3 protegidos pela auditoria anterior. A contagem normaliza separadores Windows para não contar o mesmo caminho duas vezes. O grabber original do Janga e os dois executáveis de rollback mantiveram os seus hashes. Ver [preservação](r4/preservation_audit.json).

Não foram alterados o coordenador de locomoção, atuadores dos braços, solver dos pés, gravidade, colisões, alcance, força, câmara normal, hybrid mantle ou recursos por defeito. As mudanças de fonte limitam-se ao laboratório, ferramentas e pontos de extensão do avaliador.

## 2. Sistema implementado

O catálogo `benchmark_minimal_v135_r1` admite exatamente duas tarefas para treino: Vertical Pull e Lateral Right. Reutiliza a geometria e a preparação física v1.3.4 r2, verificadas por hash. As restantes tarefas estão num catálogo separado, sem recompensa de treino. Não houve nova reparação de fixtures.

A entrada experimental exige a flag explícita e o identificador da campanha. O caminho histórico continua a exigir A0 e a construir `BaselineLab`; dois hooks permitem ao novo avaliador escolher a fábrica experimental e certificar a configuração inicial. A correção partilhada do relatório preserva uma rejeição antes do mundo, em vez de a substituir por um erro posterior de picking.

O carregamento usa a whitelist e a cópia local de Resource existentes. Cada criação de controlador instala os quatro campos antes do primeiro tick. O novo verificador confere valores exatos, todas as propriedades protegidas, identidade da cópia, original intacto e restauro do ponteiro. A configuração normal pré-tick só pode mudar os dois flags previstos, `physical_feet` e `allow_out_of_reach_grip_targets`, com valores finais conhecidos; isso não abre parâmetros adicionais ao otimizador.

| Parâmetro | A0 | Intervalo autorizado |
|---|---:|---:|
| `traversal_speed_m_s` | 0,25 m/s | 0,18–0,32 |
| `traversal_input_ramp_s` | 0,12 s | 0,07–0,20 |
| `traversal_target_max_rate` | 0,24 m/s | 0,16–0,30 |
| `traversal_target_max_acceleration` | 0,90 m/s² | 0,60–1,20 |

Continuam válidos `rate²/(2×acceleration) ≤ 0,055 m` e uma rampa de pelo menos quatro ticks a 60 Hz. Mapas incompletos, desconhecidos, mal tipados, não finitos, fora dos intervalos ou com hash canónico errado são rejeitados.

O estudo usa SQLite, uma única worker, diretórios exclusivos, manifesto anterior ao lançamento, watchdog, recibos imutáveis e orçamento reservado antes de avaliar. A identidade inclui fonte, motor, catálogo, tapes, whitelist, qualidade e sequência de propostas. O primeiro arranque verifica a ligação do GO aos pareceres, referência e contrato atuais; a retoma também audita os recibos anteriores.

O score mantém progresso, fidelidade, qualidade física e fiabilidade separados. Só os dois progressos assinados podem formar objetivos, depois de todos os gates. Métricas não medidas conservam `value: null`; dados parciais ficam fora dos objetivos. A0 é uma referência explícita no arquivo/Pareto. Os modos CLI e limites estão descritos em [reprodução](reproduction.md).

## 3. Preflight e tentativas preservadas

| Revisão | Resultado | Mundos físicos de avaliação |
|---|---|---:|
| R1 | Um dos 135 checks detetou mascaramento do motivo de rejeição de fonte | 0 |
| R2 | Transporte e ambiente passaram; o primeiro Catch terminou no Godot, mas o auditor Python falhou por variável local ausente | 1, cobrado como tentativa falhada |
| R3 | Transporte e ambiente passaram; revisão estática apertou ligação dos hashes e negativos antes de medir treino | 0 |
| R4 | 135/135 checks de transporte, seis casos de ambiente e sete processos físicos válidos | 7 |

R1–R3, fontes arquivadas, dados brutos e falhas continuam separados. Os ensaios offline de reparação do auditor estão marcados como testes com cópias de dados anteriores, sem novos mundos e sem elegibilidade para score.

O orçamento de preflight ficou em **8/8**, incluindo a tentativa R2. Para não o exceder, foi capturada apenas a tape independente adicional Vertical a 120 Hz; a tape adicional Right ficou **NOT_TESTED**. Isso limita qualquer futura afirmação de generalização em Right. Não foram retirados lugares aos outros ledgers.

A admissão R4 exerceu o manifesto completo Python → JSON → Godot, incluindo os blocos aninhados e frames reais. Dimensões numéricas integrais em representação int/float passaram; frações, strings, bools, formas erradas, ausências e não finitos foram rejeitados antes de criar gameplay. O backing headless foi estabelecido explicitamente em **1024×576**, com viewport lógico **1920×1080**, câmara V0 e dois callbacks do clock correto. Em renderizado, o tamanho real foi observado e verificado.

As sete execuções R4 foram dois Catch de referência, quatro capturas V/R a 60/120 Hz e a captura independente Vertical. Captura adaptativa permaneceu não pontuável. Nenhuma sessão foi apresentada como jogo humano.

## 4. Baseline nova: 24 processos

Cada célula teve três processos headless e três renderizados, com tape fixa, A0/B1, mundo e frequência correspondentes. Todas as janelas terminaram como `MEASURED`.

| Tarefa | Hz | Progresso assinado | Onset → fim | H/R | Repetibilidade por modo |
|---|---:|---:|---|---|---|
| Vertical | 120 | +0,2063091993 m | 425 → 545 | 3/3 STRICT_MATCH | PASS |
| Vertical | 60 | +0,2095216513 m | 236 → 296 | 3/3 STRICT_MATCH | PASS |
| Right | 120 | +0,1453312337 m | 425 → 545 | 3/3 STRICT_MATCH | PASS |
| Right | 60 | +0,1435103752 m | 236 → 296 | 3/3 STRICT_MATCH | PASS |

Total: **24/24 processos, 12/12 pares H/R e 16/16 comparações dentro do modo**. Os campos comparados incluem input pedido/aceite/aplicado, cursor tipado, câmara, picking real, contactos, pontos materiais, forças, corpo, planner e resultado da tarefa. Não foi acrescentado epsilon para obter igualdade.

As janelas têm um segundo: 121 amostras POST a 120 Hz ou 61 a 60 Hz, incluindo os extremos. Os pontos materiais e âncoras reais permaneceram estáveis; as janelas não tiveram autoridade de chão ou hybrid e conservaram o envelope de clearance. A latência Right é **null / ALREADY_MOVING_BEFORE_ONSET**, não zero. A torção axial continua NOT_APPLICABLE porque não existe um referencial válido publicado; velocidade angular total não a substitui.

As repetições idênticas demonstram repetibilidade local de uma tape e ambiente, sem significância estatística entre jogadores ou arranques independentes. O [CSV completo](r4/baseline_matrix.csv) mantém todas as execuções. Estas medições são novas; não foram preenchidas com números históricos.

## 5. Negativos, canary e aprovação limitada

Os oito processos do ledger de negativos/canaries foram `RUN_VALID`, com resultado de tarefa mantido separado.

| Controlo | Evidência |
|---|---|
| N1 a 60/120 Hz | Nove checks por frequência; quatro decisões lógicas, três dispatches, nove rays, uma supressão |
| Sidecar em falta | Rejeitado com `PICK_DISPATCH_IDENTITY_MISMATCH` sobre cópia de stream real |
| Sidecar duplicado | Rejeitado com `ORPHAN_OR_DUPLICATE_PICK_SIDECAR` |
| FREE/REACHING | Força zero; verificação bruta adicional de 228 observações |
| Asym 60 | INTERRUPTED no tick 238 por `GROUND_CLEARANCE_NOT_CERTIFIED` |
| Left 60 | INTERRUPTED no tick 265 por `NATIVE_GROUND_AUTHORITY_CHANGED_TASK`, com autoridade real observada |
| Fonte/tape/backing inválidos | Rejeições antes do mundo nos contratos de admissão |

O canary foi escolhido antes da pesquisa: velocidade 0,18, rampa 0,20, rate 0,16 e aceleração 0,60, sem aumentar força ou alcance. Em Vertical, ambas as repetições a 120 Hz completaram a janela com **+0,1245242357 m**, uma redução de **39,6419%** face a A0. Isso demonstrou sensibilidade contínua nesta tarefa.

Em Right, ambas as repetições foram interrompidas no tick 449 por clearance. A projeção oficial ficou null; a aritmética parcial de −0,0002622632 m permanece apenas como dado bruto. Não foi usada como gradiente contínuo nem convertida em progresso zero. A1 foi explicitamente omitido desta pesquisa de quatro campos e mantido como histórico.

O [contrato de qualidade](r4/quality_contract.json) foi congelado após a baseline e antes dos candidatos: eficiência não piorar mais de 0,05, excursão contrária/transversal não piorar mais de 5 mm, latência medida não piorar mais de dois ticks ou 15% de A0, conforme o maior. A repetição teve amplitude zero; isso não foi convertido numa alegação de significância. A torção indisponível mantém o seu estado/reason exato.

Os pareceres independentes [físico](r4/specialist/physics_signoff.json) e [de medição](r4/specialist/measurement_signoff.json) autorizaram somente esta pesquisa limitada. O [GO de MB2](r4/mb2_gate.json) continua preservado como decisão histórica, com os hashes correspondentes.

## 6. Estudo real e paragem

O plano tinha um teto de oito propostas de sensibilidade, seis aleatórias e quatro TPE; máximo de 18 configurações e 40 lançamentos, incluindo reserva. A pesquisa começou só depois dos dois pareceres e do gate combinado.

| Proposta | Alteração | Execuções reais | Resultado |
|---|---|---:|---|
| 0 — sensibilidade inferior | Velocidade 0,22; restantes A0 | Vertical + Right | RUN_VALID, mas sem onset certificado; candidato rejeitado, objetivos null |
| 1 — sensibilidade superior | Velocidade 0,28; restantes A0 | Só Vertical | Godot terminou; auditor marcou RUN_INVALID por recomputação do caminho |

A proposta inferior não cumpriu toda a janela quiet anterior ao tick 425: o spin ultrapassou 0,2 rad/s nos ticks 394–409. Um onset aparentemente válido no tick final não substitui esse histórico. Não houve resgate nem deslocação da janela.

Na proposta superior, o progresso vertical bruto foi +0,2173030376 m, com suporte físico completo. Esse valor **não é um resultado elegível de otimização**: a execução é inválida no pipeline e Right não chegou a correr. A falha do callback marcou STOP_STUDY e bloqueou os lançamentos seguintes.

Foram feitas **duas propostas e três lançamentos físicos**, com **quatro lugares reservados**. SQLite conserva dois trials FAIL e nenhuma linha de objetivos numéricos. Não houve random, TPE, shortlist, validação de finalistas ou sessão humana. O arquivo inclui A0 e as duas falhas; a fronteira válida contém apenas A0. Ver [resultado do estudo](r4/search_result.json).

## 7. Diagnóstico da diferença numérica

| Cálculo do mesmo caminho capturado | Valor |
|---|---:|
| Godot publicado | 0,2245515785359135 m |
| Python 3.11, `sum()` | 0,2245515785359135 m |
| Python 3.13, `sum()` | 0,22455157853591354 m |
| Redução explícita na ordem do Godot, em ambos os Python | 0,2245515785359135 m |

A diferença final é **2,7755575615628914×10⁻¹⁷ m = 1 ULP**, com representações hexadecimais `0x1.cbe1b2b09d8a6p-3` e `0x1.cbe1b2b09d8a7p-3`.

O diagnóstico usou o mesmo ficheiro de COM, sem lançar Godot. Os 120 comprimentos individuais têm exatamente os mesmos bytes nos dois interpretadores; o SHA-256 conjunto é `2ef81c7306f293e5d7e22a7d9ad72c30997b9959920dca024e759ba20e8ca104`. A diferença surge apenas na soma exterior. A documentação oficial regista a alteração do algoritmo de soma de floats a partir do Python 3.12. [Python — sum()](https://docs.python.org/3.12/library/functions.html#sum).

O primeiro prefixo diferente na recomputação offline termina no tick **439**. Isso identifica o primeiro desvio aritmético observado nesta análise, **não** um primeiro desvio físico ou H/R do candidato. O Godot não publicou cada prefixo acumulado e o candidato não teve replay renderizado.

A qualificação foi orquestrada em Python 3.11.15 e o estudo no ambiente fixado 3.13.13. O contrato não cobria suficientemente a semântica dessa redução entre interpretadores. A auditoria inicial declarou o ambiente Optuna disponível; isso não prova que a qualificação inteira o tenha usado. O [registo dos executáveis](r4/orchestration_environment.json) e as revisões posteriores tornam essa limitação explícita.

Não foi corrigida a fórmula depois de observar o candidato, nem trocada a igualdade por tolerância. As revisões independentes [de medição](r4/specialist/measurement_search_stop_review.md) e [física](r4/specialist/physics_search_stop_review.md) mantiveram o NO_GO e preservaram os pareceres iniciais.

## 8. Segurança física e jogo normal

O especialista físico relê 16.719 POST dos 39 processos de qualificação R4 e mais 1.635 POST dos três processos do estudo. Não encontrou violações físicas observáveis no escopo monitorizado. Os limites continuam: corpo de 12 kg, alcance 0,65708 m, mãos 360 N partilhados, pés 180 N/120 N por pé, assistência 20 N·m, momento combinado 150 N·m e braços 6000/220.

Na qualificação, os máximos observados foram aproximadamente 254,948 N nas mãos, 64,227 N nos pés, 51,266 N num pé, 20,0000014 N·m na assistência e 76,761 N·m no momento combinado. O pequeno resíduo da assistência permanece dentro da allowance numérica anterior; não foi alargada. O comprimento ATTACHED máximo observado foi aproximadamente 0,654083 m. Reações explícitas de força foram conferidas; isso não é uma demonstração universal de conservação angular.

O limite de contactos nativos reportados é zero neste caminho, pelo que uma lista vazia não prova ausência universal de colisões. O parecer conserva essa limitação e usa os canais de suporte, autoridade e consultas de clearance definidos no protocolo.

As regressões novas passaram **884 checks em 24 processos** e **262 checks em dez processos**: **1.146/1.146**, sem falhas. Cobrem física, pending contact, integração/reversão, movimento no chão, sinais do frame, First Ascent, hybrid mantle, vault, restauro, allocation, pés e inputs LIVE.

O Godot MCP Pro 1.17.1 confirmou o jogo normal no monitor 1: perfil 2, LIVE, hold-to-grip, provider de replay desligado, câmara virtual desligada, observer/capture desligados, massa/alcance e quatro valores originais. O screenshot foi inspecionado. O editor terminou com zero erros novos; o warning anterior de projeto aninhado foi mantido no registo. O projeto C/E foi restaurado byte a byte após fechar o editor próprio.

A exportação release e o smoke passaram. A inspeção de um pacote isolado confirmou a exclusão de **23 caminhos experimentais**. O executável local e o seu hash estão no [resumo de segurança](r4/safety_summary.json); o binário não é publicado no Git. Não foi alterado o jogo para melhorar o score.

## 9. Orçamentos finais

| Ledger | Consumo real | Limite |
|---|---:|---:|
| Preflight físico | 1 R2 + 7 R4 = 8 | 8 |
| Baseline | 24 | 24 |
| Negativos/canary | 8 | 8 |
| Otimizador | 3 lançamentos; 4 reservados | 40 / 160 episódios |
| Finalistas | 0 | 48 |
| Segurança auxiliar | 4 mundos | Contados no total geral |
| Total avaliação, incluindo auxiliares | **47** | 128 |
| Regressões separadas | **34** | 34 |
| Total físico observado | **81** | 128 + 34 |
| Sessões humanas | 0 | A combinar separadamente |

Os testes de transporte, ambiente sem corpos, parsing, SQLite sintético e recomputação offline não contam como mundos físicos. Os respetivos processos/logs ficam identificados. Foram também executados 39 testes sintéticos da pesquisa, 50 contratos das ferramentas partilhadas e 11 checks do carregador/restauro sem corpos de gameplay.

## 10. Entrega e limite da conclusão

Ficam implementados e documentados o catálogo mínimo, carregamento seguro, admissão, qualificação, contratos negativos, contrato de qualidade, proposta/score/Pareto/SQLite e limites por fase. O runner de dois mundos por processo e a validação de finalistas existem como caminhos condicionais, mas **não foram executados nem certificados** nesta campanha.

Os holdouts privados permaneceram fechados. Catch foi usado como referência protegida, não como objetivo de treino. A nova tape Vertical foi congelada antes da pesquisa, mas não chegou a validar um candidato. Não há evidência nova de transferência, generalização, preferência humana ou melhoria do feel. O [protocolo humano](human_protocol.md) continua planeado e não executado.

O estudo fica encerrado em NO_GO; não há recomendação de parâmetros além de manter A0. Uma fase futura, se autorizada, deve primeiro definir uma redução binary64 explícita e revista, usar o mesmo interpretador fixado na qualificação e pesquisa, ligar essa identidade ao manifesto e repetir a qualificação num diretório novo. Isso não autoriza alterar a igualdade física H/R ou reutilizar este resultado como vencedor.

Os dados completos, fontes e diagnósticos ficam arquivados com SHA-256 e verificação de leitura. A [decisão estruturada](r4/decision.json), os índices de evidência e o [guia de reprodução](reproduction.md) permitem auditar a campanha sem a reabrir.
