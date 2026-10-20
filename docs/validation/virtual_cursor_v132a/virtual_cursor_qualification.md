# GRIP UP — Virtual Cursor Isolation v1.3.2a

**Decisão: NO_GO_INPUT_REPLAY.** Implementação isolada e diagnóstico direto concluídos; a matriz congelada foi interrompida na admissão da primeira tape, antes de criar o mundo físico. A correção passou o diagnóstico permitido. Isso não substitui os ensaios de replay renderizado, input físico externo e mudanças de foco que ficaram por executar. Nenhuma otimização foi iniciada.

## O que foi implementado

`GripInputFrame` é um valor por tick, com cópia defensiva no construtor e nos getters. Distingue validade da mira, coordenadas viewport, movimento, estados de botões, edges ordenadas, WASD, órbita/dolly, identidade, sequência e foco. A representação armazena held/pressed/released semanticamente em `strengths` + `button_edges`, sem inferir validade a partir de `(0,0)`. As coordenadas não são arredondadas nem recentradas. Não há warp nem hook global do rato.

`LiveInputProvider` fornece o snapshot físico normal; `ReplayInputProvider` é opt-in, apenas com flag explícita `--virtual-cursor-evaluator` e build de desenvolvimento. O caminho LIVE mantém os eventos imediatos anteriores; não foi transformado num replay de edges quantizado por tick. Os snapshots LIVE não são tapes qualificadas. O controlador físico, motor de chão, hybrid/v0.8, recursos físicos, materiais e geometria ficaram byte-iguais à base.

O provider virtual tem DISABLED→ARMING→ACTIVE→FINISHING→DISABLED, com INVALID para falhas. Valida clock, sequência, frame único por tick real do motor, viewport/transformações, window mode/size, owner da câmara, FOV, bindings e identidade world/body/controller. Um estado pausado invalida a sessão. Hardware, eventos de UI e callbacks de foco são bloqueados no caminho virtual; foco real é metadata independente. Não foi comprovada ainda a eficácia destes guards contra interferência humana. Há stream limitado de rejeições, sem autoridade física.

Os pontos virtuais entram no `request_hand` normal. O seletor continua a executar os mesmos sete raios ordenados, máscara3, distância70m e exclusão do corpo, parando no primeiro hit elegível. O audit copia os resultados desses mesmos queries e o offset vencedor; preview visual posterior não pode substituir o audit do pedido. O solver continua a decidir REACHING/ATTACHED, contacto, força e âncora material. Não há body teleport, estado ATTACHED escrito pelo teste, novo apoio ou mudança de alcance.

## Câmara e ordem real

V0 usa o contrato novo `V0_PHYSICS_FOLLOW`: mesmas equações, órbita/dolly e raycast de obstrução; pose atual não interpolada do corpo; um update antes do picking e nenhum segundo follow no render. LIVE conserva `_process`50 e a pose interpolada. Esta mudança de sampling tem identidade própria e impede atribuir qualquer melhoria exclusivamente ao cursor ou explicar retroativamente o R0 antigo.

Ordem: PRE−100 carrega/commita o frame e aplica câmara/pedido; ground−10 continua a usar o move_intent guardado no Lab anterior; Lab0 guarda a intenção atual; callbacks originais do controlador aplicam os actuadores; POST+100 observa o estado pós-controle antes da próxima integração. Não é chamado post-solver. Um tick invalidado não é qualificado; callbacks separados podem consumir a intenção anterior até cleanup/teardown, sem reescrever o timing do solver.

O escopo suportado é profile4 / A0 / B1 / Swing & Catch. Profile diferente, hybrid e v0.8 são recusados antes de armar; os seus leitores globais inalterados não são anunciados como isolados. Startup normal continua profile2.

## Capturas novas, distintas dos dados v1.3.2

