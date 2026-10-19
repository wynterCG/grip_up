# GRIP UP — Física implementada até v0.6

Suplemento técnico ao [relatório integral do projeto](SISTEMA_IMPLEMENTADO_V06_PT.md), baseado na auditoria da fonte após o gate físico v0.6 M3. Distingue mecanismos implementados, aproximações e experiências. A contagem agregada, as capturas nativas e a validação humana final pertencem ao relatório principal. Nenhuma alteração de produção foi feita para escrever este documento.

## Corpo, representação e passo de simulação

O personagem físico é **um único RigidBody3D de 12 kg**, com COM personalizado na origem da pélvis. Não é CharacterBody nem um ragdoll de membros articulados. A colisão usa proxies simples no mesmo corpo: cápsula de tronco, esfera de cabeça, cápsula de pernas e caixa de sola plana. A sola evita a instabilidade de repousar uma cápsula arredondada num ponto. O perfil também conserva uma alternativa de cápsula única para comparação.

Jolt está explicitamente configurado com 120 passos/s; as suites também correm com 60. A representação interpolada segue a física. O modelo Quaternius, skeleton, TwoBoneIK e poses dos dedos são apresentação: os modificadores de ossos não escrevem a pose ou velocidades do RigidBody. Os braços e pernas visuais não têm massas, colisores articulados nem forças próprias de ragdoll.

Fontes: `project.godot`, `resources/biped_tuning.gd`, `scripts/grip_up_lab.gd`, `scripts/biped_visual.gd`, `scripts/biped_hand_pose.gd`.

## Braços: forças finitas, não uma junta rígida ilimitada

Cada mão guarda um ponto e normal locais num suporte fraco/referenciado por WeakRef. O ponto segue a transformação material atual; não fica preso no espaço quando uma viga roda. Os ombros vêm da pose física e offsets medidos: aproximadamente x±0.1919 m, y+0.5241 m, z+0.0153 m relativamente à pélvis.

O atuador é uma mola axial de **tração apenas**. Com comprimento L, alvo L0, eixo do ombro para a âncora e velocidade relativa u nesse eixo, a implementação usa:

`F = max(0, K*max(0, clamp(L-L0)) - D*u) / (1 + (D*dt + K*dt²)*inverse_effective_mass)`

Um braço claramente frouxo não empurra o corpo nem o suporte. A massa efetiva inclui inversa da massa translacional e termo rotacional com tensor de inércia e braço de alavanca; o suporte dinâmico também contribui. O denominador implícito e as convenções de ponto material/velocidade foram adaptados do core de pegas anterior de janga_proto. Não se reutilizou um servo de pose do torso que voasse para o cursor.

No bípede: K = 6000 N/m, D = 220 Ns/m, erro limitado a 0.12 m; alvo 0.18–0.62 m; alcance ombro→palma 0.65708 m; margem elástica 0.04 m e limite físico de extensão 0.66 m. O alcance de seleção/contacto e o alvo da mola são parâmetros distintos. Catch no limite 0.65708 m pode iniciar com 0.03708 m de preload; o alvo não é aumentado para esconder esse erro.

A aquisição utiliza smoothstep de 0.10 s e alocação com resposta 0.14 s. Uma mão nova não recebe força antes do contacto. Duas mãos partilham a autoridade, melhorando geometria e distribuição, sem duplicar capacidade de levantamento.

Fontes: `scripts/arm_actuator.gd`, `scripts/grip_anchor.gd`, `scripts/climbing_controller.gd`, `resources/climbing_tuning.gd`, `resources/biped_tuning.gd`.

## Orçamentos, reações e significado do modelo de pega

- Soma das magnitudes das forças de braço <= 360 N; limite por braço também 360 N. A soma não usa cancelamento de forças opostas para oferecer força grátis.
- Assistência total de atitude/swing <= 20 Nm, partilhada entre mecanismos.
- Momento **resultante vetorial** no torso, incluindo alavancas das forças e pernas opcionais, <= 150 Nm. Momentos fisicamente opostos podem cancelar; somar todas as suas magnitudes impediria movimentos translacionais válidos.
- A força do braço entra no ombro; a reação oposta entra no ponto material do suporte. Como a força é colinear à separação, o par conserva o wrench interno de força/momento.
- A assistência de rotação transmite um binário oposto aos suportes atuais, ponderado pela alocação e blend reais. Duas mãos no mesmo suporte não duplicam esse binário.

