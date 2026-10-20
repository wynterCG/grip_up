# R3 - revisao prospetiva independente de fisica e preparacao

**Estado inicial: sign-off fisico PC2 PENDENTE; primary NOT_RUN.** Esta revisao estatica nao certifica preflight nem autoriza a matriz primaria. E necessaria a cadeia real PC0/PC1/PC2 no mesmo source/engine/tapes, incluindo as quatro celulas H120/R120/H60/R60, seguida de revisao dos recibos e freeze identico.

Li integralmente `GRIP_UP_Benchmark_Preflight_Certification_R3_Spec_v1_3_3_EN.md`. Revisei offline o mirror C: catalogo v133, preparacao do driver herdado R2, fixture publica v132, consulta de clearance e helpers de onset. Nao executei motor, Git ou sync; nao alterei gameplay, fontes, tuning, tapes ou geometria. A unica escrita e este documento. R1/R2 permanecem imutaveis e os diagnosticos de R2 nao contam como PC2.

## Preparacao fisica herdada: preservar, medir e admitir falha

`qualification_fixture.gd:10` exige controller step/time zero, corpo ainda com velocidades zero, maos FREE e ausencia de ownership assisted/freeze. Exige o spawn ja existente da arena 8 e substitui o nivel sincronicamente antes do primeiro passo, removendo o subtree antigo. Nao atribui pose/velocidade ao torso, nao cria maos presas nem altera actuators. A camera recebe apenas a inicializacao declarada da fixture; picking posterior continua real.

`benchmark_driver.gd::_benchmark_prepare` adquire cada mao pelo gesto normal, na ordem do catalogo, executa o preload W finito existente e depois neutral ate ao dwell de quiet. Vertical/asimetrico usam .55 s de preload; laterais e stop 1.5 s. Uma preparacao incapaz de atingir o onset em 5 s e PRECONDITION_NOT_MET, nao evidencia de uma metrica medida. Nao recomendo aumentar preload, alterar pontos ou bandas para obter um resultado positivo.

O dwell usa diferenca de ticks/frequencia >=.25 s, nao simplesmente N amostras. As celulas progress usam quiet na componente do eixo pedido <=.1 m/s e norma angular <=.2 rad/s; isto nao e uma afirmacao de baixa energia 3D. No POST de aceitacao, verificam-se novamente apoio real, ausencia de ground authority, quiet e identidade das duas ancoras no intervalo anterior. O intervalo anterior inclui amostras suficientes para .25 s reais em 60 e 120 Hz. A latencia nao deve receber zero se a velocidade util ja excedia .02 m/s antes do onset; conservar a regra ALREADY_MOVING_BEFORE_ONSET.

O stop ganha movimento por input D e so aceita a libertacao real de comando com velocidade dirigida no intervalo [.15,.5] m/s. As duas maos continuam agarradas; release aqui nao significa largar as maos. Revalidar o onset aceito impede que um tick de preparacao elegivel seja usado para mascarar uma velocidade posterior fora da banda. O settling posterior continua norma linear <=.1, norma angular <=.2 e .25 s continuos, com path COM 3D. Ausencia de settling e um estado tipado, nunca distancia zero.

O replay fixo recertifica o onset congelado pelos dados reais; nao inventa outro onset mais favoravel. O intervalo util termina com ground/ownership/clearance invalido, perda ou mudanca de ancora. Nao encontrei necessidade de corrigir fisica ou alterar o catalogo por esta leitura. A viabilidade real dos seis casos continua por demonstrar em R3.

## Suporte, clearance e limites de interpretacao

`Fixture.audit_clearance` consulta os proxies reais ao longo de segmentos com passos de ate 2 cm/2 graus e margem conservadora para a rotacao. E uma observacao sem correccao do corpo. O mask e layer1: ground/startpad nao agarraveis. Nao e uma prova de clearance da parede, dos footholds ou de um caminho futuro arbitrario. Uma intersecao potencial invalida a janela; nao autoriza mover o corpo para fora. Contactos nao reportados pelo native buffer nao demonstram ausencia de contacto.

O gate do driver requer as duas maos ATTACHED com suporte real e esforco agregado >1 N, clearance consultado e ausencia de motor ground. FREE, REACHING, SLIPPING ou selecao pendente nao contam como onset valido de duas maos. Os guards globais continuam necessarios antes e depois do onset: 12 kg, alcance .65708 m, 360 N partilhados de maos, 180 N de pes/120 N individual, 20 Nm de assist e 150 Nm de momento combinado segundo os canais publicados existentes. Uma query ou um estado selecionado nao pode gerar tracao.

