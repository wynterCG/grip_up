# GRIP UP v1.4 — entrega do diagnóstico F0

**21-10-2026 · F0_PARTIAL · KEEP_B1 provisório · sem B3 ou promoção.**

A passagem indicada pelo jogador foi investigada: lateral da primeira parede
de The First Ascent, ao cruzar para as barras. Há resistência física dos pés
numa inversão, retenção visual sem carga noutro intervalo e contactos nativos.
Desligar os pés não melhora consistentemente a passagem. Falta registar o
episódio exato sentido pelo jogador para escolher a correção adequada.

## O que foi entregue

- Observador opt-in em `features/foot_release_lab/scripts/foot_diagnostics.gd`,
  com HUD independente para atuadores, colisão nativa, IK e oposição à intenção.
- Entrada de debug em Controls: **First Ascent / diagnose feet B0 vs B1**.
  Força A0/B1, B2 OFF e profile 4. Permite novas tentativas B0/B1 e takes únicos.
- Traces físicos POST e render após o modificador, com forças admitidas,
  workspace, pontos materiais, contactos FootBase/LowerCapsule, mãos, ground
  motor, suporte, ownership híbrido e relógios separados.
- Marcadores de contacto, IK, sole render aproximada e FootBase; não possuem
  corpos físicos nem aplicam comandos de movimento.
- Reprodução por controlos reais, quatro tentativas frescas e duas ablações
  no cruzamento, a 120 e 60 Hz, com falhas preservadas.
- Revisões independentes de física e IK, redução numérica reproduzível,
  arquivo dos raws, formulário humano e provas de preservação/exportação.

O solver, sampler, coordenador, controlador, IK, colliders, tuning e forças
originais não foram alterados. Nos 377 ficheiros originais auditados, apenas
o menu principal e o filtro de exportação mudaram. A funcionalidade nova fica
num diretório separado. O arranque normal não instancia o observador.

## Resultados e decisão

As duas B1 atingem o cruzamento. B0 desde spawn falha antes, na aquisição
HIGHER_LEFT_WALL; isso não demonstra que OFF liberta o cruzamento. A subida W
inicial ganha cerca de .272/.275 m em B1 e .163/.138 m em B0 a 120/60 Hz.

As ablações usam o mesmo prefixo B1 e o setter existente de pés OFF. Preservam
pose, velocidades, mãos e geometria no instante da intervenção. A primeira
divergência de estado ocorre nos ticks 900/455. Após a fase neutral, os estados
já diferem; comparar deslocamentos posteriores exige considerar esse momento
e os contactos. O setter também muda a posse visual, logo não isola apenas
a força do atuador.

| Hz | Bloco | B1: ΔX | Após OFF: ΔX |
|---|---|---:|---:|
| 120 | D .60 s | +.017361 m | +.045696 m |
| 120 | A .25 s | −.037362 m | −.031661 m |
| 120 | D, pedido de uma mão, .45 s | +.043179 m | +.020768 m |
| 60 | D .60 s | +.035272 m | +.028373 m |
| 60 | A .25 s | +.017590 m | −.010264 m |
| 60 | D, pedido de uma mão, .45 s | +.116649 m | −.020986 m |

Os limites são a primeira e a última amostra POST de cada bloco, não as
fronteiras START/END do driver. Não comparar as duas convenções como se
fossem medições idênticas.

Na inversão A a 60 Hz, o pé direito aplica +4.0502 Ns em X, contra −7.3317 Ns
das mãos: contribui realmente para a resistência. Também fornece 27.58–37.05 N
para cima, mantém caminho válido e margem de alcance. O movimento aponta para
o lado do apoio. Estes sinais não provam retenção indesejada ao afastar-se.

Na inversão a 120 Hz, ambos os pés estão SUPPORTING com força zero e alvos
visuais quase imóveis enquanto o corpo avança para a esquerda. Há contactos
FootBase em todos os ticks desse bloco. Não se demonstrou um defeito somente
visual nem uma âncora FREE persistentemente congelada.

**KEEP_B1 significa preservar a referência enquanto se conclui F0.** Não
significa negar a queixa ou considerar a v1.4 concluída. F1–F7, B3, correção
visual, comparação humana e promoção continuam por realizar. A própria spec
exige classificar o episódio antes de alterar a dinâmica e rejeita uma regra
baseada apenas no sinal força·intenção (§3.3 e §4.2).

