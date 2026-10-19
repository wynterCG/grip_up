# M5 — prova física do percurso curto

Ensaio do nível de produção `climbing_route_level.gd` pelo runner `test_climbing_route.gd`, a 60 e 120 Hz. O runner usa eventos reais LMB/RMB e ações W/D através da aplicação; não altera posição, rotação, velocidade, ganhos ou limites do corpo. Esta prova estabelece viabilidade de uma sequência, não diversão, facilidade humana ou robustez para todas as trajetórias.

## Geometria e alcance

- Parede frontal em z=0, x[-.75,1.25]. Chão seguro com topo y=.25 sob o percurso.
- Saliência inicial: centro (0,.51,0), dimensões (.95,.16,.22), topo .59. Segunda: centro (.62,.73,0), dimensões (.60,.16,.22), topo .81. Ambas terminam em z=.11, atrás do volume da perna na aproximação inicial.
- Primeira barra: centro (1.20,2.66,.08), dimensões (.65,.12,.24), face frontal z=.20. Última: centro (1.75,2.70,-.04), dimensões (.45,.12,.24), face frontal recuada z=.08. As barras encostam em x=1.525 sem sobreposição de volume; a chegada recuada é acessível do lado onde está o ombro. As guias indicam faces frontais; o contacto resolvido continua a ter de existir na geometria real e pode atingir uma face inferior da primeira barra.
- Pontos indicativos pedidos: (-.24,2.10,0), (.24,2.10,0), (-.24,2.43,0), (.24,2.64,0), (.45,2.55,0), (.90,2.60,0), (.95,2.63,.20), (1.45,2.65,.20), (1.20,2.63,.20), (1.75,2.68,.08).
- Alguns pedidos de parede são resolvidos para outro ponto real alcançável no mesmo collider pela política v0.7.2. O JSON guarda pedido e contacto material efetivo. Não se afirma que todos os contactos coincidem com as marcas.
- Alcance anatómico R=.65708 m, gesto finito existente de 4 m/s, comprimentos de mola e margem elástica originais. Não há extensão adicional autorizada pelo nível.

A última face está em y≈2.68: o ombro no chão está em y≈1.69 e nem um braço vertical consegue ultrapassar y≈2.35. Portanto, caminhar no chão e agarrar diretamente a chegada não completa este percurso. O objetivo exige também altura real do corpo >=1.60 m e ausência de carga dos pés/solo durante .2 s.

## Sequência física reproduzida

1. Segurar LMB no ponto inicial esquerdo e RMB no direito; esperar .3 s.
2. Manter W 3 s; soltar apenas LMB e agarrar o ponto 02. Esperar .25 s.
3. Manter W+D, soltar apenas RMB e agarrar 03. Largar D após contacto, manter W por 1 s.
4. Manter W+D. Trocar L para 04; esperar .6 s. Trocar R para 05; esperar .3 s.
5. Antes de largar L, permitir até 2 s para o ombro L entrar numa janela física de distância <.64 m da face 06. Este é um critério do jogador automatizado para escolher o momento, sem deslocar ou capturar nada. Trocar L para 06 por movimento finito.
6. Esperar .3 s; trocar R para 07, ainda na primeira barra. Esperar .3 s; trocar L para 08, também na primeira barra: este contacto descruza e alinha as mãos antes do avanço.
7. Esperar .3 s; trocar R para 09 na barra final. Manter W+D por .6 s após contacto e depois largar D, mantendo W mais .8 s.

Cada pedido espera contacto real por até 3 s. O alvo pendente não produz força. A mão de apoio anterior mantém o contacto até a troca explícita; pelo menos uma mão ficou realmente ATTACHED em todos os passos.

## Resultado final

| Medida | 120 Hz | 60 Hz |
|---|---:|---:|
| Checks | 15/15 | 15/15 |
| Tempo do primeiro contacto à conclusão | 11.092 s | 10.783 s |
| Transferências após dois apoios iniciais | 8 | 8 |
| Recuperações / perda simultânea dos apoios | 0 | 0 |
| Altura final do corpo | 1.761 m | 1.710 m |
| Subida relativamente ao início estabilizado | .594 m | .543 m |
| Maior suspensão contínua medida: COM>=1.6, apoio final, solo falso, força TOTAL dos pés<=1 N | 1.000 s | 1.267 s |
| Pico de soma das forças das mãos | 360.00 N | 262.97 N |
| Pico da força das pernas | 156.90 N | 106.19 N |
| Pico do momento combinado chão+escalada | 61.69 Nm | 94.80 Nm |

Limites preservados: mãos360 N, pernas180 N, assistência20 Nm e momento combinado150 Nm. Os picos são medidos em cada tick; as amostras de trajetória no JSON são apenas10 Hz para limitar o arquivo. Contactos completos permanecem separados.

Artefactos: `builds/climbing_route_120hz.json`, `builds/climbing_route_60hz.json`; logs do helper `builds/test_test_climbing_route.log` e `builds/test_test_climbing_route_60hz.log`.

