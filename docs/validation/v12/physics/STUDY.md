# v1.2 — repetições físicas A1/B2, pés e swing

Estado: **sem alteração dos mecanismos físicos, parâmetros ou defaults**. Trabalho em C mirror, headless; sem E/Git/MCP. As variantes continuam opt-in. Não houve sessões humanas neste estudo.

## Identidade e proveniência

O recurso de identidade preparado pela raiz identifica `feature/v1.2-locomotion-tests`, baseline `328c4c82868ac97005badb81230ba7eb0346b537`, árvore de desenvolvimento dirty. Não se apresenta esta working tree como um commit limpo. `study_001/summary.json` contém SHA256 antes/depois de onze ficheiros relevantes: controller, coordinator, A1, ambos módulos dos pés, três recursos, os dois runners v11 e project.godot. São idênticos entre início e fim das doze execuções.

Runtime: Godot `4.7.2.stable.steam.ed1daf0bf`, Jolt. SHA256 do executável usado: `12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38`. O hash de ficheiro não é o hash Git abreviado do engine. Foram confirmados no live source os valores do bípede: 12 kg, alcance palma `0.54708 + 0.11 = 0.65708 m`, alvo de mola .18–.62 m com extensão elástica .04 m, K6000/D220, mãos360 N, pernas180 N/120 N por pé, assist20 Nm, momento150 Nm, planner .24 m/s e .9 m/s². Os defaults base antigos de `climbing_tuning.gd` não substituem os overrides do `biped_tuning.gd`.

## Estudo repetido v11, sem reinterpretar as métricas antigas

`features/locomotion_test_suite/tests/study_v12.py --repeats 3` executou os runners v11 originais, sem os editar: allocation e feet, três vezes em cada frequência. **12 execuções válidas, 636 checks / 0 falhas técnicas**. Cada stdout/JSON foi preservado em `study_001/`; `summary.json` inclui valores individuais, média, mínimo, máximo, range, desvio padrão, comandos e hashes.

Estas são repetições do mesmo estado inicial, não três seeds/participantes. Dentro de cada grupo os valores observados foram iguais (range zero); isso demonstra repetibilidade desta execução, não ausência universal de variabilidade do Jolt. Não há intervalo de confiança populacional.

A projeção antiga usa o **body origin** e direção `normalize(input.x,input.y,0)`; não se relabelou como COM ou como nova métrica v12. O twist antigo usa eixo do tronco, projetando body-right e world-right nesse eixo; não é idêntico ao eixo de carga de todos os diagnósticos de suporte. Esta definição foi mantida para reproduzir honestamente a regressão conhecida.

| caso / Hz | A0 progresso | A1 progresso | Δ A1−A0 | A0 twist RMS | A1 twist RMS |
|---|---:|---:|---:|---:|---:|
| assimétrico /120 | .208892 m | .188734 m | −.020159 m | .049775 rad | .073677 rad |
| assimétrico /60 | .200003 m | .186510 m | −.013493 m | .062303 rad | .078325 rad |
| diagonal assimétrico /120 | .108477 m | −.006197 m | −.114674 m | .049372 rad | .097907 rad |
| diagonal assimétrico /60 | .094688 m | −.007042 m | −.101730 m | .055917 rad | .099487 rad |

A1 reduziu progresso e aumentou twist nos quatro grupos. A diagonal continua com progresso **negativo**. Decisão: **REVISE**, sem tentar alterar parâmetros para passar. As verificações técnicas continuam válidas porque distinguem resultado funcional negativo de violação dos orçamentos físicos.

No Step de personagem completo: A0 fixo, B0 pés OFF; B1/B2 pés ON; mesmas mãos adquiridas por gesto real e W durante 3 s. Média das três repetições:

| Hz | B0 subida | B1 subida | B2 subida | Δ B2−B1 | trabalho positivo B1/B2 |
|---|---:|---:|---:|---:|---:|
| 120 | .159642 m | .272321 m | .271633 m | −.688 mm | 20.721 /20.747 J |
| 60 | .135616 m | .273284 m | .273139 m | −.145 mm | 20.529 /20.645 J |

A integral das mãos B1/B2 foi 257.137/257.330 N·s a120 e 238.482/238.271 N·s a60. Subida, carga e trabalho não mostram uma vantagem consistente de B2. O ganho grande B0→B1 pertence aos pés já existentes, não ao ranking novo. O estudo v11 anterior teve diferenças submilimétricas que mudaram de sinal a60; não foram descartadas nem convertidas em prova de superioridade. Decisão global B2: **INCONCLUSIVE**, sem promoção.