Isto representa um **gripper capaz de transmitir binário finito**, não uma junta pontual ideal sem momento. As mãos também não são limitadas por um cone de atrito de dedos; a capacidade é uma aproximação de pega finita controlada por `grip_load_limit`/limites de integridade. Não é uma simulação detalhada de tendões, contacto de dedos ou fricção da mão.

Acima da capacidade, o estado muda para SLIPPING após 0.20 s; a força é reduzida por 0.65, há recuperação se a carga baixa durante 0.16 s e libertação se o escorregamento persiste. O limite elástico também pode perder um catch. Contactar e conseguir reter são resultados distintos.

O ensaio de PinJoint Jolt demonstrou que uma junta sem este limitador suportava 490 N num corpo de 50 kg, acima dos 360 N disponíveis. Esse ensaio explica a escolha dos atuadores explícitos; não prova que nenhuma solução com juntas e limitadores pudesse ser construída.

## Locomoção no chão

O motor de terceira pessoa atua no **mesmo** corpo, com forças finitas e direção relativa à câmara. Exige plano caminhável, torso suficientemente vertical e sola praticamente em contacto: limite superior de gap 0.018 m, tolerância de penetração -0.04 m, normal vertical>0.65. Não há controlo aéreo nem salto por atribuição de velocidade. O motor pára durante REACHING legado/ATTACHED/SLIPPING; uma seleção distante puramente pendente v0.6 não desativa a caminhada.

Velocidade nominal 2.6 m/s; aceleração máxima 14 m/s² e travagem 18 m/s². Upright e servo de yaw partilham 65 Nm só no chão. Em suporte dinâmico, o motor usa velocidade do ponto de contacto e aplica reação de força e um contrabinário que compensa a diferença entre força no COM do jogador e reação no contacto.

É um motor de solo simplificado, não uma marcha gerada por forças de cada perna. A força central de caminhada é limitada e condicionada pelo contacto; não é um modelo completo de cone de atrito e forças plantares humanas. O binário 65 Nm não é uma segunda assistência aérea que se some aos 20 Nm de escalada.

Fonte: `scripts/ground_locomotion.gd`.

## Swing suportado e controlo de rotação

WASD nos perfis experimentais pede uma direção horizontal mundial calculada a partir da câmara. O router conserva a referência por gesto/tecla, evitando que MMB ou dolly mude silenciosamente a direção física já pedida.

`supported_swing.gd` transforma a direção em binário usando o braço de alavanca real COM→ombro, ponderado pelas mãos realmente adquiridas. A direção mantém significado quando o torso roda. Há rampa de 0.10 s, pedido máximo 18 Nm e governador dependente da velocidade angular relativa, com referência 1.8 rad/s. Acelerações e travagens são trabalho realizado através do suporte; depois de largar todas as âncoras, não existe propulsão ou assistência aérea residual.

O governador limita a autoridade no eixo solicitado;1.8 rad/s não é um limite universal da velocidade angular ou linear do corpo. Gravidade, outras direções e a geometria dos apoios continuam a contribuir para o movimento.

Esse swing partilha 20 Nm com o controlo de twist e atitude. O twist de base usa referência adquirida e eixo do tronco, ganhos 16/3, fade de projeções singulares e blend de contacto. Não congela rotação ou impõe uma orientação por transform. A inércia, gravidade e damping continuam a produzir um pêndulo; duas mãos restringem naturalmente mais do que uma.

## Perfis de entrada preservados

| Perfil | Comportamento físico |
|---|---|
|0, legado|W encurta o alvo axial, S alonga; A/D distribui carga ou pede binário limitado relativo à vista. Mantém a comparação original.|
|1, drag|Deslocamento de rato por mão adquirida é consumido uma vez por passo e limitado a 0.6 m/s de alteração do alvo; WASD pede swing suportado. Alvos não são reancorados ao mover a câmara.|
|2, contextual|Movimento relativo do rato pede esforço filtrado baseado na geometria atingida. Arrastar para baixo contrai; para cima pede extensão ativa. Guarda postura conseguida e relaxa pedidos bloqueados, sem integrar pixels indefinidamente num comprimento. Rato também dirige a mira virtual da mão livre; este acoplamento foi rejeitado como UX, mas está preservado para comparação.|
|3, independent aim|Rato seleciona superfícies; nunca fornece comprimentos, forças ou metas de postura. WASD mantém swing suportado. Políticas A/B/C abaixo só reagem a apoios físicos reais.|

