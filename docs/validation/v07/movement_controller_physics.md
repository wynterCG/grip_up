# v0.7 — controlador de movimento: auditoria física

Data: 19 de outubro de 2026. Estado: **candidato técnico opt-in; decisão humana M5 pendente**. Não é aprovação dos controlos nem prova de diversão. M6 mantle/top-out e M7 desafio reativo não foram implementados nesta ronda.

## Contrato e autoridade

Foi lida integralmente a especificação `GRIP_UP_Intent_Driven_Physical_Locomotion_Spec_v0_7_EN.md`. O baseline v0.6 foi protegido pelo agente principal antes das alterações; ver [baseline_snapshot.md](baseline_snapshot.md). A ronda M0 executou os 3116 checks existentes. Este suplemento cobre os módulos físicos; o principal regista input real, arenas, capturas nativas e regressão agregada.

O perfil novo é `control_profile=4`, com `intent_climb_enabled=false` por omissão. Os perfis 0–3 não recebem o novo coordenador. Não se alteraram massa 12 kg, K=6000 N/m, D=220 N·s/m, erro axial máximo .12 m, rest .18–.62 m, alcance de contacto .65708 m, extensão elástica .04 m, gesto de mão 4 m/s, orçamento de mãos 360 N, assistência 20 N·m, momento resultante 150 N·m ou orçamento opcional dos pés 180 N/120 N por pé. P0 continua a referência; o novo perfil não liga P2 nem o planner automático A/B/C. Space continua opt-in e desligado na experiência inicial.

API pública adicionada a [climbing_controller.gd](../../../features/grip_up/scripts/climbing_controller.gd):

```gdscript
controller.set_control_profile(4)
controller.intent_climb_enabled = true
controller.set_traversal_input(Vector2(direita, cima), camera_right)
controller.set_ground_support(snapshot)
```

O snapshot do chão contém `grounded`, `point`, `normal`, `support_id`, `velocity`/`point_velocity`, `authority`/`motor_authority` e, sobretudo, `applied_force`/`applied_torque` **deste mesmo tick**. O motor de chão é executado primeiro pelo principal. O snapshot é informativo: o coordenador não cria contactos. A cópia de diagnóstico remove a referência Node `support`, mantendo IDs depois de um reset de cena.

Os únicos novos escritores de objetivos físicos são [intent_locomotion_coordinator.gd](../../../features/grip_up/scripts/intent_locomotion_coordinator.gd) e a integração explícita do controller. Nenhum escreve pose, velocidade linear/angular, impulso ou força livre de COM. As forças continuam exclusivamente nos `ArmActuator`, `FootContactSolver`, motor de chão e assistência reagida existentes.

## Modelo mínimo implementado

O coordenador Tier 1 normaliza o vetor digital e limita a subida do comando em .12 s. Calcula uma velocidade **virtual** de .25 m/s, uma aceleração virtual limitada a 1 m/s² e um horizonte geométrico de .18 s. O deslocamento virtual é limitado a .055 m. Não é uma velocidade atribuída ao corpo.

Para cada mão realmente `ATTACHED`, calcula a diferença entre a distância atual ombro–âncora e a distância que resultaria de deslocar o ombro por esse pequeno objetivo. Essa diferença modifica um comprimento de postura já alcançado, sempre dentro dos limites anatómicos. O avanço do objetivo usa o envelope de travagem e aceleração do `arm_target_coordinator.gd`: máximo .24 m/s e .9 m/s². A captura de postura alcançada e a relaxação de procura bloqueada adaptam a abordagem geométrica usada nos controlos anteriores; não integram segundos de W em metros de contração escondida.

A captura de extensão/contração tem janela de assentamento de .25 s depois do comando. Depois, o estado neutro mantém a postura alcançada, sem seguir indefinidamente a deformação elástica. Saturação observada acima de 94% da força ou escala central abaixo de .90, slipping ou erro de seguimento persistente interrompem o avanço e deixam a velocidade do objetivo travar limitadamente. Os testes mantêm o corpo livre para continuar o seu movimento por inércia.

Foi corrigido um erro encontrado durante a comparação de rates: extrapolar diretamente a velocidade descendente do corpo fazia um pedido W planear **extensão**, particularmente a 60 Hz. A expressão atual é `v_des*h + .5*a_req*h*h`, limitada pelo mesmo pequeno envelope. Não se aumentou força nem alcance para resolver essa inversão.

Não existe otimizador Tier 2, pesquisa de próxima pega ou destino no cursor. A distribuição entre duas mãos continua a distribuição comum suavizada existente, com aquisição ~.10 s e resposta de alocação ~.14 s. O coordenador não afirma que um objetivo de comprimento atingido corresponde a uma rota concluída.