Todos os seis casos usam B1 fisico ON. Ausencia de ground motor nao torna a tarefa arm-only: footholds podem contribuir. O Step exige carga compressiva real >1 N antes e no onset. O quociente integral Nfoot/(Nfoot+handUp) tem unidades compativeis mas nao e fracao do peso corporal: a normal pode nao ser vertical e faltam outros termos. Sem um controlo causal B1 OFF, nao atribuir melhoria ao B1. Trocas de apoio dos pes devem ser divulgadas, mesmo conservando as ancoras das maos.

Estas fixtures sao estaticas. A comparacao de reacoes publicadas nao demonstra conservacao exata de um beam dinamico livre que nao foi exercitado. Twist sem frame valido fica null. PC2 certifica apenas os catches das duas tapes/frequencias observadas, nao a viabilidade destes seis onsets nem generalizacao de Jolt, hardware, cameras ou gestos.

## Risco infra concreto comunicado antes do freeze

No source herdado inicialmente lido, `benchmark_driver._virtual_scope` observa o tamanho rendered na admissao, mas `virtual_cursor_driver.gd:80-86::_fresh` volta a atribuir `get_window().size=requested_size` antes de construir o mundo, inclusive rendered. Se o tamanho mudar entre estes pontos, o setter pode ocultar um ambiente errado antes de o guard de episodio estar ativo. Nao foi reproduzido, mas e contrario a PC1 se usado como reparacao silenciosa de rendered.

Recomendacao minima, exclusivamente infra: no caminho benchmark R3, rendered deve verificar e rejeitar o tamanho atual antes de qualquer setter; headless pode inicializar explicitamente o backing autorizado. Preservar os caminhos historicos de projection qualification se protegidos. Nao mudar camera equations ou pixels. Esta questao fica aberta ate releitura do patch/contrato; nao e uma falha fisica medida.

As restantes correccoes necessarias sao as ja exigidas pela spec: utilitario unico para fronteiras inteiras com tipo/finito/integralidade/shape/bounds exatos, verdadeiro Python->bytes JSON->Godot->admissao final e comparacao de representacao float32 apenas onde o API assim a define. Nunca canonicalizar COM, raios, normais, pontos materiais ou forcas. Conservar os valores raw e o resultado do comparador legado.

## Condicoes do sign-off posterior

Antes do primary: quatro replays PC2 no mesmo candidato; um por H/R x 60/120, tapes originais por frequencia; actual backing/logical/clock antes do mundo; input real sem duplicacoes; seven-ray picking original; pending sem forca; contacto real, source FREE e destino mantido na mesma ancora/material por retencao continua; budgets e restauracao validos. Comparar por tick, sem alinhar pelo contacto nem tolerar alteracao material. Catch concluido nao compensa input/ray/trajectory diferente.

Respeitar tres ledgers: ate 12 replays de precertificacao, no maximo tres candidatos e quatro celulas por candidato, interrompendo no primeiro erro; ate dois diagnosticos puros adicionais por candidato; primary separado com teto 96; 34 regressoes noutro ledger. Um candidato reparado tem nova identidade e recomeca a sua certificacao, nao herda celulas de outro source. Nao confundir os contratos puros iniciais com os dois slots adicionais de reparacao.

Aprovar a fronteira PC2 so depois dos novos recibos. Certificacao nao e benchmark GO, nao conta como n3 primario e nao autoriza tuning. A0/B1/profile4 experimental e o startup profile2/LIVE devem ficar preservados. Primary posterior continua dependente das quatro tarefas primarias em ambos Hz; Step/stop ficam explicitamente excluidos se a cobertura nao satisfizer os requisitos, sem quota artificial.

## Identidade estatica dos dados revistos

| Ficheiro | SHA256 |
|---|---|
| `features/evaluator_virtual_cursor/resources/benchmark_eval_v133.json` | `47462fac8b3340dd0426c631d64ea19b13fb07bf3c6dee89ec80d213bedc2f5d` |
| `features/evaluator_qualification/fixtures/qualification_fixture.gd` | `be9b1dd8688bde5c02e9c98f79ee17b4291418d0de9eb6309cd79022031f5e97` |
| `features/evaluator_qualification/fixtures/qualification_level.gd` | `d34c279f1603c9f916164b3b5e4162fab61a059d0250bc5b35c2924453bd3f99` |
| `features/evaluator_qualification/resources/fixture_registry_v132_r1.json` | `f1f6e127a5f932aa0890cff58ad0264057907778fecbed6914b8e031c213a4af` |

