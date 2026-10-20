# Evidência Godot MCP Pro

Foi usado o Godot MCP Pro 1.17.1, através do CLI local, para iniciar `reliability_review.tscn`. O processo executou o mesmo driver físico e produziu contacto, carga e retenção reais, com restauro e invariantes válidos. É `automated_rendered_scripted`, sem input humano ou classificação de feel.

O recibo apresenta `monitor_index=0` (monitor 1 na convenção usada no projeto). A captura terminou com duas imagens, observadas visualmente e guardadas com o [índice original](native/attempt_001/screenshot_index.json):

| Imagem | Último tick físico observado | Tempo do episódio | Mãos observadas |
|---|---:|---:|---|
| [Antes da seleção de destino](native/attempt_001/screenshots/frame_01.png) | 281 | 2,341667 s | ATTACHED / FREE |
| [Contacto no destino](native/attempt_001/screenshots/frame_02.png) | 438 | 3,650000 s | ATTACHED / ATTACHED |

As imagens são de `frame_post_draw`, associadas ao último snapshot `post_control`. Não são snapshots do solver. O readback/save custou aproximadamente 45,8 e 41,5 ms; esta demonstração com screenshots não é uma repetição independente de custo nulo nem integra a matriz qualificada de 32 execuções.

O [resultado original](native/attempt_001/engine_result.json) é copiado para consulta; a cópia integral com manifestos, hashes, logs, rastos e comandos fica em [native_mcp_001.zip](evidence/native_mcp_001.zip). As imagens mostram também a plataforma/pés, reforçando que o ensaio não demonstra suspensão exclusivamente por um braço.

## Ativação local e identidade

A primeira tentativa de ligação, com o editor fechado, e a tentativa seguinte com o plugin não ativo ficaram preservadas. A configuração local `override.cfg` não foi suficiente para ativar o plugin no editor observado. Foi necessário adicionar temporariamente a ativação a `project.godot`; o plugin também geriu os seus autoloads locais e o editor reserializou a configuração. Esta é uma diferença de proveniência declarada, não uma alteração silenciosa da baseline.

O manifesto suplementar usa os hashes reais da cópia E: nessa altura e `dirty_tree=true`. Dos 254 ficheiros públicos do mapa qualificado, apenas `project.godot` diferia, por essa configuração local do editor. O resultado não é comparado como tape de identidade exata com as 44 execuções qualificadas. A [ativação](development/mcp_activation/activation.json), a [configuração temporária](development/mcp_activation/project_after_mcp_before_restore.godot) e o [restauro byte a byte](development/mcp_activation/restoration.json) ficam documentados.

## Diagnósticos e arranque normal

A cena de laboratório apresentou cinco avisos estáticos, preservados no arquivo: quatro nos ficheiros históricos `response_metrics.gd`/`optimization_trial_driver.gd`, mais o nome local `ready` que sombreia o sinal herdado de Node no driver novo. A resposta do plugin contém 15 linhas para esses cinco diagnósticos; não se chama a isso 15 exceções de runtime. Não houve exceção observada que impedisse a captura. O código medido foi mantido congelado e estes avisos não foram ocultados ou corrigidos depois para reetiquetar a execução.

Depois de parar a cena de investigação, o MCP iniciou o main normal. A [consulta de runtime](normal_startup_mcp/attempt_001/runtime.json) confirmou:

- Perfil 2, A0, 120 Hz, hold-to-grip ativo.
- Velocidade/rampa/rate/aceleração em 0,25 / 0,12 / 0,24 / 0,9.
- Massa 12 kg, alcance 0,65708 m, budget mãos 360 N, assist 20 Nm e momento combinado 150 Nm.
- Nenhum driver de investigação, observer, recorder ou sessão de testes ativa.
- Flags normais de pés físicos/intent-aware em OFF, conforme o arranque original.

A consulta de erros dessa sessão veio vazia. O jogo e o editor foram então fechados, o pedido explícito de investigação removido e `project.godot` reposto com SHA256 `6ae2782544aa70dfb6a099260ead68de0b0bb7007093ef846bbb2dabfc6a86c9`, igual em C:/E:. O [smoke posterior ao restauro](normal_startup_mcp/attempt_001/post_restore_cli.json) executou o main por 180 frames sem erros reportados. O projeto não ficou em modo de investigação.