## Referencial e estados

[locomotion_support_frame.gd](../../../features/grip_up/scripts/locomotion_support_frame.gd) usa normais e materiais de apoios reais, nunca o alvo pendente. Normais opostas escolhem um material dominante em vez de normalizar zero. Em teto/overhang, a projeção vertical degenerada usa a tangente anterior e depois um fallback geométrico. O material dominante transporta a base anterior. A normal é filtrada em .10 s.

**Correção importante descoberta na captura nativa:** misturar a normal de compressão UP de um pé muito carregado com a normal WALL de uma mão fazia W rodar cerca de 80° para dentro da parede sem mudar geometria nem câmara. Havendo mãos reais, agora são essas normais que definem a tangente de escalada; pés continuam listados e participam na capacidade, modo e forças. A regressão usa um pé com peso 100 contra mão .05 e mantém W=UP durante um segundo. Sem mãos, os apoios reais remanescentes podem definir o referencial.

Política de sinais explícita: `r = up.cross(normal_outward)`. Preserva gravity-up e handedness válida. A câmara serve de fallback onde a tangente é degenerada; não pode inverter apenas r e criar uma base refletida. D é a lateral geométrica da superfície, não screen-right para qualquer posição inicial da câmara do outro lado da parede. Uma órbita durante o gesto não muda a direção física. Casos de cantos/tetos foram verificados numericamente quanto a finitude e ortogonalidade; legibilidade humana nesses casos ainda não foi estabelecida.

Modos publicados: `GROUNDED`, `GROUNDED_REACHING`, `CLIMB_TWO_HANDS`, `HANG_ONE_HAND`, `CLIMB_HANDS_FEET`, `FOOT_TRANSITION`, `AIRBORNE` e `FALLING_RECOVERY`. Um pending isolado não muda AIRBORNE para escalada. Pés precisam de contactos SUPPORTING reais. Slipping não recebe novos objetivos de deslocamento. Contactos perdidos deixam imediatamente de autorizar propulsão.

## Chão, pés e reação

O principal fornece a fração de participação do chão a partir de carga realmente medida. O motor de chão possui a componente horizontal que lhe corresponde; a componente horizontal do objetivo e o swing do coordenador são escalados por `1-authority`. Tração vertical pode começar enquanto há peso no chão, evitando o deadlock “braços slack → chão100% → braços nunca podem puxar”. Não se força uma separação vertical do chão.

Pedidos de pés no **mesmo corpo de chão** são excluídos antes do commit do solver. Pés numa saliência distinta conservam o solver de compressão/fricção existente. W/S alimenta o objetivo de extensão de perna existente; não cria outra força ascendente. Pés são opcionais e não foram ativados por omissão.

O controller inclui o vetor de momento já aplicado pelo motor de chão no limite do mesmo tick. Resolve `|tau_ground + s*tau_climb| <= 150` para reduzir a escala comum admissível de mãos/pés/assistência. `telemetry.torque` mantém o significado anterior de escalada; `combined_ground_climb_torque` expõe a soma nova. O limite refere-se aos atuadores modelados, não a momentos externos de colisões arbitrárias.

Cada força de mão atua no ombro e tem oposta na âncora material; a força é axial, pelo que a diferença dos pontos não cria um binário residual livre. O momento de gripper/swing tem reação oposta distribuída por alocação×blend. Duas mãos no mesmo material repartem **um** momento, não dois. Pés aplicam força e oposta no mesmo ponto real de contacto. Permanecem as aproximações documentadas na v0.6: braço virtual sem massa, momento finito de gripper idealizado, colisões de gesto por raios/segmentos e massa efetiva AUTO assimétrica aproximada no actuator legado.

## Resultados dedicados

Comandos usados, ambos com backend Jolt do projeto:

```powershell
python C:\Users\Wynter\grip_up\tools\project.py test test_intent_locomotion
python C:\Users\Wynter\grip_up\tools\project.py test test_intent_locomotion -- --60hz
python C:\Users\Wynter\grip_up\tools\project.py test test_intent_swing
python C:\Users\Wynter\grip_up\tools\project.py test test_intent_swing -- --60hz
```

| Suite nova | 120 Hz | 60 Hz |
|---|---:|---:|
| `test_intent_locomotion.gd` | 49 / 0 falhas | 49 / 0 falhas |
| `test_intent_swing.gd` | 30 / 0 falhas | 30 / 0 falhas |