## Verificação executada

| Grupo | Execuções | Verificações | Resultado |
|---|---:|---:|---|
| Regressões físicas e integração, 120/60 Hz | 24 | 884 | Todas passaram |
| Regressões de input, 120/60 Hz | 10 | 262 | Todas passaram |
| Contratos do observador, 120/60 Hz | 2 | 38 | Todas passaram |
| F0 diagnóstico real desde spawn | 4 | Sem score de qualificação | 2 blocos completos; 2 falhas de preparação |
| F0 ablação localizada | 2 | Sem score de qualificação | 2 blocos completos; resultado misto |
| Arranque normal e exportação | Separados de F0 | Sanidade | Passaram |

As regressões incluem física, pending contact, integração/inversão de intenção,
ground locomotion, frame, First Ascent, hybrid mantle, vault resilience/restore,
A0/A1 e B1/B2; e drag/contextual/independent/distant/capture input. As suites
First Ascent incluem percurso e restauro híbrido nas suas reproduções, não
aceitação humana desta passagem. Logs e identidades estão em `regressions/`.

Os contratos novos verificam opt-in, arranque LIVE, configurações A0/B1,
ausência de corpos nos marcadores, força efetiva zero com pés OFF, relógios,
recibos, takes sem overwrite e limpeza do observador/HUD. Após esses contratos
houve apenas limpeza de nomes locais e de Variants nullable no observador,
para remover avisos; o parse check passou. A sessão humana aberta mantém a
versão observacional anterior, cujos fontes estão congelados nos arquivos.

Godot MCP Pro abriu o jogo maximizado no monitor 1; o screenshot foi inspecionado.
O HUD está legível e não cobre a zona da passagem. A consulta inicial do editor
reportou avisos de shadowing/ternários do observador, não erros de execução;
foram limpos no fonte final sem alterar dinâmica ou schema. A sessão aberta
continua com a versão anterior para não interromper o jogador.

O arranque fresco coincide com o snapshot anterior: profile 2, A0, pés OFF,
hold, LIVE e sem observadores/evaluador. First Ascent continua a ligar B1 por
opção própria. A exportação `--export-release` e o smoke do executável passaram.
A inspeção do pack num processo isolado confirma exclusão do diagnóstico e
dos antigos laboratórios, e ausência do observador no arranque. O campo
`release_template=false` nessa inspeção descreve o motor de editor que inspeciona
o pack, não o template usado pelo comando de exportação. O smoke do executável
é sanidade de arranque, não um playtest completo.

## Identidade, preservação e limites

Baseline: `54a1b98268a1aabf127118135473a94fb3f10f64`, tag
`baseline/pre-v1.4-foot-release`; branch `feature/v1.4-intent-foot-release`.
Godot `4.7.2.stable.steam.ed1daf0bf`, Jolt, SHA256
`12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38`.

O snapshot original e o ensaio de rollback antecedem as edições. Os fontes dos
quatro primeiros runs e das duas ablações têm arquivos separados e readback.
Os seis raws completos estão em `F0_raw_attempts.zip`, com 49 membros, CRC e
SHA de cada membro verificados. `F0_archive_receipt.json` identifica o arquivo;
`F0_measurements.json` pode ser regenerado por `reduce_F0.py` após extraí-lo.

Os hashes de 9.471 ficheiros históricos, do grabber protegido de Janga e dos
executáveis de rollback permanecem iguais. Não se reabriu auto-tuning, M7 ou
campanhas antigas. Os resultados numéricos não são uma recompensa de optimizer.

UNKNOWN não é zero: contacto nativo não reportado não prova ausência; reação
de suporte dinâmico é derivada do contrato, não medida independentemente;
sole render é proxy; relógios render/física não são tratados como simultâneos.
Este diagnóstico não certifica suportes móveis, performance sem observador ou
feel. Não foram escritos testes de uma política B3 que ainda não existe.

## Passo seguinte

O jogo ficou aberto para reproduzir o gesto reportado. Avisar quando prender,
indicando corpo bloqueado, perna presa visualmente ou ambos. Esse take será
comparado com carga, contacto nativo, workspace, mãos e render para localizar
o primeiro sinal relevante. O formulário em `human_ab_form.md` continua
honestamente pendente. Só depois se escolhe e implementa a correção justificada.
