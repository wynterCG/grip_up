# GRIP UP v0.7.1 — refinamento do controlo

Esta ronda parte do feedback «sim está melhor» sobre a v0.7. Conserva o modelo de escolher apoios com o rato e pedir movimento do corpo com WASD. O objetivo é tornar o esforço mais contínuo e o contra-comando mais direto. O feedback anterior não é apresentado como avaliação humana desta revisão.

## O que mudou

1. **Contra-comando de balanço:** uma inversão explícita passa a alimentar a rampa física existente sem atravessar também a primeira rampa de intenção. Arranque e neutral sem inversão conservam o comportamento anterior. O sistema não decide travar por observar a velocidade do corpo.
2. **Progresso sob carga:** a postura guardada acompanha a geometria realmente alcançada durante o gesto. A deformação elástica já necessária para suportar o peso deixa de consumir o deslocamento adicional pedido. Um comando bloqueado não acumula movimento futuro; neutro não faz a postura avançar.
3. **Sentido no primeiro apoio horizontal:** o referencial conserva a orientação lateral da câmara no fallback inicial, mantendo a orientação dos eixos e o transporte pelo material depois do contacto.

No HUD, `EXTENDED` identifica uma mão presa perto do alcance anatómico. Em Controls, **The Step / early grips + feet** abre a combinação usada nas duas transferências: pés físicos e seleção antecipada de um ponto distante. A parede inteira continua agarrável; as marcas são guias.

## Como experimentar

Abrir **Controls → The Step / early grips + feet**. Agarrar as duas marcas baixas com LMB/RMB e manter os botões. Usar W para subir. Conservar a mão direita, largar a esquerda e selecionar o ponto02 mantendo LMB. Depois conservar a esquerda, largar a direita e selecionar03 mantendo RMB; W com um breve D ajuda a aproximar o ombro do segundo destino. Não é necessário soltar e clicar repetidamente num alvo ainda fora de alcance.

Em **The Hang**, pedir balanço lateral e inverter o comando para sentir a resposta mais cedo. A temporização continua a contar: a alteração reduz atraso, mas não transforma qualquer contra-comando numa travagem ideal.

## Evidência e limites

A comparação isolada do primeiro checkpoint mede 208→75 ms a120Hz e200→83 ms a60Hz até ao primeiro contraesforço. O impulso inicial no sentido errado cai aproximadamente79–81%. A nota [reversal_physics.md](reversal_physics.md) preserva também os casos em que o trabalho líquido continua positivo. A revisão final reconhece ainda uma lacuna neutra de até0,12s entre duas teclas opostas; depois de uma pausa maior, o pedido volta ao caminho de arranque habitual. A igualdade de arranque/neutro é verificada entre os caminhos de swing com o mesmo controlador de progresso, não uma alegação de que toda a trajetória de W permaneceu igual à v0.7.

A sequência nova de duas transferências usa eventos reais de rato, W e um breve D. Verifica continuidade de pelo menos uma mão presa, preservação imediata da pose e velocidade ao largar, ponto material escolhido sem retargeting e ausência de força de uma mão pendente. Os ensaios a60 e120Hz não são avaliação humana.

Massa12kg, mãos360N, assistência20N·m, momento total150N·m, pés180N no total/120N cada, alcance anatómico e ganhos K/D mantêm-se. Perfis0–3 e o grabber do Janga são preservados. O perfil4 permanece opcional, com perfil2 no arranque. Mantle e o novo desafio reativo continuam dependentes da comparação humana M5.

## Validação final

**3504 verificações automáticas, zero falhas, em109 execuções de suite/frequência.** Incluem todas as regressões anteriores e os quatro novos ensaios: reversão37, progresso14, sinal17 e handoffs10 por frequência. Não foram afrouxados os testes históricos de locomoção e swing. [Resultados](results.json).

No editor de `E:\Godot Games\grip_up`, o Godot MCP Pro repetiu os movimentos com eventos de input: **32 verificações nativas, zero falhas**, sem perda de foco. As duas transferências chegaram aos pontos escolhidos a60 e120Hz. A mão pendente nunca contribuiu força e houve pelo menos um apoio de mão real durante toda a sequência. Estas observações são automáticas, não um segundo playtest humano.

| Sessão renderizada: mesmo W durante3s | 120Hz | 60Hz |
|---|---:|---:|
| Subida, só mãos |0,162m|0,139m|
| Subida, pés físicos ligados |0,273m|0,275m|
| Carga integrada das mãos, só mãos |405,33N·s|378,19N·s|
| Carga integrada das mãos, pés ligados |257,22N·s|238,07N·s|
| Primeiro e segundo contacto superior, pés ligados |ambos|ambos|

Os pés transportaram carga real. Estes números não demonstram uma melhoria universal de altura sobre a v0.7: nessa sessão histórica, pésON tinha dado0,285m/0,263m. A correção de progresso é isolada no [ensaio físico dedicado](progress_physics.md), que passa de0,061→0,157m a120Hz e0,088→0,183m a60Hz. W prolongado continua a poder atingir um pico e depois oscilar ou perder altura; não há garantia de velocidade constante nem de subida ilimitada.

O editor terminou com **zero erros/avisos**. O executável Windows `builds/GripUp-v0.7.1.exe` foi exportado e renderizou três frames de smoke test. O [recibo final](final/verification.json) verifica hashes das fontes entre as cópias C/E, igualdade do executável e o grabber do Janga inalterado. O arquivo inclui [vídeo automático](final/scripted_candidate.mp4), capturas, traces e recibos; os números não são ratings de conforto.

Foi deixada uma sessão a120Hz no Step, perfil4, pés e seleção antecipada ligados, P0 e Space desligado. O arranque normal da aplicação conserva as opções anteriores. A build v0.7 permanece disponível para comparação.

**Decisão: conservar como candidato de refinamento e pedir nova comparação ao jogar.** O feedback positivo da base justifica este trabalho, mas ainda não avalia o resultado específico. Permanecem limites de retenção em apoios reativos, perda legítima de pega no alcance e temporização do balanço. Mantle e o desafio reativo novo não começaram.
