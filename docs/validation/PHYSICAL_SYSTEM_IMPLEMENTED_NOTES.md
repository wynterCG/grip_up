# Notas para o relatório integral — sistema físico implementado

Auditoria de código na fonte C após o gate físico v0.6 M3. Estas notas distinguem mecanismos implementados, aproximações e experiências; não substituem a contagem agregada nem os ensaios nativos/humanos mantidos pelo agente principal. Nenhuma alteração de produção foi feita para escrever este documento.

## Corpo, representação e passo de simulação

O personagem físico é **um único RigidBody3D de12kg**, com COM personalizado na origem da pélvis. Não é CharacterBody nem um ragdoll de membros articulados. A colisão usa proxies simples no mesmo corpo: cápsula de tronco, esfera de cabeça, cápsula de pernas e caixa de sola plana. A sola evita a instabilidade de repousar uma cápsula arredondada num ponto. O perfil também conserva uma alternativa de cápsula única para comparação.

Jolt está explicitamente configurado com120 passos/s; as suites também correm com60. A representação interpolada segue a física. O modelo Quaternius, skeleton, TwoBoneIK e poses dos dedos são apresentação: os modificadores de ossos não escrevem a pose ou velocidades do RigidBody. Os braços e pernas visuais não têm massas, colisores articulados nem forças próprias de ragdoll.

Fontes: `project.godot`, `resources/biped_tuning.gd`, `scripts/grip_up_lab.gd`, `scripts/biped_visual.gd`, `scripts/biped_hand_pose.gd`.

## Braços: forças finitas, não uma junta rígida ilimitada

Cada mão guarda um ponto e normal locais num suporte fraco/referenciado por WeakRef. O ponto segue a transformação material atual; não fica preso no espaço quando uma viga roda. Os ombros vêm da pose física e offsets medidos: aproximadamente x±.1919m, y+.5241m, z+.0153m relativamente à pélvis.

O atuador é uma mola axial de **tração apenas**. Com comprimento L, alvo L0, eixo do ombro para a âncora e velocidade relativa u nesse eixo, a implementação usa:

`F = max(0, K*max(0, clamp(L-L0)) - D*u) / (1 + (D*dt + K*dt²)*inverse_effective_mass)`

Um braço claramente frouxo não empurra o corpo nem o suporte. A massa efetiva inclui inversa da massa translacional e termo rotacional com tensor de inércia e braço de alavanca; o suporte dinâmico também contribui. O denominador implícito e as convenções de ponto material/velocidade foram adaptados do core de pegas anterior de janga_proto. Não se reutilizou um servo de pose do torso que voasse para o cursor.

No bípede: K6000N/m, D220Ns/m, erro limitado a.12m; alvo .18..62m; alcance ombro→palma .65708m; margem elástica .04m e limite físico de extensão .66m. O alcance de seleção/contacto e o alvo da mola são parâmetros distintos. Catch no limite .65708m pode iniciar com .03708m de preload; o alvo não é aumentado para esconder esse erro.

A aquisição utiliza smoothstep de.10s e alocação com resposta.14s. Uma mão nova não recebe força antes do contacto. Duas mãos partilham a autoridade, melhorando geometria e distribuição, sem duplicar capacidade de levantamento.

Fontes: `scripts/arm_actuator.gd`, `scripts/grip_anchor.gd`, `scripts/climbing_controller.gd`, `resources/climbing_tuning.gd`, `resources/biped_tuning.gd`.

## Orçamentos, reações e significado do modelo de pega

- Soma das magnitudes das forças de braço <=360N; limite por braço também360N. A soma não usa cancelamento de forças opostas para oferecer força grátis.
- Assistência total de atitude/swing <=20Nm, partilhada entre mecanismos.
- Momento **resultante vetorial** no torso, incluindo alavancas das forças e pernas opcionais, <=150Nm. Momentos fisicamente opostos podem cancelar; somar todas as suas magnitudes impediria movimentos translacionais válidos.
- A força do braço entra no ombro; a reação oposta entra no ponto material do suporte. Como a força é colinear à separação, o par conserva o wrench interno de força/momento.
- A assistência de rotação transmite um binário oposto aos suportes atuais, ponderado pela alocação e blend reais. Duas mãos no mesmo suporte não duplicam esse binário.

Isto representa um **gripper capaz de transmitir binário finito**, não uma junta pontual ideal sem momento. As mãos também não são limitadas por um cone de atrito de dedos; a capacidade é uma aproximação de pega finita controlada por `grip_load_limit`/limites de integridade. Não é uma simulação detalhada de tendões, contacto de dedos ou fricção da mão.

