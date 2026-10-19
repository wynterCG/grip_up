# GRIP UP v0.7.2 — alcançar e agarrar dentro do limite real

O pedido do designer foi reduzir a necessidade de acertar no indicador de alcance: clicar para além do limite deve permitir ao braço ir até onde consegue e atuar num contacto alcançável. Esta revisão altera explicitamente a regra de seleção do perfil4; a comparação de ponto exato da v0.6 continua no perfil3.

## Comportamento

Em **Controls → The Step / max reach + feet**, manter LMB/RMB numa superfície. Se o ponto clicado estiver longe demais, o controlador propõe um ponto na interseção do plano dessa superfície com o alcance do braço. Um raycast real tem de confirmar geometria do mesmo corpo dentro do alcance. A mão percorre a trajetória finita já existente e só começa a carregar depois de o avaliador confirmar contacto real.

O alcance continua a ser **0,65708m**, incluindo palma, sem uma redução artificial para90%. O contacto resolvido fica fixo em coordenadas locais do material; mover o rato, a câmara ou o corpo não arrasta uma mão agarrada pela parede. O clique original e o contacto escolhido ficam distintos nos diagnósticos.

Se não existir superfície elegível nessa projeção, se outro corpo a bloquear ou se o próprio plano estiver longe demais, o pedido conserva o comportamento pendente: estender até onde é possível sem força antes de tocar. Não há procura global de outra plataforma, contacto imaginário ou movimento automático do corpo para o clique. A resolução depende da opção de seleção antecipada, já ligada pelo botão **max reach + feet**.

Também foi corrigida a apresentação no chão: perfis3/4 podiam ter um endpoint físico esticado mas manter os braços na animação Idle/Walk. Agora o IK dos braços acompanha a tentativa enquanto as pernas conservam a animação de chão. Os comprimentos dos ossos mantêm-se.

## Evidência

O teste físico dedicado compara clique a~0,695m com contacto real a0,65708m. Chegada em~0,275s a120Hz e0,283s a60Hz, sem deslocamento instantâneo da mão ou do corpo. Força antes do contacto: zero; força depois do contacto: positiva. Os27 checks por frequência cobrem também cancelamento, material móvel, obstáculos, projeção sem geometria, outra superfície e preservação do perfil3/flagOFF. [Nota física](reachable_grip_physics.md).

Os12 checks visuais por frequência verificam endpoint no alcance máximo, braço renderizado no seu comprimento máximo e direção correta, pernas em gait de chão e regresso dos braços ao repouso depois de largar. A animação Idle desloca o ombro visual relativamente ao ombro físico fixo; neste fixture a distância wrist→target chega a~6cm. O teste regista essa diferença e verifica a extensão máxima sem alongar os ossos, não uma coincidência visual perfeita nessa pose.

No Godot MCP Pro, cliques3cm e15cm acima do ponto limite da parede adquiriram contacto real abaixo do clique em ambas as frequências. **26 verificações nativas passaram**, sem perda de foco, mantendo os dois contactos presos no fim de cada tentativa. O editor não reportou erros/avisos. Estes são ensaios automáticos; o «perfeito» inicial do designer aprovou a proposta.

Depois de a sessão atualizada ficar disponível, o designer respondeu **«muito melhor»**. Este é feedback humano positivo desta revisão de alcance. Não foram inferidos ratings numéricos, resultados nos restantes modos ou conclusão de toda a comparação M5.

Massa, ganhos K/D, força360N, assistência20N·m, momento150N·m, alcance, blend e velocidade finita da mão não mudaram. Os comparadores anteriores e a build `GripUp-v0.7.1.exe` ficam preservados.

A matriz completa passou **3582 verificações automáticas em113 execuções**, incluindo as regressões anteriores, sem falhas. [Resultados](results.json) e [recibo final](final/verification.json). A build Windows `builds/GripUp-v0.7.2.exe` renderizou os três frames do smoke test; as fontes C/E e o executável têm os hashes verificados. Código em`46f7210`.

A sessão final fica no Step a120Hz, perfil4, seleção antecipada e pés ligados, P0 e Space desligado, pronta para a comparação humana. Abrir a build começa nas opções normais anteriores; **Controls → The Step / max reach + feet** prepara o mesmo cenário.