Logs: `builds/test_test_intent_locomotion*.log`, `builds/test_test_intent_swing*.log`. Dados: `builds/intent_locomotion_120hz.json`, `_60hz.json`, `builds/intent_swing_120hz.json`, `_60hz.json`. A mensagem de certificado Windows no stderr de alguns ensaios60 não é erro de script; o helper valida footer, failures e ausência de SCRIPT ERROR.

O fixture dedicado de braços usa cápsula de ensaio de 1.7 m, 12 kg e os mesmos ganhos/alcances, não o rig composto completo. Por isso os resultados seguintes são medidas mecânicas; The Step do principal verifica o corpo composto real.

| Medida dedicada, 1.2 s de comando | 120 Hz | 60 Hz |
|---|---:|---:|
| Uma mão, neutral, deslocamento Y | −.0296 m | −.0312 m |
| Uma mão, W, deslocamento Y | +.0284 m | +.0274 m |
| Ganho W face ao mesmo neutral | +.0581 m | +.0585 m |
| Duas mãos, W, deslocamento Y | +.0997 m | +.1036 m |
| Duas mãos W, pico de mãos | 294.7 N | 262.7 N |
| Uma mão S, alteração de rest | +.0885 m | +.0884 m |
| Uma mão D: x face ao neutral | +.1136 m | +.1276 m |

S não é descida garantida: neste fixture a60 o braço acabou por perder contacto por extensão anatómica. Essa falha é preservada no JSON; o check verifica que a extensão é comandada sem compressão/força descendente inventada. A120 esse contacto reteve no intervalo observado. Não se aumentou a margem .04 m para igualar os resultados.

O ensaio articulado tem 15 kg, a mesma superfície do controlo fixo e hinge real. A reação leva-o ao seu stop (~−.2000 rad neste sentido/convenção Jolt). A120 a mão retém e o corpo sobe .0638 m no intervalo medido; a60 perde contacto durante o assentamento inicial e o comando posterior não produz força. Logo este fixture demonstra reação e **uma limitação de retenção**, não sucesso universal em suportes móveis. A variação Y posterior do suporte é pequena porque já assentou no stop antes do intervalo W. Não se deve atribuir essa rotação inteira ao W posterior.

O par fechado dinâmico adicional usa inércias isotrópicas de ensaio, zero gravidade e damping, evitando confundir drift giroscópico do integrador com reação do atuador. A120: erro de momento linear 9.54e−7 kg·m/s; angular 7.18e−7 kg·m²/s; residual de wrench axial 2.40e−7 N·m. A60: 4.95e−7, 5.36e−7 e 1.33e−7 respetivamente. O ensaio aplica tração e ~10.4 N·m de assistência reais; não testa apenas forças zero.

### Balanço: pedido, trabalho e limites

Mesma geometria, cinco segundos, um apoio real:

| Comando deliberado | Trabalho incremental swing120 / 60 | Energia cinética relativa máxima120 / 60 |
|---|---:|---:|
| Neutral | 0 / 0 J | 1.651 / 1.651 J |
| Pump com fase | +19.913 / +20.178 J | 7.830 / 7.779 J |
| Brake antecipado | −.616 / −1.334 J | 1.149 / 1.175 J |

O trabalho é `tau_swing_after_cap.dot(omega_body−omega_support_weighted)`, não energia total do mundo. Exclui gravidade, contactos, atrito, juntas e outros atuadores. O fixture de brake antecipa a inversão em .20 s para compensar as rampas existentes. Um script que só invertia ao observar a velocidade mudar de sinal fez +2.6 J de trabalho líquido a120, apesar de reduzir amplitude; esse comportamento motivou a medição com timing explícito. Não se alega travagem automática nem facilidade humana estabelecida.

D continuamente durante12 s não causa aceleração ilimitada no fixture: pico .770/.764 m/s numa mão; energia tardia .00198/.00361 J. Com duas mãos: pico .199/.209 m/s e energia tardia ~.0023/.0024 J. As mãos retêm, os caps mantêm-se e, ao largar todos os apoios, força e assistência tornam-se exatamente zero.

## Respostas às dez perguntas de investigação