Acima da capacidade, o estado muda para SLIPPING após.20s; a força é reduzida por.65, há recuperação se a carga baixa durante.16s e libertação se o escorregamento persiste. O limite elástico também pode perder um catch. Contactar e conseguir reter são resultados distintos.

O ensaio de PinJoint Jolt demonstrou que uma junta sem este limitador suportava490N num corpo de50kg, acima dos360N disponíveis. Esse ensaio explica a escolha dos atuadores explícitos; não prova que nenhuma solução com juntas e limitadores pudesse ser construída.

## Locomoção no chão

O motor de terceira pessoa atua no **mesmo** corpo, com forças finitas e direção relativa à câmara. Exige plano caminhável, torso suficientemente vertical e sola praticamente em contacto: limite superior de gap .018m, tolerância de penetração -.04m, normal vertical>.65. Não há controlo aéreo nem salto por atribuição de velocidade. O motor pára durante REACHING legado/ATTACHED/SLIPPING; uma seleção distante puramente pendente v0.6 não desativa a caminhada.

Velocidade nominal2.6m/s; aceleração máxima14m/s² e travagem18m/s². Upright e servo de yaw partilham65Nm só no chão. Em suporte dinâmico, o motor usa velocidade do ponto de contacto e aplica reação de força e um contrabinário que compensa a diferença entre força no COM do jogador e reação no contacto.

É um motor de solo simplificado, não uma marcha gerada por forças de cada perna. A força central de caminhada é limitada e condicionada pelo contacto; não é um modelo completo de cone de atrito e forças plantares humanas. O binário65Nm não é uma segunda assistência aérea que se some aos20Nm de escalada.

Fonte: `scripts/ground_locomotion.gd`.

## Swing suportado e controlo de rotação

WASD nos perfis experimentais pede uma direção horizontal mundial calculada a partir da câmara. O router conserva a referência por gesto/tecla, evitando que MMB ou dolly mude silenciosamente a direção física já pedida.

`supported_swing.gd` transforma a direção em binário usando o braço de alavanca real COM→ombro, ponderado pelas mãos realmente adquiridas. A direção mantém significado quando o torso roda. Há rampa de.10s, pedido máximo18Nm e governador dependente da velocidade angular relativa, com referência1.8rad/s. Acelerações e travagens são trabalho realizado através do suporte; depois de largar todas as âncoras, não existe propulsão ou assistência aérea residual.

Esse swing partilha20Nm com o controlo de twist e atitude. O twist de base usa referência adquirida e eixo do tronco, ganhos16/3, fade de projeções singulares e blend de contacto. Não congela rotação ou impõe uma orientação por transform. A inércia, gravidade e damping continuam a produzir um pêndulo; duas mãos restringem naturalmente mais do que uma.

## Perfis de entrada preservados

| Perfil | Comportamento físico |
|---|---|
|0, legado|W encurta o alvo axial, S alonga; A/D distribui carga ou pede binário limitado relativo à vista. Mantém a comparação original.|
|1, drag|Deslocamento de rato por mão adquirida é consumido uma vez por passo e limitado a.6m/s de alteração do alvo; WASD pede swing suportado. Alvos não são reancorados ao mover a câmara.|
|2, contextual|Movimento relativo do rato pede esforço filtrado baseado na geometria atingida. Arrastar para baixo contrai; para cima pede extensão ativa. Guarda postura conseguida e relaxa pedidos bloqueados, sem integrar pixels indefinidamente num comprimento. Rato também dirige a mira virtual da mão livre; este acoplamento foi rejeitado como UX, mas está preservado para comparação.|
|3, independent aim|Rato seleciona superfícies; nunca fornece comprimentos, forças ou metas de postura. WASD mantém swing suportado. Políticas A/B/C abaixo só reagem a apoios físicos reais.|

O código portátil atual declara perfil2 por omissão, com hold-to-grip ligado. Os testes/runtime podem selecionar explicitamente perfil3. Não confundir configuração de uma sessão com mudança do default fonte. Flags v0.5/v0.6 são opt-in e falsas por omissão.

## Postura A/B/C e variantes P0/P1/P2 são dois eixos distintos

**A/HOLD_LENGTH:** conserva comprimentos adquiridos, sem subida automática. **B/BOUNDED_AUTO_PULL:** calcula uma configuração confortável absoluta a partir de apoios materiais atuais, ombros, COM e afastamento de superfície. **C/LOAD_AWARE_AUTO_PULL:** usa o mesmo planeamento limitado, mas pondera dois apoios pela capacidade/geometria/massa do suporte; alocações limitadas aproximadamente a.2..8.

