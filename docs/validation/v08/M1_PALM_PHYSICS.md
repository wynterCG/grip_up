# v0.8 M1 — palmas axiais: gate isolado

**Gate M1 aprovado:49/49 checks a120 Hz e49/49 a60 Hz.** Uma palma real produz subida mensurável numa postura mecanicamente favorável, dentro dos limites, e um suporte dinâmico recebe reação. Isto **não** é um mantle nem uma prova de transição desde uma suspensão ordinary. A necessidade de braço dobrado e momento de punho para ombros abaixo da aresta continua separada.

## Código e rollback

- Novo `features/grip_up/scripts/palm_support_solver.gd`.
- Integração estreita em `climbing_controller.gd` e `intent_locomotion_coordinator.gd`.
- Cena independente `features/grip_up/tests/palm_compression_lab.tscn` e respetivo script.
- Runner `features/grip_up/tests/test_palm_compression.gd`.

Flags de controller, ambasfalse por defeito: `physics_mantle_v08_enabled`, `palm_compression_enabled`. Requer perfil4 e lançamento inativo. Desativar a experiência preserva o caminho trativo anterior; o teste compara exatamente as trajetórias com masterOFF versus masterON/palmOFF. Os45 checks físicos históricos também passaram a120 Hz depois da integração. O root mantém os restantes controlos e regressões.

Um H0 normal precisa de soltar, pedir novamente e chegar fisicamente à superfície. Não existe palm roll/H1, deslocação automática da âncora para o topo ou nova distância de alcance. A mão pode estar em `GRIP_TRACTION`, `REPOSITIONING`, `PALM_CONTACT`, `PALM_SLIPPING` ou `FREE`; só um modo produz esforço por mão.

## Contacto e modelo mecânico

P-A: palma virtual, sem collider de mão nem reação nativa duplicada. A área declarada mede7×10 cm. O centro e8 amostras de perímetro têm de encontrar o MESMO collider e a mesma superfície, normal compatível e erro de posição<=3 mm. A normal precisa de dot(UP)>=.85. Uma consulta volumétrica verifica a região imediatamente no lado livre da palma. Também são exigidos chegada atual do endpoint, alcance anatómico e LOS do ombro quando este está no lado utilizável da superfície. A orientação da área é guardada no referencial material, não recapturada da câmara.

Sem área, chegada, anatomia, superfície ou percurso válido, a mão perde autoridade imediatamente; não recebe a pega trativa como fallback adesivo. Uma mão apenas visualmente próxima ou PENDING não é uma palma.

Para P=contacto, S=ombro, u=(S−P)/|S−P| e normal n:

`F = u * max(0, [K*max(0,Lrest−|S−P|) − D*vrel_axial] / [1+(D*dt+K*dt²)*inverse_effective_mass])`.

O solver reutiliza o denominador implícito do modelo anterior, com sinal de compressão. K/D são os valores existentes6000/220 multiplicados pela alocação atual da mão. Se a extensão real exceder o alvo mais2 mm, o elo não consegue puxar o corpo de volta e a força ézero. A velocidade e massa efetiva incluem COM real, braços de alavanca e suporte dinâmico.

O elo só admite força quando u·n>0 e a linha AXIAL inteira cabe no cone `|u_tangent|<=mu*(u·n)`. Fora do cone, toda a força ézero e a palma entra em deslizamento/liberta; não se projeta uma força normal artificial que criaria um momento sem fonte. Mu é o atrito do material quando existe, ou.85 por defeito. A sobrecarga usa a capacidade declarada de palma e tempos de integridade; o teste específico de deslizamento M1 cobre o cone de atrito, não um estudo extensivo da resistência máxima da palma.

A força admitida é aplicada no ombro através de `apply_force(F,S−body.origin)`; o suporte recebe `apply_force(−F,P−support.origin)`. Os argumentos são offsets mundiais, não pontos absolutos. Como F é colinear com S−P, o wrench resultante do par ézero: `(S−P)×F≈0`. Não há momento de punho M1.

Uma palma axial tampouco transmite o torque de atitude antigo como se fosse uma junta aderida. A alocação do assistente20 Nm exclui palmas; numa mistura tração+palma, a reação do assistente passa apenas pela mão trativa. Com palmas apenas, esse assistente ézero. As forças das palmas continuam a criar os momentos reais dos ombros e a contar no limite150 Nm.

## Intenção, limites e telemetria