O driver/transport de R3 ainda esta em preparacao e nao se congela por este parecer. O addendum de PC2 tera de apontar a identidade final realmente medida.

## Addendum estatico - hook e fronteira tipada R3

Releitura apos implementacao, ainda sem executar motor: **o risco rendered acima esta fechado no caminho benchmark R3 revisto**. O pai `virtual_cursor_driver.gd::_prepare_projection_size` conserva o setter historico como comportamento por defeito. `_fresh` agora chama esse hook antes dos dois awaits. O override de `benchmark_driver.gd:30` apenas verifica tamanho real 1024x576 e pedido canonico; nao escreve na janela. Se o tamanho rendered mudar depois da admissao, o hook ou a verificacao apos os awaits rejeita o ambiente; nao ha reparacao silenciosa por setter neste caminho. A unica inicializacao do tamanho R3 fica no helper headless antes do clock/mundo. Esta e uma correcao de infraestrutura, sem alteracao de camera/physics/targets.

`benchmark_backing.gd::canonical_dimensions` e agora a fronteira nomeada partilhada: exige chave e Array de comprimento dois; rejeita bool/string/null/objetos antes de qualquer comparacao numerica; verifica finito, integralidade exata, positividade/bounds antes da conversao para inteiro; depois compara dimensoes esperadas. Guarda raw sanitizado, tipos e canonico. `projection_schema` exige window/logical/probe boolean. O preflight le o manifest JSON real e chama `Backing.initialize(root, projection_config)`; a admissao primaria chama o mesmo helper com o mesmo campo. Nao vi canonicalizacao de grandezas fisicas continuas. O hook preworld nao substitui a validacao tipada inicial.

Fecho apenas estatico: ainda nao e PC0/PC1/PC2 PASS. A certificacao precisa dos ficheiros transportados e recibos reais, identidade do candidato e quatro replays; a equivalencia do resultado de dois caminhos nao se infere so por partilharem uma funcao. A extracao do setter para um hook preserva o comportamento default por leitura de codigo, mas a preservacao runtime continua dependente das regressoes separadas.

| Source relido no addendum | SHA256 |
|---|---|
| `benchmark_backing.gd` | `8f58890808027d5bf7bf05a751e27687d3a8ad14ee82cff92ca39ce93164737c` |
| `benchmark_preflight.gd` | `0a8898516faf570ffe9ada430ac5f6054e818f5f70af25bbf998d81afd51eed2` |
| `benchmark_driver.gd` | `f8799d9c3b1ede93e384a251b300046b9975d97833bb55171e9b8888a3a19c72` |
| `virtual_cursor_driver.gd` | `18d5c09f26f5e132df86d4935f0759b98c4bfc34cca79db40f10d05b336844a3` |

## Fronteira formal PC2 - candidato 003

**Sign-off fisico: APPROVED_FOR_PRIMARY**, exclusivamente para o snapshot `a6bd333c5f4fc8f8571d5c907db09f858da9429852befc20e2777f9dc9b36986` e engine/tapes abaixo. Esta decisao sucede ao estado inicial pendente; aprova a fronteira de preflight, nao o benchmark, as metricas dos novos dominios, pesquisa ou defaults. O primary continua 0/96 nesta revisao e requer freeze dos mesmos bytes, restantes sign-offs e regressoes separadas.

Evidencia nova: `builds/eval_virtual_cursor/benchmark_v133_r3/candidate_preflight/benchmark_v133_r3_candidate_003/`. Usei `results.json` final, nao o estado de progresso intermediario de `replay_matrix.json`. Candidatos 001/002 conservam falhas PC0 puras e zero processos fisicos; nao emprestam passes ao candidato 003.

PC0 do candidato 003 tem 135 checks, zero failures, 41 casos de transporte real por ficheiro e zero corpos. Os casos de dimensoes incluem int/float/mixed, rejeicoes de shape/tipo/finito/integralidade/bounds, source alterado, tape corrupta e viewport errado. `admission_receipt.json` liga o resultado ao mesmo snapshot. PC1 possui quatro ambientes positivos H/R x Hz e tres rejeicoes previstas (backing errado H/R e opt-in errado), zero mundos. Isto e evidencia de admissao, nao tarefas fisicas.

Revi os quatro resultados PC2, os audits completos POST, manifests e comparacoes. Todos RUN_VALID, stderr vazio, clock READY antes do mundo e criacao em post_completed com old_subtrees_absent. R60 preserva 15 callbacks iniciais a 120 Hz sem mundo; so depois de dois callbacks a 60 Hz cria a cena. Nenhuma dessas amostras antigas foi contada como gameplay a 60 Hz.