O conforto atual usa30% do intervalo .18..62m: cerca de.312m. Os alvos avançam no máximo.25m/s e1m/s²; o settle pára após2s, slip/perda de apoio, saturação ou bloqueio. A travagem finita pode continuar um pequeno avanço, que é medido; não é um corte instantâneo de velocidade do alvo. A mesma configuração material tem plano absoluto em cache: largar/agarrar repetidamente o mesmo ponto não acrescenta altura acumulada. Não há objetivo dependente do próximo marcador ou do cursor.

**P0:** lógica de atitude v0.4 preservada. **P1:** transporta a referência de twist com a rotação material observada e usa velocidade axial relativa ao suporte. Mantém16/3 e os mesmos20Nm; melhora twist no suporte móvel, não a amplitude de roll na parede estática. **P2:** experiência de preferência de tilt viável, com frame/COM/apoios atuais e rate/acceleration/blend limitados. Substitui/crossfade a assistência anterior, sem outro motor de20Nm.

P2 ficou explicitamente **REJECT como default**, disponível apenas como experiência: alguns ensaios reduziram tilt mas pioraram a duração da janela da mão livre ou a dinâmica pendular. Não é correto dizer que P2 foi uma melhoria geral ou que o projeto ganhou um solver completo de postura humana.

Fontes: `scripts/support_posture_planner.gd`, `scripts/arm_target_coordinator.gd`, `scripts/supported_twist_refinement.gd`, `scripts/supported_posture_refinement.gd`; resultados em `V05_M2_PHYSICS.md`, `V05_M2_P2_PHYSICS.md`, `V05_M3_PHYSICS.md`.

## Space/dyno

Space segura uma carga através de extensão real limitada (.75m/s, duração nominal.45s); ao largar, pede contração até2m/s por até.30s e liberta as âncoras originais, preservando momentum. Charge mínimo.08s e cooldown.45s. Só atua por braços adquiridos; não chama um impulso central ou escreve velocidade. A identidade das âncoras impede que uma mão acabada de agarrar seja largada por uma sequência de lançamento antiga.

Perfis1/2/3 exigem `experimental_launch_enabled`, falso por omissão; perfil0 conserva a comparação. Ganho de altura e retenção do catch dependem de posição, curso realmente disponível e janela de alcance; não há promessa universal de apanhar um ponto .82m acima. As séries de teste e capturas distinguem pico de altura, contacto momentâneo e retenção.

## Pernas: apresentação passiva versus contacto físico opcional

As pernas passivas de apresentação têm alvos pendulares independentes, afetados por gravidade e aceleração do quadril, com limites anatómicos e transições suaves. Quando totalmente suspensas, tendem a.999 do comprimento natural; não há agachamento arbitrário constante. Piso/obstáculos podem encurtar o alvo e dobrar o joelho. Estes alvos não aplicam forças ao corpo.

`physical_feet=false` é uma experiência separada, efetivamente implementada. Cada pé pode estar FREE/SEARCHING/PLANTING/SUPPORTING/SLIDING, procura candidato, desloca-se a2m/s com caminho varrido, verifica contacto atual/alcance, guarda contacto local e aplica mola unilateral de compressão. N>=0 e |T|<=μN; no ar ou separado não suga a parede nem puxa o apoio. A capacidade total de pernas é180N, por pé120N; soma de momento entra no mesmo limite global150Nm. Não aumenta o orçamento de braços360N, mas é uma fonte física adicional de apoio explicitamente separada.

A força/reação entram no mesmo ponto mundial de contacto, representando uma perna virtual sem massa que transmite momento. Contactos válidos já existentes podem sustentar momentaneamente uma postura sem mãos; não surgem novos apoios autonomamente sem intenção de escalada. Um alvo distante pendente por si só não autoriza plantar novos pés. O motor de caminhada e o solver de pés têm handoff para não duplicar motores de solo. Nos perfis independentes, W/S são swing e não o antigo comando direto de extensão dos pés; contactos opcionais continuam a suportar passivamente.

Fontes: `scripts/biped_leg_motion.gd`, `scripts/foot_contact_solver.gd`, `scripts/foothold_candidate_sampler.gd`, `resources/foot_tuning.gd`.

## Seleção, previsão, buffers e v0.6 não são a mesma autorização

O targeting faz raycasts reais da câmara, incluindo pequenos samples de assistência existentes; UI e sólidos occludentes são tratados no app. A seleção guarda o ponto/normal, não uma posição conveniente próxima.

