# R3 - revisao fisica independente da campanha primaria

**Preflight: PREFLIGHT_CERTIFIED, preservado. Primary: NO_GO_BENCHMARK.** Ha replays e medicoes uteis num subconjunto120Hz, mas as tarefas obrigatorias nao qualificam em ambas as frequencias. Depois da matriz de dominios, o primeiro controlo negativo tambem disparou um hard stop de integridade de contagem de picking. Nenhum destes factos autoriza corrigir ou retomar a campanha congelada.

Revisao offline do mirror C em 2026-10-20. Nao executei motor, Git ou sincronizacao, nao alterei fontes, tapes, geometria, tuning ou documentos de precertificacao. Escrevi apenas este novo parecer. Li os recibos finais, audits POST e comparacoes; resultados secundarios de admission/preservacao sao distinguidos das observacoes fisicas.

## Identidade, contagem e preservacao

Source primario medido: `7a578995915d56ade2fa447f3adfdd6e19dc0218`. Snapshot certificado composto source+helpers: `a6bd333c5f4fc8f8571d5c907db09f858da9429852befc20e2777f9dc9b36986`. Os295source hashes e5helper hashes do source_identity primario ainda correspondem aos ficheiros atuais C na releitura. Nao se deve confundir este snapshot composto com a hash apenas do mapa de source guardada em cada manifest.

Engine observado: Godot4.7.2 stable Steam/Jolt, binary SHA256 `12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38`. A0/B1/perfil4, massa12kg e os quatro valores baseline permanecem os declarados; nao houve variantes de tuning. A ausencia de mudancas de gameplay apoia-se na preservacao por hashes anteriormente auditada e nos recibos de restauracao, nao num resultado positivo da tarefa. O root comunica BQ0 fresco34processos/1146checks PASS e ordinary startup exato, em ledger separado.

Os ficheiros primarios estao em `builds/eval_virtual_cursor/benchmark_v133_r3/primary/benchmark_v133_r3/`. As contagens finais desta revisao derivam dos recibos individuais, nao de um ledger intermediario que ainda mostrava uma fase em andamento:

| Grupo primario | Processos | Resultado relevante |
|---|---:|---|
| BQ1 puro |13|12 positivos e1rejeicao esperada; zero mundos, fora dos resultados fisicos |
| BQ2 referencias novas |12|6pairs H/R STRICT_MATCH;3porHz |
| Dominios |48|12captures adaptivos +34replays nas17pairs +2controles probeOFF |
| Negativo N1 |1|RUN_INVALID/MISSING_REAL_PICK_RECORDS; hard stop |
| Total de tentativas primarias com admissao fisica |61/96|maximo, nao61sucessos |
| Diagnosticos primarios posteriores |0/4|Nao executados nesta revisao |

Os cinco controles nomeados restantes ficam NOT_RUN_EARLY_STOP. Os24processos de dominio nao executados relativamente ao teto72 resultam das preparacoes sem onset legal e da cobertura prospetiva delimitada; nao sao passes presumidos nem budget transferivel. Os quatro PC2 anteriores continuam apenas precertificacao, fora deste total. Nenhum resultado R1/R2 foi convertido em resultado R3.

## Referencias fisicas BQ2

As12referencias foram RUN_VALID. As seis comparacoes H/R e as oito comparacoes offline within-mode publicadas sao STRICT_MATCH. A equivalencia e por tick, mesma tape/frequencia/backing, sem exigir igualdade entre60e120Hz. As tapes originais porHz continuam as certificadas, nao diagnostic-only.

Em120Hz cada referencia mantem536POST: contacto440, origemFREE455 e primeira retencao qualificada527. Em60Hz sao263POST: contacto215, origemFREE223 e retencao259. O destino e a mesma ancora/ponto material real, carregada no fim, com normal underside-Y e inicialmente fora do alcance. Nao se concatenam regrips. Ground e B1 contribuem durante a sequencia: isto nao demonstra arm-only swing nem nova conservacao de momento angular num beam livre. O comparador legado de representacao permanece auditavel; a igualdade tipada de cursor nao arredonda raios, ancoras ou campos fisicos.

Este PASS de BQ2 e restrito ao mecanismo/tapes/contextos observados. Nao basta para qualificar as tarefas de movimento seguintes.

## Estado por dominio

`domains_session.json` final contem48RUN_VALID,17pairs STRICT_MATCH e `hard_stop` vazio nessa etapa. A observacao fisica e18MEASURED,25INTERRUPTED e5PRECONDITION_NOT_MET, contando captures e controles. Process completed/RUN_VALID significa execucao admissivel, nao tarefa concluida. Nenhum capture adaptivo conta como replica fixa.

