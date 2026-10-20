# v1.1 — A1: heurística de geometria/carga, experiência não aceite

Data: 2026-10-20. **Decisão de engenharia: REVISE; manter A0 como predefinição.** A1 está implementado como comparação opt-in, mas os resultados atuais não sustentam promovê-lo como melhoria do movimento. Os checks de segurança passam; a resposta útil e a torção pioram nos casos assimétricos medidos. Não foram recolhidos ratings humanos por este trabalho.

## Âmbito e interface

Ficheiros deste trabalho:

- [constraint_aware_allocation.gd](../../../features/grip_up/scripts/constraint_aware_allocation.gd): novo helper de intenção, sem aplicação de forças.
- [intent_locomotion_coordinator.gd](../../../features/grip_up/scripts/intent_locomotion_coordinator.gd): ligação opcional limitada ao cálculo geométrico de alvos.
- [test_locomotion_allocation.gd](../../../features/grip_up/tests/test_locomotion_allocation.gd): runner novo e saídas próprias.
- Este relatório. O integrador é responsável pelos flags/UI, observador LP1, controller e validação da aplicação; não foram editados por este agente.

```gdscript
controller.intent_locomotion.movement_allocation = 0 # A0, predefinição
controller.intent_locomotion.movement_allocation = 1 # A1, comparação experimental
```

Não há A2. A0 mantém o cálculo anterior e a sua ordem. A1 só substitui a pequena mudança geométrica por mão, antes dos mesmos mecanismos de postura alcançada, anti-windup, limite de repouso e limites de taxa/aceleração. Nenhuma mola, força, massa, âncora, colisão, velocidade corporal, frame, seleção de pés ou swing foi alterado. O reset do coordenador e a retirada para híbrido limpam o helper; não mudam a política explicitamente selecionada.

O helper fornece `evaluate(controller, ids, body_step, direction, delta) -> Dictionary`. O resultado aparece em `telemetry.intent_locomotion.movement_allocation` apenas quando A1 está ativo. Inclui label/variant, mudanças originais/admitidas, pesos, alinhamento assinado, carga/margem material, sensibilidade local e momento axial estimado. `advisory_classification` pode ser AVAILABLE/PARTIALLY_ACTUATABLE/SATURATED/NO_SUPPORT. `collision_assessed=false`: não inventa GEOMETRICALLY_BLOCKED sem evidência de colisão.

## Modelo implementado

1. Usa somente mãos ATTACHED, com âncora válida e de tração. Pending e palmas não recebem uma autoridade nova.
2. Calcula o incremento original `|âncora − (ombro + passo_virtual)| − comprimento_atual`. Contração é negativa; alongamento alivia tensão e permanece intacto.
3. Para contração, pondera o alinhamento **assinado** da tração com o comando e a margem de carga material. Alinhamento fraco/oposto é atenuado; uma margem acima de 35% não recebe penalização de carga. Não altera o limite de integridade nem a capacidade do atuador.
4. Estima a sensibilidade axial incremental usando o denominador implícito e a massa efetiva existentes. Para duas alavancas de sinal oposto em torno do eixo do tronco, reduz apenas a contração que aumenta o binário incremental resultante. A redução adicional tem máximo de 75%; o outro braço nunca é amplificado.
5. Filtra a ponderação com resposta de 0,08 s. Os limites originais de alvo continuam depois: 0,24 m/s e 0,9 m/s²; repouso 0,18–0,62 m; offset 0,055 m; deformação máxima da mola 0,12 m.

Isto é uma heurística local, não uma otimização de wrench, previsão de colisões ou prova de viabilidade. Não aumenta o budget: 360 N partilhados de mãos, 20 N·m comuns de assistência e 150 N·m resultantes. Os pés mantêm o seu budget separado de 180 N e a mesma seleção. A reação física continua a ser aplicada pelo controller/atuador existentes.

Limitações do modelo: massa efetiva/COM AUTO herdados do atuador, derivada local que não representa os contactos seguintes, redistribuição de carga e evolução da orientação. Uma redução de momento instantâneo pode deslocar a carga para o outro braço e **aumentar** a torção integrada. Os dados abaixo demonstram esse risco; não se deve anunciar que a heurística já o resolveu.

## Protocolo e resultados

Suite nova: `test_locomotion_allocation`, a 120 e 60 Hz. **77 checks, 0 falhas em cada frequência**, sem SCRIPT ERROR ou warnings de script nas execuções finais. Isto valida segurança/contratos; não são 77 provas de melhoria de gameplay.

Ficheiros:

- `builds/locomotion_allocation_120hz.json` e `locomotion_allocation_60hz.json`.
- `builds/test_test_locomotion_allocation.log` e `test_test_locomotion_allocation_60hz.log`.
- Desenvolvimento preservado em `builds/locomotion_allocation_development_001_120hz.{json,log}`. A primeira execução com dependência LP1 ainda em edição teve erro de compilação do observador; não é um resultado físico.