W pede extensão do elo compressivo; S permite descarregar/baixar através de alvo menor. Não há relação com pixels ou um alvo direto de COM. O alvo usa geometria alcançada e offset pendente máximo.055 m. O melhor progresso real de cada comando é capturado a partir de uma referência fixa, sem somar jitter em uma catraca. Emneutral mantém-se a postura alcançada, relaxando pedido não cumprido. Taxa.24 m/s e aceleração.9 m/s² são as existentes.

Uma mão é avaliada UMA vez no loop central: força trativa OU compressiva. A soma de magnitudes de ambas continua<=360 N; pernas continuam180 N, assistente20 Nm e momento total150 Nm. O teste misto exige força simultânea de uma pega trativa e uma palma, somadas exatamente na mesma telemetria.

`hands[id].contact_mode` e `hands[id].palm` registam validade, motivo, alvo, taxa/aceleração, força pedida/aplicada, normal/tangente, limite de fricção, reação e offsets mundiais. `telemetry().ledge_transfer.palm_support` contém o resumo do solver. Release limpa também valores diagnósticos para não publicar carga antiga como contacto atual.

## Fixture favorável e resultados

O corpo isolado tem massa12 kg, capsule1.7 m/r.15, ombros e comprimentos do perfil bípede, gravidade durante a pressão estática e damping zero. A pose é configurada **antes** de o corpo entrar no mundo. A postura é deliberadamente um apoio invertido/handstand: para uma mão, a rotação inicial alinha o ombro sobre a linha vertical COM–palma; para duas, alinha o centro dos ombros e deixa os dois apoios simétricos. O corpo não intersecta a plataforma na configuração inicial.

Isto retira da primeira prova o problema separado de alavancar um ombro abaixo da aresta. Nenhuma reposição de pose/velocidade acontece durante o ensaio. As mãos começam livres, chegam em tempo finito e só depois se aplica a intenção W. A subida é medida relativamente à pose imediatamente anterior à pressão, sem contar a posição inicial como progresso.

| Medida |120 Hz |60 Hz |
|---|---:|---:|
| Checks |49/49 |49/49 |
| Subida real,1 palma, contra gravidade |.08271 m |.07010 m |
| Subida real,2 palmas, contra gravidade |.03437 m |.03406 m |
| Pico de força,1 palma |177.57 N |183.76 N |
| Pico de soma das forças,2 palmas |175.50 N |181.58 N |
| Subida,1 palma + plataforma livre30 kg, zeroG |.05911 m |.06113 m |
| Erro máximo do momento linear do par livre |1.19e−7 kgm/s |1.19e−7 kgm/s |
| Resíduo máximo do wrench axial no caso2palmas |1.43e−6 Nm |1.07e−6 Nm |

A menor subida com duas palmas não indica força duplicada nem uma comparação de desempenho humano: há alocação/blend e dinâmicas distintas das posturas. O critério é contribuição genuína dentro do orçamento, não que duas mãos sejam sempre mais rápidas.

Passam ainda: palma no ar3 cm sem força, área insuficiente no canto, atrito insuficiente com ângulo oblíquo, obstáculo surgido no braço, suporte destruído, release imediato sem carga stale, ausência de adesão num contacto descarregado, planeamento sem escrita do torso, pedido bloqueado3 s sem windup, neutral, flagOFF exata e mistura de tração+compressão. O par dinâmico não tem gravidade nem contactos externos; a plataforma move-se efetivamente para baixo. O ensaio não promete conservação exata de energia ou de momento angular integrado para todas as inércias do Jolt.

Artefactos finais: `builds/palm_compression_120hz.json`, `builds/palm_compression_60hz.json` e os logs `test_test_palm_compression*.log`. O run60 também emite o aviso conhecido de certificados Windows; não houve SCRIPT ERROR.

## Falhas preservadas e próximo gate

Fixtures iniciais upright e inclinada falharam a subida: a linha axial empurrava para fora, entrava fora do cone de fricção ou gastava trabalho rodando o corpo, antes de sustentar a massa. Estão preservadas em `docs/validation/v08/development/palm_upright_fixture_failed_120hz.{json,log}` e `palm_lean_fixture_failed_120hz.{json,log}`. A fixture favorável final é identificada explicitamente, não apresentada como solução dessas poses.

**KEEP para capacidade axial isolada; M4 top-out ainda não validado.** Um ombro abaixo de uma aresta não pode receber força ascendente de um elo que só empurra ao longo da linha palma→ombro. A próxima extensão precisa de um braço dobrado realmente livre de obstáculos e um momento finito de articulação/punho, carregado no MESMO20 Nm, com wrench completo conservado. Nenhum resultado M1 autoriza ignorar LOS, criar momento ilimitado, dobrar força com duas palmas ou declarar a manobra completa.