- O predictor v0.2 fornece NOW/SOON/UNAVAILABLE num horizonte limitado .10..25s, nominal.20s, usando viagem finita da mão e movimento material. Não autoriza contacto futuro.
- O buffer antigo faz uma única tentativa held por alvo, com prazo nominal.15s; a integração v0.5 usa .12s, opt-in no perfil3. Não repete cliques depois do timeout.
- O reach advisory v0.5 é leitura apenas. Prevê janelas amostradas e velocidades e estima risco de carga; confiança cai em suportes móveis, rotação, contactos e dinâmica já suportada. É explicitamente não certificado, sem autorização nem speed-deny arbitrário. Houve testes de equivalência física bit a bit advice OFF/ON.
- v0.6 guarda uma seleção distante enquanto o botão está realmente segurado, sem horizonte/timeout curto. O endpoint transporta-se com o ombro e tem gesto próprio4m/s relativo à frame; todo o segmento mundial é varrido. O alvo não puxa nada enquanto pendente. Pode voltar a fora de alcance ou ficar bloqueado, continuar a esperar e só adquirir ao chegar ao contacto atual válido. Não usa previsão para fixar.

O CaptureEvaluator verifica alcance atual, mão junto do ponto, ray local de contacto, normal e LOS. A velocidade relativa/energia restante são diagnósticos de risco, não garantias de apanhar/reter. Em v0.6 esta avaliação é sempre obrigatória mesmo com a previsão/buffer antigos desligados. O modo OFF conserva a recusa antiga de out-of-reach e o caminho legado.

Fonte v0.6: `scripts/pending_grip_target.gd`; contrato e evidência em `V06_M1_PHYSICS.md`, `V06_M2_PHYSICS.md`, `V06_M3_PHYSICS.md`.

## Diagnóstico e limites de precisão

O journal de transferência distingue REQUEST/TRANSIT/CONTACT/RETENTION, immutable snapshots por tentativa e falhas como POSE_UNREACHABLE/PATH_OBSTRUCTED/HAND_TOO_SLOW/CATCH_OVERLOAD/GRIP_SLIP. SUCCESS de contacto não apaga uma perda posterior. Cancelamentos de botão/UI/focus são neutros. Ring e fila de eventos têm capacidade256; snapshots atuais mantêm duas mãos. Logs JSONL em disco são por sessão/processo; não são um array de memória ilimitado por frame.

Telemetria separa twist axial, swing pendular, trabalho/potência incremental e PUMPING/BRAKING/NEUTRAL, esforços/reações e budgets. Trabalho estimado por atuadores não é uma certificação de energia mecânica total: gravidade, contactos, damping e dissipação do integrador também contam. O cache do planeador é por configuração material durante o teste e é limpo no reset; não é o ring de256 eventos.

Limitações materiais a declarar: mãos/braços virtuais com ray de ponto, sem colisão volumétrica de todos os membros; rig visual não é ragdoll; motor de solo simplificado; planos de postura não resolvem toda a dinâmica futura; mãos são grippers aproximados; suportes AUTO-COM ainda têm aproximação de massa efetiva no atuador legado. v0.6 corrige somente velocidade do ponto nas novas âncoras opt-in. A conservação do wrench aplicado é testada separadamente da deriva angular integrada do Jolt em corpos anisotrópicos a rodar — a deriva também aparece com o controlador desligado.

Flags `posture_solver`, `directional_grip_quality`, `reactive_challenge` em ClimbingTuning permanecem pontos de experiência/telemetria sem implementação física correspondente ligada a essas flags. Isso não invalida o planeamento A/B/C realmente implementado, nem a viga reativa real das cenas, mas não devem ser apresentados como sistemas futuros já completos.

## Evidência e estado de aceitação

Os ensaios atuais cobrem signs/tensão/folga, forças/torques, um/dois apoios, reações dinâmicas, swing/catch, captura versus retenção, lançamentos, alcance total, chão, pernas passivas, pés físicos, policies/variantes, flags OFF e os gates M1/M2/M3 de seleção distante, em60/120Hz. A fonte contém comparações isoladas e rotas por input real; estas últimas e o total agregado final pertencem ao relatório do agente principal.

Uma rota automatizada que passa não certifica conforto humano. Native MCP comprova eventos e apresentação reais, não substitui sessões humanas/rating. O parecer físico de v0.6 M3 é PASS dentro das fixtures descritas, com o default experimental ainda OFF; KEEP/REVISE/REJECT de UX deve citar os resultados M4 reais e as limitações observadas.