O código portátil atual declara perfil 2 por omissão, com hold-to-grip ligado. Os testes/runtime podem selecionar explicitamente perfil 3. Não confundir configuração de uma sessão com mudança do default fonte. Flags v0.5/v0.6 são opt-in e falsas por omissão.

## Postura A/B/C e variantes P0/P1/P2 são dois eixos distintos

**A/HOLD_LENGTH:** conserva comprimentos adquiridos, sem subida automática. **B/BOUNDED_AUTO_PULL:** calcula uma configuração confortável absoluta a partir de apoios materiais atuais, ombros, COM e afastamento de superfície. **C/LOAD_AWARE_AUTO_PULL:** usa o mesmo planeamento limitado, mas pondera dois apoios pela capacidade/geometria/massa do suporte; alocações limitadas aproximadamente a 0.2–0.8.

O conforto atual usa 30% do intervalo 0.18–0.62 m: cerca de 0.312 m. Os alvos avançam no máximo 0.25 m/s e 1 m/s²; o settle pára após 2 s, slip/perda de apoio, saturação ou bloqueio. A travagem finita pode continuar um pequeno avanço, que é medido; não é um corte instantâneo de velocidade do alvo. A mesma configuração material tem plano absoluto em cache: largar/agarrar repetidamente o mesmo ponto não acrescenta altura acumulada. Não há objetivo dependente do próximo marcador ou do cursor.

**P0:** lógica de atitude v0.4 preservada. **P1:** transporta a referência de twist com a rotação material observada e usa velocidade axial relativa ao suporte. Mantém 16/3 e os mesmos 20 Nm; melhora twist no suporte móvel, não a amplitude de roll na parede estática. **P2:** experiência de preferência de tilt viável, com frame/COM/apoios atuais e rate/acceleration/blend limitados. Substitui/crossfade a assistência anterior, sem outro motor de 20 Nm.

P2 ficou explicitamente **REJECT como default**, disponível apenas como experiência: alguns ensaios reduziram tilt mas pioraram a duração da janela da mão livre ou a dinâmica pendular. Não é correto dizer que P2 foi uma melhoria geral ou que o projeto ganhou um solver completo de postura humana.

Fontes: `scripts/support_posture_planner.gd`, `scripts/arm_target_coordinator.gd`, `scripts/supported_twist_refinement.gd`, `scripts/supported_posture_refinement.gd`; resultados em `V05_M2_PHYSICS.md`, `V05_M2_P2_PHYSICS.md`, `V05_M3_PHYSICS.md`.

## Space/dyno

Space segura uma carga através de extensão real limitada (0.75 m/s, duração nominal 0.45 s); ao largar, pede contração até 2 m/s por até 0.30 s e liberta as âncoras originais, preservando momentum. Charge mínimo 0.08 s e cooldown 0.45 s. Só atua por braços adquiridos; não chama um impulso central ou escreve velocidade. A identidade das âncoras impede que uma mão acabada de agarrar seja largada por uma sequência de lançamento antiga.

Perfis 1/2/3 exigem `experimental_launch_enabled`, falso por omissão; perfil 0 conserva a comparação. Ganho de altura e retenção do catch dependem de posição, curso realmente disponível e janela de alcance; não há promessa universal de apanhar um ponto 0.82 m acima. As séries de teste e capturas distinguem pico de altura, contacto momentâneo e retenção.

## Pernas: apresentação passiva versus contacto físico opcional

As pernas passivas de apresentação têm alvos pendulares independentes, afetados por gravidade e aceleração do quadril, com limites anatómicos e transições suaves. Quando totalmente suspensas, tendem a 0.999 do comprimento natural; não há agachamento arbitrário constante. Piso/obstáculos podem encurtar o alvo e dobrar o joelho. Estes alvos não aplicam forças ao corpo.

`physical_feet=false` é uma experiência separada, efetivamente implementada. Cada pé pode estar FREE/SEARCHING/PLANTING/SUPPORTING/SLIDING, procura candidato, desloca-se a2 m/s com caminho varrido, verifica contacto atual/alcance, guarda contacto local e aplica mola unilateral de compressão. N>=0 e |T|<=μN; no ar ou separado não suga a parede nem puxa o apoio. A capacidade total de pernas é180 N, por pé 120 N; soma de momento entra no mesmo limite global 150 Nm. Não aumenta o orçamento de braços 360 N, mas é uma fonte física adicional de apoio explicitamente separada.

