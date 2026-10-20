# Revisão independente PV1 — preflight de fontes

2026-10-20. Revisão estática, sem motor, ensaios, alteração de fontes, Git ou sincronização. Esta nota precede qualquer mundo PV. Não constitui GO de projeção/replay nem prova de ausência de efeito instrumental.

## Autoridade e preservação

Foram inspecionados os hooks de `grip_up_lab.gd` e `grip_targeting.gd`, o novo `projection_probe.gd`, `virtual_cursor_driver.gd`, `run.py`, `projection_comparison.py`, `projection_campaign.py`, os contratos novos, `test_plan.json` e a identidade de baseline.

A baseline declarada no ficheiro é `d87d35cbdf6a9f593b1608368ed3be59eb36d2f9`. A comparação local de bytes dos 280 ficheiros da sua lista encontrou apenas quatro diferenças em ficheiros já existentes: Lab, Targeting, virtual driver e Python run.py. Os restantes 276 correspondiam à lista. Os módulos novos não pertenciam à lista antiga e precisam da identidade própria do novo freeze. Este resultado é uma leitura pontual, não um lock: o coordenador ainda estava a corrigir os contratos quando foi escrito.

Os hooks de seleção têm o âmbito mínimo previsto. Lab obtém o probe apenas enquanto possui input virtual e só chama begin/end quando não é nulo. Targeting continua a mesma ordem dos sete offsets, máscara 3, alcance de query 70 m, exclusão do torso e break no primeiro hit elegível. O vetor original utilizado pela query é agora uma variável guardada e passada ao probe; o hit é o resultado da única `intersect_ray` existente. As leituras adjacentes de local-ray/world-ray/effective transform não fazem queries físicas adicionais nem substituem o vetor da query.

O probe só lê campos de corpo/câmara/input/material. Não foi identificada escrita de pose/velocidade, força, alvo físico, collider ou ATTACHED neste caminho. A mudança de Window encontra-se no driver de ensaio, antes de construir o mundo. O caminho LIVE, o solver, os budgets, as geometrias e a câmara original não foram alterados nos restantes ficheiros protegidos. Esta inspeção não substitui as regressões normais nem o controlo ON/OFF.

O canal binário é apropriado: Godot emite os bits binary64 dos escalares promovidos, separados da representação JSON. O valor vetorial float32 promovido continua a ser float32, não adquire precisão extra. Zero com sinal e qualquer arredondamento do leitor JSON devem ser distinguidos de um desvio real do motor. O contrato deve verificar que o sidecar está completo e ligado ao mesmo payload, em vez de aceitar apenas os bits que por acaso existam.

## Achados enviados antes do freeze

As localizações referem a primeira versão lida; podem deslocar-se nas correções posteriores. Nenhum achado abaixo é uma falha física observada.

| ID | Local | Defeito concreto na versão lida | Correção mínima pedida |
|---|---|---|---|
| PF1 | `projection_probe.gd`, begin_pick | `physics_delta` era calculado como 1/Hz, embora descrito como delta real. | Passar o delta efetivamente recebido pelo callback de física antes do commit; manter expected delta separado. |
| PF2 | `projection_comparison.py`, validate | `numeric_bits={}` ou um mapa incompleto podia passar, pois só eram validados os paths presentes. | Exigir conjunto completo dos paths de float do payload, bits com formato/tamanho válidos, tipo e finitude coerentes. |
| PF3 | `projection_comparison.py`, pair | A comparação numérica Python usa igualdade numérica e não distingue −0/+0. A primeira versão não comparava sidecars. | Comparar bits nos estágios declarados estritos; não chamar igualdade de bits a uma igualdade que omite sinal de zero. Já se viu uma correção intermédia para local/world-ray, ainda antes do freeze. |
| PF4 | probe/driver | Window era validada antes do mundo e antes/depois de cada pick entre si, mas faltava confronto no próprio pick com o tamanho solicitado. Uma mudança entre picks poderia não ser rejeitada. | Guard de tamanho real por pick contra manifest e viewport lógico contra tape; nenhuma correção silenciosa de coordenadas. |
| PF5 | comparison pair / campaign paired | O retorno HARD_STOP para PICK_COUNT não tinha `hard_reasons`, mas o chamador indexava esse campo. | Retorno/consumo uniforme, com receipt explícito em vez de KeyError que interrompe sem gravar a razão. |
| PF6 | campaign, observer controls | O resultado ON/OFF era guardado, mas não decidia hard stop para diferença de input/câmara/material. | Aplicar gates explícitos; diferença numérica contínua pode continuar apenas como diagnóstico, nunca prova de efeito zero. |
| PF7 | campaign, tape loading | O plano continha SHA da tape, mas o executor recebia apenas o path. Validava o payload, não o SHA pré-registado no plano. | Comparar SHA do ficheiro com o plano antes de executar; não aceitar outra tape apenas por ser internamente válida. |

PF3 tem dois níveis: zero com sinal nas saídas local/world-ray é diretamente relevante para localizar a diferença; bits de transforms/projeção/query/material também devem ter a política declarada. Não basta preservar bits no disco se o comparador que anuncia STRICT_MATCH os ignora. Comparar runtime IDs entre processos continua incorreto; a normalização deve remover só identidade de processo, preservando geometria/material e os valores físicos observados.

