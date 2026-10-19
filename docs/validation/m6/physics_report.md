# M6 — relatório físico da tentativa de mantle / top-out

## Decisão física

**M6 funcional NÃO está concluído.** O candidato identifica uma aresta real e tenta transferir carga com os atuadores existentes. Nos ensaios de plataforma de1.25 m e2.10 m, mãos apenas e mãos+pés não alcançaram apoio real no topo nem caminhada sobre a plataforma. Os45 checks por frequência aprovam segurança, geometria, esforço limitado e reações; não aprovam o objetivo funcional.

O feedback humano positivo sobre o percurso M5 autorizou esta experiência. Não é uma avaliação humana do mantle, nem uma classificação formal de diversão.

## Implementação e interface

Ficheiros físicos:

- `features/grip_up/scripts/ledge_transfer.gd`: candidato geométrico e pedido de torque; não aplica forças, cria contactos ou escreve transform/velocidade.
- `features/grip_up/scripts/climbing_controller.gd`: propriedade `intent_auto_mantle_enabled=false`, atualização apenas no perfil4, torque incremental e telemetria.
- `features/grip_up/scripts/intent_locomotion_coordinator.gd`: apenas com a flag e candidato ativo, o mesmo W ganha uma componente para dentro da plataforma. O vetor continua normalizado e usa o planeamento geométrico e os atuadores originais.
- `features/grip_up/tests/test_intent_mantle.gd`: fixtures físicas independentes através da aplicação; JSONs `builds/intent_mantle_120hz.json` e `builds/intent_mantle_60hz.json`.

O root integra arena, UI e critério funcional no nível11. Os perfis0–3 e o perfil4 com flagfalse não recebem direção ou torque novos. Não houve alteração de ganho K/D dos braços, massas, anatomia, força máxima, atrito, colliders, motor do chão, captura ou algoritmo dos pés.

`telemetry().ledge_transfer` contém `enabled`, `status`, `reason`, `top_point`, `top_normal`, `support_id`, `inward`, `destination_clear`, `path_clear`, `path_scope`, `requested_torque`, `applied_torque` e `physical_completion` quando aplicáveis. Estados de tentativa não são sucesso. `physical_completion` do módulo só indica que o probe real de chão identificou o topo do suporte; o objetivo completo do app exige adicionalmente largar as mãos, estabilidade real e caminhar. Nos ensaios atuais nenhum dos critérios de topo/caminhada se verificou.

`destination_clear` significa apenas que as formas atuais do corpo caberiam numa pose upright de destino, obtida por uma consulta sem mover o corpo. **Não prova um caminho contínuo.** `path_clear` permanecefalse e `path_scope` explicita que a trajetória inteira é desconhecida. Cada posição intermediária efetiva continua dependente das colisões do Jolt.

## Contactos e autoridade

O candidato requer simultaneamente:

1. Perfil4 e flag explícita; intenção de escalada ativa, sem lançamento em curso.
2. Duas mãos realmente ATTACHED, ou uma mão ATTACHED e um pé já carregado acima de1 N. Uma mão pendente não conta.
3. Um raycast atual que encontra uma superfície superior com normal.dot(UP)>=.85 no MESMO collider da pega. A pesquisa parte8 cm para dentro e percorre28 cm acima/12 cm abaixo da pega.
4. Outra consulta35 cm mais para dentro deve encontrar o mesmo topo, com altura compatível em2.5 cm. Uma saliência estreita não é uma plataforma imaginária.
5. Ocupação livre do destino aproximado:45 cm para dentro, origem do corpo93 cm acima do topo, usando os CollisionShape3D reais.
6. W positivo explícito. Não há novo pedido de força ou avanço automático emneutral.

Uma geometria desaparecida, topo inadequado, destino ocupado ou perda dos apoios elimina imediatamente o torque M6. Se apenas W for largado mantendo geometria válida, o esforço anterior decai pelo limite de slew, no máximo.2 s para uma solicitação de8 Nm. Essa cauda é o comando anterior limitado, não um controlador autónomo que decide travar a velocidade.

O module não muda a posição material das mãos nem solicita regrips automaticamente. Os pés usam o sampler, gesto de plantação finito, verificações de anatomia, compressão unilateral e cone de fricção já existentes. Não houve nova adesão, força aérea ou força central no torso.

## Parâmetros novos e orçamentos existentes

Constantes isoladas do candidato M6:

| Parâmetro | Valor |
|---|---:|
| Inclinação desejada máxima |55° |
| Rigidez de atitude |12 Nm por unidade de erro vetorial |
| Amortecimento no eixo de pitch relativo ao suporte |3 Nms |
| Pedido máximo M6 |8 Nm |
| Slew do pedido |40 Nm/s |
| Componente de W para dentro |.5 antes de normalizar o vetor |

São objetivos suaves, não limites cinemáticos ou locks. O corpo pode ficar bloqueado, rodar de outra forma ou cair. O limite de8 Nm não é capacidade adicional: o pedido entra por último no mesmo cap de assistência de20 Nm. `applied_torque` é a diferença vetorial efetiva depois desse cap, multiplicada pelo escala final do allocator. O total continua sujeito a150 Nm, incluindo braços, pés e torque efetivo do motor de chão no mesmo tick.

