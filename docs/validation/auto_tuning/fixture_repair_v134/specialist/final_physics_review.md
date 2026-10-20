# v1.3.4 - revisao fisica independente final

**Decisao: FEASIBILITY_NO_GO.** A contabilidade de picks foi reparada e as referencias continuam a reproduzir. Vertical e stop agora produzem janelas completas em ambasHz; existem outros sucessos parciais. Porem Asymmetric60 e LateralLeft60 interrompem, e Step nao obtem onset com carga B1 em nenhuma frequencia. Isto nao satisfaz o piloto completo nem autoriza novo benchmark, tuning, defaults ou revisao posterior do source medido.

Este e um documento novo; `physics_review.md` permanece o parecer de fronteira pre-piloto. Revisao offline de `final_session.json` FINAL_CLOSED e recibos/audits individuais em `builds/eval_virtual_cursor/fixture_feasibility_v134_r1`. Nao executei motor, Git ou sync, nem alterei fontes, fixtures, tapes, documentos R3 ou o parecer pre-piloto. A seguranca final de produto/release ainda esta pendente dos ensaios frescos do root e nao e presumida PASS aqui.

## Identidade e contagem

- Source final: `6cc47db32fccbc0998383c2da6fda6d17c093af6`.
- Snapshot: `00b1a8cccbee79f1b8525e0878d6668e5278e658ff104b5d387be281ad65dbf1`.
- Catalogo r2 SHA256: `5ac75d6ce44a62e494d8bfe3076d6d0568e71dc3105eca246d5ca96c0451b7a8`.
- Engine observado4.7.2 stable Steam/Jolt, binary SHA256 `12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38`.

Os303source hashes e5helpers de active_source ainda correspondem aos ficheiros atuais C. Os195ficheiros de gameplay/projeto presentes na baseline source R3 conservam os mesmos hashes. Nao li E nem executei Git; esta verificacao e de bytes no mirror e manifests, nao uma declaracao sobre estado Git nao inspecionado.

O desenvolvimento teve8processos separados e nao fornece passes ao piloto final. O FINAL_CLOSED tem **34processos de48maximos**:2N1+4referencias+12captures+16replays fixos. As10pairs sao todas STRICT_MATCH:2referencias e8dominios viaveis. Os quatro captures falhados nao foram seguidos por pares; nao se gastou a reserva6. Nao ha hard stop ou RUN_INVALID, mas ha falhas de tarefa e onset. Zero ranking, pesquisa, holdout ou n3qualificado. As34regressoes de produto pertencem a outro ledger.

## Instrumentacao reparada e referencia fisica

N1novo120 e60 passa o contrato Godot e Python:4eventos logicos,3dispatches reais,1suprimido. Tick1 invalid aim nao cria query/target novo; tick3 valid(0,0)faz os sete MISS reais; as queries de origem/destino em55/282ou nos ticks da tape60 sao normais. O ray_count total observado e9: sete do MISS e um de cada hit que termina a selecao; nao21rays inventados para preencher uma matriz. Os nove checks internos passam em ambos processos. A falta real de sidecar continua distinta da ausencia prevista de dispatch. O N1R3 falhado permanece historico, nao foi reclassificado.

Nas referencias novas H/R120, contacto440, origemFREE455 e retencao527,536POST por processo. Nas H/R60,215/223/259e263POST. Os destinos sao contactos reais carregados, mesmo ponto material/ancora ate ao fim, inicialmente fora do alcance. As duas pairs de referencia sao STRICT_MATCH. As tapes/contexto incluem B1 e ground durante a sequencia e nao sao arm-only. A igualdade e no mesmoHz/backing, nao entreHz.

## Resultados de captura por dominio

Todos os pares fixos que foram executados repetem exatamente os respetivos canais medidos, incluindo onsets e tarefas. Uma capture adaptiva nao conta como replay fixo; os resultados abaixo sao descritores de viabilidade, nao melhorias de score sobre R3, pois altura/preparacao/geometria sao novas.