A força/reação entram no mesmo ponto mundial de contacto, representando uma perna virtual sem massa que transmite momento. Contactos válidos já existentes podem sustentar momentaneamente uma postura sem mãos; não surgem novos apoios autonomamente sem intenção de escalada. Um alvo distante pendente por si só não autoriza plantar novos pés. O motor de caminhada e o solver de pés têm handoff para não duplicar motores de solo. Nos perfis independentes, W/S são swing e não o antigo comando direto de extensão dos pés; contactos opcionais continuam a suportar passivamente.

Fontes: `scripts/biped_leg_motion.gd`, `scripts/foot_contact_solver.gd`, `scripts/foothold_candidate_sampler.gd`, `resources/foot_tuning.gd`.

## Seleção, previsão, buffers e v0.6 não são a mesma autorização

O targeting faz raycasts reais da câmara, incluindo pequenos samples de assistência existentes; UI e sólidos occludentes são tratados no app. A seleção guarda o ponto/normal, não uma posição conveniente próxima.

- O predictor v0.2 fornece NOW/SOON/UNAVAILABLE num horizonte limitado 0.10–0.25 s, nominal 0.20 s, usando viagem finita da mão e movimento material. Não autoriza contacto futuro.
- O buffer antigo faz uma única tentativa held por alvo, com prazo nominal 0.15 s; a integração v0.5 usa 0.12 s, opt-in no perfil 3. Não repete cliques depois do timeout.
- O reach advisory v0.5 é leitura apenas. Prevê janelas amostradas e velocidades e estima risco de carga; confiança cai em suportes móveis, rotação, contactos e dinâmica já suportada. É explicitamente não certificado, sem autorização nem speed-deny arbitrário. Houve testes de equivalência física bit a bit advice OFF/ON.
- v0.6 guarda uma seleção distante enquanto o botão está realmente segurado, sem horizonte/timeout curto. O endpoint transporta-se com o ombro e tem gesto próprio 4 m/s relativo à frame; todo o segmento mundial é varrido. O alvo não puxa nada enquanto pendente. Pode voltar a fora de alcance ou ficar bloqueado, continuar a esperar e só adquirir ao chegar ao contacto atual válido. Não usa previsão para fixar.

O CaptureEvaluator verifica alcance atual, mão junto do ponto, ray local de contacto, normal e LOS. A velocidade relativa/energia restante são diagnósticos de risco, não garantias de apanhar/reter. Em v0.6 esta avaliação é sempre obrigatória mesmo com a previsão/buffer antigos desligados. O modo OFF conserva a recusa antiga de out-of-reach e o caminho legado.

Fonte v0.6: `scripts/pending_grip_target.gd`; contrato e evidência em `V06_M1_PHYSICS.md`, `V06_M2_PHYSICS.md`, `V06_M3_PHYSICS.md`.

## Diagnóstico e limites de precisão

O journal de transferência distingue REQUEST/TRANSIT/CONTACT/RETENTION, immutable snapshots por tentativa e falhas como POSE_UNREACHABLE/PATH_OBSTRUCTED/HAND_TOO_SLOW/CATCH_OVERLOAD/GRIP_SLIP. SUCCESS de contacto não apaga uma perda posterior. Cancelamentos de botão/UI/focus são neutros. Ring e fila de eventos têm capacidade 256; snapshots atuais mantêm duas mãos. Logs JSONL em disco são por sessão/processo; não são um array de memória ilimitado por frame.

Telemetria separa twist axial, swing pendular, trabalho/potência incremental e PUMPING/BRAKING/NEUTRAL, esforços/reações e budgets. Trabalho estimado por atuadores não é uma certificação de energia mecânica total: gravidade, contactos, damping e dissipação do integrador também contam. O cache do planeador é por configuração material durante o teste e é limpo no reset; não é o ring de 256 eventos.

Limitações materiais a declarar: mãos/braços virtuais com ray de ponto, sem colisão volumétrica de todos os membros; rig visual não é ragdoll; motor de solo simplificado; planos de postura não resolvem toda a dinâmica futura; mãos são grippers aproximados; suportes AUTO-COM ainda têm aproximação de massa efetiva no atuador legado. v0.6 corrige somente velocidade do ponto nas novas âncoras opt-in. A conservação do wrench aplicado é testada separadamente da deriva angular integrada do Jolt em corpos anisotrópicos a rodar — a deriva também aparece com o controlador desligado.

Flags `posture_solver`, `directional_grip_quality`, `reactive_challenge` em ClimbingTuning permanecem pontos de experiência/telemetria sem implementação física correspondente ligada a essas flags. Isso não invalida o planeamento A/B/C realmente implementado, nem a viga reativa real das cenas, mas não devem ser apresentados como sistemas futuros já completos.