1. **Uma mão:** tensão só pode puxar para a âncora. W ganhou ~5.8 cm face ao neutral; D lateral alterou o pendular face ao neutral, usando até20 N·m, mas não comandou uma translação axial impossível. Sem apoio, ON/OFF produz exatamente a mesma trajetória balística. Um eixo paralelo ao lever de ombro não fornece o binário desejado; a classificação axial `DIRECTION_UNACTUATABLE_AXIAL_SWING_ONLY` não promete que swing conseguirá alcançar qualquer alvo.
2. **Duas mãos:** a geometria fixa permitiu ~10 cm de subida em1.2 s, com pico de força inferior a360 N. Não se adicionou capacidade por mão. A transição2→1 preserva âncora, rest e velocidades do sobrevivente no evento.
3. **Pés:** só o solver existente pode plantar e empurrar. A integração The Step do principal, antes da correção final do frame, mediu a120 ~.130 m com pésOFF e ~.287 m ON, catch superior apenas ON, pico de pés ~78.4 N e trabalho positivo ~17.8 J; carga integrada das mãos ~383→317 N·s. Estes números são desenvolvimento, não aprovação final pós-fix. O principal arquiva/reexecuta os ensaios finais. O benefício vem de compressão real, não da pose IK.
4. **Retargeting:** sim, o Tier1 produz movimento COM e neutro com drift de rest <3 mm depois de .8 s de assentamento +1 s de observação. Quatro segundos contra teto bloqueador mantêm erro<.10 m e caps; ao soltar não há metros de objetivo acumulado. Isso não prova ausência de oscilação em toda geometria.
5. **Comparação A/B/C:** não há prova de superioridade geral nem motivo para Tier2 nesta ronda. No The Step de desenvolvimento, baseline B/C subiu ~.106 m e não adquiriu o alvo alto; novo perfil com pés conseguiu-o. Essa é uma diferença localizada de coordenação/capacidade. Não se empilham os planners B/C e o novo coordenador.
6. **Reação móvel:** os resíduos do par dinâmico confirmam a reação de mão e momento partilhado. A v0.6 já cobre reação compressiva de pés no mesmo ponto; a nova integração reutiliza-a sem outro caminho de força. Não foi acrescentada nesta ronda uma prova fechada de conservação com mão+pé no mesmo beam articulado e contactos externos simultâneos; esse teste fica explicitamente em aberto.
7. **60/120 Hz:** o ganho W relativo mantém-se semelhante; picos e retenção em condições adversas diferem. S e hinge unilateral mostram perdas60 preservadas. O erro de inversão de W foi um bug de planeamento corrigido, não escondido com tuning. As mesmas rampas mantêm resposta finita, mas exigem antecipação para brake.
8. **Orientação:** P0 permanece, com o twist longitudinal finito já existente. Não se introduziu motor upright/P2. O ensaio one-hand ainda oscila e roda; boa postura visual não está garantida. O frame de escalada deixou de rodar com a participação vertical dos pés, separando essa legibilidade de um lock do torso.
9. **Impossibilidade:** zero apoios, pending-only, slipping, direção axial sem alavanca, saturação e erro persistente têm guardas distintas. A integridade/limites continuam a poder soltar uma pega; o coordenador não congela velocidade para “resolver” impossibilidade. Tracking parado é rotulado `POSTURE_TARGET_NOT_REACHED`: não afirma colisão sem evidência de contacto nem distingue perfeitamente equilíbrio de força e obstrução.
10. **Assistência vs autoplay:** só WASD pode pedir deslocamento novo. Cursor e alvo pendente não entram no objetivo COM. Neutral conserva apenas o alcançado; mão distante não atrai o corpo; sem apoio o trajeto é balístico igual ao controlo. Nenhuma mão é redirecionada para outra superfície. Pés podem procurar candidatos locais através do sampler já existente, nunca uma rota.

## Telemetria e decisão provisória

`telemetry.intent_locomotion` expõe input bruto/filtrado, `input_frame_id`, timestamp e frame de origem; modo/frame/IDs; intenção e velocidade virtual; velocidade relativa real; `actual_com_displacement`/`actual_height_gain`; goals/rates/acelerações; reversões voluntárias; saturação; motivo primário; ação dos pés e tempo do planner em µs. Ganho real de altura não é deduzido do sucesso de targets. Tempo de input até progresso, contagens de correções, conforto e agência humana exigem os ensaios do principal/M5; não foram inventados a partir de checks.

Regressões existentes executadas pelo especialista nesta ronda: core45 ambosHz, pending_contact47 a120 e independent_physics89 a120. A regressão agregada e native final são responsabilidade do principal e devem ser citadas na decisão geral com o estado pós-fix do frame. Os logs iniciais com falhas e capturas anteriores ao frame fix foram preservados em `docs/validation/v07/development/`.

**Decisão física: KEEP como candidato isolado M1–M4, REVISE/avaliar com humanos antes de qualquer promoção.** Há avanço útil mãos+pés, balanço fisicamente auditável e negativas seguras. Ainda não há evidência de que o jogador se sente a escalar melhor; tetos/cantos, descida no limite, retenção em beams e timing de travagem continuam limites honestos. Não avançar M6/M7 com base nestas contagens.