| Dominio |120Hz|60Hz|Resultado do contexto completo |
|---|---|---|---|
| Vertical |MEASURED,+.206309199m; onset425..545;latencia.091667s |MEASURED,+.209521651m;236..296;latencia.083333s |Viavel neste par porHz |
| Asym |MEASURED,+.189690351m;487..607;latencia.066667s |INTERRUPTED,232..237;primeirohit238 |Par120apenas; requisito60falha |
| LateralLeft |MEASURED,+.146508537m;427..547 |INTERRUPTED,242..264;ground265 |Par120apenas; requisito60falha |
| LateralRight |MEASURED,+.145331234m;425..545 |MEASURED,+.143510375m;236..296 |Viavel neste par porHz |
| Step B1 |PRECONDITION_NOT_MET,QUIET_ONSET_NOT_REACHED |Mesmo estado |Sem janela de medicao; pares nao executados |
| Stop duas maos |MEASURED;path3D.112680404m;settling.833333s |MEASURED;path3D.118185152m;settling.866667s |Viavel diagnosticamente porHz; nao n3 |

As laterais medidas conservam latencia **null/PRECONDITION_NOT_MET/ALREADY_MOVING_BEFORE_ONSET**. Quiet exige apenas modulo da velocidade no eixo<=.1, portanto pode admitir movimento acima do limiar de resposta util.02. Nao substituir por latencia0nem alegar melhor resposta. O progresso/eficiencia podem ser medidos independentemente desta latencia indisponivel.

Stop e neutral de comando com maos agarradas, nao release das maos nem active brake. Os valores de path ate settling nao sao path dos cinco segundos. O drift assinado final e+.001548890m120 e-.012670932m60; sinal negativo nao invalida um stop genuino. Confirmacao sustentada e preservada; nao transformar uma janela incompleta em parada de0m.

## Ancoras, apoio e interrupcoes reais

Nas oito captures MEASURED, as duas maos permanecem ATTACHED em uma unica ancora e ponto local por mao, durante os121/61POST das janelas de1s ou601/301do stop5s. Nenhum POST dessas janelas tem grounded/native_ground_authority. Sao observacoes de movimento obtido por apoios reais, sem ancoras deslocadas manualmente. A diferenca material de altura Asym120 e~.1208m, nao simetria apenas renomeada. B1 contribui durante toda a janela Asym120 e em alguns ticks de outros casos; nao atribuir tudo aos bracos.

### Asym60: nova pose supera a separacao estatica nominal

No onset232, COM~(-.053025,1.166678,.272489), maosATTACHED e ground motor desligado. Primeiro238: FootBase contra **V134SpawnPadR2**, OVERLAP_OR_ROTATION_BOUND com margem.001326307m; nao END_OVERLAP nem sweep hit nesse tick. No239a margem e.001531487m. Ground predicate=false, F/Tground=0 e native contact limit0.

A pose evoluida temZ~.2725, diferente da antiga pose r1Z~.239usada para estimar4.283mmnominais de folga. Esta estimativa nunca foi um envelope de aceitaçao futura. O guard corretamente perde a certificacao; nao aumentar tolerancia ou citar a folga estatica como prova contra o hit. O prefixo autorizado tem rawdy-5.96046e-7m e path.000175617m; a metrica completa fica null/INTERRUPTED. Native contact truth continua UNKNOWN: o bound nao prova colisao real nem falso positivo.

### LateralLeft60: desta vez ha esforco efetivo do ground motor

No265, o suporte passa para V134SpawnPadR2, pontoZ~.391775/Y.25. Ao contrario do primeiro tick grounded do R3 antigo, aqui ja existe motor_authority~.038143, applied_force~(-6.40465,0,-.20713)N e applied_torque~(.98519,2.13293,.79175)Nm. E mudanca real de autoridade publicada, suficiente para terminar a tarefa hanging. A query ground ainda e CLEAR nesse tick: predicate de sole/ground motor e bounds dos proxies sao observacoes diferentes. O manifold nativo nao reportado continua UNKNOWN.

O rawprefixo ate264 e+.030757656m/path.054500108m. Nao creditar movimento apos265 nem usar este prefixo como horizonte1scompleto. A direita60concluir e a esquerda60falhar e um resultado a preservar, nao permissao para espelhar artificialmente um sucesso ou alterar a ordem de inputs congelada.

## Step e verificacao independente dos proxies contra o lip

Nenhum Step certifica onset. Nos ultimos5squiet, Fnfoot<=1N ocorre521/600ticks120e293/300ticks60. Ha tambem perdas transitorias de clearance(3/600e13/300), angular quiet(33/600e17/300) e velocidade no eixo(30/600e14/300); as duas maos continuamATTACHED e nao ha grounded/ground motor nesses periodos. Nao reduzir a falha composta a um unico booleano em todos os ticks.

