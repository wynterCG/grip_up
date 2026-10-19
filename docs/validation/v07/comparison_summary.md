# GRIP UP v0.7 — primeiro candidato de locomoção por intenção

19 de outubro de 2026. **Disponível para experimentar; M5 humano ainda aberto.**

## A mudança de jogabilidade

O pedido do designer foi claro: a experiência atual de escalar não está interessante, e uma visão mais macro pode torná-la funcional. O candidato passa a separar duas decisões: **escolher onde agarrar com o rato** e **pedir para deslocar o corpo com WASD**. A física tenta concretizar esse pedido através dos apoios existentes.

No novo perfil4, W/S significa cima/baixo do plano de escalada e A/D significa atravessar. No chão, WASD continua a andar. LMB/RMB são sempre hold-to-grip, com libertação independente. A mira não altera comprimentos nem procura uma postura em direção à próxima pega. Sem apoio real, não há propulsão.

O arranque continua no perfil2. Perfil4, pés físicos e alvos distantes são opções separadas; P0 é a referência e Space começa desligado. A build é `E:\Godot Games\grip_up\builds\GripUp-v0.7.exe`. O relatório completo anterior continua como referência histórica do [sistema v0.6](../../reports/SISTEMA_IMPLEMENTADO_V06_PT.md); este documento descreve a alteração v0.7.

## Como experimentar o primeiro movimento

Em **Controls**, escolher **The Step / physical feet ON**. Agarrar as marcas00/01 mantendo os botões das mãos. Usar W para pedir subida. Conservar uma mão, largar a outra e escolher02 para tentar o contacto mais alto. A parede inteira continua agarrável; as marcas são orientação.

Comparar com **The Step / hands only** e com **Compare v0.6 / current arena**, mantendo geometria e flags iguais. Na comparação antiga, A/B/C continua a ter o seu significado anterior. Em perfil4, o coordenador novo possui os objetivos e não se soma ao auto-pull B/C.

Também estão disponíveis **The Hang**, **The Traverse** e **The Corner**, além dos comparadores da viga e das dez transferências. O próximo passo de design é observar se a pessoa percebe e quer repetir Step, Swing e Transfer; não construir uma montanha longa antes disso.

## Implementação e autoridade

| Camada | Alteração |
|---|---|
| Input | Perfil4 explícito, vetor digital normalizado, hold obrigatório, rato independente |
| Referencial | Normais materiais de apoios reais; filtragem de0,10s, fallback em teto e normais opostas |
| Intenção | Rampa de0,12s; velocidade virtual0,25m/s; aceleração de planeamento até1m/s² |
| Objetivo geométrico | Horizonte0,18s, deslocamento limitado a0,055m; não é posição imposta ao corpo |
| Braços | Comprimentos absolutos derivados da geometria, até0,24m/s e0,9m/s²; solver axial existente |
| Neutro e bloqueio | Conserva comprimentos de postura alcançada; sem lock do corpo, integração ilimitada de procura ou burst guardado |
| Pés | Sampler e compressão/fricção existentes, só após contacto e quando explicitamente ligados |
| Chão | Participação baseada em carga medida; motor do chão executa antes da escalada |
| Balanço | Momento limitado e reagido existente, dirigido pela intenção admissível |
| Visual | Bípede/IK seguem o resultado; HUD normal mostra estados, números ficam no debug |

Massa12kg, mãos360N, assistência20N·m, momento150N·m, pés180N/120N cada, alcance0,65708m e alvos0,18–0,62m foram preservados. Não existe força nova de COM, teleporte, atribuição de velocidade para subir, junta infinita, escolha automática da próxima mão ou Tier2 de otimização.

Os estados distinguem GROUNDED, GROUNDED_REACHING, HANG_ONE_HAND, CLIMB_TWO_HANDS, CLIMB_HANDS_FEET, FOOT_TRANSITION, AIRBORNE e FALLING_RECOVERY. Um pending não é um apoio. Slipping e perda de contacto retiram autoridade ao coordenador. O avaliador de captura continua a decidir contacto real.

O motor do chão partilha autoridade horizontal com a escalada segundo a carga medida e mantém caminhada quando só há um alvo pendente. Tração vertical pode começar com os braços slack e o corpo no chão. Pedidos de pés no mesmo corpo de chão já possuído pelo motor são removidos; uma saliência distinta pode suportar um pé real.

