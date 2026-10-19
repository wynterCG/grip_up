# v0.9 M1 — motor assistido no mesmo RigidBody

**Gate inicial43/43; extensão de recuperação nativa54/54 a120 Hz e54/54 a60 Hz**, Godot4.7.2 stable Steam `ed1daf0bf`, Jolt integrado. Código do motor congelado para integração. Isto valida o transporte/colisão/restauro isolado; não aprova por si só mantle F1/F2, animação, walking integrado ou experiência humana.

## Escopo e ficheiros

- `features/grip_up/scripts/mantle_kinematic_motor.gd` — novo RefCounted, autoridade assistida e perfis/queries num só módulo.
- `features/grip_up/tests/test_hybrid_motor.gd` — fixture física independente, runner SceneTree.
- Este relatório e `M1_gate_{120,60}hz.{json,log}`.

Não foram alterados o controller dinâmico, forças, tuning, input, níveis, animação, main, motor de marcha ou módulos v0.8 por este agente. Todas as execuções foram headless, sem E/Git/MCP. Os snapshots/commits de integração pertencem ao root.

## Decisão de autoridade

Escolhido o próprio `RigidBody3D` com `freeze_mode=FREEZE_MODE_KINEMATIC` e `freeze=true`, apenas durante o estado assistido. O mesmo RID/corpo mantém todas as colisões. Traduções usam `move_and_collide`; rotação e transformação local das shapes só são aplicadas após uma certificação de volumes independente. Não existe um segundo corpo ativo nem shape de colisão globalmente desligada.

O caminho congelado foi suficiente no build real, incluindo ticks físicos separados e retorno à simulação. Assim não foi necessário implementar o fallback AnimatableBody3D. Não se reivindica um benchmark comparativo desse fallback: evitou-se a complexidade de transferir autoridade entre dois corpos quando a opção preferida já passou os critérios isolados.

Esta é a assistência cinemática explicitamente autorizada pela spec v0.9. Não é trabalho muscular simulado, conservaçāo de energia ou um resultado dos360 N/20 Nm antigos. Os motores dinâmicos têm de ser desativados pelo coordenador ANTES de `begin`; o motor não tenta competir com eles.

## API e contrato

| Chamada | Comportamento |
|---|---|
| `configure(body)->bool` | Só lê/captura o compound standing e contactos atuais; não muda shapes, inércia, freeze ou pose. Requer capsule inferior `LowerCapsule` e sola `FootBase`, shapes Box/Sphere/Capsule sem escala. |
| `begin()->bool` | Revalida contacto inicial e transfere uma vez para freeze kinematic; uma segunda chamada ativa é idempotente. Divide a cápsula inferior em duas cápsulas cuja união inicial é a original. |
| `validate_segment(from,to,from_flex,to_flex)->Dictionary` | Preflight read-only de translação, rotação e perfil; `clear/reason`, subpassos, padding, collider/segmento bloqueado. |
| `move_step(pose,flex,dt)->Dictionary` | Revalida o mundo vivo, usa movimento nativo e aplica apenas a parte validada. Publica `clear`, `moved`, `attempted_motion`, `allowed_motion`, `blocked_collider`, pose/flex reais. |
| `pose_for(flex)` | Transforms locais de thigh/shin/sole e pontos hip/knee/ankle aprovados, para planner/animação. |
| `lowest_point(flex)` | MenorY de TODOS os volumes reais, não só da sola. |
| `standing_clear(pose)` | Verifica compound normal completo na pose indicada; não prova ground support. |
| `standing_snapshot()` | Cópia pública de nomes/transforms/tipos/raios; as referências originais de shapes para restauro ficam privadas. |
| `end_dynamic(velocity)` | Recusa se flex não for0 ou standing colidir; restaura recursos/transforms originais, modo físico e velocidade final segura. |

Todas as mutações têm de ser chamadas no physics process, fora de `_integrate_forces` e callbacks de queries. O perfil standing original tem de ser a fonte da configuração; não configurar sobre um `AdaptiveShin` v0.8 já ativo nem combinar duas autoridades de proxy.

`refresh_start_contacts()` é query-only. É chamado automaticamente antes de preflight a partir da POSE ATUAL e antes do begin. Não permite que uma pose futura do plano introduza obstáculos na lista de contactos tolerados. Isto é necessário porque a configuração pode ocorrer no spawn, muito antes da chegada à parede.

## Geometria do tuck

HEEL_BACK: cápsula inferior original h.84/r.15, centroY−.4967; duas centerlines de.27 m, ancaY−.2267. A coxa fica vertical; a canela roda até150°. A sola conserva dimensões e orientação local, deslocando-se com o endpoint. A cabeça e o torso não mudam nem desaparecem. A união das duas cápsulas em flex0 é exatamente a cápsula standing original.

