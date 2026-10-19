# v0.7.1 — resposta ao contra-comando

Checkpoint físico independente da correção posterior de progresso contínuo. O designer confirmou melhoria da base v0.7; esta alteração não refaz o sistema nem liga mantle/M6 ou desafio reativo/M7.

## Alteração isolada

Só `intent_locomotion_coordinator.gd` muda em produção. O perfil4 deteta uma **mudança explícita de comando para direção oposta**, não a velocidade do corpo. Durante esse contra-gesto, fornece ao `SupportedSwing` o comando novo sem repetir a primeira rampa de intenção .12 s. Mantém a rampa física existente .10 s, governor, reação e limites. Os braços e pés continuam a receber a intenção suavizada anterior.

Gesto inicial, comando constante e libertação sem reversão usam o caminho anterior. Após um contra-gesto curto, libertar fornece ZERO em vez de ressuscitar a cauda de sentido antigo. Um gesto novo iniciado do neutro volta ao caminho anterior. Não há reset de torque/velocidade nem seleção automática de brake baseada em omega. A assistência pendular só existe com apoios reais.

Perfis0–3, massa, K/D, aquisição, alcance, força360 N, assistência20 N·m, momento150 N·m e forças opcionais de pé não mudam. Não foi criado parâmetro de força nem nova API de input. Telemetria adicional: `swing_reversal_active` e `swing_request_world`.

## Evidência matchedbaseline

`test_intent_reversal.gd` executa o candidato e um adaptador de teste que restaura exatamente o pedido serial de swing da v0.7. Geometria, ganho, input e estado inicial são iguais. As comparações de arranque e de libertação simples verificam igualdade **exata** de traço físico/força/rest. O guião de brake reativo tem a mesma regra fechada nos dois casos; os timings das teclas podem divergir quando a dinâmica diverge. Não é input humano.

| Medida | 120 Hz: antigo → novo | 60 Hz: antigo → novo |
|---|---:|---:|
| Primeiro contraesforço >.05 N·m | .2083 → .0750 s | .2000 → .0833 s |
| Impulso de torque no sentido errado, primeiros250 ms | 1.6236 → .3408 N·m·s | 1.4807 → .2812 N·m·s |
| Trabalho swing, brake reativo5 s, sem antecipação | +3.4577 → +2.8500 J | +3.3579 → +.1483 J |
| Energia cinética relativa máxima desse guião | 1.6844 → 1.6844 J | 1.8141 → 1.0185 J |

A resposta ao contra-comando melhora 58–64% e o impulso no sentido errado cai ~79–81%. **Isto não prova brake ideal:** trabalho líquido continua positivo neste guião, especialmente120. O integral dos primeiros500 ms de uma reversão isolada também não é sempre menor; a60 passa de1.4502 para1.4635 J. O ganho aceite é expressão mais cedo do comando, não uma promessa de energia sempre removida.

O ensaio histórico de swing30checks continua a passar sem editar o teste. Pump passa a fazer mais trabalho com as inversões explícitas, sem aumentar torque máximo: a120 ~25.21 J face aos19.91 J v0.7; a60 ~25.04 J face20.18 J. O brake antecipado conserva trabalho negativo; comando constante12 s e neutral conservam os resultados anteriores. Essa mudança de trabalho vem do timing, não de mais força autorizada.

## Validação e envelope

Novo runner `test_intent_reversal.gd`: **27 checks / zero falhas a120 e60 Hz**. Outputs `builds/intent_reversal_<hz>.json`. Cobre igualdade do arranque e neutral, reversão, impulso errado, brake reativo, libertação curta sem cauda antiga, perda de apoio/ausência de motor no ar e reação num material dinâmico partilhado. O par fechado usa inércias isotrópicas de ensaio e zero damping/gravidade para isolar o wrench modelado.

O envelope de atrito **não foi ampliado**. Em produção o corpo mantém μ=.12, e pés continuam unilaterais/fricção limitada pelo mínimo material/solver. O fixture pendular não tem contacto deslizante de corpo/chão: não mede um novo envelope de Coulomb. O momento do gripper continua o modelo idealizado finito já documentado, não uma simulação completa de dedos e atrito torsional. Damping do fixture fixo é o existente .08/.35 em modo combinado com defaults de mundo; esses valores não mudaram.

Preservação: `development/intent_reversal_baseline_120hz.json`, `_60hz.json`, logs `reversal_baseline_*`, fonte `coordinator_before_reversal.gd.txt` e fonte/checkpoint `coordinator_after_reversal_only.gd.txt`. Os dados iniciais mostram o brake que injeta energia, sem apagar a falha de design. Uma primeira execução do novo teste teve erro de inferência de tipo em variável local e foi corrigida antes de medir produção; não é um resultado físico passado.

Decisão deste checkpoint: **KEEP como refinamento de resposta delimitado, sujeito a native/humano**. Não altera o arranque aprovado nem interpreta neutral como um pedido autónomo de travar.
