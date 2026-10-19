# v1.1 LP0 — auditoria física da referência

Data: 2026-10-20. Âmbito: inspeção **somente de leitura** do espelho `C:\Users\Wynter\grip_up`, confrontada com a spec `GRIP_UP_Locomotion_Refinement_Pre_M7_Spec_v1_1_EN.md`, lida integralmente, e com o [relatório pre-M7](../../reports/SISTEMA_IMPLEMENTADO_PRE_M7_PT.md).

**Não foi alterado código, tuning, input, geometria ou flags. Não foram executados Godot, suites, exportações ou sessões nativas nesta auditoria.** A única escrita deste trabalho é este documento. Não houve acesso operacional ao projeto E, Git ou MCP.

O integrador comunicou a referência `baseline/pre-v1.1-locomotion` em `6646cde`, branch `feature/v1.1-locomotion-refinement`, e a passagem de 782 checks/28 execuções dirigidas a 60/120 Hz, com 355 fontes e os ficheiros project/export preservados. Estes são resultados comunicados pelo integrador, não novas execuções do auditor. A spec cita o relatório anterior em `d4fcaec07e050593236fc5f81ff5ca51f3b0576f`; os hashes abaixo identificam os ficheiros efetivamente lidos agora. A identificação runtime comunicada é Godot **4.7.2-stable Steam**, build `ed1daf0bf`; não se deve substituir esse identificador por uma suposta execução da distribuição official.

LP0 ainda exige a sessão genuína do designer e observações concretas. O feedback positivo anterior e a travessia automatizada não encerram essa avaliação, nem autorizam promover A1/B2/C1.

## 1. Valores e seleção de perfil

Os números da tabela da spec coincidem com a fonte. É essencial distinguir o recurso genérico do perfil efetivo do bípede.