| Dominio |120Hz|60Hz|Decisao fisica para o dominio completo |
|---|---|---|---|
| Vertical |Onset268; interrupcao275; ate274 rawprogress0 |QUIET_ONSET_NOT_REACHED |DIAGNOSTIC_ONLY; nao elegivel |
| Assimetrico |QUIET_ONSET_NOT_REACHED |QUIET_ONSET_NOT_REACHED |DIAGNOSTIC_ONLY; replays fixos sem cobertura |
| Lateral esquerda |n3pairs, +.149168375m; latencia.141666667s |Onset179, interrupcao200; raw+.018447442m |Subconjunto120medido; dominio ambosHz nao elegivel |
| Lateral direita |n3pairs, +.149263170m; latencia.141666667s |Onset179, interrupcao200; raw+.018611609m |Subconjunto120medido; dominio ambosHz nao elegivel |
| Foot-supported Step |QUIET_ONSET_NOT_REACHED |QUIET_ONSET_NOT_REACHED |EXCLUDED da utilizacao de ranking; sem onset legal |
| Stop de duas maos |1pair +probeOFF; path3D.116283647m,settling.816666667s |Onset199; interrupcao200 |DIAGNOSTIC_ONLY; cobertura e frequencias insuficientes |

### Vertical e assimetrico: alcance da consulta de clearance

No capture vertical120 `vertical_pull_clean_120_headless_r0_53e37f75`, a janela certifica onset268. O primeiro hit275 e `OVERLAP_OR_ROTATION_BOUND`, FootBase contra EQ132SpawnPad, um segmento, query_margin `.00076574349m`. Nao ha `SWEPT_GROUND_INTERSECTION` nem `END_OVERLAP` nesse tick. ground_motor.grounded=false, native_ground_authority=false, F/Tground=0. O contacto nativo e UNKNOWN porque max_contacts_reported=0; a lista vazia nao prova ausencia de apoio passivo do solver.

O corpo esta praticamente estacionario antes da interrupcao: COMy1.164214373m, rawprogress0, path3D2.07034e-7m ate274. Uma reconstrucao offline do FootBase transformado, recortado pela frenteZ=.32do pad, poe um ponto ideal aY~.249829m frente ao topY=.25m. Esta proximidade submilimetrica e compativel com uma fronteira de contacto; nao permite chamar o hit automaticamente falso positivo, nem prova a intensidade de uma reacao nativa. As metricas publicadas interrompidas ficam null; rawprogress0 nao e uma medicao de desempenho elegivel ou prova de incapacidade de subida em todo o jogo.

O assimetrico120 nao consegue o dwell legal: nos600POST finais,574tem clearance nao certificado; as duas maos ficam ATTACHED e nao ha ground motor. O fim tem o mesmo FootBase/SpawnPad conservative hit. Em vertical60 e assimetrico60, os300POST finais nao certificam clearance; no fim tambem existe END_OVERLAP do FootBase contra SpawnPad. Isto e mais forte que um limite rotacional apenas, mas continua uma consulta de geometria, nao um par/impulso de contacto nativo reportado. Os restantes valores de quiet sao baixos; nao culpar simplesmente falta de estabilidade angular quando o guard impeditivo e clearance.

### Laterais: movimento util120, janela interrompida60

Em120Hz a janela348..468termina legalmente, sem ground authority ou perda de ancoras. As seis replicas fixas por direcao coincidem nas tres pairs. B1 esta ON; nao atribuir os15cm exclusivamente aos bracos ou alegar ganho sobre outro controlador. Left/right sao ensaios separados com sinais e ordem de aquisicao proprios, nao numeros espelhados artificialmente.

Em60Hz ambas as direcoes mantem maos reais e clearance certificado ate199. No200, o ground predicate passa a true no EQ132SpawnPad, com ponto observadoY~.25m. **Nesse primeiro tick, applied_force, applied_torque e motor_authority continuam todos zero.** O codigo tipado NATIVE_GROUND_AUTHORITY_CHANGED_TASK cobre a entrada do estado grounded; nao significa que um impulso de marcha foi observado ou causou a deslocacao anterior. A janela hanging foi corretamente interrompida pelo criterio estabelecido.

O onset179 verifica quiet apenas no eixo pedido, nao velocidade3D baixa: vY~-.163m/s e vZ~-.046m/s sao divulgados. Isto respeita a definicao de clean lateral existente, mas limita a interpretacao de 'estabilizado'. A latencia util.15s ocorreu antes da interrupcao e pode permanecer MEASURED; o progresso completo requerido fica INTERRUPTED/null. Os raw+.01845/+.01861m sao prefixos autorizados, nao uma tarefa completa nem escores positivos.