O momento já aplicado pelo chão é incluído na alocação **do mesmo tick**, preservando150N·m na soma dos atuadores. Não se trata de um teto para momentos externos de qualquer colisão. Apoios dinâmicos recebem as reações existentes.

## Comparação automática no Step real

Três segundos do mesmo W, corpo composto e geometria idênticos. Os valores medem deslocamento físico a partir do início do comando. O pedido de pega alta é feito pelo guião através do mesmo input; não é selecionado pelo coordenador.

| Condição | Subida120Hz | Subida60Hz | Contacto superior120/60 |
|---|---:|---:|---|
|v0.6 perfil3/A, pésOFF|≈0,000m|≈0,000m|Não / Não|
|v0.6 perfil3/B, pésOFF|0,106m|0,150m|Não / Não|
|v0.6 perfil3/C, pésOFF|0,106m|0,109m|Não / Não|
|v0.7 perfil4, pésOFF|0,130m|0,050m|Não / Não|
|v0.7 perfil4, pésON|0,285m|0,268m|Sim / Sim|

Não há superioridade universal do novo perfil mãos-only: a60Hz, B sobe mais neste intervalo. O resultado que justifica experimentar o candidato é a coordenação com **pés reais**, que permite contacto superior neste cenário. A diferença entre frequências no corpo composto e a resposta mãos-only continuam pontos de revisão.

A carga integrada das mãos na v0.7 passa de383,17 para333,96N·s a120Hz e de338,92 para289,69N·s a60Hz quando os pés são ligados. Picos de pés:79,45/83,25N, dentro do orçamento. Os dados incluem trabalho positivo dos pés e forças realmente aplicadas. Estes números não são ratings de conforto.

Dados completos: [final/intent_arenas_120hz.json](final/intent_arenas_120hz.json) e [60hz](final/intent_arenas_60hz.json). Há30 amostras por condição, incluindo posição, velocidade, carga e monitor do passo físico. Não se deduz uma garantia de FPS do número de checks; tempos do monitor dependem da máquina e carga concorrente.

## Verificação técnica

| Conjunto | Resultado |
|---|---:|
|Baseline pré-edição|3116 verificações, zero falhas|
|Matriz final com regressões anteriores|3348 verificações, zero falhas,101 execuções de suite/frequência|
|Locomoção física nova|49 por frequência|
|Balanço novo|30 por frequência|
|Input/integração jogável|19 por frequência|
|Arenas e comparadores|18 por frequência|
|Native via Godot MCP Pro|15 a120Hz +15 a60Hz, zero falhas finais|
|Editor na sessão final|Zero erros/avisos|
|Exportação Windows|Build produzida e3 frames renderizados no smoke|

As suites cobrem diagonais, frames degenerados, pés carregados sem inversão de W, zero atuação no ar/pending, contacto real, limites, neutro, saturação/bloqueio, continuidade de mãos e reação móvel. O conjunto anterior permanece na matriz, incluindo a rota de dez transferências com os perfis antigos.

As sessões com imagem repetem StepOFF/ON, contacto alto com pés, um comando de traverse com órbita e um pequeno Hang. Ambas medem subida maior com pés e adquirem a pega alta. São **guiões automáticos**, não participantes humanos. Ver [vídeo](final/scripted_candidate.mp4), [recibo120](final/rendered_120hz.json), [recibo60](final/rendered_60hz.json) e [verificação/hashes](final/verification.json). O vídeo não contém narração.

## Descobertas e falhas preservadas