Estes valores provêm das execuções finais já feitas pelo root após o recuo da barra; para esta atualização documental não houve novos reruns. Não se confundem janela de suspensão e estado permanente: a120 Hz houve1.000 s contínuo com carga total dos pés<=1 N, mas nas últimas amostras os pés voltaram a carregar aproximadamente5.6–11.2 N. A60 Hz as últimas amostras têm força dos pés exatamente0 N. Em ambas as frequências a janela exigida foi contínua, superior a.2 s, com contacto real na barra final, corpo elevado e sem solo; não foi apenas um tick sem contacto. A prova não afirma que os pés ficam desligados após a conclusão.

## Iteração e limites

A primeira proposta, com barras centradas em x1.40/y2.78 e x1.95/y2.82, falhou: a primeira barra ficou a1.087 m do ombro livre L durante a saída da parede, claramente além de R. Aproximar e baixar as barras, e escolher uma face frontal real, resolveu a geometria sem mudanças no atuador. Uma tentativa de chegada em x1.45 foi interceptada pela primeira barra a60 Hz; escolher x1.75 expôs a barra final de facto. Estes são resultados de desenvolvimento resumidos; os artefactos finais contêm a geometria aprovada, não um replay do cenário inicial falhado.

Uma espera fixa antes da barra foi sensível à fase da oscilação. A janela física antes de largar L preserva um gesto legível: manter o apoio, aproximar-se, trocar quando o corpo oferece alcance. Não demonstra captura garantida em qualquer fase.

A sequência preliminar de seis transferências passou headless13/13 em ambas frequências mas o ensaio nativo120 falhou a passagem direta da mão R da parede à barra final. A diferença de fase/render expôs uma obstrução real: o segmento de partida da mão atravessava a primeira barra. O journal registou uma janela de alcance de .558 s encerrada com `PATH_OBSTRUCTED`; esperar mais tempo depois do contacto não resolvia a captura anterior. Esse ensaio foi preservado pelo root em `docs/validation/v073/development/native_first_120hz.json` e no trace comprimido associado.

Acrescentar somente R na primeira barra e cruzar L imediatamente à final também falhou headless: a pose inclinada deixava o ombro L muito longe. A sequência de oito transferências acrescenta dois contactos intermédios na primeira barra, permitindo alinhar os apoios e avançar de novo com R. Passou headless com a geometria anterior, mas uma execução nativa ainda expôs bloqueio da trajetória final. O root preservou as falhas nativas iniciais e respetivos traces no diretório de desenvolvimento. A prova final acima substitui essas sequências/geometrias preliminares; não se afirma equivalência de fases entre render e headless. A validação nativa final é tarefa separada do root.

A barra final anterior sobrepunha a primeira em20 cm e ambas tinham face frontal z=.20. A tentativa de corrigir avançando a face final para z=.32 também falhou nos dois ensaios headless: o ombro R estava em z≈.118–.164, atrás dessa face, e o próprio collider de destino bloqueava o gesto apesar da distância estar dentro do alcance. Esses resultados completos foram arquivados em `docs/validation/v073/development/forward_final_bar_headless_120hz.json`, `forward_final_bar_headless_60hz.json` e nos logs homónimos. O ajuste final remove a sobreposição em x e recua a face para z=.08; não altera trajetória, regras de colisão, ganhos ou caps do braço. A captura final passou a ocorrer após.133 s a120 Hz e.117 s a60 Hz, sem autorização de contacto futuro. A120 Hz o pedido original de.6644 m foi resolvido para um ponto real aR=.65708 no mesmo collider; a60 Hz o pedido já estava dentro do alcance.

Os ficheiros completos dos ensaios headless de sete transferências foram sobrescritos antes do pedido de arquivo. `docs/validation/v073/development/headless_seven_transfer_summary.json` preserva valores observados no output das ferramentas, identificando explicitamente essa proveniência e a ausência dos logs brutos; não representa uma reexecução ou trace completo. Os ensaios nativos iniciais foram preservados separadamente pelo root.

O scorer final exige também o collider `Finish hanging bar`. Uma região AABB sozinha sobrepunha parte da primeira barra e podia atribuir chegada ao suporte errado; a janela de suspensão do runner já exige o suporte final e força TOTAL das pernas<=1 N.

Com apenas .3 s de D após o contacto final, o caso60 Hz teve .183 s de suspensão estrita à altura pedida. Continuar o mesmo comando por .6 s, sem força adicional, satisfaz a condição de .2 s. O scorer foi revisto pelo root para contar também forças de pés SLIDING; não basta o nome do estado SUPPORTING para afirmar suspensão.

Não se demonstra um salto obrigatório, bombeamento energético necessário, mantle, saída por cima da parede, locomoção aérea sem apoio ou uma nova técnica de teto. A última etapa é transferência curta e suspensão real. Pés podem voltar a procurar contactos enquanto alguma mão continua presa; a conclusão prova a janela suspensa medida, não suspensão indefinida. W prolongado não garante subida monotónica ou velocidade vertical constante.