## T05 / FEET_02 — prova nova espelhada e normal inclinada

`test_measurement_physics.gd` acrescenta dois pares de saliências de verdade, cada qual com espelho equivalente de corpo, geometria e comando. Plana e inclinada ±.12 rad; mesma superfície μ=.85. São fixtures isolados de perna virtual: corpo de12 kg com esfera pequena e gravidade zero. Não se afirma que reproduzem todas as colisões do bípede. O corpo só se desloca pela aplicação das forças existentes; nenhuma velocidade é atribuída após inicialização.

A geometria nova é data-driven em `features/locomotion_test_suite/resources/technical_fixtures_r1.json`, schema `technical_fixtures_v12_1`, revisão1. Define spawn/forma do corpo de prova, yaw de espelho e posições/tamanhos/inclinações de candidatos. O cálculo de altura conserva `base_y + tan(tilt) × x` em double antes de converter para Vector3, tal como na autoria anterior. Massas, inércias, atrito, forças, parâmetros anatómicos, tempos e orçamento do solver não foram retunados ou substituídos pelo recurso.

O loader recusa revisão/schema e formas/regras não suportadas antes de executar o ensaio. Os outputs registam `fixture_path`, `fixture_revision`, `fixture_sha256` e `outcome_changes_expected:false`. Os fixtures de swing/reação herdados, e os antigos runners A1/B2, continuam sem alterações.

Cada combinação compara B0/B1/B2, primeiro gesto finito/plantação e depois .25 s de esforço. Os sinais são relativos à intenção do próprio espelho:

| geometria / Hz | B1 progresso | B2 progresso | resultado |
|---|---:|---:|---|
| plana /120 | −4.264 mm | +4.264 mm | B2 corrige a direção neste caso |
| plana /60 | −4.079 mm | +4.079 mm | idem |
| inclinada /120 | −10.213 mm | −10.213 mm | B2 falha em corrigir apoio; ambos contra intenção |
| inclinada /60 | −9.839 mm | −9.839 mm | idem |

Todos estes resultados se repetem no espelho correspondente; B0 permanece sem força/movimento. Na inclinação o custo de saliência alta vence a utilidade com sinal e B2 mantém o mesmo apoio inadequado. **A gate funcional de benefício B2 em múltiplas geometrias NÃO foi satisfeita.** O JSON contém `B2_benefit_gate_met=false` e `MOVEMENT_AGAINST_INTENT`; não se alterou força, geometria ou scoring para esconder a falha. O resultado local recomenda revisão do ranking, e o resultado global continua sem benefício demonstrado.

## T06 — pump, coast, brake e comando constante

O novo runner reutiliza o fixture e APIs de `test_intent_reversal.gd`, profile4/A0. O estado inicial oscilante é ganho por .6 s de D em apoio real. Não há escrita de velocidade. Pump/brake são políticas **scripted** de fase angular atual, sem antecipação nem controlador novo em gameplay. São iguais quanto à geometria e preparação.

Trabalho de swing é `decomposition.swing_after_common_cap · relative_spin × dt`, contribuição incremental da fonte de swing já existente. Não inclui trabalho axial, potencial gravitacional, todos os torques ou energia total. A proxy cinética soma os campos relativos existentes, sem os declarar conservação do sistema.

| Hz | política / duração | trabalho incremental | maior ângulo pendular | pico torque swing |
|---|---|---:|---:|---:|
| 120 | pump /2 s | +11.573 J | .3671 rad | 16.082 Nm |
| 120 | coast /2 s | +.799 J | .2537 rad | 12.174 Nm |
| 120 | brake /2 s | −2.262 J | .2185 rad | 17.841 Nm |
| 120 | D constante /8 s | +.597 J | .3026 rad | 17.884 Nm |
| 60 | pump /2 s | +11.554 J | .3646 rad | 16.097 Nm |
| 60 | coast /2 s | +.758 J | .2515 rad | 11.982 Nm |
| 60 | brake /2 s | −2.205 J | .2179 rad | 17.934 Nm |
| 60 | D constante /8 s | +.622 J | .3014 rad | 17.882 Nm |

