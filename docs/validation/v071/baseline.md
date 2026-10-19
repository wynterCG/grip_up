# v0.7.1 — refinamento da base aprovada

O designer respondeu “sim está melhor” à v0.7 e pediu para continuar. Esta ronda mantém a direção de controlo e trabalha expressão do contra-comando, progresso sob carga e transferências. Não é uma aprovação humana antecipada das alterações novas.

Baseline recuperável: `cea4ae0`, branch `feature/v0.7-intent-driven-locomotion`; código do candidato em`7afacef`. Build anterior `GripUp-v0.7.exe` preservada. O recibo de3348 verificações e30 checks nativos foi copiado para [pre_v071](../../baselines/pre_v071/verification.json). A branch nova é `feature/v0.7-control-refinement`.

Primeiro checkpoint isolado: `1f075b7`, resposta ao contra-comando. Arranque e neutral sem reversão permanecem exatamente iguais nos comparadores dedicados. Ver [reversal_physics.md](reversal_physics.md).

O ensaio novo de duas transferências no Step encontrou uma limitação antes da correção de progresso: W completava a primeira pega alta mas não a segunda. Um breve D adicional permitia a segunda a120Hz, enquanto a60Hz o alvo continuava fora de alcance. Não foi aumentado o alcance para o agarrar. As tentativas iniciais e os logs com falha ficam em [development](development/).

A hipótese confirmou-se, juntamente com a interferência do preload no pequeno envelope de movimento. O código de integração está em`4a89d40`; os [resultados finais e a decisão](comparison_summary.md) incluem3504 verificações automáticas e32 nativas sem falhas. Massa, limites de força/momento, captura real, hold-to-grip e independência da mira continuam a ser invariantes. A força efetivamente usada pode aumentar dentro do mesmo teto, como detalha a [nota física](progress_physics.md).

M5 humano continua em avaliação. Mantle/top-out e o novo desafio reativo permanecem gates posteriores da spec, não trabalho silenciosamente promovido nesta ronda.