### Step e stop

O Step tem esforco B1 real, mas permanece grounded nas600amostras finais120 e300em60, logo nao satisfaz onset nonground. Ao fim120, Fnfoot~36.66N, ground authority~.1618e torque nao nulo; em60Fnfoot~33.18N. Nao substituir a medicao ausente por 'pes nao funcionam', nem creditar uma subida de origem ground ao benchmark de climbing. A carga compressiva observada nao demonstra melhoria causal de B1 sem um controlo B1OFF.

No stop120, o comando neutral e aceite no386a partir de movimento dirigido legal. O settling comeca .816666667s depois e so e confirmado no514apos.25s continuos; path3D.116283647m. O resto da janela permanece autorizado. A pair fixa e o controlo probeOFF coincidem; n1pair nao equivale a n3. Trata-se de release passivo de comando com grips mantidos, nao travagem ativa nem libertacao das maos. Em60, onset199 legal e grounding no200deixam zero intervalo de trajetoria utilizavel apos o onset: path/settling null INTERRUPTED, nao parada instantanea de0m.

## Seguranca observada

Recalculei offline limites e estados dos26111POST das12referencias+48dominios. Nao encontrei forca em maos FREE/REACHING, mudanca de massa12/alcance.65708, delta/phase incorretos, COM/v/omega nao finitos, invariantes publicados true ou falhas de restauracao. Os picos globais sao maos254.947983N, pes71.227966N, pe individual71.227965N, assist20.0000014Nm e momento combinado76.760712Nm. Os residuos de precisao nativa do limite20nao constituem um novo envelope/tolerancia desta revisao.

Isto e seguranca observada nos canais publicados, nao prova absoluta de ausencia de body writes: a autoridade tambem depende da fonte congelada auditada. Foot force, reacao e momentos sao comparados; nao inventar trabalho mecanico total, twists sem frame valido, contactos nao reportados ou teste dinamico inexistente. A interrupcao de uma janela valida nao e um hard safety violation por si propria.

## N1 e hard stop posterior

O primeiro negativo, `swing_catch_train_120_headless_r1_e0310d17`, tem engine completed/exit0, nove checks internos PASS, contacto440/sourceFREE455/retained527e cleanup completo. Os536POST mostram caps iguais a referencia e zero forca pendente. Mesmo assim, o runner congelado produz RUN_INVALID/MISSING_REAL_PICK_RECORDS e a campanha deve parar.

A causa observavel e4entradas logicas de pick versus3registos de consulta real. Tick1 falseaim+press gera apenas `INVALID_AIM_NO_NEW_TARGET`, sem raycast novo. Tick3 valid[0,0] executa os sete raios reais e MISS; ticks55/282fazem as queries normais. O guard de contagem nao distingue a rejeicao sem query das consultas reais. Este diagnostico offline explica o desacordo de contagem; nao autoriza mudar o contrato aposfreeze, declarar o negativo PASS ou tratar a ausencia esperada de query como bypass fisico. Os cinco controles restantes ficam sem cobertura pela paragem, sem novos diagnosticos ou resgate de slots.

## Veredicto e limites

PREFLIGHT_CERTIFIED e BQ2 PASS permanecem verdadeiros e separados do primary NO_GO_BENCHMARK. O benchmark global nao satisfaz os dominios primarios em ambosHz, mesmo antes do hard stop N1. Left/right120formam um subconjunto tecnico medido e repetido; nao concedem elegibilidade geral ao catalogo nem permissao de Optuna, tuning, holdout ou novos defaults.

Nao recomendo corrigir fixtures/guards/tapes/source nesta campanha nem reclassificar interrupcoes para atingir quota. Um futuro estudo pode usar estes motivos como dados de autoria e medicao, mas precisa do seu proprio escopo autorizado. Nao ha observacao humana inventada, melhoria de gameplay demonstrada por estes dados ou alteracao ao sistema jogavel decorrente desta revisao.

Hashes dos recibos lidos:

| Ficheiro relativo ao diretorio primario | SHA256 |
|---|---|
| `source_identity.json` | `33bbcd4d2a9d5be6699bc054fa2ee8505eb16052dfadbbc9d832ff252b99b98a` |
| `reference_session.json` | `cb7ad4e07f40765e3bbd007a6e2fb6d680077fc74b71e1ed114010391968cf83` |
| `reference_within_mode.json` | `7ddc71cd33bc07bd578f2c0f80a76d3bf02cea8a647f736e7f162bb433dd6963` |
| `domains_session.json` | `8d89c066be937b5f075db2cb20c1da5b8f632621e96317b75e64c850562893d9` |
