# v0.7.2 — agarrar onde o braço realmente chega

O utilizador pediu que um clique um pouco além do alcance não obrigue a prever um indicador preciso: se a mesma superfície tem contacto alcançável, a mão deve ir até onde consegue e atuar aí, sem teleporte. Isto substitui a exigência de alvo material exato **apenas no perfil4 com `allow_out_of_reach_grip_targets=true`**. O perfil3 conserva a seleção exata v0.6; flagOFF continua a rejeitar um pedido fora da anatomia.

## Resolução física mínima

Novo `features/grip_up/scripts/reachable_grip_resolver.gd`, chamado por `request_held_grip` no `climbing_controller.gd`. Só atua se o clique está além de R. A resolução acontece uma vez, no pedido:

1. O ponto e normal clicados definem um plano tangente atual ao material. Projeta-se a esfera anatómica atual do ombro nesse plano.
2. O candidato é o ponto no disco de interseção na direção do clique. Usa o R anatómico existente, não90%, e não estende o braço além da esfera para alcançar o clique.
3. Um raycast real do ombro até ao candidato, continuado25 mm para testar a superfície, tem de devolver **o mesmo collider**, com ponto real a uma distância≤R+1 µm. O plano é apenas uma proposta, nunca evidência de contacto.
4. O ponto e normal retornados pela física tornam-se uma âncora material local fixa. Não se repete a resolução a cada frame, não desliza a pega e não escolhe outro objeto.
5. A mão percorre a trajetória finita existente. `PendingGripTarget`, `GripCaptureEvaluator`, blend, integridade e forças continuam a autorizar contacto/atuação exatamente como antes.

Se o plano está fora da esfera, não há superfície real nessa projeção ou outro collider bloqueia, a resolução não inventa um contacto: mantém o alvo original como pending, sem força até haver contacto real. Isto não é um solver global da superfície mais próxima; não procura automaticamente outra face distante do mesmo objeto.

Não foram alterados `pending_grip_target.gd`, `supported_swing.gd`, o coordenador de locomoção ou tuning. A abordagem normal existente funcionou no alcance máximo; não foi necessário um bypass de trajetória ou uma tolerância especial de contacto.

## Clique, objetivo e diagnóstico

`pending_diagnostics` do perfil4 acrescenta:

- `original_selection_world`, `original_selection_local`, `original_selection_normal_local`, `original_selection_distance`;
- `contact_resolution_applied`, `contact_resolution_reason`, `contact_resolution_blocker_id`;
- quando aplicado, `resolved_contact_world_at_selection`, `resolved_contact_distance`;
- `selection_policy=REACHABLE_SAME_COLLIDER_ON_REQUEST`.

`target_world` continua a ser o objetivo físico atual, agora o ponto resolvido, seguindo o material. Os campos `*_at_selection` são snapshots do pedido. O original local permite reconstruir o clique num suporte móvel. `hand.capture` também guarda o original e a resolução; a classificação da seleção fora do alcance refere-se ao clique original, não é apagada porque o contacto resolvido já cabe na esfera.

Não existe atração para o clique original nem COM autopull. O braço livre/pending continua com força e alocação zero. Depois de contacto, o mesmo braço axial pode transmitir tração: inicializa rest a partir da separação real, limitado a.62 m, com o blend existente. O alcance de contacto continua.65708 m, o rest .18–.62 m e a margem elástica máxima .04 m. Forças/momentos continuam360 N,20 N·m e150 N·m; pés e chão não ganharam outra autoridade.

## Validação dedicada120/60 Hz

`test_reachable_grip.gd`: **27 checks, zero falhas em ambas as frequências**. Outputs `builds/reachable_grip_120hz.json` e `builds/reachable_grip_60hz.json`.

| Medida do fixture desimpedido | 120 Hz | 60 Hz |
|---|---:|---:|
| Distância original clicada | .69462234 m | .69462234 m |
| Distância real resolvida | .657080054 m | .657080054 m |
| R existente | .65708 m | .65708 m |
| Tempo até contacto real | .2750 s | .2833 s |
| Pico de tração observado, depois do contacto | 60.97 N | 52.26 N |

A diferença de54 nanómetros em relação a R é arredondamento float32. O resolver permite apenas1 µm numérico na verificação do raycast; não há margem de alcance de jogo. O teste confirma que o pedido não altera pose/velocidades, a mão não se anexa no clique, o gesto respeita4 m/s relativos ao ombro, o avaliador real aceita a chegada e só então surge tração. O contacto retém até.8 s desde o pedido neste fixture de gravidade zero, mais de.5 s após a chegada. Isso não garante retenção em qualquer queda/carga.

Negativas: plano totalmente fora da esfera; plano imaginário sobre uma forma pequena que não existe na posição proposta; collider diferente a bloquear; cancelamento antes da chegada; perfil3 exato e flagOFF. Todas conservam zero força antes de contacto válido. Num suporte dinâmico a âncora resolvida fica localmente fixa e o contacto permanece; residual de momento linear do par~2.98e−8/2.38e−7 kg·m/s, confirmando a reação oposta já existente.

Regressão complementar: `test_pending_contact.gd` **47/47 em ambas as frequências** sem editar o runner. A matriz completa, visual e native são executados pelo agente principal. O problema visual de IK grounded/pending foi tratado separadamente pelo principal; esta nota descreve a resolução física, não reivindica correção do rig pelo resolver.

## Limites e interpretação

- Um braço que não tocou em nada não recebe força da superfície, mesmo se estiver completamente esticado.
- Movimento do ombro/suporte durante o gesto pode retirar o ponto resolvido do alcance; continua o pending existente e a captura não é antecipada.
- Se só outra face do objeto seria alcançável, esta proposta de plano pode falhar. Não muda de face/collider por magia nem aplica uma nova âncora a cada frame.
- Tração real depois de agarrar pode mover corpo e suporte, incluindo a deformação/rest preload existentes. Isso difere de puxar o corpo para um alvo ainda não tocado.
- A seleção ficou mais tolerante ao clique, não fisicamente mais forte. A diversão e o conforto específicos desta alteração dependem do uso humano da build.

Código físico congelado após os resultados acima; nenhuma alteração em E, editor/MCP ou Git foi feita pelo especialista.