Existe B1 transitorio na preparacao: pico Fn agregado33.5327N120e28.9523N60. Ao fim, porem, Fn=0e os targets estao na parede aY~.663668/.676008em120e~.674729/.675097em60, acima do top.65do novo lip. Estados SUPPORTING/PLANTING e contacto na parede nao substituem compressao util. Sem janela legal nao ha medicao de trabalho de Step para aceitar ou score; nao alegar que o sistema de pes nunca produz forca.

Usei as poses/shapes reais publicados e a caixa estatica do lip, centro(0,.57,-.01),size(.95,.16,.22). Para capsules, calculei distancia minima do segmento central a AABB menos raio; para a esfera, distancia ponto/AABB menos raio; para FootBase, separating-axis test de OBB/AABB (o valor positivo e uma separacao num eixo, nao distancia Euclidiana minima). Nao e uma consulta Godot nova ou prova de impulso nativo; e analise geometrica offline das formas ideais guardadas, sem aplicar margins/slop do solver.

O LowerCapsule chega perto da tangencia com o lip durante a preparacao:

| Amostra analitica |120Hz|60Hz|
|---|---:|---:|
| Menor gap ideal fullprep |-.781micrometro,tick255|-.159micrometro,tick144|
| Menor gap nos ultimos5squiet |-.033micrometro,tick380|-.046micrometro,tick195|
| Gap final |+5.165mm|+2.137mm|

Sinais negativos submicrometricos estao na escala de precisao destes transforms/analise e nao demonstram deep overlap ou manifold. Tambem nao permitem afirmar ausencia de contacto calf/lip: o native contact limit e0. Torso/head estao separados no teste ideal; FootBase tem eixo separador positivo durante todo o prep, minimo~.075m120/~.098m60. Logo a questao marginal e o LowerCapsule, nao um sole nativo que subiu para o lip. Nao ha **janela de Step medida** onde se possa usar esta tangencia para atribuir ou negar trabalho B1; a analise e da preparacao falhada.

O recuo1cm aprovado antes do freeze evitava o overlap ideal~2.13mm previsto na pose antiga; nao prometia clearance de todas as novas poses. A layer1query conserva o seu escopo de pad/floor e nao certifica ausencia de contacto com este lip grippable layer2. Esta limitacao fica explicita, sem mudar o motor ou a leitura de contacto para fabricar um passe.

## Limites de forca, estado e restauracao

Revi os **17750POST** dos34processos finais. Nao encontrei forca em maos fora de ATTACHED/SLIPPING, massa diferente12kg, alcance diferente.65708m, phase/delta errados, COM/v/omega nao finitos, invariantes publicados true ou falha nos recibos de restauracao. Picos globais: maos254.947983N, pes75.818257N, pe individual72.406007N, sharedassist20.0000014Nm e momento combinado76.760712Nm. O residuo de float no limite20e precisao nativa publicada, nao um envelope novo desta revisao.

Cleanup remove providers/held/orbit e restaura camera LIVE/recursos/frequencia segundo os recibos. Ausencia de body writes tambem depende do source auditado, nao apenas de um booleano runtime. As fixtures sao estaticas: comparar reacoes/forces publicadas nao equivale a provar nova conservacao de momento num beam dinamico livre. Nao inventar energia total, torque de contacto ou native manifold ausente.

## Conclusao e fronteira seguinte

FR0instrumentacao e referencias mostram os seus passes observados; a autoria tornou algumas manobras efetivamente mensuraveis. O piloto nao satisfaz, porem, todos os dominios/frequencias exigidos: **FEASIBILITY_NO_GO**, com sucessos parciais preservados. Os pares estritos provam fidelidade do que foi executado, nao resgatam captures interrompidas ou sem onset.

O source final permanece congelado; nao ha mais desenvolvimento autorizado neste budget, nova rodada96ou Optuna implicitos. Uma investigacao futura tem de partir destes motivos observados e de autorizacao propria, sem retunar o jogador para passar um teste. Fresh34regressoes, ordinary startup, export/MCP e protecao final de produto sao verificacoes separadas **PENDENTES DO ROOT** nesta data; este parecer nao as antecipa. Nao existe claim humano de feel/diversao.

Recibos base:

- `final_session.json` SHA256 `dcd0c34a3534857c7fe00d176c53c0d69f1f49c7e791659cb0f15115f722a3c1`.
- `active_source.json` SHA256 `6a41b08100bdc82a520fb998db4223351075d10c45e8d8f6131e85b3ec7590c9`.

Parecer limitado aos bytes/recibos lidos apos FINAL_CLOSED, sem novas execucoes ou alteracoes de source pelo especialista.
