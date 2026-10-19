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

## Adenda final: passagem breve pelo neutro e interação com progresso

O checkpoint acima foi isolado pelo principal em `1f075b7`. Depois da correção de [progresso](progress_physics.md), a dinâmica de fase mudou. A120, o guião reativo atravessou um tickZERO entre A/D: deixou de ser detetado como reversão direta e ficou exatamente igual ao controlo serial. Isto corresponde a um caso real de key-up/key-down, não justifica afrouxar o teste.

A versão final reconhece o **último comando explicitamente oposto** através de uma lacuna de até à rampa existente .12 s. Não cria comando durante essa lacuna: ZERO continua ZERO. Após neutral longo, um novo gesto usa o arranque anterior. Nenhum valor de omega decide a direção na produção. O script de investigação usa omega apenas para representar a escolha de teclas de um guião de brake.

Novo runner final: **37 checks / zero falhas em ambas as frequências**, incluindo oposição direta, ZERO1tick entre teclas, neutral.4 s com igualdade exata ao controlo, libertação curta sem cauda antiga, suporte perdido e par dinâmico. O resultado anterior27 fica histórico.

| Medida final com a mesma correção de progresso nos dois controlos | 120 Hz: serial → revisto | 60 Hz: serial → revisto |
|---|---:|---:|
| Latência direta | .2083 → .0750 s | .2000 → .0833 s |
| Impulso errado250 ms | 1.6048 → .3383 N·m·s | 1.4860 → .2860 N·m·s |
| Latência após ZERO1tick | .2000 → .0750 s | .1833 → .0833 s |
| Brake reativo5 s, sem antecipação | +3.5061 → −2.0349 J | +3.5037 → −2.4384 J |
| Energia cinética relativa máxima no brake | 1.6847 → .9885 J | 1.8141 → 1.0185 J |

Os resultados finais mostram trabalho negativo neste guião e resposta mais cedo. Não demonstram travagem universal para qualquer fase/apoio ou feedback humano. O trabalho de uma reversão isolada depende da evolução da velocidade e não é um critério universal de sucesso. Os orçamentos e os valores da rampa física permanecem iguais.

No par dinâmico do runner final, a120 `dp=4.78e−7 kg·m/s`, `dL=7.70e−6 kg·m²/s`; a60 `dp=4.81e−7`, `dL=1.14e−6`. Momento swing efetivamente aplicado ~15 N·m, com reação oposta. São inércias isotrópicas de ensaio e zero gravidade/damping; não uma afirmação de conservação ideal de todo o jogo com contactos externos.
