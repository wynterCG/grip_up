# v0.7.1 — progresso real, descarga e sinal do primeiro apoio horizontal

Escopo: refinamento do perfil4 já preferido pelo designer. Não liga M6/M7, não muda perfis0–3, não altera força máxima, ganhos, alcance ou o corpo físico. As fontes de produção alteradas nesta ronda são apenas `intent_locomotion_coordinator.gd` e `locomotion_support_frame.gd`. Os testes49/30 anteriores permanecem sem edição e passam nas duas frequências.

## Falha de progresso identificada

O latch anterior só guardava contração se `actual_length <= rest_length + .025`. Sob carga, a mola implícita pode precisar de mais de25 mm de deformação, especialmente60 Hz. O corpo já se movia, mas essa postura real não era guardada; W voltava a pedir apenas o primeiro pequeno objetivo. O ensaio dedicado antigo mediu erro carregado de56.6/58.5 mm, abaixo do limite axial .12 m mas acima desse gate.

Existia uma segunda interferência: o clamp `actual±.055` usava toda a deformação já necessária para suportar o peso como se fosse parte do deslocamento adicional pedido. Uma configuração a60 com ~.043–.058 m de strain carregada quase consumia o envelope .055, mesmo havendo capacidade até360 N. Capturar apenas o delta sem preservar esse preload não resolveu o movimento. Os resultados falhados foram arquivados em `development/progress_net_only_failed_*hz.json`.

## Correção delimitada

1. Um gesto ativo estabelece uma referência de comprimento real e de hold já existente. O latch captura o **extremo geométrico líquido realmente alcançado** nessa direção a partir dessa referência fixa. Não soma todos os pequenos deltas negativos: oscilar no mesmo sítio não pode fabricar progresso infinito.
2. O neutro deixa de capturar novo progresso. Um comando novo ou direção realmente diferente estabelece uma referência nova. A referência não é reiniciada em cada passagem por saturação.
3. O objetivo continua a ser a geometria de um pequeno deslocamento virtual, com máximo .055 m e os mesmos .24 m/s/.9 m/s². O clamp preserva adicionalmente a deformação carregada medida no início do gesto; o total continua limitado pelo `max_length_error=.12` existente. Não é aumento do deslocamento COM pedido nem uma força extra de apoio.
4. Saturação/tracking impedem **adicionar contração**, mas não impedem extensão que descarrega strain não alcançada. O guard antigo também bloqueava neutral/S no mesmo target saturado, deixando o esforço preso. A primeira execução expôs esse problema e foi preservada em `development/progress_saturation_relax_failed_*hz.json`.

O uso de capacidade física existente aumenta: o novo ensaio pode atingir360 N, enquanto o gate antigo limitava indiretamente o esforço a valores menores. **O cap não aumentou, mas a força realmente utilizada pode ser maior.** Ganhos6000/220, assistência20 N·m, momento150 N·m, massa12 kg e geometria anatómica mantêm-se. Não se deve resumir esta mudança como “a mesma força efetiva em todo instante”.

## Medições no fixture físico dedicado

`test_intent_progress.gd` compara o candidato com um adaptador que restaura o gate+.025 e o clamp antigos. Mesma massa, suporte, ganhos e comandoW3 s; aquisição real finita. O fixture usa a cápsula de ensaio anterior, não substitui o bípede composto do app. **14 checks / zero falhas a120 e60 Hz**.

| Medida | 120 Hz: antigo → revisto | 60 Hz: antigo → revisto |
|---|---:|---:|
| Subida líquida apósW3 s | .0608 → .1569 m | .0876 → .1831 m |
| Rest inicial / final revisto | .5315 / .3833 m | .5315 / .3728 m |
| Rate máximo de target revisto | .2166 m/s | .2112 m/s |
| Aceleração máxima de target revista | .9 m/s² | .9 m/s² |
| Força de mão total máxima revista | 360 N | 360 N |
| Erro geométrico máximo observado revisto | .0965 m | .1000 m |
| Drift de rest após assentar, mais1.5 s sem input | 0 m | 0 m |
| VariaçãoY ao inverter paraS.7 s | −.0390 m | −.0847 m |

O pico de altura ocorre antes do fim: cerca de.35/.335 m aos1.5 s neste fixture. **W prolongado não garante subida monótona nem velocidade constante**: geometria, torque, saturação e oscilação continuam a limitar o corpo. O guião não retargeta a próxima mão nem desloca a âncora para produzir esse pico.

Negativa bloqueada: seis segundos deW numa cage física conservam hold~.512 m, em vez de integrar até ao mínimo. Deslocamento do corpo~.021 m; o rest sob esforço fica~.463 m e relaxa para~.512 m ao soltar. Retirar a cage depois do neutral não revela novo deslocamento de target; pico de velocidade posterior~.073/.052 m/s. O efeito elástico é finito e a energia não é apagada por writes de velocidade.

O principal reportou o seu guião real de duas transferências `test_intent_handoffs.gd` **10/10 em ambas as frequências** com esta correção: W, nova pega esquerda, breve W+D e nova pega direita, mesmos pontos e continuidade. Os dados finais de app/native e o significado para a experiência de jogo são registados no relatório de integração do principal; esta nota não transforma esse guião em teste humano.

## Primeiro apoio horizontal: correção de sinal separada

No fallback inicial de teto/barra, `camera_right.cross(normal)` seguido de `up.cross(normal)` dá `right=-camera_right_projected`. A correção é `normal.cross(camera_right)`. Mantém handedness válida, não altera a projeção vertical de uma parede nem o frame já estabelecido durante uma órbita.

Novo `test_intent_frame_sign.gd`: **17 checks / zero falhas a120 e60 Hz**, com UP/DOWN, três yaw iniciais, determinante da base positivo, órbita posterior e corpo dinâmico em pega real de underside. D desloca X+.0442 m face a+.0308 m neutral em.4 s a120; a60 +.0486 face a+.0333 m. A diferença comprova o sinal relativo, não um motor lateral livre ou velocidade de traverse constante.

Outputs: `builds/intent_frame_sign_<hz>hz.json`, `builds/intent_progress_<hz>hz.json`. Fontes prévias/intermédias e baselines permanecem em `docs/validation/v071/development`. Não se alterou o teste histórico49 para ocultar a falta original de uma asserção de sinal.

## Gates e limites finais

| Suite | Checks por frequência | Resultado120/60 |
|---|---:|---|
| intent_reversal |37|zero falhas / zero falhas|
| intent_progress |14|zero falhas / zero falhas|
| intent_frame_sign |17|zero falhas / zero falhas|
| intent_locomotion histórico |49|zero falhas / zero falhas|
| intent_swing histórico |30|zero falhas / zero falhas|

A revisão preserva zero motor no ar/pending, contacto antes de esforço, reações opostas e limites partilhados. A travagem rápida continua a depender de um comando oposto real; não há brake automático no neutro. O [checkpoint de reversão e sua adenda final](reversal_physics.md) distinguem a primeira alteração isolada da lacuna curta posterior de.12 s entre teclas.

Os coeficientes de atrito não mudaram: corpo de produção μ=.12; pés continuam dentro do cone de atrito/material do solver existente. O fixture pendular não mede contacto deslizante ou um novo envelope biomecânico de dedos. Posturas, inércia e colisões são as mesmas do baseline correspondente.

Decisão física: **KEEP os três refinamentos como candidato delimitado**, com regressão completa e captura nativa a cargo do principal. O designer aprovou a direção da base; esta ronda específica ainda precisa de feedback sobre controlo, previsibilidade e conforto, sem inferir diversão das contagens.
