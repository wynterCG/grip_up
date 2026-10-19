# GRIP UP v0.7.3 — primeiro percurso contínuo

Depois do feedback «muito melhor» sobre o alcance v0.7.2, o designer pediu para continuar. Esta fase combina os movimentos já disponíveis num percurso curto: **subir, atravessar e transferir em suspensão**. É um novo ensaio M5 de jogabilidade, sem promover esse feedback a aprovação humana dos modos ainda não comparados.

## Jogar

Em **Controls → PLAY / The first route**, manter LMB/RMB nos contactos escolhidos e usar W para ganhar altura. Atravessar para a direita com W+D, alternando as mãos. Avançar ambas as mãos pela primeira barra antes de chegar à barra turquesa. R recomeça o percurso. Há chão seguro por baixo.

As áreas pintadas são regiões largas de progresso, não pontos exatos obrigatórios. As superfícies continuam livres e a resolução de alcance da v0.7.2 mantém-se. O jogo nunca seleciona uma pega nem movimenta o corpo em direção ao objetivo. O final deixa o controlo disponível e não abre o formulário de ratings automaticamente.

O percurso tem duas saliências reais, parede e duas barras estáticas sem sobreposição de volume. A última barra está recuada para dar à mão um caminho de aproximação livre. As dimensões foram ajustadas às capacidades medidas, sem aumentar força ou alcance. Não há salto obrigatório, novo pump assistido, top-out ou estrutura reativa nesta fase.

## Progresso e conclusão

Cada etapa exige uma mão realmente ATTACHED, âncora válida dentro de uma região e altura efetiva do corpo, durante pelo menos0,2s. Uma seleção pendente não conta. Perder todas as mãos reinicia o percurso e regista uma recuperação.

O final exige contacto no **collider da última barra**, corpo a pelo menos1,60m, sem apoio do chão e com carga total dos pés no máximo1N durante0,2s contínuos. Inclui forças de pés SLIDING: não basta procurar o estado SUPPORTING. Os pés podem voltar a encontrar apoio depois da conclusão; não se promete suspensão indefinida.

Os comprimentos, massa12kg, mãos360N, assistência20N·m, momento150N·m, pés180N/120N por pé e contacto finito não mudam. Os módulos de física da v0.7.2 são preservados; esta fase acrescenta geometria, pontuação baseada em observação, integração e testes.

## Validação e limites

A matriz completa, com as regressões anteriores, passou **3636 verificações automáticas em117 execuções**. Depois do último ajuste geométrico, repetiram-se as suites diretamente afetadas: route_progress, climbing_route e intent_integration, a60/120Hz. Os testes novos cobrem impedir bypass por alvo pendente, chão, pés a deslizar sob carga, contacto noutro material, altura insuficiente e perda de apoios. [Resultados](results.json).

O playthrough físico realiza oito transferências depois das duas pegas iniciais, sem escrever pose ou velocidade do personagem. Passa15/15 checks em ambas as frequências: ganho de altura~0,594m/0,543m, suspensão contínua~1,00s/1,27s e zero recuperações. A [nota de física](../m5/route_physics.md) contém geometria, sequência, picos de esforço e limitações.

O teste nativo usa Godot MCP Pro e input através da aplicação. **34 verificações passaram**,17 por frequência, sem perda de foco. Conclusão em~10,85s a120Hz e11,97s a60Hz desde o primeiro contacto, com zero recuperações. A medição independente nativa confirmou suspensão contínua por0,367s/0,617s no material final sem carga significativa dos pés. Não é uma avaliação humana de diversão. Os [recibos](final/verification.json), capturas e [vídeo](final/scripted_candidate.mp4) finais ficam em final/.

O editor terminou sem erros/avisos. A build Windows `builds/GripUp-v0.7.3.exe` foi exportada e renderizou três frames de smoke test. O recibo verifica as fontes e o executável nas cópias C/E, mantendo o grabber do Janga inalterado. O código do percurso está em`a0ebfa9`; a build v0.7.2 e os laboratórios anteriores ficam disponíveis.

As tentativas falhadas não foram transformadas em êxitos: houve distância excessiva, trajetória atravessando a primeira barra, alvo na barra errada e uma chegada com a face frontal do lado oposto ao ombro. O arquivo [development](development/) conserva recibos/traces nativos e falhas completas da variante frontal. Alguns ensaios headless intermédios foram sobrescritos antes de serem arquivados; nesses casos há apenas um resumo com proveniência parcial, identificado como tal.

Uma asserção nativa inicial exigia pés sem carga no snapshot posterior à chegada. Foi substituída por uma medição independente, por tick, da janela real de suspensão no material final, que é o contrato do objetivo. A falha anterior está preservada em `native_recessed_foot_recontact_120hz.json`; o código não impede os pés de voltarem a apoiar depois. Os logs Windows foram normalizados para LF, preservando mensagens e falhas.

**Decisão: conservar como percurso de ensaio M5 e comparar ao jogar.** O designer aprovou a base de alcance, ainda não esta rota. M6 mantle e M7 desafio reativo continuam por iniciar. O objetivo desta revisão é observar se a sequência cria fluxo, sem inferir diversão das contagens automáticas.