- Standing lowest localY: **−.916700 m**.
- HEEL_BACK flex1 lowest localY: **−.646700 m**, definido pelo volume do joelho/coxa.
- A sola pode ficar mais alta, perto de−.4129 m; usar esse valor isolado para cruzar o bordo seria incorreto.

O planner tem de elevar o corpo acima do topo por `−lowest_point(flex)+margem`, manter a orientação apropriada e só depois cruzar. O perfil não representa uma perna articulada dinâmica ou força de pé: é um volume assistido explícito, a sincronizar com o pose driver.

## Certificação contínua

Uma query apenas no destino não é suficiente. Para cada segmento:

1. Soma-se translação, raio conservador de todo o compound×ângulo de rotação e limite de movimento de morfologia×variação de flex.
2. Divide-se o intervalo até o limite de deslocamento de um ponto ser<=3 mm. Acima de4096 intervalos, recusa-se com `QUERY_RESOLUTION_EXCEEDED`.
3. Em cada midpoint, todas as shapes são infladas por metade do limite de movimento do intervalo +skin.1 mm. Capsule/Sphere expandem pelo raio; Box expande em todas as faces. Isto contém os volumes intermediários, incluindo cantos durante rotação e arco dos segmentos.
4. O raio de rotação provém do envelope imutável do perfil, não apenas de uma amostra tucked que poderia subestimar o standing.
5. A pose final também é consultada. O mundo vivo volta a ser verificado no `move_step`.
6. A tradução efetiva passa pelo `move_and_collide`; se o motor nativo bloquear, não se impõe o transform da animação. Qualquer deslocamento parcial nativo é publicado como tal e o coordinator deve parar/reconciliar progressão.

Contacto inicial de parede é um caso limitado: até2 mm de contacto nativo estático já existente podem permitir uma translação estritamente para FORA. São exigidos collider conhecido e normals dos pares compatíveis com esse afastamento. Não se concede essa tolerância para girar/dobrar em contacto, mover para dentro, nem tocar um obstáculo novo. A primeira rota deve afastar o corpo alguns centímetros com perfil/orientação constantes antes de alinhar/tuck. A fixture com0.5 mm de contacto confirmou tanto a aceitação do afastamento quanto a recusa do aprofundamento.

### Extensão: recuperar overlap que o Jolt dinâmico já tinha admitido

A integração LOW60 revelou um caso diferente do contacto superficial: o torso tinha9.152 mm de penetração na plataforma e o contacto NATIVO do próprio Jolt registava o mesmo ponto z−.009151, shape0 e impulso~1.73 Ns. Transform do Node e PhysicsServer coincidiam; não era um erro de frame ou visual. O limite genérico2 mm recusou corretamente aquela configuração. O recibo falhado permanece em `start_rejection_depth_60hz.{json,log}`; não foi reclassificado como geometria inicialmente livre.

Uma fixture inclinada pressionada dinamicamente contra parede reproduziu20.00016 mm de overlap persistente. Isto coincide com o valor documentado de [Jolt penetration_slop=.02 m](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-physics-jolt-physics-3d-simulation-penetration-slop). A spec assistida autoriza retirar o corpo desse contacto; não autoriza aumentar tolerância de passagem através de sólidos.

O ensaio nativo simples também revelou que `move_and_collide` acrescenta recuperação silenciosa nesse caso: pedir3 mm para fora moveu20.495 mm, sem devolver colisão. `test_move(recovery_as_collision=true)` também não forneceu uma previsão útil dessa correção. Esses dados estão em `native_extra_departure_{500N,200N}_60hz.json`; **a técnica não foi aceite para a fase de recuperação**.

O ramo autorizado é mais restrito:

- snapshot atual com mesmo proxy, collider estático, ponto e normal realmente presentes nos contactos nativos;
- limite bruto20 mm, apenas1 µm de tolerância numérica de comparação; overlap geométrico sem esse testemunho continua recusado;
- orientação e flex constantes, vetor estritamente exterior às normals medidas;
- nenhuma nova interseção, mesmo noutro proxy/collider;
- consultas de todo o corpo e profundidade monotonicamente não crescente em cada intervalo/subpasso;
- somente enquanto esse overlap inicial existir, aplica-se a TRANSLAÇÃO EXATA previamente certificada no corpo FROZEN, evitando a correção extra do `move_and_collide`;
- assim que fica livre, volta o movimento nativo normal. Não há permissão geral para transforms não verificados.

A autorização expira quando o overlap inicial desaparece. Em preflight só sobrevivem as keys que ainda intersectam no início de cada intervalo; em runtime a lista é eliminada assim que fica livre. O mesmo collider não pode reutilizar essa exceção numa colisão nova posterior.

Ambas as frequências mediram20→17→14→11→8→5→2→0 mm em passos pedidos/reais de3 mm, com14 pequenos subpassos de recuperação e depois chamadas nativas normais. Direção pior, rotação, morfologia, blocker novo e overlap sem contacto nativo foram explicitamente recusados. A monotonicidade refere-se ao overlap já existente; a rota posterior continua a exigir clearance normal. A telemetria `start_contact_audit` e `native_overlap_recovery_steps` distingue este caso de uma rota inicialmente livre.

