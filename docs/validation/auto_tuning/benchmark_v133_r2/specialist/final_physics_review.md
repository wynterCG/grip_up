# Revisao fisica independente final - benchmark v1.3.3 R2

**Decisao: NO_GO da qualificacao R2.** O bloqueio primario e uma falsa rejeicao de admissao JSON, antes de qualquer mundo ou tick de gameplay. Nao e uma falha fisica de catch nem evidencia de defeito Jolt. Os diagnosticos posteriores permanecem PARTIAL/DIAGNOSTIC_ONLY; nao retomam a matriz nem qualificam os novos dominios.

Revisao offline do mirror C, em 2026-10-20, sem executar motor, Git, sincronizacao ou alterar fontes. Li os resultados de admissao, o primeiro BQ2, os quatro diagnosticos, os audits POST completos dos dois catches e a comparacao. A unica escrita e este novo parecer. O NO_GO anterior de R1 permanece independente e inalterado.

## Campanha primaria preservada

Fonte congelada R2: `3ee5fabb6e2709d94dcc0e0663ba990bed8e75e3`.

`preflight_session.json` confirma 13 assertions novas: 12 positivas H/R x 60/120 Hz x n3 e uma rejeicao correta de tamanho 1440x810. Os positivos observaram backing 1024x576, viewport logico 1920x1080 e dois deltas finais corretos. Em rendered 60 Hz foram preservadas amostras iniciais a 120 Hz antes da confirmacao a 60 Hz. Estes preflights nao criaram corpos de gameplay e nao sao resultados fisicos.

O primeiro BQ2, `swing_catch_train_120_headless_r1_658b4656`, terminou `RUN_INVALID` / `BLOCKED_SETUP` / `ENVIRONMENT_NOT_COMPARABLE:CANONICAL_BACKING`. O recibo contem `backing_initialization={}`, `world_creation_record={}`, zero callbacks pre/post e audit exato `{"frames":[],"ticks":[]}`. O stderr esta vazio. A rejeicao aconteceu no guard do manifest, antes do helper que inicializa a janela.

A comparacao de arrays `[1024,576]` inteiros com os valores numericos desserializados por Godot rejeitou um pedido dimensionalmente canonico. O diagnostico puro reproduz `old_array_comparison=false` para os numeros JSON. Isto distingue o bloqueio de um tamanho real errado. A correcao subsequente usa verificacao de tipos numericos e igualdade escalar exata, sem arredondar dimensoes e sem mudar tolerancias fisicas.

O meu parecer estatico anterior, `initialization_review.md`, nao detetou este caminho positivo apos JSON. O PASS desse documento era limitado a inicializacao/encaminhamento; nao constitui aprovacao do BQ2. Os 19 checks anteriores da correcao headless tambem nao demonstravam admissao positiva com este `projection_config` canonico presente. Esta lacuna deve acompanhar a leitura do parecer inicial.

| Gate/dominio R2 | Classificacao | Evidencia |
|---|---|---|
| BQ1 ambiente/clock puro | PASS | 12 positivos + 1 negativo correto; zero corpos |
| BQ2 execucao primaria | REJECT | Primeiro pedido bloqueado antes de simular; nenhuma pair primaria |
| Vertical, assimetrico, lateral esquerda/direita | MISSING_COVERAGE | Nenhum novo mundo/capture/replay de dominio |
| Foot-supported Step e stop | MISSING_COVERAGE | Nenhuma observacao primaria; nao promover fixtures antigas |
| Elegibilidade para scoring/pesquisa | NO_GO | Gates primarios nao satisfeitos; optimizer OFF |

## Quatro diagnosticos delimitados

`diagnostics_session.json` conserva a paragem primaria e o teto de quatro processos. Foram gastos exatamente quatro:

1. D1, source `dd7f77dc7b7c55011b22432174c93a4c4e9ca3cd`: contrato puro com 16 checks e uma falha. O negativo `["1024",576]` provocou `String != float` em GDScript. Este erro e preservado, nao contado como PASS. Zero corpos.
2. D2, source final `7a726febcb5257cac2cef23312c3b01d5cddb39b`: contrato puro 16/16, depois de verificar o tipo numerico antes da igualdade exata. Zero corpos.
3. D3: catch fixo headless 120 Hz, `swing_catch_train_120_headless_r1_02ec69c9`, RUN_VALID.
4. D4: catch fixo rendered 120 Hz, `swing_catch_train_120_rendered_scripted_r1_244b0d01`, RUN_VALID.

Nao existe diagnostico fisico 60 Hz nesta campanha: o processo D1 consumiu um slot. Nao ha n3, novo controlo probe OFF ou novos dominios. A pair unica de 120 Hz so permite uma conclusao diagnostica sobre estes dois processos e esta tape/fonte/ambiente.

## Cadeia fisica efetivamente observada em D3/D4