## Evidência e estado de aceitação

Os ensaios atuais cobrem signs/tensão/folga, forças/torques, um/dois apoios, reações dinâmicas, swing/catch, captura versus retenção, lançamentos, alcance total, chão, pernas passivas, pés físicos, policies/variantes, flags OFF e os gates M1/M2/M3 de seleção distante, em 60/120 Hz. A fonte contém comparações isoladas e rotas por input real; estas últimas e o total agregado final pertencem ao relatório do agente principal.

Uma rota automatizada que passa não certifica conforto humano. Native MCP comprova eventos e apresentação reais, não substitui sessões humanas/rating. O parecer físico de v0.6 M3 é PASS dentro das fixtures descritas, com o default experimental ainda OFF; KEEP/REVISE/REJECT de UX deve citar os resultados M4 reais e as limitações observadas.

## Evidência física final de v0.6 M3

A suite `test_pending_contact.gd` passa 47/47 a 120 Hz e 60 Hz. As suites M1/M2 mantêm 32/32 cada, core 45/45 e captura v0.5 25/25 em ambos os passos. O agente principal reportou 3116 verificações na regressão v0.6 agregada; deve conservar essa contagem no relatório principal junto do artefacto final correspondente.

A mão selecionada não aplicou força antes de ATTACHED. O catch estático a 0.4482 m demorou 0.2083 s a 120 Hz; um alvo inicialmente 1.0171 m distante foi alcançado por movimento corporal ascendente real a 0.9 m/s e contactado em 0.475 s. No ponto a 100% de extensão, a separação real 0.657080114 m foi guardada e o alvo inicial continuou 0.62 m. Contactar não apagou velocidade. A troca de uma para duas mãos preservou a mão antiga durante toda a fase pendente e partilhou os limites normais depois do contacto.

A fixture de 12 m/s tem condições iniciais explicitamente impostas, incluindo um endpoint livre inicialmente válido. Mostrou uma janela física de cerca de 0.09167 s demasiado curta para o gesto finito: classificou HAND_TOO_SLOW sem apanhar, conservou 12 m/s e manteve a intenção enquanto o botão continuava premido. Não representa um impulso disponível no jogo. Um apoio reduzido a 1 N depois de um catch válido escorregou e largou por grip_overload; SUCCESS/contacto e GRIP_SLIP/retenção ficaram separados.

Dois contactos no mesmo suporte dinâmico de 30 kg tiveram erro do par de força zero e resíduo do momento aplicado inferior a 6e-6 Nm; não duplicaram o binário de reação. Na cápsula anisotrópica, houve deriva angular integrada de 0.03891/0.03646 N·m·s durante 0.8 s, enquanto um controlo sem atuação já derivava 0.04534 N·m·s. O relatório não apresenta isso como conservação angular exata. Um controlo adicional de inércia isotrópica, separado e explicitamente autorado na fixture, teve deriva angular 6.22e-6/2.49e-6 N·m·s e linear inferior a 1e-6 Ns. Nenhum parâmetro de produção foi alterado para esse ensaio.

O primeiro ensaio nativo registou um swing que chegou a estabelecer contacto e depois largou por arm_extension_limit; essa falha inicial de retenção foi preservada. A sequência anterior também usava uma fixture apresentada como alvo estático distante cujo próprio apoio B fazia o torso subir e entrar em alcance, pelo que não demonstrava atração pela mão pendente. O ensaio posterior separou um alvo realmente distante de um cenário de swing reiniciado, com o mesmo intervalo de retenção do teste headless, e passou na validação nativa comunicada pelo agente principal sem alterações físicas. As contagens, evidências e resultados posteriores de 60/120 Hz ficam em [V06.md](../validation/V06.md). Não se apresenta a falha inicial como estado corrente de todos os catches, nem se apaga esse registo para garantir retenção universal. Decisões de ergonomia e conclusão KEEP/REVISE/REJECT têm de citar os resultados finais de M4, sem substituir observação humana por uma rota automatizada.

Handoffs detalhados: [M1](../validation/V06_M1_PHYSICS.md), [M2](../validation/V06_M2_PHYSICS.md), [M3](../validation/V06_M3_PHYSICS.md). As limitações de postura P2 e de previsão estão em [P2](../validation/V05_M2_P2_PHYSICS.md) e [M4 advisory](../validation/V05_M4_PHYSICS.md).
