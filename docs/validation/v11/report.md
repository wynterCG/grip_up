# GRIP UP v1.1 — experiências de locomoção antes de M7

Esta entrega implementa comparadores e diagnóstico da [spec v1.1](../../specs/grip_up_v1.1.md), preservando a locomoção atual. **Não há uma melhoria geral demonstrada nem promoção de novos controlos.** O resultado negativo de A1 é parte da entrega, não um teste escondido. A spec inteira e a avaliação humana não estão concluídas.

## Referência e reprodução

- Projeto/editor: `E:\Godot Games\grip_up`; espelho de trabalho em `C:\Users\Wynter\grip_up`.
- Branch: `feature/v1.1-locomotion-refinement`.
- Referência jogável: tag `baseline/pre-v1.1-locomotion`, commit `6646cdeda0a0104b723c483905a9a4fc36e00674`.
- Congelamento LP0: commit `c3bcf1b3567c76bbc56e47aee13e7c971dedddd9`.
- Godot 4.7.2 Steam, hash `ed1daf0bf001b61586d9930840f2f1394092c079`, Jolt integrado; 120 Hz e comparação 60 Hz.
- Build anterior preservada: `builds/GripUp-v1.0-pre-v1.1.exe`, SHA256 `79c592e0dcaffdfe185cd9c4115a74a7f0e98f21c8f3705e4869807b11aa8293`.

O designer esclareceu que a spec fornecida já definia o trabalho. Prosseguimos com experiências isoladas sem exigir outro questionário. Isso não equivale a classificações humanas, aprovação de defaults ou autorização para M7. O relatório [pré-M7](../../reports/SISTEMA_IMPLEMENTADO_PRE_M7_PT.md) e os recibos LP0 são históricos; o manifesto da presente entrega é separado.

## Comportamento entregue e decisões

| Sistema | Comparação e alteração real | Decisão atual e limites |
|---|---|---|
| LP1 diagnóstico | Observador opcional por tick, movimento útil, forças, pés sob carga, contactos nativos e janelas de transição ±0,5 s. Corrige a origem do pedido de swing observado no perfil 4. | **KEEP técnico** como ferramenta; não é prova de melhoria do feel. Não escreve estado físico. |
| A movimento | A0 anterior; A1 atenua pedidos de contração por geometria, carga e custo angular estimado. Mesmos limites de alvo e atuação. | **REVISE**. Menos progresso e mais twist em casos assimétricos. A0 continua predefinido. A2 não implementado. |
| B pés | B0 OFF; B1 anterior; B2 pontua os mesmos candidatos locais por esforço possível, compressão/atrito, gesto, deriva e continuidade. | **REVISE / experiência local**. Direção melhora num fixture controlado, vantagem geral não demonstrada. B1 continua predefinido. Não há novo planeamento de carga multissuporte. |
| C balanço | Feedback opcional de esforço driving/braking/neutral para uma mão, baseado na potência incremental já existente. | **KEEP técnico do feedback, benefício humano pendente**. É apenas um piloto de leitura; revisão física completa C1 e C2 não implementadas. |
| D transições | Instrumentação, regressões reais de mãos/top-out e arquivo de janelas. Motor híbrido e walking preservados. | **KEEP do mecanismo atual nos ensaios**. Sem correção física especulativa; não é uma auditoria humana exaustiva de todas as transições. |
| E qualidade de pega | Sem alteração. | **ADIADO**, opcional e condicionado à aceitação anterior/ficção de contacto. |
| F câmara | Sem alteração. | **ADIADO**, opcional e condicionado à aceitação anterior. |

Detalhes: [LP1](LP1_DIAGNOSTICS.md), [A1](A1_PHYSICS.md), [B2](B2_PHYSICS.md).

## Resultados físicos relevantes

No fixture assimétrico W, a 120 Hz, A0→A1 passou de 0,20889→0,18873 m úteis e de 0,04977→0,07368 rad de twist RMS. Na diagonal passou de +0,10848→−0,00620 m úteis. A 60 Hz as regressões têm o mesmo sentido. O high ledge A1 falha a 60 Hz; o recibo está preservado em `lp1_hybrid/attempt_001`. Passar os 77 checks de segurança por frequência não transforma estes resultados em melhoria de gameplay.