Mantêm-se360 N para soma das forças das mãos e180 N para pernas. A rigidez K6000/D220, alcance anatómico .65708 m, repouso .18–.62 m, margem elástica .04 m e contacto finito4 m/s não foram alterados. O planeamento de comprimentos continua limitado por.24 m/s, .9 m/s² e offset geométrico .055 m. Não existe um alvo COM que aplique força direta.

A assistência do torso recebe reação oposta nos apoios dinâmicos reais segundo os pesos de alocação/blend já existentes. Duas mãos no mesmo corpo não duplicam o torque. As forças axiais e reações correspondentes continuam aplicadas aos pontos originais dos ombros e contactos.

## Ensaios físicos

Fixture ordinary: plataforma sólida x±1, z[-1.6,0], topo2.10 m; chão segurotop.25; origem inicial(0,1.17,.40); contactos frontais(-.20,2.05,0)/(.20,2.05,0). Saliências reais dos pés em x±.31, topo.65 e extremidade frontal z=.11. Variante baixa usa topo1.25 e pegas1.20. Variantes adversas usam plataforma com profundidade.12 ou ocupação do destino por obstáculo.

As formas de fixture são configuradas antes das capturas. O corpo do personagem não é reposicionado nem recebe velocidades de roteiro. Cada mão chega por gesto finito e contacto real. A comparação mantém W por6 s. Se houvesse ground_support no collider da plataforma, o teste largaria as mãos e mediria caminhada de30 cm; essa fase nunca foi alcançada.

| Capacidade medida |120 Hz |60 Hz |
|---|---:|---:|
| Checks de segurança/geométricos |45/45 |45/45 |
| Topo1.25: picoY, mãos, candidatoOFF |1.1674 m |1.1671 m |
| Topo1.25: picoY, mãos, candidatoON |1.1674 m |1.1671 m |
| Topo1.25: picoY, mãos+pésON |1.2030 m |1.1852 m |
| Topo2.10: picoY, mãosON |1.3561 m |1.3213 m |
| Topo2.10: picoY, mãos+pésON |1.4797 m |1.4750 m |
| Topo2.10: subida máxima, mãos+pésON |.3130 m |.3083 m |
| Topo2.10: pico de força das mãos, mãos+pésON |220.18 N |190.02 N |
| Topo2.10: pico de força dos pés, mãos+pésON |96.98 N |110.76 N |
| Ground real na plataforma |não |não |
| Mãos livres e caminhada30 cm no topo |não |não |
| **Gate funcional M6** |**FAIL** |**FAIL** |

O topo estreito e destino ocupado não recebem esforço M6. Os pés podem continuar a realizar esforço legítimo em saliências existentes; rejeitar mantle não desativa os mecanismos originais de escalada.

O último fixture utiliza plataforma RigidBody3D livre de30 kg, gravidade e damping zero em ambos os corpos e sem chão, para isolar reações. Duas pegas finitas ativam o torque; o suporte ganha rotação real, com spin final≈(.02824,.00039,-.00038) rad/s a120 Hz e≈(.03070,.00046,-.00018) a60 Hz. Resíduos amostrados de momento linear total e do wrench axial das mãos foram0 na precisão reportada. A perda da última mão retirou todo torque M6 no tick seguinte. Isto verifica o par real de esforços nesse fixture; não é prova de conservação exata de energia ou momento angular integrado para toda geometria anisotrópica do Jolt.

Um run120 terminou com warning de capacidade do sistema de jobs Jolt durante concorrência de processos; os45 checks e footer passaram. O run60 isolado passou45/45 com o aviso de certificados Windows já conhecido, sem SCRIPT ERROR. Não se atribui um efeito físico a esses avisos. O root mantém a matriz de regressão e ensaios nativos separados.

## Porque a capacidade atual não chega

Os braços são cabos/atuadores de tração: se o ombro passar acima da mão, a força aponta para baixo, não empurra a palma contra o topo. A inclinação limitada não cria esse grau de liberdade. Em postura upright com mãos na aresta, a tração deixa de produzir sustentação vertical muito antes de o corpo conseguir pôr os pés sobre ela.

Além disso, o torso, cabeça, perna e sola são formas fixas de UM RigidBody3D. A sola fica aproximadamente.917 m abaixo da origem do corpo. Para estar de pé num topo a2.10 m, a origem precisaria de ficar perto de3.017 m; o melhor pico observado foi1.480 m. Para o topo1.25, o alvo upright seria≈2.167 m e o pico observado1.203 m. Dobrar visualmente os joelhos não altera esse impedimento de colisão. Pés virtuais comprimem apenas contra apoios alcançáveis e não recolhem a forma da perna/sola.

Não se prova impossibilidade matemática de toda manobra dinâmica possível deste corpo. Prova-se que esta assistência limitada, com estas geometrias e sequências, não realiza um top-out ordinary. O resultado não foi escondido por animação, impulso, escrita de transform, alteração de collider, aumento de força ou vitória por proximidade.

Próxima capacidade a estudar, com autorização própria: apoio compressivo real das palmas contra superfícies superiores, partilhando força/momento e reação física, e uma solução de colisão para pernas recolhidas que represente efetivamente a mudança anatómica. Não foi implementada nesta experiência. Até existir uma capacidade demonstrada, o percurso M5 aprovado continua a experiência jogável; o nível M6 permanece identificado como experimental.
