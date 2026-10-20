# v1.1 B2 — seleção local de apoio orientada pela intenção

Estado: **implementado como experiência opt-in; benefício de locomoção não demonstrado no Step**. B1 continua a seleção predefinida. A0 foi mantido em todas as comparações de personagem completo; A1 não participou. Não foram recolhidas classificações humanas nem se infere melhoria de diversão destes ensaios.

## Âmbito e interface congelada

- [foothold_candidate_sampler.gd](../../../features/grip_up/scripts/foothold_candidate_sampler.gd): `sample(..., context: Dictionary = {})`; `context.enabled` permite a pontuação adicional. Sem esse contexto conserva a ordem dos raios, validações, expressão de custo e desempates B1. Não acrescenta raycasts, nem mesmo com B2 ligado.
- [foot_contact_solver.gd](../../../features/grip_up/scripts/foot_contact_solver.gd): `intent_aware_selection: bool = false`, `selection_intent: Vector3 = Vector3.ZERO`, `candidate_selection(include_candidates: bool = false)`.
- [test_intent_feet.gd](../../../features/grip_up/tests/test_intent_feet.gd): runner independente, resultados em `builds/intent_feet_120hz.json` e `builds/intent_feet_60hz.json`.

As ligações acima são relativas à raiz documental `docs/validation/v11`; o caminho de implementação é `features/grip_up/...` na raiz do projeto.

O solver consulta B2 apenas em FREE/SEARCHING. Não substitui um contacto PLANTING/SUPPORTING/SLIDING para perseguir uma intenção nova. O ponto escolhido continua material-local; chegada, anatomia, obstrução, pressão, atrito, perda do apoio e aplicação de forças pertencem ao mecanismo anterior.

Mudar B1↔B2 limpa apenas histórico de pontuação, diagnóstico e contador de mudanças. Não modifica contactos, comprimento-alvo ou esforço já plantado. A atribuição repetida do mesmo valor é idempotente, como exige a integração por tick. `reset()` também limpa esse histórico.

`candidate_selection()` devolve uma cópia compacta, sem referências a corpos: política, intenção, contador de mudanças e última seleção por pé. O argumento `true` acrescenta os candidatos avaliados. O diagnóstico inclui custo anterior e adicional, utilidade de compressão com sinal, qualidade de carga vertical, atrito, espaço de extensão, tempo de gesto estimado, velocidade relativa do suporte, penalização de deriva, bónus de continuidade e razões de rejeição. É o último evento de procura, não uma promessa de esforço atual. `future_contact_authorized` é sempre `false`.

## Modelo de ranking

Para cada candidato já validado pela geometria atual, a direção unitária da perna é do tornozelo para a anca. A direção transmissível é projetada no mesmo cone unilateral do solver: componente normal não negativa e tangente limitada por μN. A utilidade é o produto escalar dessa direção transmissível com a intenção mundial limitada a módulo 1. Assim, para empurrar o corpo para a esquerda pode ser preferível um apoio à direita — selecionar um destino à esquerda não é equivalente a produzir esforço para a esquerda.

O custo adicional é:

`−0.35 × utilidade + 0.15 × (1 − carga_vertical) + 0.10 × (1 − espaço_extensão_normalizado) + 0.35 × deriva − continuidade`.

A deriva é `min(0.4 m, |velocidade_relativa| × tempo_gesto)`; o tempo é distância atual/velocidade finita de plantação existente. A velocidade do ponto de um RigidBody inclui rotação e COM real do direct state; StaticBody usa as velocidades constantes. Não há previsão de acelerações ou garantia de interceção.

A continuidade tem bónus máximo 0.035, decrescendo linearmente até zero a 8 cm do último ponto no mesmo material. Uma intenção claramente oposta pode ultrapassá-la. Apoio desaparecido não fica elegível por ter histórico. Estes coeficientes são heurísticos de ranking, não novas unidades de força, nem resultado de otimização ou calibração humana.

## Invariantes físicos

Nenhuma escrita de pose/velocidade do corpo foi adicionada. Não foram alterados velocidade de plantação, alcance da perna, gesto, pressão, rigidez, atrito, orçamento ou aplicação de reação. Mantêm-se 360 N partilhados pelas mãos, 180 N para as pernas, 120 N por perna e 150 Nm de momento combinado. Não existe esforço antes de contacto confirmado, tração da perna ou sucção numa parede sem atrito. As forças de perna continuam opostas nos dois corpos e aplicadas no mesmo ponto mundial real.

O novo ensaio dinâmico mede momento linear total, não oferece uma nova certificação integral de momento angular/inércia de todos os cenários. O modelo anterior de reação não foi reescrito. O valor `linear_error` das linhas de apoio estático inclui a reação externa ao mundo e não deve ser interpretado como erro de conservação de um sistema fechado.

## Resultados focados congelados