| PC2 | POST | Contacto real | Origem FREE | Primeira retencao qualificada | Distancia no pedido / R |
|---|---:|---:|---:|---:|---|
| H120 e R120, cada processo | 536 | 440 | 455 | 527 | .814921677 / .65708 m |
| H60 e R60, cada processo | 263 | 215 | 223 | 259 | .807716429 / .65708 m |

A retencao corresponde a .6 s depois da libertacao real da origem. Desde o contacto ate ao fim cada processo conserva uma unica ancora runtime e um unico ponto local do destino, sempre ATTACHED e carregado no fim. Sao 97 POST consecutivos por processo120 e 49 por processo60, sem juntar regrips. O destino e a superficie underside real com normal local -Y. O maior comprimento publicado enquanto ATTACHED foi .654083252 m120 e .651668251 m60. FREE/REACHING nao recebeu forca em qualquer dos 1598 POST revistos.

| Pico publicado/recalculado da norma | 120 Hz H=R | 60 Hz H=R |
|---|---:|---:|
| Maos agregadas | 254.947983 N | 242.386597 N |
| Pes agregados | 45.470654 N | 38.390640 N |
| Assist partilhada | 20.0000014 Nm | 20.0000009 Nm |
| Momento combinado | 67.245478 Nm | 76.760712 Nm |

Estes residuos decimais no limite20 sao precisao nativa ja reportada, nao um novo envelope desta revisao. COM/v/omega e forcas das maos revistos sao finitos; massa12/perfil4 e delta de cada POST sao constantes e corretos. As reacoes de forca das maos publicadas sao opostas exatamente nos vetores guardados. Nao inferir daqui nova prova de momento angular de um suporte dinamico livre: estas tapes usam apoios estaticos. Todos os invariantes publicados estao false; os booleans de ausencia de body writes continuam apoiados tambem pela auditoria do source, nao apenas por auto-declaracao runtime.

Ha contribuicao B1 e de ground:120 tem160POST grounded e26com pe loaded;60 tem107 e25, respetivamente, por processo. Pico de ground force168N e torque41.94Nm120/65Nm60. Nao chamar estes catches arm-only nem atribuir toda a energia aos bracos. A retencao e contacto sao reais apesar deste escopo misto, que permanece divulgado. Native contacts nao reportados continuam UNKNOWN.

`replay_comparison_120.json` e `_60.json` sao STRICT_MATCH: nenhum primeiro desvio nos seis canais INPUT/PICK/CONTACT/PHYSICS/TASK/ENVIRONMENT; point_of_call STRICT_MATCH sem hard reasons e sem desvio fisico posterior. O cursor tipado e STRICT_MATCH em todos os536/263pares de ticks. O comparador legado e preservado como CURSOR_OR_CAMERA_MISMATCH, explicado pela auto-comparacao raw JSON64 versus Vector2 nativo32, com originais/bits guardados. Nao houve arredondamento de raios, geometrias ou dados fisicos para aprovar.

Identidade independente: recalculei o digest dos295source hashes e5helper hashes, obtendo exatamente o snapshot aprovado. Todos os300 ficheiros listados do mirror C ainda correspondem; nao li E nem executei Git. Os195 ficheiros de producao/projeto presentes no source map da baseline R2 conservam os mesmos hashes. Os quatro manifests e baseline_candidate transportam o mapa correto, as hashes de ficheiro do manifest conferem e os recibos observam a mesma binary SHA do engine. Dirty tree de precertificacao e explicitamente declarado; nao substitui o freeze/commit identico exigido antes do primary.

- Engine: `4.7.2.stable.steam.ed1daf0bf`, binary SHA256 `12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38`.
- Tape120 original, nao diagnostic-only: `d09f2569cbbafb4db2d3571b806dc804622fe4efda3c6ba9d8790a51bdb2991b`.
- Tape60 original, nao diagnostic-only: `a711b9cb2792890fddd3782db0705a003fdccae4fad67fa3085f895c0a2a2e9d`.
- `results.json` SHA256: `fba4fcd119595f4b7c5c8a955d47ab8043baca1c670bc37cd440a5b6d98ed180`.

Os quatro processos libertam held buttons, removem provider/router frame e restauram camera LIVE, frequencia e recursos originais. O startup profile2 e declarado preservado pelo recibo; a preservacao completa de gameplay/release ainda deve cumprir o ledger separado de regressoes. A certificacao permite tentar o benchmark original sob gates, nao dispensa as12 novas referencias primarias, n3 de dominios ou hard stops. Nenhuma conclusao de diversao humana, generalizacao ou autorizacao de ML resulta deste sign-off.