Cada audit contem 536 POST, todos com delta 1/120, massa 12 kg e alcance publicado .65708 m. O COM inicial observado em ambos e `[-.550000011920929,1.1693193912506104,.4000000059604645]`. A inicializacao headless ocorre antes do mundo; rendered observa o tamanho canonico. O clock READY antecede a criacao do mundo.

A selecao do destino tem distancia inicial .814921677 m, maior que .65708 m, e normal local de underside `[0,-1,0]`. A mao direita esta REACHING no tick 282 e ainda no 439, com forca zero; contacta efetivamente no 440. A mao de origem fica FREE no 455. A primeira retencao qualificada e no 527, .6 s depois da libertacao da origem; no fim 536 o destino continua ATTACHED e carregado. Os 97 POST desde 440 ate 536 conservam uma unica identidade runtime de ancora e um unico ponto material local por processo. Nao foi concatenada retencao de regrips diferentes.

Recalculo offline dos vetores escalares/vetoriais publicados, igual em D3/D4:

| Quantidade | Pico observado |
|---|---:|
| Soma do esforco das maos | 254.947983 N |
| Soma do esforco dos pes | 45.470654 N |
| Maior forca de um pe | 45.470654 N |
| Norma assist partilhada | 20.0000014 Nm |
| Norma momento combinado publicado | 67.245478 Nm |
| Norma forca ground motor | 168.000009 N |
| Norma torque ground motor | 41.939711 Nm |

Nao encontrei forca nao nula em maos fora de ATTACHED/SLIPPING em qualquer dos 1072 POST. Os residuos decimais do limite de assist sao da precisao nativa dos valores publicados; nao foi criado novo envelope nem tolerancia de qualificacao nesta revisao. Os invariantes publicados estao todos false e os recibos de cleanup/restauracao passam. A ausencia de body writes nao se prova apenas por um booleano: continua dependente do escopo de autoridade e da fonte auditada, alem das observacoes runtime.

Estes catches nao sao arm-only: cada processo inclui 160 POST com ground verdadeiro e 26 com algum pe marcado loaded; os picos acima confirmam contribuicoes reais. Nao atribuir a deslocacao total ou energia apenas aos bracos. Native contacts vazios tambem nao provam ausencia de contacto quando a capacidade de reporte e zero. Reacoes/forcas publicadas participam na comparacao, mas esta pair estatica nao e uma nova prova independente de conservacao de um suporte dinamico livre.

## Comparacao precisa versus legado

`diagnostic_pair_120.json` publica STRICT_MATCH nos seis canais requeridos, com `first_by_layer` nulo em ENVIRONMENT/INPUT/PICK/CONTACT/PHYSICS/TASK. `point_of_call.status` tambem e STRICT_MATCH e nao publica diferenca fisica. O parecer aceita isto apenas como comparacao diagnostica dos canais precisos publicados, sem promover a pair a BQ2 primario.

O mesmo ficheiro conserva `legacy_layers` com CURSOR_OR_CAMERA_MISMATCH no tick 55: `480.534973144531` versus `480.53497314453125`. Inspecionei os ficheiros originais: **em ambos os processos**, `benchmark_audit.json` preciso guarda o segundo valor e `virtual_audit.json` normal guarda o primeiro. Ambos se convertem no mesmo valor Vector2 float32. Assim existe evidencia direta de uma diferenca de representacao dentro de cada processo, nao de um desvio H/R no cursor preciso. Nao eliminar este achado legado, nao lhe aplicar uma tolerancia ad hoc, nem declarar igualdade de todos os ficheiros brutos. A equivalencia observada usa a representacao precisa declarada e os vetores originais de query/probe; nao demonstra equivalencia fora deste escopo.

## Fecho e identidade

A falsa rejeicao JSON esta explicada e a correcao final tem evidencias puras e uma pair fisica diagnostica. Isto nao satisfaz a qualificacao prospetiva R2 que foi corretamente interrompida. Nao recomendo retomar a campanha, reutilizar estes dois catches como replicas primarias ou iniciar tuning/holdout com base neles.

Recibos relativos a `builds/eval_virtual_cursor/benchmark_v133_r2`:

| Recibo | SHA256 lido nesta revisao |
|---|---|
| `source_identity.json` | `4401bfcd0be1815acd2e39e4414f8c1b808a159562a3f64ce53b4e0b43feab6f` |
| `diagnostic_final_source_identity.json` | `0d27b118fa1a9478b02cd2aed4e38e636386a97cf57bfa8fea612f96bb2d245b` |
| `diagnostics_session.json` | `8eb5300e21deee282de30e6732d12845dd058356ca6312ac97da172a2c949e39` |
| `diagnostic_pair_120.json` | `36f1b8a0b0687b758a2f2a45af3d7fe8df7b2ecea95577395623ec87ed1cb177` |

As regressoes de gameplay e verificacoes de release/startup comunicadas pelo root sao evidencia separada de preservacao; nao preenchem a cobertura ausente dos novos dominios. Nao ha observacao humana inventada, ganho de locomocao demonstrado, novo default aprovado ou permissao de pesquisa decorrente deste parecer.