## Gates e interpretação da instrumentação

A política de compatibilidade restringe o delta a uma allowlist e compara todos os restantes hashes com a baseline, mantendo `capture_source_hashes` originais. Isso preserva a separação histórica desejada, desde que o novo freeze registe os SHA antigos/novos exatos. A allowlist é uma fronteira de ficheiros, não prova automática de que qualquer conteúdo permitido é só de leitura; esta revisão do diff e o freeze completam esse controlo.

Uma leitura adjacente depois da query é uma observação útil, mas não se deve descrevê-la como interceção das variáveis internas de `project_ray_normal` anterior. O campo de ordem no probe explicita essa diferença. O guard adjacent-world igual ao vetor original é conservador: se falhar, o trace é inválido para atribuir a cadeia, não autorização para substituir o vetor utilizado.

`get_camera_transform()` pode diferir de global transform por offsets/fase. O probe regista ambos e a flag física; APIs internas sem acesso público ficam `UNAVAILABLE_PUBLIC_API`. Os transforms públicos de canvas/stretch não devem ser convertidos em supostas leituras internas. A causa só pode ser atribuída após comparar os novos dados.

O tempo `probe_usec` mede a janela begin→end por pick, incluindo leituras e construção do sidecar, mas exclui escrita final do ficheiro e o restante logger. É custo parcial de observação por pick, não custo total do ensaio nem prova de latência nula.

O plano confirma 36 processos normais mais quatro diagnósticos individuais máximos; regressões separadas. P2/P3 têm n=3 total por célula, contando o preliminar. Os controlos mantêm o observador físico antigo ON e variam apenas o novo probe. Logo, não podem ser chamados observador totalmente OFF.

## Releitura das correções antes do freeze

O coordenador respondeu aos achados e foi feita nova leitura estática dos ficheiros, ainda sem qualquer execução do motor por este especialista:

- PF1: o driver passa `delta` ao probe imediatamente antes do commit; `physics_delta` usa esse valor e o probe verifica compatibilidade com a frequência. O guard original do driver também permanece.
- PF2: validate deriva todos os paths de floats, excluindo o próprio sidecar, e exige igualdade do conjunto de chaves; verifica formato de 16 dígitos hexadecimais/8 bytes, valor coerente e finitude antes de restaurar o valor binário.
- PF3: `strict_difference` compara a representação binary64 dos floats nos estágios de pick, incluindo zero com sinal. O comparador também mantém diagnóstico explícito dos bits local/world-ray. A camada física histórica continua a sua comparação numérica publicada; não se deve apresentá-la como uma comparação bit-a-bit de todos os campos do mundo.
- PF4: begin_pick verifica Window real contra manifest e visible rect lógico contra o frame da tape, além da comparação environment antes/depois.
- PF5: PICK_COUNT retorna agora `hard_reasons`, consumido pelo chamador sem a lacuna identificada.
- PF6: os controlos ON/OFF interrompem em diferenças das camadas input/cursor/camera/raycast/material-anchor. Uma diferença exclusivamente física fica preservada como diagnóstico, sem reivindicar não interferência.
- PF7: cada execução verifica o SHA do ficheiro de tape contra o valor congelado no plano antes de chamar o executor.

Os sete achados estão **fechados por revisão de fonte**. A confirmação dos testes/execuções é responsabilidade dos receipts do coordenador; este especialista não os executou nem inventou os seus resultados.

Identidade da releitura:

| Ficheiro | SHA256 |
|---|---|
| `grip_up_lab.gd` | `4789bff5e5db866aebcb26f593e549639f7d3c4bbe5643e8bfeec813b2c88b7b` |
| `grip_targeting.gd` | `7a9f7f7896f7ac53570a7c46d975c997884204d4a271dcae1c64fbff07c0407c` |
| `projection_probe.gd` | `8034665b24b854c7c2b15cea21bd2ce861b020abc5a42a78e7187bc86adc6ca8` |
| `virtual_cursor_driver.gd` | `36cad7acbdcd21fc9d275e4b5819dca6919de274f98281d585405a2052be684b` |
| `run.py` | `780b23eb2d1c271618111545e481bc0b06de249f538d4a96ad40c60bff0719ea` |
| `projection_comparison.py` | `baaef4094dd09dc9c173bcc706da6830d907d65eb16be3aedf3f605fb2d575a9` |
| `projection_campaign.py` | `61ebb756df125f6ce8f83759c6f4daa97545e42b274bc5b8963b195c7f8461d7` |
| `test_plan.json` | `aaed4dda59216e81207d73002464a7caee6f675419066bad494ca8a130a05d4d` |

## Estado do preflight

O encadeamento de autoridade da seleção e os contratos corrigidos são adequados à investigação limitada. **Não ficou um bloqueador estático PF1–PF7 pendente nesta releitura.** O coordenador pode fechar o freeze após os contratos e regressões previstos; isto não antecipa qualquer GO de projeção/replay. Nenhum dado PV foi usado para propor estas correções; nenhuma tolerância, parâmetro físico, tape ou objetivo foi alterado por este especialista.