B2 mudou o deslocamento horizontal no fixture de uma perna e duas saliências: +4,264→−4,264 mm a 120 Hz; +4,079→−4,079 mm a 60 Hz, com intenção para a esquerda e mesmo esforço. No Step completo, B1→B2 subiu 0,27232→0,27163 m a 120 Hz e 0,27315→0,27366 m a 60 Hz. A diferença inferior a 1 mm muda de sinal: não sustenta ganho geral. A melhoria B0→B1 pertence aos pés anteriores.

Os pares dinâmicos de A1/B2 verificam reação no suporte, mas não são certificados universais de energia nem uma nova validação de todos os sistemas articulados. As aproximações, geometria dos fixtures e limites estão nos relatórios especializados.

## Utilização

Em Controls, escolher o perfil 4. Para referência: A0, B1 ou pés OFF conforme comparação, feedback/diagnóstico OFF. Para testar apenas B2: manter A0, ligar pés físicos e selecionar B2. Para comparar A1: manter o mesmo estado dos pés e selecionar A1; não misturar alterações para atribuir vantagem. O feedback de swing e o observador são independentes. R mantém as escolhas e reinicia o nível.

Hold LMB/RMB, cursor para selecionar, libertar para largar, MMB para orbitar e roda para distância mantêm-se. O cursor não contrai braços no perfil de intenção. A escolha B2 não liga os pés silenciosamente. A observação mantém no máximo 16 janelas completas e 16 pendentes; desligá-la evita o custo de cópias por tick.

## Verificação técnica desta entrega

**5 094 checks headless, 159 execuções, zero falhas**: 4 356 da regressão anterior em [v11_baseline/results.json](../v11_baseline/results.json) e 738 em [final/attempt_001/results.json](final/attempt_001/results.json), incluindo comparadores, observador, pés, percurso e regressão v1.0. As frequências estão discriminadas nos recibos. O asset isolado tem uma execução, os restantes ensaios ambas as frequências. Estes totais contam checks técnicos, não participantes nem observações humanas.

Uma variável local A1 chamada `load` produzia um aviso de shadowing no editor. Foi renomeada para `current_load`, sem mudar a expressão física, depois da matriz. A suite A1 foi repetida a 60/120 Hz: [warning_cleanup/attempt_001](warning_cleanup/attempt_001/results.json). Não se somam os 154 checks repetidos ao total anterior. Os recibos mantêm os hashes das versões efetivamente testadas.

O percurso visível A0+B2 com feedback e observação ligados passou 18/18 em ambas as frequências via Godot MCP Pro, monitor 1. [Primeira captura](native/attempt_001/results.json): picos mãos/pés/momento 331,98 N/120,05 N/95,22 Nm a 120 Hz e 312,58 N/118,33 N/75,79 Nm a 60 Hz. Todas as linhas assistidas arquivadas têm ownership exclusivo 16; não se exige aceleração zero na colisão. As 16 últimas janelas por execução são guardadas comprimidas com screenshots. A medição de CPU no último tick, 82/104 µs, é apenas uma amostra, não um estudo de performance.

A build Windows `GripUp-v1.1-experimental.exe` exporta e arranca com renderização de três frames. Este smoke verifica arranque/apresentação, não repete todo o percurso dentro do executável. O teste nativo usa o projeto no editor. Hashes, paridade C/E e verificações finais constam de `verification.json` nesta pasta.

A revisão dos traces encontrou ainda forças individuais das mãos em cache durante ownership híbrido, apesar de os atuadores já estarem desligados. O observador passou a publicar zero nesse intervalo. Os traces nativos antigos conservam o campo desatualizado; não são prova de força aplicada durante o top-out. Observador, híbrido e percurso foram repetidos a 60/120 Hz em [assisted_observer_fix/attempt_001](assisted_observer_fix/attempt_001/results.json), 120 checks sem falhas, além da matriz inicial. O arquivo nativo final indicado no manifesto verifica explicitamente os vetores zero.