Todos retêm o apoio e respeitam os caps. Neutral tem trabalho residual inicial porque o comando anterior atravessa os filtros existentes; não foi apresentado como zero imediato. O pedido raw é zero, o máximo residual depois de1 s é ~.00138/.00122 Nm e o torque final a2 s é zero. Não existe nova travagem autónoma. O comando constante produz trabalho positivo e negativo durante fases diferentes; pico cinético relativo ~3.81/3.79 J e velocidade pendular ~.728/.719 rad/s nesse ensaio de8 s. Isto não prova limitação energética assintótica nem facilidade de aprendizagem humana.

## T10 / sem propulsão no ar

O runner reutiliza ainda o fixture fechado de reações de `safety_and_reaction`: dois braços no mesmo suporte dinâmico, gravidade e drag zero, inércias isotrópicas para isolar o wrench dos erros giroscópicos discretos. Contracomando real; sem editar o solver. Resíduos finais:

- 120 Hz: |Δp| = 4.78e−7 kg·m/s; |ΔL| = 7.70e−6 kg·m²/s; pico torque swing14.996 Nm.
- 60 Hz: |Δp| = 4.81e−7 kg·m/s; |ΔL| = 1.14e−6 kg·m²/s; pico15.047 Nm.

Também foi libertado o apoio e mantido comando oposto: força e assist são zero em todos os ticks amostrados sem apoio, sem motor horizontal aéreo. Trata-se de reação/wrench e perda de autoridade nos fixtures indicados, não de prova de qualquer tarefa dinâmica ou autorização para mantle em apoios móveis.

## Testes, falhas preservadas e limites

Novo runner físico: **55 checks /0 falhas técnicas a120 e55 /0 a60**; JSON `builds/measurement_physics_<hz>hz.json`, logs e cópias finais nesta pasta. A validação numérica separada terminou com56/56 por frequência após extensão overshoot/settling, prioridade de onset/PREHELD e cleanup de warnings. Com as12 repetições antigas: **858 checks finais em16 execuções**, não somando iterações de desenvolvimento nem a matriz completa da raiz. O checkpoint anterior48+55+repetições correspondia a842, preservado nos logs históricos.

Última revalidação do runner físico: **55/55 em ambas as frequências após extração da geometria para JSON**, logs/JSON em `geometry_refactor/`. `geometry_refactor/before/` preserva fonte e resultados anteriores. `geometry_refactor/comparison.json` demonstra igualdade exata de todos os outcomes físicos reportados (cada seleção espacial/normal/deslocamento/trabalho/carga dos pés, swing, reação e decisões) entre autoria em código e revisão1. Identidades de instância/diagnósticos de seleção, que são processuais, não entram nessa igualdade. Nenhum outcome adverso deixou de existir.

Hashes finais desta alteração:

- `test_measurement_physics.gd`: SHA256 `831dc77effc77df377a7a248531e1283d06d52ec8d52a07c7fe73567fd1c9cf2`.
- `technical_fixtures_r1.json`: SHA256 `fdfe4f483171c73e3007b2e26030c4e04cfa8dc12eff9566483392c033b6037a`.

O runner anterior à extração tinha SHA256 `e12a001b5272509ab3740f885b1ffcec3a097bcce155caa61216d0b355ed11fb`, preservado em `geometry_refactor/before/test_measurement_physics.gd.txt`. Os valores numéricos das tabelas acima continuam exatamente os mesmos.

`development_001/` preserva55 checks com2 falhas em cadaHz: expectativa injustificada de B2 positivo na inclinação e expectativa de torque neutral já zero após1 s. `development_002/` preserva a segunda iteração que confundia pedido filtrado com pedido raw. As asserções finais não promovem o outcome negativo a sucesso: preservam explicitamente o caso adverso no teste e no relatório. Nenhuma mudança física ocorreu entre essas iterações; corrigiram-se definições do ensaio, não tolerâncias para permitir mais força.

Faltam comparações humanas, várias posturas/velocidades iniciais e variedade de colisão do bípede em ambos os normais. O fixture de pés não mede redução de carga da mão porque não contém braços: essa medida vem separadamente do Step completo. T07/M-C, transições, export e benchmark10 minutos pertencem aos outros componentes/validação da raiz. Não os reivindico como cobertos por estes runners.

Recomendação física desta amostra: manter A0/B1, A1 REVISE, B2 sem promoção e com caso inclinado a rever. Pump/brake possuem sinais mecânicos distinguíveis num teste scripted; não demonstram domínio de um jogador. Não autoriza automaticamente M7 nem uma nova configuração default.