1. A primeira observação de0,9s no Step mediu só1,8cm e falhou o objetivo do ensaio. O candidato precisou de uma janela maior para expressar o movimento; a resposta inicial lenta não foi convertida em sucesso humano.
2. O primeiro apoio largo avançava até ao colisor rígido da perna. A saliência foi recuada para não bloquear o próprio corpo composto, mantendo um local fisicamente alcançável para o pé. A geometria final é igual em todos os comparadores.
3. A extrapolação da velocidade descendente podia planear extensão ao pedir W. O objetivo foi corrigido, mantendo rates/forças.
4. Misturar a normal UP de um pé com a normal WALL fazia W virar para dentro da parede. Mãos reais agora definem a tangente; pés continuam a contribuir como apoios/capacidade. Há regressão explícita com peso de frame100 para o pé e0,05 para a mão, sem alterar a direção vertical.
5. O primeiro ensaio nativo de órbita a60Hz observava a direção depois de já ter perdido ambas as mãos. O sistema corretamente retirou a propulsão e publicou vetor zero. A observação final é feita enquanto existe apoio real, com uma asserção adicional dessa condição. A perda anterior continua documentada: prolongar D sem transferir pode exceder a extensão e soltar as mãos.
6. Um warning de variável local no helper de captura e mensagens InputMap de uma fixture que libertava ações antes de as criar foram corrigidos. Os logs iniciais ficaram preservados; não são resultados finais silenciosamente limpos.

Arquivo: [development](development/). Não foram aumentados força, alcance ou retenção para obter os passes.

## Limitações físicas relevantes

O corpo continua único, com membros visuais e atuadores virtuais. O novo controlador não resolve toda a biomecânica, colisões dos membros ou pose de corpo inteiro. O tratamento de bloqueio persistente usa POSTURE_TARGET_NOT_REACHED; não inventa a certeza de uma colisão sem evidência.

O fixture articulado unilateral retém a120Hz e pode perder a mão durante assentamento a60Hz. S pode acabar por exceder a extensão e perder uma pega. A travagem de balanço com as rampas atuais requer antecipação; um guião tardio chegou a fazer trabalho líquido positivo. O ensaio deliberado de brake usa0,20s de antecipação. Cantos/tetos têm validação numérica, mas não uma convenção de controlo aprovada por humanos.

Não foi feito um novo ensaio fechado de conservação com mão e pé simultaneamente na mesma viga articulada. Os caminhos de reação antigos são reutilizados e o Step mede a contribuição composta. O [suplemento do especialista](movement_controller_physics.md) responde às dez perguntas da spec e identifica os limites exatos das medições.

## Estado dos milestones e decisão

| Gate | Estado honesto |
|---|---|
|M0|Baseline técnica protegida em6752c67; queixa do designer registada; estudo humano de baseline incompleto|
|M1|Perfil/frame/negativas implementados e testados como candidato|
|M2|Coordenador Tier1 implementado; subida/descida/lateral e recusas físicas medidas|
|M3|Pés e handoff de chão integrados; StepOFF/ON comparado|
|M4|Balanço e reações auditados; timing humano ainda não validado|
|M5|Pendente: comparação humana Step/Hang/Traverse e decisão de game feel|
|M6|Não iniciado: mantle/top-out condicionado aM5|
|M7|Não iniciado: desafio reativo novo condicionado aM5|

A regra da spec exige física **e** compreensão/melhoria humana para encerrar um milestone de controlo. Por isso M1–M4 são candidatos com gates técnicos passados; não se apresentam como aceitação humana concluída.

**Decisão: REVISE / experimentar com humanos, manter opt-in.** Existe um primeiro movimento funcional e uma diferença verificável de apoio dos pés. Não há ainda evidência de que escalar ficou interessante. O [protocolo](human_playtest_protocol.md) recolhe Control, Physical Credibility, Clarity, Comfort, Skill Expression, Would Play Another Level e uma resposta livre.

## Ficheiros e reprodução

Novos módulos: `locomotion_support_frame.gd`, `intent_locomotion_coordinator.gd`, `intent_test_level.gd` e quatro cenas pequenas. Integração: `climbing_controller.gd`, `climbing_input_router.gd`, `ground_locomotion.gd`, `grip_up_lab.gd`, tuning e debug. O actuator axial, captura, pending e integridade das pegas não foram reescritos. Os testes novos são os quatro `test_intent_*`; os helpers `capture_intent_*` não entram na build exportada.

```powershell
python tools/run_regressions.py v07
python tools/project.py test test_intent_arenas
python tools/project.py test test_intent_arenas -- --60hz
python tools/project.py export
python tools/project.py smoke
```

O baseline v0.6 (`298b881`) e a sua build permanecem disponíveis. M0 foi protegido em`6752c67`; o candidato de código está em`7afacef`. O Janga original mantém o hash do grabber. Não há merge automático para main nem alteração silenciosa do perfil de arranque.