[Captura final corrigida](native/attempt_003/results.json): 18/18 em cada frequência, com 285/126 linhas assistidas arquivadas a 120/60 Hz, todas com forças normais das mãos zero e ownership exclusivo. Picos mãos/pés/momento: 332,04 N/120,06 N/94,66 Nm a 120 Hz; 299,12 N/136,33 N/63,54 Nm a 60 Hz. A variação entre execuções é reportada, não tratada como determinismo exato. [Chegada a 120 Hz](native/attempt_003/v11_120hz_finish.png), [chegada a 60 Hz](native/attempt_003/v11_60hz_finish.png) e [controlos](controls.png) foram inspecionados visualmente. O [editor termina sem erros ou avisos](editor_errors_final.json).

Os traces grandes estão em `.json.gz`, com compressão sem perdas; por exemplo, `gzip.open(caminho, 'rt')` seguido de `json.load(...)`. Os resumos `results.json` ficam legíveis sem descompressão. As tentativas falhadas e as execuções anteriores não foram descartadas.

O [arranque limpo](runtime_startup.json) confirma perfil 2, A0, novos switches OFF, 120 Hz e limites de referência. A [sessão preparada](prepared_candidate.json) é diferente: First Ascent, perfil 4, A0+B2, pés físicos e feedback ON, observador/trace OFF, monitor 1. É uma configuração explícita para experimentar, não uma alteração dos defaults. Não há helper de inputs a correr.

## Alterações de código

| Ficheiros | Responsabilidade |
|---|---|
| `constraint_aware_allocation.gd`, `intent_locomotion_coordinator.gd` | Heurística A1 isolada e seleção A0/A1; sem autoridade física direta |
| `foothold_candidate_sampler.gd`, `foot_contact_solver.gd` | Ranking B2, memória local, diagnóstico e troca idempotente sem replantar contactos carregados |
| `climbing_controller.gd`, `locomotion_observer.gd` | Integração por perfil, origem real de swing e observação opcional |
| `transfer_diagnostics.gd`, `capture_trace.gd` | Origem corrigida do pedido e inclusão de observações compactas |
| `grip_up_lab.gd` | Comparadores independentes, mensagens e feedback; controlos antigos preservados |
| Cinco suites `test_locomotion_*`/`test_intent_feet`/`test_refinement_course` e helper de captura | Segurança, comparação, transições e percurso finito; recibos separados |
| `tools/run_*`, `archive_locomotion_refinement.py`, `verify_locomotion_refinement.py` | Regressão, arquivo de tentativas, conservação de evidência e manifesto de paridade |
| `export_presets.cfg`, `tools/project.py` | Nome/versionamento da build v1.1; executável v1.0 preservado |

O manifesto enumera os caminhos e hashes concretos. Atuador de braços, swing físico, support frame, walking e controller híbrido conservam os hashes do congelamento LP0. A lista acima não atribui uma reescrita desses motores à v1.1.

## Preservação e trabalho restante

Mantêm-se corpo 12 kg, alcance ~0,65708 m, mãos 360 N partilhados, pés 180 N/120 N por pé, assistência 20 Nm, momento 150 Nm, variação de alvo 0,24 m/s e aceleração 0,9 m/s². Sem alteração da trajetória híbrida estática de 1,15 s, sem top-out dinâmico, aumento de força, teleporte de escalada, root motion ou novo nível M7.

Ainda faltam avaliação humana A/B, revisão de A1 baseada nos resultados, demonstração de benefício geral de B2 e o trabalho físico completo C1 se se justificar. E/F permanecem condicionais. A revisão das transições usa os novos traces para justificar correções específicas; colisões legítimas não são tratadas automaticamente como bugs. Não se inventam ratings nem sessões terminadas.

**Pré-M7: NO-GO para promover as experiências como melhoria comprovada.** A referência A0 continua disponível e os testes técnicos da entrega são registados separadamente. Uma decisão de gameplay exige observação do designer; não está implicitamente aprovada por uma regressão automática.