O replay LOW60 adicional `test_hybrid_start_probe.gd` passou7/7, incluindo native ground e marcha30 cm após esta recuperação. É um teste automatizado integrado de um cenário, não substitui o F1/F2 completo do root ou avaliação humana. Cópias: `start_recovery_pass_60hz.{json,log}`. Gate isolado final: `M1_native_recovery_gate_{120,60}hz.{json,log}`.

As queries preservam a collision mask e excluem apenas o próprio RID. Objetos dinâmicos são bloqueadores; não recebem um empurrão cinemático artificial. Alterar layer/mask enquanto o motor está ativo interrompe o movimento com `COLLISION_AUTHORITY_CHANGED`.

## Retorno dinâmico e recuperação

O baseline privado guarda os recursos standing originais, transforms, inércia e freeze mode. No retorno normal, o caller tem primeiro de chegar a flex0 através de movimento/perfil validado. O motor remove a shin temporária e restaura os mesmos recursos e transforms, não uma aproximação reconstruída.

A velocidade de saída vem do movimento assistido medido/escolhido pelo coordinator, limitada a3 m/s para evitar um unfreeze explosivo. A velocidade angular é limpa no handoff upright; não se repõe o spin de chegada pré-mantle. A massa, gravidade e camadas não são alteradas pelo motor. O ensaio verifica que forças pendentes anteriores ao freeze não reaparecem como impulso depois de ticks congelados.

Se o standing não couber, o motor **não** desliga colisões, não restaura um corpo penetrante e não declara sucesso. Mantém-se congelado, com razão explícita, até o corridor poder ser validado ou o nível ser reiniciado. A implementação isolada não oferece rollback por teleporte nem queda automática com perfil reduzido. Este STOP/reset é a alternativa segura autorizada; a UX e destruição/recriação de nível pertencem ao root. Se o corpo for destruído no reset, `end_dynamic` reconhece `BODY_REMOVED` sem consultar objetos inválidos.

## Evidência

| Medida |120 Hz |60 Hz |
|---|---:|---:|
| Checks |43/43 |43/43 |
| Erro máximo de tracking em ticks reais |5.96e−8 m |1.49e−8 m |
| Subpassos no preflight combinado |693 |693 |
| Limite acumulado de movimento de ponto |2.07698 m |2.07698 m |
| Padding de cada midpoint desse caso |.00159854 m |.00159854 m |
| Corpo após ground settle nativo |Y1.99170005 |Y1.99169981 |
| Ground support real após restauro |sim |sim |

A rota combinada isolada move(+.25,+.40,−.25)m, roda.4 rad e passa flex0→1 ao longo de1 s de ticks reais. A fixture tem o compound de12 kg do perfil bípede, sem motores antigos. O deck final tem topoY1.075; COM/sole esperados são1.075+.9167=1.9917. Não se conta uma raycast isolada como contacto: o teste lê o collider real nos contactos nativos do RigidBody depois do retorno à gravidade.

Passam também: paredão fino entre endpoints livres; canto da sola que colide somente a meio da rotação; obstáculo atravessado somente a meio da morfologia apesar de ambos perfis finais livres; blocker dinâmico sem deslocamento; obstáculo surgido no unfold; restauro recusado e posteriormente permitido após remoção do blocker; commit/end idempotentes; recursos standing idênticos; masks/massa preservados; forças antigas sem replay; contacto nativo inicial não aprofundante.

As versões incrementais22/27/37 e o gate inicial43 passaram. O ensaio integrado LOW60 recusado e a correção nativa excessiva foram preservados na extensão acima; o primeiro check adicional de blocker comparava o basis de antes de um tick congelado com o basis normalizado pelo servidor e foi corrigido para comparar o estado imediatamente antes/depois da query recusada. O motor não avançava nesse caso. O gate final54 passou com a asserção de não movimento mantida. Falhas de integração/rota adicionais permanecem sob ownership do root, sem reclassificar recusa correta de colisão como sucesso.

## Limites e decisão

**GO M1 para integração da rota/pose**, não aprovação de v0.9 completo. O motor não deteta ledges, não escolhe start/destination, não anima mãos e não decide que existe suporte no topo. Não certifica moving-platform mantle, interpolação visual ou conforto humano. Formas arbitrárias/escala e outros perfis de pernas precisam de um novo bound antes de serem suportados.

Referências primárias consultadas: [RigidBody3D freeze modes](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html), [PhysicsBody3D movimento/teste nativo](https://docs.godotengine.org/en/stable/classes/class_physicsbody3d.html), [PhysicsShapeQueryParameters3D](https://docs.godotengine.org/en/stable/classes/class_physicsshapequeryparameters3d.html). Os gates43/43 inicial e54/54 final foram obtidos no build local exato, não inferidos apenas dessas páginas.
