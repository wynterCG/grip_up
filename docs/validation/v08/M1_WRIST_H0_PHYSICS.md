# v0.8 — extensão M1: pressão normal com momento finito e H0 dobrado

Código físico congelado após **37/37 checks a120 Hz e37/37 a60 Hz**. Regressões reexecutadas no mesmo código: M1 axial49/49 e core histórico45/45, em ambas as frequências. Estes resultados provam capacidades locais de contacto e esforço; **não provam um top-out completo desde suspensão**. O gate M4 pertence ao ensaio integrado e mantém os seus critérios de pernas, contacto nativo e marcha.

## Ativação e ficheiros

Além de `physics_mantle_v08_enabled` e `palm_compression_enabled`, a extensão exige `palm_wrist_support_enabled=true`. Todos começam false; requer perfil4. O ramo axial M1 continua disponível com o novo flag false. `mantle_support_handoff_enabled=false` é uma propriedade reservada para coordenação explícita; este patch não usa esse flag para inventar força ou translação.

- `scripts/palm_arm_path.gd`: testemunho geométrico atual, sem autoridade física própria.
- `scripts/palm_support_solver.gd`: pressão normal unilateral, alvo limitado e momento pedido.
- `scripts/pending_grip_target.gd`: waypoint adicional opcional apenas quando existe testemunho válido.
- `scripts/climbing_controller.gd`: reserva do orçamento de momento, alocação e aplicação dos pares.
- `tests/palm_compression_lab.gd`: variante isolada upright, distinta do handstand axial.
- `tests/test_palm_wrist.gd`: runner novo; o runner axial histórico mantém49 checks.

Os paths são relativos a `features/grip_up/`. Não foram alterados inputs, cenários de jogo, render, massa, K/D, limites, geometria do robot ou ator de pernas.

## H0: contacto real com braço dobrado

Uma linha reta ombro–palma pode atravessar a face vertical de uma plataforma quando o ombro está abaixo da aresta. A extensão não ignora a colisão. Calcula um testemunho atual de ombro→cotovelo→punho→palma:

- braço superior declarado.27000 m e antebraço.27708 m; a soma coincide com a cadeia medida.54708 m. A divisão individual é uma aproximação explícita do modelo virtual;
- segmento de mão.11000 m; não acrescenta comprimento ao ombro→punho;
- cápsulas de consulta com raio.020 m para os dois segmentos do braço, livres de obstáculos;
- punho acima/para o lado livre da aresta, com segmento final que encontra o mesmo collider no contacto;
- área de palma7×10 cm completa, anatomia existenteR=.65708 m e normal de topo válida.

Vários planos de cotovelo são tentados numa amostra pequena e determinística. O testemunho é recalculado a partir da pose/material atuais, não de uma previsão. Não é um braço rígido articulado nem uma prova contínua de todos os volumes de uma mão complexa.

A mão move-se primeiro para um waypoint acima/fora da aresta, depois para a aproximação normal e finalmente para o ponto material. Todas as pernas do gesto continuam sujeitas à varredura mundial, workspace anatómico, transporte real do ombro e limite relativo4 m/s. A geometria do braço torna admissível uma transmissão dobrada, mas não substitui a chegada real: o CaptureEvaluator continua a exigir endpoint atual, contacto real no collider e alcance. PENDING nunca produz força. O ramo novo preserva o ponto material escolhido; não faz roll de palma/H1 nem percorre a borda automaticamente.

Se o testemunho deixar de existir depois do contacto, a palma liberta e perde força/momento no mesmo passo de preparação. As razões diferenciam anatomia, footprint, superfície e segmento bloqueado. A snapshot pending apaga testemunhos antigos quando a geometria atual é inválida.

## Wrench e orçamento

Para ombroS, contactoP e normaln, a pressão proposta é **F=N*n**, N>=0. O corpo recebe F no ombro e o suporte recebe −F no contacto material. O par dessas forças teria momento `(S−P)×F`. O atuador articular finito fornece ao corpo:

`C = −(S−P)×F`.

Assim, o par completo tem força e momento resultantes zero. Equivalentemente, a força externa normal atua emP no corpo, mas a fonte finita C e o seu custo são explícitos. O suporte recebe pressão normal no ponto; **não** recebe outro contramomento −C, que duplicaria a correção. O assistente antigo continua a reagir através das mãos trativas reais.

Antes da alocação central, soma-se `Σ|C_i|`. Se exceder20 Nm, todas as forças de punho e os respetivos C são escalados pelo mesmo fator. O assistente de atitude/balanço recebe apenas `20−Σ|C_i|`; não existe20 Nm por mão. Depois, o alocador existente aplica os360 N de soma de magnitudes das mãos e150 Nm de momento resultante, incluindo braços, C, pés e ground. Os180 N das pernas permanecem separados. A telemetria identifica soma de momentos de punho, C vetorial e assistente realmente reagido; as contribuições diagnósticas antigas são reduzidas pela mesma reserva.