Godot 4.7.2 Steam/Jolt; **29 checks, 0 falhas a 120 Hz e 29 checks, 0 falhas a 60 Hz**. Ambos os comandos do helper terminaram com código 0. Sem SCRIPT ERROR. O ambiente Windows imprimiu ocasionalmente aviso de leitura da store de certificados, sem relação com a física. O cleanup inicial do runner foi guardado por `InputMap.has_action`, evitando ações ainda não registadas antes do primeiro Lab.

O fixture isolado apresenta duas saliências iguais à esquerda e direita, uma perna e intenção para a esquerda. Não é um percurso nem representa ganho vertical importante. Com a mesma geometria/input, B1 escolhe esquerda e desloca o corpo para a direita; B2 escolhe direita e o desloca para a esquerda, sem acrescentar força:

| Hz | B1 Δx | B2 Δx | trabalho relativo B1/B2 | pico da perna B1/B2 |
|---|---:|---:|---:|---:|
| 120 | +4.264 mm | −4.264 mm | 0.05766 J | 22.212 N |
| 60 | +4.079 mm | −4.079 mm | 0.04983 J | 20.315 N |

Com apoios dinâmicos, B2 deslocou −3.466 mm / −3.299 mm a 120/60 Hz; resíduo de momento linear total de 5.96e−8 / 6.66e−8 kg·m/s. Foram ainda verificados: equivalência exata da seleção OFF no mesmo estado; continuidade e inversão de intenção; desaparecimento do collider; preparação sem aplicação; gesto finito; parede sem atrito; inatividade/reset; cones de atrito, orçamentos e ausência de força antes da plantação.

No Step real, duas mãos foram adquiridas por API de gesto finito e W foi pressionado durante 3 s. B0 = pés físicos OFF, B1 = seleção anterior, B2 = seleção nova. A0 fixo, mesmo nível, personagem, apoios e comandos:

| Hz | modo | subida real | integral dos módulos de força das mãos | trabalho positivo dos pés |
|---|---|---:|---:|---:|
| 120 | B0 | 0.15964 m | 404.612 N·s | 0 J |
| 120 | B1 | 0.27232 m | 257.137 N·s | 20.721 J |
| 120 | B2 | 0.27163 m | 257.330 N·s | 20.747 J |
| 60 | B0 | 0.13506 m | 376.732 N·s | 0 J |
| 60 | B1 | 0.27315 m | 238.348 N·s | 20.631 J |
| 60 | B2 | 0.27366 m | 238.180 N·s | 20.595 J |

O trabalho positivo neste Step é `max(0, F_pé · velocidade_ponto_corpo)`, com saliências estáticas. Não é energia metabólica. A integral das mãos soma módulos de força, não apenas sustentação vertical. A comparação B0/B1 mostra contribuição física dos pés já existentes; não é melhoria atribuível a B2.

As diferenças B1/B2 no Step são inferiores a 1 mm e mudam de sinal entre frequências. **Não sustentam promoção de B2 por melhor movimento, descarga das mãos ou trabalho útil.** A prova local demonstra direção de esforço mais coerente num caso assimétrico construído; o resultado global é parcial. A raiz reportou ainda First Ascent A0+B2 18/18 em ambas as frequências (`docs/validation/v11/lp3_course/attempt_001`), evidência de compatibilidade desse replay, não comparação de vantagem ou sessão humana.

## Limitações e decisão

- A procura continua limitada à amostragem local anterior; B2 não descobre superfícies fora dos mesmos raios.
- Tempo de gesto é estimativa de distância/velocidade; a trajetória real pode conter waypoints, obstáculos e movimento adicional do corpo.
- Velocidade relativa é penalização conservadora por módulo; não distingue uma plataforma que se aproxima de outra que se afasta, nem prevê aceleração/rotação futura.
- Um contacto plantado não é replaneado sob carga. A intenção pode só afetar a próxima procura natural. Não houve alteração de mecânica de libertação ou transferência.
- Não existe superfície finita de sola, articuladores de perna ou otimização multissuporte novos; continuam as aproximações anteriores de pernas virtuais e contacto pontual.
- Não foram executadas avaliações humanas de B2, nem se afirma que melhora o divertimento ou a robustez geral.

Decisão: **manter B1 por defeito e B2 opt-in experimental, com benefício global não demonstrado**. Não alterar forças, alcance ou geometria para fabricar uma vantagem. A1 continua separadamente REVISE.

## Identidade da produção congelada

- `foothold_candidate_sampler.gd`: SHA256 `a87cf3ccbf13e8fb38c322fe8720cd68219940af1434ba20e49bd9bc87fa3095`.
- `foot_contact_solver.gd`: SHA256 `efe3e3c3fe0f2bf9d9de9f35df9a0ea768e9f6e168c9fab22fdc4611c5af4fb0`.

Nenhuma alteração em controller, input, UI, coordenação A0/A1, swing ou geometria foi feita neste pacote B2. A integração e a matriz completa pertencem à raiz.