Foram executadas três capturas de desenvolvimento: uma inicial120 antes dos últimos guards e duas congeladas120/60 no commit5c9d644. Não são réplicas de qualificação, não são somadas a32/32 históricos nem usadas para reward. Nas duas congeladas houve contacto físico, destino carregado, origem FREE e retenção da mesma âncora. O pedido foi além do alcance estático0.65708m, com a margem original0.02m do cenário. Ambos selecionaram a face inferior−Y real de `catch`.

| Hz | Contacto destino | Origem FREE | Primeira retenção ≥0.6s | Distância no pedido | Face real |
|---|---:|---:|---:|---:|---|
| 120 | 440 | 455 | 527 | 0.814922 m | −Y |
| 60 | 215 | 223 | 259 | 0.807716 m | −Y |

Isto documenta diretamente a face60Hz nesta captura nova. Não resolve o caso antigo de+Z por decreto, não prova imunidade ao rato e não qualifica trajetórias contínuas. Os episódios incluem as contribuições B1/chão; não são arm-only.

## Primeira falha e paragem

O primeiro dos24 processos, `V0-H_120_r1_c56d2f29`, devolveu `BLOCKED_SETUP / INPUT_BUTTON_EDGE`. A tape continha mão0 inteira em JSON; o parser Godot devolveu0.0 e a validação por membership numa lista de inteiros recusou-a. O primeiro edge na tape era tick55, mas **nenhum tick de cenário foi executado**. Não existe desvio físico, de câmara ou de material medido nesta tentativa. `first_divergence.json` separa admissão de tape de mismatch durante uma simulação.

A captura construía Dictionary com inteiros; por isso o erro só surgiu no roundtrip JSON. A correção d13fd0c aceita valores numéricos integralmente iguais a0/1 e passos de roda−1/+1; rejeita mão fracionária, sem arredondar pixels. Os testes agora incluem roundtrip real JSON e mão0.5. A matriz não foi repetida:1 tentativa rejeitada,23 NOT_RUN_EARLY_STOP. V0-H/R/M/F×60/120×n3 continua **não qualificado**.

## Diagnóstico permitido depois da paragem

A proposta inicial de executar os quatro negativos foi restringida pela revisão independente. Só N1 era diretamente relacionado com o gate JSON; N2/N3/N4 continuam NOT_RUN_EARLY_STOP. A proposta e a adjudicação ficam preservadas separadamente.

N1 executou uma vez a120Hz em fonte corrigida. Utilizou uma tape derivada `diagnostic_only`, mantendo frames/referências/manifest SHA e `capture_source_hashes` originais, e declarando o novo mapa do replay + quatro diffs aprovados. Python e GDScript recusam esta tape fora de um caso negativo. Não é recaptura, substituição da tape congelada ou resultado qualificado. Os primeiros quatro frames têm as alterações negativas explícitas no harness.

Os9 checks passaram: rejeição de source, viewport, câmara, tick duplicado e tick em falta; validade sem mira preserva semântica held; pressão com mira inválida não cria novo target; `(0,0)` explicitamente válido é aceite e executa o targeting real. Houve depois contacto440, origem FREE455 e retenção527, face−Y, como observação diagnóstica. Não foram executados os casos de mouse/wheel externo, Alt+Tab humano, UI adversarial, silhouette de um pixel ou abort a meio. A implementação desses hooks não é prova de que passaram.

## Revisão física independente

Foram inspecionados1335 snapshots POST das duas capturas congeladas e N1. Nos474 estados-mão REACHING a força foi zero; também zero fora de ATTACHED/SLIPPING. Todos têm12kg/profile4/sem ownership hybrid. Picos observados: mãos254.948N, pés45.471N, por pé45.471N, assistência20.0000014Nm (arredondamento float), momento combinado76.761Nm. Mantêm-se360N partilhados,180N pés/120N por pé,20Nm assistência e150Nm resultante. Nenhum limite foi aumentado. Detalhes e limites estão no parecer independente.

