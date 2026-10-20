# Comparação entre modos e frequências

## Âmbito

Fonte medida: `24b18d760604fffe3455c5b4c9b8b72f37577b4d`, catálogo `benchmark_eval_v131` revisão 3. Todas as execuções são automatizadas. Não existe avaliação humana de feel. O [relatório técnico de captura](reports/catch_002/comparison.md), os seus JSON por par e os rastos arquivados permitem inspecionar os valores originais.

As comparações exigem identidade de engine, fonte, esquema, configuração, fase de amostragem e cenário antes de analisar comportamento. Os estados `pre_control` e `post_control` nunca são misturados. A localização numérica usa epsilon 10⁻⁶ para encontrar diferenças; esse valor não é uma tolerância de equivalência física. Ticks globais do processo não substituem ticks do episódio.

## Captura: repetição por contexto

| Frequência / modo | Isolado, trace ON | Episódio 5/7, trace ON | Trace OFF / observer ON | Trace OFF / observer OFF |
|---|---:|---:|---:|---:|
| 120 Hz headless | 3/3 | 3/3 | 1/1 | 1/1 |
| 120 Hz renderizado | 3/3 | 3/3 | 1/1 | 1/1 |
| 60 Hz headless | 3/3 | 3/3 | 1/1 | 1/1 |
| 60 Hz renderizado | 3/3 | 3/3 | 1/1 | 1/1 |

São 32 contactos e retenções reais, não 32 demonstrações de suspensão apenas pelos braços. O ensaio admite contribuição B1 e pode tocar no chão. Os estados legados dependentes de um observer desligado não são usados como prova de ausência de chão ou aceleração zero.

No headless, o progresso da captura foi exatamente 0,53419018 m a 120 Hz e 0,63439047 m a 60 Hz, em todos os contextos e controlos de instrumentação. O modo renderizado de 60 Hz apresentou valores próximos de 0,6344–0,6347 m. No renderizado de 120 Hz surgiram também valores próximos de 0,4506 m, apesar de cumprir o mesmo objetivo discreto. Não se agregam frequências diferentes como se fossem repetições da mesma distribuição.

## Divergência de comando a 120 Hz

O caso renderizado isolado r1 e o caso renderizado em sequência r3 não repetem a mesma tape efetiva do headless. A primeira divergência de comando desses outliers acontece no tick 419 PRE e é observada no input aceite no POST do mesmo tick: o renderizado mantém W+D enquanto o headless pede W+A. No POST 418, a velocidade angular consultada pela política era aproximadamente −0,0405834 no headless e −0,00306284 no outlier; só o primeiro tinha cruzado o limiar −0,04 da política histórica.

| Evento destino | Headless 120 | Outlier renderizado 120 |
|---|---:|---:|
| Contacto real | 438 | 478 |
| Mão fonte FREE | 453 | 493 |
| RETAINED | 510 | 550 |

O contacto atrasa 40 ticks, cerca de 0,333 s. O progresso cai de 0,534190 m para 0,450639/0,450768 m. O par isolado r1 atinge diferenças máximas observadas de COM de 0,150458 m, velocidade de 0,484131 m/s e spin de 2,350142 rad/s. Uma diferença material inicial de micrómetros não justifica chamar equivalente a toda esta trajetória.

Há também pares próximos: o isolado renderizado r2 não diverge em comandos e contacta no tick 438; o isolado r3 altera comando já no tick 290 e contacta no tick 440. Os ficheiros por par preservam a primeira diferença de alvo, a primeira diferença de estado e a primeira diferença discreta separadamente. O matching do interpretador e do setup não garante matching de inputs numa política com feedback.

Assim, o objetivo discreto de captura está repetível neste orçamento, mas a equivalência de trajetória/pontuação não está certificada. Não se cria uma tolerância de 15 cm para absorver o outlier. Os valores observados são um envelope descritivo por modo/frequência/contexto, não um limiar prospetivo aprovado para candidatos.

## Arranque, ordem e instrumentação

A primeira matriz rejeitada misturava deltas físicos no mundo renderizado de 60 Hz. Na segunda matriz, os oito processos renderizados de 60 Hz observaram 15 callbacks a 120 Hz **sem Lab criado**, depois dois callbacks corretos a 60 Hz e só então criaram o mundo. Os callbacks obsoletos são preservados no recibo `clock_startup`; não aparecem como ticks válidos do cenário. As outras condições não precisaram de descartar ticks de um mundo.

O primeiro estado físico de captura headless passou a coincidir entre isolado e sequência. A auditoria dos seis ensaios headless de 120 Hz encontrou 1068 amostras por episódio com comandos, alvos e valores físicos iguais; os nomes automáticos de alguns nós diferiam. O cleanup regista ausência dos subtrees antigos e zero corpos antigos ainda no espaço físico antes da criação seguinte.

Recorder OFF desliga a escrita de rastos. Observer OFF desliga, separadamente, o observer antigo; o leitor novo continua necessário para controlar e verificar o ensaio. Não existe uma condição de instrumentação absolutamente nula. O custo publicado por chamada abrange apenas o probe POST, incluindo snapshot, derivação de eventos e serialização; exclui PRE, observers antigos, engine e rendering.

Nos isolados headless, o custo POST observado com trace ON foi cerca de 1,17–1,19 ms/chamada e, com trace OFF, cerca de 0,27 ms/chamada. O tempo total dos processos headless de 120 Hz foi 4,61–4,92 s com trace ON, 3,54 s com trace OFF e 3,09 s com observer antigo também OFF. No renderizado de 120 Hz foram 7,42–7,70 s, 7,33 s e 7,29 s, respetivamente. Estes controlos OFF têm uma execução por célula; não suportam um intervalo de confiança ou uma atribuição causal exclusiva. A tabela técnica conserva todos os custos e a respetiva dimensão de amostra.

## Comparação 60/120 Hz

Os deltas válidos são 1/120 e 1/60 s. As durações de preparação/observação mantêm semântica em segundos e confirmação por tempo decorrido. Não se exige igualdade de número de tick entre frequências nem se faz zip de amostras como se fossem simultâneas. Contacto, retenção, deslocação, reversão e settling devem ser lidos no respetivo relógio físico.

A diferença de progresso headless de aproximadamente 0,1002 m entre frequências permanece visível. Não é apresentada como melhoria de tuning ou como equivalência numérica. Os controlos de locomoção e a decisão global são documentados no relatório final, com interrupções e precondições separadas das metas físicas.