| Grandeza | Fonte atual / valor efetivo |
|---|---|
| Física | [project.godot:18](../../../project.godot#L18): 120 Hz, Jolt e interpolação ativa; comparação a 60 Hz pertence aos runners |
| Corpo | [biped_tuning.gd:5](../../../features/grip_up/resources/biped_tuning.gd#L5): 12 kg, COM personalizado na origem; a criação em [lab:297](../../../features/grip_up/scripts/grip_up_lab.gd#L297) aplica CCD e amortecimento próprio linear 0,08/angular 0,35 |
| Geometria normal | Tronco cápsula 0,98 m/r0,22; cabeça r0,13; cápsula inferior 0,84 m/r0,15; sola 0,36×0,08×0,28 m. Um único corpo; não há ragdoll de membros |
| Alcance | [biped_tuning.gd:42](../../../features/grip_up/resources/biped_tuning.gd#L42): 0,54708 m medidos até ao pulso + 0,11 m de palma = 0,65708 m |
| Atuador | Repouso 0,18–0,62 m; extensão elástica 0,04 m; K=6000 N/m, D=220 N·s/m; erro de mola limitado a 0,12 m |
| Gesto e aquisição | Mão 4 m/s; blend 0,10 s; distribuição 0,14 s. No alvo persistente a velocidade do gesto é relativa ao referencial transportado do ombro; a velocidade mundial pode incluir o transporte |
| Braços | [climbing_tuning.gd:63](../../../features/grip_up/resources/climbing_tuning.gd#L63): soma das magnitudes até 360 N; limite individual também 360 N, não 360 N por mão adicionais |
| Assistência / momento | 20 N·m partilhados de assistência; 150 N·m de momento resultante dos atuadores. Não são limites das impulsões de colisão/gravidacionais do motor |
| Intenção Tier 1 | [climbing_tuning.gd, grupo v0.7](../../../features/grip_up/resources/climbing_tuning.gd): velocidade virtual 0,25 m/s, rampa 0,12 s, resposta 4/s, aceleração virtual 1 m/s², horizonte 0,18 s, offset máximo 0,055 m |
| Alvos de repouso | Taxa 0,24 m/s; aceleração 0,9 m/s²; tracking 0,065 m; confirmação de stall 0,35 s |
| Pés | [foot_tuning.gd:3](../../../features/grip_up/resources/foot_tuning.gd#L3): 180 N no total, 120 N/pé, gesto 2 m/s, blend 0,12 s, amostragem 0,10 s |
| Balanço | [climbing_tuning.gd, grupo v0.3](../../../features/grip_up/resources/climbing_tuning.gd): pedido nominal 18 N·m, rampa 0,10 s e governador de velocidade relativa 1,8 rad/s; sujeito aos 20/150 N·m comuns |
| Caminhada | 2,6 m/s; aceleração 14 m/s², travagem 18 m/s²; torque próprio até 65 N·m, sujeito à partilha de autoridade no perfil 4 |
| Top-out | [hybrid_mantle_route.gd:8](../../../features/grip_up/scripts/hybrid_mantle_route.gd#L8): duração nominal 1,15 s. A discretização física pode acrescentar um tick ao instante observado de término |

O arranque mantém [lab:81](../../../features/grip_up/scripts/grip_up_lab.gd#L81) `physical_feet_enabled=false`, `input_profile=2`; os flags híbridos v0.9/v1.0 também começam desligados. Os botões de laboratório selecionam o perfil 4 e experiências explicitamente. First Ascent seleciona perfil 4, pés ON e híbrido v1.0; isso não muda o arranque normal. P0 é a comparação escolhida pelas arenas de intenção.

`posture_solver`, `directional_grip_quality` e `reactive_challenge` continuam propriedades de investigação: a sua presença no recurso/telemetria não demonstra implementação dos sistemas sugeridos pela v1.1. Não existem os novos seletores A1/A2/B2/C1/C2 de LP2–LP4.

## 2. Atuadores, limites e reações

### Braços e captura

[arm_actuator.gd:15](../../../features/grip_up/scripts/arm_actuator.gd#L15) calcula tensão axial não negativa com denominador implícito:

`T = max(0, (K·max(erro,0) − D·velocidade_relativa)/(1+(D·dt+K·dt²)·massa_inversa_efetiva))`.

A massa efetiva inclui a alavanca/inércia e, quando o apoio é um `RigidBody3D`, a sua contribuição. O braço não empurra. Alongar o alvo pode permitir descida por gravidade; não cria compressão numa direção indisponível. O ramo de erro suficientemente negativo elimina a tensão.

[controller:428](../../../features/grip_up/scripts/climbing_controller.gd#L428) mantém o alvo no material; no perfil 4 a resolução de superfície alcançável ocorre **no pedido**, no mesmo collider. Não acompanha automaticamente o cursor nem desliza para a próxima pega. [controller:501](../../../features/grip_up/scripts/climbing_controller.gd#L501) exige ponto atual, endpoint válido, distância anatómica, chegada finita e `CaptureEvaluator`; previsões e histerese de rótulo não autorizam contacto. Pending não entra em `_attached_ids()`. Um alvo selecionado não acrescenta força, capacidade ou um apoio virtual.

Aquisição e retenção são coisas diferentes. O alvo inicial é `clamp(separação_real,0,18,0,62)`, podendo existir pré-carga numa captura a 0,65708 m. [controller:819](../../../features/grip_up/scripts/climbing_controller.gd#L819) liberta acima de 0,62+0,04 m. O limite material, a confirmação de sobrecarga e a recuperação/saída de SLIPPING estão em [controller:1202](../../../features/grip_up/scripts/climbing_controller.gd#L1202). SLIPPING conserva autoridade reduzida; não deve ser confundido com pending sem autoridade.

### Alocação e conservação do wrench aplicado

[controller:1107](../../../features/grip_up/scripts/climbing_controller.gd#L1107) limita a soma de magnitudes dos braços e o **momento vetorial resultante**, incluindo pés e assistência. Momentos que fisicamente se cancelam não são somados como magnitudes. A distribuição de força não duplica o orçamento por haver duas mãos.

As forças dos braços são aplicadas no ombro e a reação no ponto material, em [controller:1140](../../../features/grip_up/scripts/climbing_controller.gd#L1140). Como a tração é colinear com ombro–contacto, `(S−P)×F=0`: a diferença de pontos de aplicação não deixa um binário fantasma no par ideal. A assistência angular recebe reação oposta nos apoios dinâmicos com pesos normalizados por allocation×blend; duas mãos no mesmo corpo não duplicam essa reação. Apoios estáticos pertencem ao mundo externo, não a um sistema fechado de dois corpos.

Os pés aplicam ±F no **mesmo ponto mundial** em [foot_contact_solver.gd:204](../../../features/grip_up/scripts/foot_contact_solver.gd#L204). O motor de chão aplica força no centro do personagem, reação no contacto e o contrabinário correspondente em [ground_locomotion.gd](../../../features/grip_up/scripts/ground_locomotion.gd), preservando o wrench do par no modelo de COM usado.

No perfil 4 o chão publica os vetores realmente aplicados no tick; o allocator resolve uma escala adicional para `|torque_chão + escala·torque_escalada| ≤ 150`, em [controller:1116](../../../features/grip_up/scripts/climbing_controller.gd#L1116). Isto é mais forte que somar dois budgets de 150. O chão também reserva conservadoramente espaço a partir da amostra anterior da escalada; o controller é quem faz a verificação vetorial do tick atual.

Limitações preservadas:

- O torso usa COM CUSTOM zero. O atuador genérico ainda calcula COM a partir da propriedade `body.center_of_mass`; em apoios AUTO assimétricos a massa efetiva e certas velocidades legadas são aproximadas. O novo Anchor persistente tem correção opt-in por direct state ([grip_anchor.gd:31](../../../features/grip_up/scripts/grip_anchor.gd#L31)); isso não corrigiu globalmente a massa efetiva de `arm_actuator.gd`.
- Conservação do wrench aplicado não é uma prova de conservação de energia ou de momento integrado exato em qualquer simulação Jolt, com contactos, amortecimento, gravidade e juntas externas.
- Os 180 N de pernas são capacidade separada documentada. Não são força extra dos braços; o momento combinado continua partilhado.
- O experimento v0.8 permite compressão de palma/binário de pulso, sob flags separados e dentro dos budgets existentes. Não é o mecanismo de movimento normal nem a explicação do sucesso do híbrido.

## 3. Tier 1 atual e viabilidade de A1

[intent_locomotion_coordinator.gd:75](../../../features/grip_up/scripts/intent_locomotion_coordinator.gd#L75) lê mãos realmente ATTACHED; exclui pending e, para planeamento, mãos SLIPPING. Constrói uma intenção limitada no referencial real, converte um pequeno passo corporal virtual em diferenças geométricas de comprimento e entrega alvos aos mesmos atuadores. Não move corpo, não aplica força central nem escolhe a próxima superfície.

Já existem mecanismos importantes que A1 deve preservar:

- [Captura de progresso alcançado:50](../../../features/grip_up/scripts/intent_locomotion_coordinator.gd#L50): referência absoluta por gesto/direção e âncora, em vez de somar pequenas oscilações favoráveis. Neutro não captura progressivamente o balanço passivo.
- [Envelope:68](../../../features/grip_up/scripts/intent_locomotion_coordinator.gd#L68): conserva a deformação carregada existente, permitindo avanço físico a 60 Hz sem consumir os 55 mm apenas em erro elástico.
- [Limites:188](../../../features/grip_up/scripts/intent_locomotion_coordinator.gd#L188): alvo absoluto limitado, taxa/aceleração, espera do blend de captura, deteção de stall e bloqueio de contração adicional em saturação; extensão que alivia carga continua permitida.
- Neutro elimina a nova deslocação virtual; os alvos convergem finitamente para a postura alcançada. Não congela a velocidade do corpo nem elimina colisões/pendularidade.

O sistema já usa carga para pesar o referencial, partilhar chão/escalada e detetar saturação. Isso **não equivale ao A1 da spec**. No perfil 4 não há escolha de alocação entre braços por sensibilidade translacional/angular da intenção: a distribuição normal tende a 1 para uma mão ou 0,5/0,5 para duas. A política C load-aware antiga pertence ao ramo do **perfil 3**, não ao Tier 1.

O pré-teste atual em [linhas158–165](../../../features/grip_up/scripts/intent_locomotion_coordinator.gd#L158) é apenas `abs(eixo·direção)>.12` para alguma mão e saturação a partir da telemetria anterior. Não resolve sinal de tração unilateral, distribuição de wrench, colisões futuras, envelope de fricção de todos os contactos ou alcance temporal. `POSTURE_TARGET_NOT_REACHED` é deliberadamente genérico; não prova bloqueio por colisão. Não existe a classificação completa AVAILABLE/PARTIALLY_ACTUATABLE/GEOMETRICALLY_BLOCKED da proposta.

**A1 é tecnicamente viável como experimento local posterior**, sem substituir mola ou allocator: estimar utilidade axial/carga e custo de binário por mão, produzir apenas taxas de alvo dentro dos limites atuais e aceitar direção não realizável. Uma previsão local será aproximada; não pode garantir subida ou captar a mão seguinte. A2/Jacobiano numérico no corpo vivo não está autorizado nem justificado por esta auditoria.

Estudo mínimo após os gates humanos/LP1: A0 e A1 na mesma geometria/input, primeiro parede com duas mãos assimétricas e depois viga realmente dinâmica. Medir projeção de deslocação real, torque axial versus pendular, margens/cargas, saturação e retenção. Manter pés e swing fixos nessa comparação; não promover uma mera subida mais rápida como melhoria de agência. Nenhum destes estudos novos foi executado aqui.

## 4. Pés atuais: B1, sem B2

[foothold_candidate_sampler.gd:34](../../../features/grip_up/scripts/foothold_candidate_sampler.gd#L34) pesquisa localmente em torno da pose de repouso, com offsets laterais/frontais. A classificação atual favorece viagem curta, degrau mais alto e normal capaz de suportar peso ([cost:56](../../../features/grip_up/scripts/foothold_candidate_sampler.gd#L56)). Não recebe a direção WASD, não conhece o trajeto pintado e não antecipa uma rota.

Existem estados independentes FREE/SEARCHING/PLANTING/SUPPORTING/SLIDING. Anatomia, lado da superfície, contacto atual no mesmo corpo e visibilidade são verificados por raios; uma colocação elevada usa waypoints finitos para passar sobre o espelho do degrau. SEARCHING/PLANTING não carregam peso. O contacto material pode seguir o apoio móvel; isso é transporte, não velocidade muscular infinita.

W/S já atua na extensão/redução do alvo compressivo quando há contactos válidos; logo “pés ativos” não é uma capacidade totalmente ausente. O B2 proposto é seleção/alocação **direcional** melhorada sobre esta base. O solver limita `N≥0` e `|T|≤μN`, com μ=min(0,85,fricção do apoio quando definida). Não há tração/sucção na parede. Perda de superfície/aresta elimina a força no mesmo prepare; não há rampa que conserve força fantasma depois da perda. “Suavizar perda” só poderá suavizar intenção antes da perda, nunca fingir contacto após ela.

Limitações: extremidades/segmentos e contacto são virtuais, validados sobretudo por raios/anatomia; não há pé articulado com massa nem pesquisa volumétrica completa da sola como polígono de pressão. Os limites de alcance e cone angular são uma aproximação de joelho/quadril. A guarda de compatibilidade com colisores inferiores adaptativos é exclusiva do v0.8. Não há ranking por intenção, histerese explícita entre candidatos equivalentes ou alocação otimizada mão–pé.

## 5. Balanço e referenciais

[supported_swing.gd:9](../../../features/grip_up/scripts/supported_swing.gd#L9) filtra o comando, usa `intent×lever` para obter uma direção de binário e um governador dependente da velocidade relativa. A alavanca aplicada é a média real dos ombros ao COM, ponderada por allocation×blend. Uma geometria paralela não ganha um eixo artificial nem força translacional.

O binário nominal de 18 N·m partilha o limite de 20 com amortecimento/torção; não se soma livremente a esse limite. O governador pode opor-se a velocidade acima do alvo mesmo com tecla mantida. Em neutro, a intenção existente decai pela rampa e continuam gravidade/amortecimento; não há travagem pendular autónoma que escolhe a fase ótima.

Já existe uma correção limitada de reversão explícita do perfil 4 ([coordinator:114](../../../features/grip_up/scripts/intent_locomotion_coordinator.gd#L114)): se o novo gesto é oposto ao anterior recente, evita a primeira das duas rampas em série, conservando a rampa física de 0,10 s do swing. A memória curta cobre um zero entre teclas até à duração de 0,12 s, sem inventar um comando depois da libertação. Não constitui C1 novo nem garante travagem eficaz em qualquer fase.

[locomotion_support_frame.gd:18](../../../features/grip_up/scripts/locomotion_support_frame.gd#L18) mantém orientação transportada no material, prioridade das normais das mãos sobre pés de apoio e mistura de 0,10 s para mudanças comuns de normal. Câmara sozinha não gira um referencial já estabelecido. O fallback inicial horizontal usa `normal×camera_right` com handedness preservada. Normais quase opostas usam o material dominante sem interpolar por zero: não se pode afirmar que toda mudança de canto é sempre suave.

P0/P1/P2 e A/B/C continuam comparadores do perfil 3. P1 corrige torção axial relativa ao apoio; P2 altera postura/tilt e foi rejeitado como melhoria geral. Não se deve atribuir ao perfil 4 uma assistência P2 só porque a UI mantém o seletor. Estudos anteriores de pump/brake e P1 encontram-se em [M2](../V05_M2_PHYSICS.md) e [M3](../V05_M3_PHYSICS.md); não são resultados novos de LP0 nem ratings de jogadores.

## 6. Transições e autoridade

| Transição | O que a fonte faz / limite da afirmação |
|---|---|
| Chão + pending | [ground_locomotion.gd:27](../../../features/grip_up/scripts/ground_locomotion.gd#L27) ignora pending persistente como motivo para desligar caminhada; não passa a apoio de escalada |
| Chão → carga de mãos/pés | O motor corre antes do controller no perfil 4, mede força anterior projetada na normal e limita authority a 6/s; ar passa imediatamente a zero. O controller consome o snapshot final do mesmo tick para partilha/momento |
| Uma ↔ duas mãos | Inicializa a nova pega a partir de separação real, blend e allocation graduais. Retira apenas a mão libertada; a sobrevivente mantém âncora e alvo. A força pode redistribuir-se fisicamente sem haver uma atribuição direta de velocidade |
| Perda de pés | Remove contacto inválido; mantém os restantes se válidos. Uma stance existente pode continuar sem mãos, mas não começa autonomamente novas colocações sem contacto de escalada |
| Chão + pé no mesmo corpo | [controller:1100](../../../features/grip_up/scripts/climbing_controller.gd#L1100) filtra esse pedido de pé para evitar dois motores no mesmo contacto de chão |
| Chão nativo | O chão normal tem ray/intervalo de sola até 18 mm; `require_native_support` é false por defeito. Híbrido e v0.8 exigem adicionalmente contacto nativo FootBase e carga. Não afirmar que todo perfil/cenário já usa essa exigência estrita |
| Commit híbrido | [hybrid:96](../../../features/grip_up/scripts/hybrid_mantle_controller.gd#L96) retira pegas/forças normais, suspende chão e passa ao motor cinemático certificado; não é subida produzida pelos budgets de músculos |
| RESTORE → chão | Geometria standing, sola nativa no apoio correto e orientação válida; sob v1.0 também revalida o material. Invalidação retém a pose atual congelada/R, sem reconstruir colisores ou recuar a outra pose |
| DYNAMIC_GROUNDED | Depois de entregar à caminhada normal, o guard RESTORE não volta a congelar o corpo se o apoio mudar. Vitória exige também 30 cm de caminhada real relativa ao suporte |

Nada nesta inspeção mede uma distribuição nova de aceleração/jerk ou latência humana. Há continuidade de estado e budgets na fonte; afirmar que uma transição “já é confortável” exigiria a sessão LP0 e traces de evento, não apenas a leitura.

## 7. Lacunas de observação concretas para LP1

Estas são observações de fonte, sem patch ou diagnóstico inventado de sessão humana:

1. **Pedido swing legado versus perfil 4.** [lab:604](../../../features/grip_up/scripts/grip_up_lab.gd#L604) zera `set_swing_intent` e chama `set_traversal_input`. O esforço real do perfil 4 vem de `intent_locomotion.swing` em [controller:1063](../../../features/grip_up/scripts/climbing_controller.gd#L1063). O campo genérico `telemetry.swing_requested` e a emissão `SWING_AXIS_UNACTUATED` em `transfer_diagnostics.sample` ainda consultam `_swing_requested`. Podem mostrar zero/não emitir causa mesmo com pedido real. Para o baseline ler também `intent_locomotion.swing_request_world` e o binário aplicado; corrigir o observador só depois do gate apropriado.
2. **Pé a deslizar ainda suporta.** `actual_foot_count` e os contactos do frame do coordenador contam apenas SUPPORTING, enquanto o solver e o loadshare de chão aceitam SLIDING com força real. O rótulo pode omitir autoridade existente. Não usar apenas esse contador para concluir “nenhum pé faz força”; inspecionar `foot.force`, N/T e os pedidos admitidos.
3. **Velocidade relativa do Tier 1.** A referência de velocidade translacional do coordenador agrega velocidades das mãos, não a dos pés no modo foot-only. Em apoios diferentes não é uma descrição completa do movimento relativo a todos os contactos.
4. **Viabilidade e saturação aproximadas.** A verificação axial não é um solver unilateral e a saturação usa a amostra anterior. Não converter o motivo genérico de stall em “colisão provada”.
5. **Energia.** `swing_power` representa contribuição incremental depois do cap comum, contra spin relativo ponderado pelos apoios. O integral distingue pump/brake no modelo, mas exclui trabalho gravitacional, colisões, drag, juntas e energia dos outros corpos. Pendularidade orbital `r×v/|r|²`, twist axial e tilt corporal são grandezas diferentes; não substituí-las por yaw/RMS indistinto.
6. **Segurança não é garantia de captura.** Há janelas curtas, overshoot e retenções perdidas legitimamente. Sucesso de contacto, carga retida e conclusão de percurso devem continuar separados. O histórico First Ascent preservou falhas renderizadas antes das escolhas mais curtas; os passes posteriores não apagam esse histórico.

## 8. Testes existentes relevantes — inventário, não nova execução

Links referem asserções existentes. A lista não declara que todos foram reexecutados nesta auditoria; recibos LP0 pertencem ao integrador.

| Contrato | Suites existentes |
|---|---|
| Tier 1, nenhum apoio/pending, budgets, referencial/apoio dinâmico | [test_intent_locomotion.gd](../../../features/grip_up/tests/test_intent_locomotion.gd) |
| Progresso sob carga a 60/120, neutro, S, bloqueio sem windup | [test_intent_progress.gd](../../../features/grip_up/tests/test_intent_progress.gd) |
| Reversão explícita/zero curto/neutro longo e reação | [test_intent_reversal.gd](../../../features/grip_up/tests/test_intent_reversal.gd) |
| Sinal inicial em teto, handedness e orbit sem retarget | [test_intent_frame_sign.gd](../../../features/grip_up/tests/test_intent_frame_sign.gd) |
| Pump/coast/brake, tecla mantida 12 s, material dinâmico | [test_intent_swing.gd](../../../features/grip_up/tests/test_intent_swing.gd), [test_swing_diagnostics.gd](../../../features/grip_up/tests/test_swing_diagnostics.gd), [test_posture_study.gd](../../../features/grip_up/tests/test_posture_study.gd) |
| Contacto/fricção, nenhum esforço antes do plant, pé em falta, perda, momento do par | [test_foot_support.gd](../../../features/grip_up/tests/test_foot_support.gd), [test_foot_integration.gd](../../../features/grip_up/tests/test_foot_integration.gd) |
| Chão, apoio móvel, ausência em ar e transições de carga | [test_ground_locomotion.gd](../../../features/grip_up/tests/test_ground_locomotion.gd), [test_intent_integration.gd](../../../features/grip_up/tests/test_intent_integration.gd), [test_intent_handoffs.gd](../../../features/grip_up/tests/test_intent_handoffs.gd) |
| Alvo distante em movimento, colisão/COM, contacto versus retenção, reação do par | [test_pending_motion.gd](../../../features/grip_up/tests/test_pending_motion.gd), [test_pending_contact.gd](../../../features/grip_up/tests/test_pending_contact.gd), [test_reachable_grip.gd](../../../features/grip_up/tests/test_reachable_grip.gd) |
| Preservação da rota/corpo, obstáculos, restauração e guard RESTORE | [test_hybrid_motor.gd](../../../features/grip_up/tests/test_hybrid_motor.gd), [test_hybrid_resilience.gd](../../../features/grip_up/tests/test_hybrid_resilience.gd), [test_vault_restore_guard.gd](../../../features/grip_up/tests/test_vault_restore_guard.gd), [test_vault_resilience.gd](../../../features/grip_up/tests/test_vault_resilience.gd) |
| Percurso composto, progresso real e caminhada final | [test_first_ascent.gd](../../../features/grip_up/tests/test_first_ascent.gd), [first_ascent_exercise.gd](../../../features/grip_up/tests/first_ascent_exercise.gd), captura nativa separada |

O próximo trabalho permitido continua a ser a observação genuína de Step/Hang/Traverse/Corner/First Ascent. A1, B2, C1/C2, transições novas, qualidade direcional, câmara e M7 **não foram implementados ou promovidos por LP0**.

## 9. Identidade das fontes auditadas

SHA256 dos bytes lidos no espelho C, sem normalizar fins de linha. Estes hashes documentam esta leitura; o checkpoint/manifesto de release é responsabilidade do integrador.

| Ficheiro | SHA256 |
|---|---|
| project.godot | `6ae2782544aa70dfb6a099260ead68de0b0bb7007093ef846bbb2dabfc6a86c9` |
| resources/biped_tuning.gd | `b8a4f1aaa01c7563144dbbc10b80046fbb4a33fedd7addf75989a028349714c3` |
| resources/climbing_tuning.gd | `daca2f518dc0ebd9cd5be79cb94d2e55d359ae760e807a8b0c14f00d9eea96c4` |
| resources/foot_tuning.gd | `fac341838df47ca0a649d33fb276f28173019254cac251ac0db9d118c875aa72` |
| scripts/intent_locomotion_coordinator.gd | `812d6956c23af7261ed766cf715c63b1b8848f8c11a023f199a0271564aff71f` |
| scripts/locomotion_support_frame.gd | `a28df3c2f54fda33f7b11fe71c76a171ea18958533db3a0b8b3bb57e8481011c` |
| scripts/arm_actuator.gd | `0d7cb1db9a1748e1d7c986db71ac6dd0d553f7f9fe8646afa24f20a6e66a45b7` |
| scripts/climbing_controller.gd | `6690d00d1d1bb35d54a943a8761960c9694497976ba98bdd7359b9ab96bdbd60` |
| scripts/supported_swing.gd | `30add7cec43245b57908f0f0513087d7fbc6c2f12f2be87978f34d4b90aa7255` |
| scripts/foot_contact_solver.gd | `d3f2047806cdb909e11bfd1dd1b9589669c93e02df1ef0ced410678bc190f061` |
| scripts/foothold_candidate_sampler.gd | `47bbe40523b0fff92554e790128fabe3d7f08cbf523f82c8d36cd5c52a5f04a9` |
| scripts/ground_locomotion.gd | `26178a4b0bd0083f20a4ecf82a501f3b56815ac561f40aeb994b530f99b91798` |
| scripts/hybrid_mantle_controller.gd | `00579a4030cf23a17e498c32cace29a4a72b83c56dfcb8dee6a828ac528808bd` |

Todos os caminhos abreviados desta tabela são relativos a `features/grip_up/`, exceto `project.godot`.