N1 coincide pontualmente com a captura120 nos COM/v/omega e force budgets publicados. Isso não cria envelope contínuo nem aprovação de Jolt/replay entre processos ou Hz. A retenção verificada está ligada à mesma âncora material real. Nenhuma conclusão de causalidade sobre a interferência antiga do sistema operativo foi tirada.

## Segurança do projeto

- 34 processos de regressão: **1146 checks passaram** (24 de física/locomoção:884; mais10 de input LIVE:262), cobrindo pegas/forças, pending, intenção, inversão, chão, frames, First Ascent, mantle/hybrid, recovery e pés.
- Contratos finais: **24 checks Godot +11 testes Python passaram**; não somamos reexecuções de desenvolvimento como cobertura nova.
- Godot MCP Pro1.17.1, monitor0: main ordinary profile2, input LIVE, provider DISABLED, câmara virtual false, flags/pesos/alcance/bindings iguais à base. Screenshot `normal_main.png`, inspecionado visualmente. O scanner inicial assinalou apenas um projeto antigo dentro de builds; consulta fresca após main:0 erros.
- Após fechar apenas o editor iniciado nesta tarefa, project.godot foi restaurado byte a byte. Um novo processo headless confirmou o snapshot normal exatamente igual ao guardado na v1.3.2.
- Export release Windows e startup smoke passaram. A inspeção do pack com o motor num diretório isolado confirmou a ausência dos drivers/providers de teste e startup profile2/DISABLED. Essa inspeção usa a build de ferramentas, não pretende medir `OS.is_debug_build` da template. A tentativa de script externo na template release expirou40s e foi preservada; a primeira inspeção sem diretório isolado foi descartada por fallback a fontes locais. Os recibos não foram ocultados.
- Dos4625 ficheiros anteriores,4620 estão byte-iguais em C e E. Só quatro scripts de input/câmara/diagnóstico e a exclusão de export têm diffs aprovados. Todo o evaluator antigo, relatórios, tapes, controller, tuning, Janga e rollback permanecem iguais. Paridade dos278 ficheiros públicos de fonte verificada.

## Entregáveis e utilização

`test_matrix.json`, `first_divergence.json`, `verification.json`, auditoria/revisões specialist, protocolo original e adjudicação, e `evidence_manifest.json` acompanham este relatório. O [suplemento de input LIVE](live_input_safety_addendum.md) regista os10 processos finais, incluindo as verificações originais de focus-out e release. Não preenche células V0. Os ZIP têm SHA256 por arquivo e por membro e foram relidos para validar os bytes. Extraia para uma pasta nova; não sobreponha os estudos históricos.

O projeto de utilização continua em `E:\Godot Games\grip_up`. Recuperação: tag `baseline/pre-v1.3.2a-virtual-cursor`, commit0be1667; fonte inicial5c9d644, correção diagnóstica d13fd0c. O ficheiro de rollback pré-v1.3 foi preservado, sem substituir a build anterior.

## O que continua por fazer

A infraestrutura permanece disponível mas **não autorizada para scoring**. Uma nova qualificação deve ter orçamento/identidade próprios e começar com o roundtrip corrigido, antes de render/humanos, câmara/silhouette e abort/foco. Este relatório não reabre essa campanha. One-hand60, lateral mirror, envelopes contínuos e holdouts da v1.3.2 continuam abertos. Optuna/ML/Jev/RL/M7 continuam OFF. Sem avaliação de gamepad ou novo playtest de feel nesta fase; código/bindings LIVE preservados e regressões disponíveis passaram.

## Referências de API

As APIs foram consultadas na documentação oficial e exercitadas no motor instalado4.7.2, sem assumir que a página stable descreve a ordem específica deste projeto: [Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html), [Input](https://docs.godotengine.org/en/stable/classes/class_input.html), [Viewport](https://docs.godotengine.org/en/stable/classes/class_viewport.html), [coordenadas do rato](https://docs.godotengine.org/en/stable/tutorials/inputs/mouse_and_input_coordinates.html). O código e os traces deste projeto definem a ordem medida.
