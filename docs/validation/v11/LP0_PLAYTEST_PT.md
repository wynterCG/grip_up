# v1.1 LP0 comparação de referência

Esta sessão usa o controlo existente, antes de qualquer refinamento v1.1.
Referência: `6646cdeda0a0104b723c483905a9a4fc36e00674`, tag
`baseline/pre-v1.1-locomotion`. A build anterior está preservada localmente
como `builds/GripUp-v1.0-pre-v1.1.exe`.

## Jogar

Usar 120 Hz, perfil 4, P0 e hold-to-grip. Mira independente, alvos distantes
ativos e Space desligado. Não alterar forças, sensibilidade ou geometria entre
tentativas. Os atalhos abaixo escolhem os pés conforme o modo de referência.

| Ordem | Controls | Pés | Observar |
|---|---|---|---|
| 1 | The Step / max reach + feet | ON | Subir e descer; alternar para a mão mais alta |
| 2 | The Hang | OFF | Uma mão; aumentar o balanço deliberadamente e depois travar |
| 3 | The Traverse | OFF | Transferir para a direita e inverter; conservar um apoio |
| 4 | The Corner | OFF | Aproximar o canto e rodar a câmara durante uma direção mantida |
| 5 | PLAY / The first ascent | ON | Ligar os movimentos e chegar ao topo para caminhar |

LMB/RMB mantêm cada mão. W/S pede subir/descer; A/D pede deslocação lateral.
MMB orbita, roda aproxima/afasta, R repete. Largar o botão liberta a mão. Na
transição híbrida já comprometida, o controlo continua a seguir as regras v1.0.

Jogar livremente; não é preciso concluir todas as arenas para fornecer uma
observação válida. Uma falha deve ser registada como falha, sem ser substituída
por um sucesso automático.

## Registo real

Em cada arena, escrever três observações curtas:

1. O que tentei fazer.
2. O que o personagem fez.
3. O resultado pareceu justo/previsível? O que atrapalhou mais?

Registar se houve perda inesperada de pega, rotação indesejada, falta de
resposta, pé sem efeito percetível, dificuldade de travar ou problema de câmara.
Estes são exemplos de coisas a observar, não problemas já confirmados.

Quando houver comparação A/B, usar as mesmas condições e acrescentar ratings
1–5 de precisão, conforto, leitura física, agência, peso, fluidez e vontade de
repetir. Não preencher ratings a partir das frases positivas anteriores.

## Estado

**PENDENTE de observações humanas desta baseline.** Preparar o jogo e ligar
o trace não constitui uma sessão concluída. Os testes automáticos e a auditoria
física estão separados em `lp0/` e `LP0_PHYSICS.md`.

A spec define o gate LP0 como uma baseline jogável/reproduzível e uma lista
priorizada de problemas observados: **“No rewriting before this gate.”**
Os refinamentos A–F e o conteúdo M7 não foram iniciados nesta preparação.