Os ensaios fixos usam o mesmo corpo de 12 kg, perfil de braços do bípede, apoios reais, aquisição finita, gravidade e o mesmo input por 1,4 s. Pés OFF. A cápsula isolada mede 1,7 m/r0,20 e o amortecimento usa REPLACE 0,08/0,35: é um fixture controlado do mecanismo, **não uma réplica completa da geometria/drag da aplicação**. A mão direita assimétrica é mais baixa e afastada lateralmente. Não há edição de pose/velocidade durante a atuação.

| Caso / Hz | Movimento útil A0 → A1 (m) | Twist RMS A0 → A1 (rad) | Tilt RMS A0 → A1 (rad) |
|---|---:|---:|---:|
| Simétrico W /120 | 0,23357 → 0,23353 | 0,000585 → 0,000581 | 0,27316 → 0,27315 |
| Simétrico W /60 | 0,21116 → 0,21112 | 0,000532 → 0,000519 | 0,25724 → 0,25723 |
| Assimétrico W /120 | 0,20889 → 0,18873 | 0,04977 → 0,07368 | 0,36974 → 0,36263 |
| Assimétrico W /60 | 0,20000 → 0,18651 | 0,06230 → 0,07833 | 0,36267 → 0,35858 |
| Assimétrico diagonal /120 | 0,10848 → −0,00620 | 0,04937 → 0,09791 | 0,29880 → 0,28123 |
| Assimétrico diagonal /60 | 0,09469 → −0,00704 | 0,05592 → 0,09949 | 0,28741 → 0,26775 |

Todos esses casos conservaram as pegas durante a janela. Uma mão com W produziu os mesmos resultados A0/A1 nesta geometria: deslocamento 0,22630 m/120 e 0,22068 m/60. Uma redução ligeira de tilt não compensa a perda de movimento útil ou o aumento de twist. Não foi encontrada melhoria geral.

Checks adicionais:

- Nenhum apoio e pending: força/binário exatamente zero, trajetórias balísticas A0/A1 iguais.
- O helper não modifica pose, velocidades ou comprimentos ao avaliar. Pode sugerir alvos; não tem autoridade de captura.
- A0 produz resultados de alvo/estado exatamente iguais sobre a **mesma geometria viva** com cache A1 não utilizada. Execuções Jolt independentes não são alegadas bit-idênticas: diferença de deslocamento A0 repetido 0,0000546 m/120 e 0/60, registada.
- Neutro e câmara não acumulam alvo; a extensão geométrica que alivia tensão é preservada.
- Quatro segundos contra caixa rígida não acumulam contração arbitrária; retirar a caixa após neutro deixa drift do alvo de 0 m em ambas as frequências. Reset e commit híbrido limpam memória.
- Par dinâmico fechado, sem gravidade/drag desde o início e com inércias isotrópicas explícitas: esforço não nulo de 5,53 N/120 e 5,75 N/60. Resíduo de momento linear 3,58e−7/2,38e−7 kg·m/s e angular 6,75e−7/4,92e−7 kg·m²/s. É uma verificação do par físico aplicado; não prova conservação energética em cenas com chão/juntas/drag. Não é um novo estudo de desempenho de uma viga articulada.

O primeiro teste do par mudava gravidade/drag/inércia **depois** de uma fase carregada: não constituía o sistema fechado limpo pretendido e falhou o seu check. O fixture final define essas condições antes da aquisição; não foi aumentado o limite da asserção para ocultar o resultado.

## Integração e decisão

O integrador comunicou `test_locomotion_hybrid` com A1+observador: 22/22 a120 Hz, mas HIGH não completou a60 Hz (LOW passou); recibo `docs/validation/v11/lp1_hybrid/attempt_001`. Não foi alterado o gate de aquisição, native ground ou caminhada. A regressão é compatível com a atenuação de contração útil observada, embora a causa específica de cada falha da aplicação não seja provada apenas por esta correlação.

**REVISE, não promover para default.** A1 é seguro nos fixtures testados e preserva os budgets, mas a hipótese de melhorar a alocação não se confirmou. A0 permanece a referência jogável. A UI deve identificar A1 como experiência, sem promessa de maior agência ou subida. Não há justificação para adicionar A2 automaticamente ou misturar B2/C1 na mesma comparação para mascarar estes dados.

Uma revisão posterior exigiria separar melhor sustentação existente, ganho translacional e custo angular no horizonte físico real. Antes de implementar outra técnica, usar os traces LP1 e feedback do designer para decidir se a limitação relevante é mesmo esta, em vez de postura, timing de captura ou geometria. Nenhuma avaliação humana, rating, KEEP ou melhoria de diversão é inventada neste relatório.