Com alavanca horizontal.25 m,20 Nm permitem no máximo80 N normais no conjunto. Duas palmas mal alinhadas não passam magicamente a sustentar o peso de12 kg (~118 N). Uma mão trativa, um pé real ou aproximação física de COM podem continuar necessários. Sem pressão, C é zero. Não há componente tangencial nem sucção neste ramo; logo o cone de atrito é respeitado trivialmente comT=0. A admissibilidade do contacto continua a exigir footprint e normal.

## Alvo e integridade

W/S comandam um alvo escalar de separação NORMAL do ombro relativamente à palma, permitindo esforço ascendente com ombro inicialmente abaixo do topo. O alvo não é posição de COM. Usa progresso real extremo por gesto, offset pendente máximo.055 m, taxa.24 m/s e aceleração.9 m/s². Não acumula entrada bloqueada. Neutral relaxa a parte não alcançada; o travão discreto deixa, no máximo, o deadband derivado `.5*a*dt²` (~31 µm a120 Hz /125 µm a60 Hz).

A mola unilateral usa osK6000/D220 existentes multiplicados pela alocação da mão, denominador implícito positivo e velocidade relativa normal real. A massa inversa usa uma estimativa conservadora dos pontosS/P e o suporte dinâmico. Não se reivindica uma solução articulada exata ou conservação de energia do integrador.

A capacidade material de palma é verificada sobre a carga admitida do passo anterior, depois dos limites compartilhados; ao confirmar sobrecarga, força e C tornam-se zero e a mão liberta. Este atraso de medição de um passo é explícito. Nenhum contador de carga pedida impossível é usado para fazer a mão falhar só por saturar o orçamento muscular.

## Ensaios e medidas

A fixture upright começa com ombros18 cm abaixo do topo e palmas8 cm dentro da plataforma. A pose é atribuída antes de o corpo entrar no mundo. O corpo simplificado tem12 kg, capsule1.7 m/r.15; estes testes isolados não substituem o compound/adaptive collider do jogo. As mãos começam livres e chegam por gesto finito. Nos ensaios de contribuição local a gravidade é zero, explicitamente, para não confundir capacidade parcial de pressão com sustentar todo o peso.

| Medida |120 Hz |60 Hz |
|---|---:|---:|
| Checks |37/37 |37/37 |
| Subida real, uma palma, zeroG |.09901 m |.10302 m |
| Subida real, duas palmas, zeroG |.11607 m |.12007 m |
| Pico normal, uma palma estática |11.87 N |12.37 N |
| Subida com plataforma livre30 kg, zeroG |.03695 m |.03829 m |
| Resíduo máximo do wrench no par livre |2.38e−7 Nm |1.19e−7 Nm |
| Erro máximo do momento linear no par livre |3.58e−7 kgm/s |1.19e−7 kgm/s |
| Pico Σ|C| com gravidade e duas palmas |20.000002 Nm |20.000001 Nm |

O caso com gravidade satura o orçamento conjunto e o corpo cai: posição finaly2.24535 /2.22316 desdey2.70. É evidência de limitação mecânica real, não um teste funcional aprovado de sustentação ou mantle. O runner passa os critérios de segurança/custo esperados; não converte essa queda num sucesso de manobra.

Passam ainda: comprimentos geométricos, contacto finito de ambas as mãos, inexistência de força PENDING,4 m/s, reação dinâmica, liberação sem resíduo, obstáculo surgido depois do contacto, material fraco, suporte destruído, cancelamento por foco, planeamento sem escrita de pose/velocidade e3 s de pedido não alcançado sem windup.

Artefactos: `builds/palm_wrist_{120,60}hz.json` e logs correspondentes. Cópias congeladas em `docs/validation/v08/development/wrist_gate_{120,60}hz.{json,log}`. `wrist_first_120hz` preserva o primeiro ensaio: a plataforma livre levantava o corpo, mas o check então exigia arbitrariamente pico>5 N apesar de medir4.33 N; o runner final separa esse caso leve e continua a exigir subida real. A primeira asserção de neutral demasiado apertada também expôs o deadband discreto de125 µm a60 Hz; o critério final deriva-o da aceleração/dt, sem alterar o atuador para forçar o teste.

**KEEP da capacidade wrist/H0 isolada; M4 continua dependente de prova integrada de top-out, restauro das pernas e marcha real.** Nenhuma operação escreve transform ou velocidade do corpo durante a simulação. Estas medições não representam avaliação humana de conforto ou diversão.
