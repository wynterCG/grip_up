# Swing & Catch — investigação v1.3.1

O estudo v1.3 permanece congelado. A nova implementação altera o contrato de execução do avaliador, nunca a física A0/B1. Os valores de progresso de drivers diferentes não representam ganhos de jogabilidade.

## Reprodução histórica

`historical_001` executou o commit original `1b0a86272a2939452dbe14130df25cde40278a82`, com os 239 hashes públicos e o mesmo executável Godot verificados. A reconstrução de bytes e a importação deixaram o worktree histórico identificado como dirty; não se apresenta como checkout limpo.

| 120 Hz, driver original | Contacto e retenção / repetições | Progresso observado (m) |
|---|---:|---|
| Headless, isolado | 3/3 | 0,405552 nas três |
| Headless, episódio 5/7 | 3/3 | 0,405552 nas três |
| Renderizado, isolado | 2/3 | 0,405322; 0,415912; falha 0,192164 |
| Renderizado, episódio 5/7 | 0/3 | 0,192193; 0,192147; 0,192165 |

O estado preparado já diferia antes do comando de captura. O driver antigo não registava os inputs efetivamente aceites em cada tick. Não é possível recuperar retroativamente essa informação, identificar um subtick de falha que não foi observado, ou atribuir a diferença exclusivamente ao Jolt. O controlo recorder OFF antigo não existe sem modificar a fonte histórica; não foi simulado.

## Primeira matriz do novo driver: tentativa preservada

`catch_001`, commit `e13a8465ca7bc023dfdf35996ead37b55bdd7573`, planeou 32 execuções e parou na 25. As 16 condições de 120 Hz e as oito headless de 60 Hz concluíram com contacto e retenção. A primeira condição renderizada de 60 Hz foi rejeitada como `BLOCKED_TRACE / ACTUAL_DELTA_MISMATCH`; as sete condições seguintes ficaram por executar.

O rasto rejeitado contém 15 ticks com delta efetivo de 1/120 s, apesar do pedido de 60 Hz; a partir do tick 16 observa-se 1/60 s. Já existia um corpo a mover-se durante os ticks incorretos. Isto demonstra uma mudança tardia do passo efetivo relativamente à criação do mundo. O detalhe interno de batching do engine não foi isolado. Não se contam esses ticks como 60 Hz, nem a captura ausente como falha física válida do A0.

A auditoria de 120 Hz também encontrou diferença de lifecycle entre o primeiro mundo e os seguintes: no primeiro PRE, COM Y de 1,169319391 m contra 1,169999957 m, diferença de aproximadamente um passo de gravidade. Isolado/sequência não constituíam setups físicos idênticos. No par headless/renderizado isolado r1, os comandos e eventos discretos coincidiram; a primeira diferença de estado acima do epsilon de localização apareceu no tick 94 PRE. O alvo material selecionado no tick 282 diferiu cerca de 4,29 µm. Estes são descritores observados, não tolerâncias universais de aceitação.

O [relatório desta tentativa](reports/phase_startup_001/comparison.md) conserva também as falhas. A sua revisão não é substituída pela revisão seguinte.

## Correções do avaliador

A revisão seguinte confirma dois callbacks consecutivos com delta real correto antes de construir qualquer Lab, guarda todos os deltas de arranque e bloqueia por orçamento/deadline se não estabilizar. A criação inicial e as seguintes passam pela mesma fronteira `post_completed`. O guard de delta mantém-se ativo durante todo o cenário; não se descartam silenciosamente ticks de um mundo medido.

Separadamente, as fixtures novas passam à revisão 3: a preparação quieta exige 0,25 s efetivamente decorridos, em vez de contar N amostras que abrangiam apenas N−1 intervalos. O controlo de baixa energia revalida velocidade e spin no instante do comando aceite. Não mudam força, alcance, damping, geometria ou condições históricas de sucesso. As revisões 1 e 2 e os seus recibos ficam preservados.

Estas alterações corrigem defeitos demonstrados do harness. Como também mudam a fase de emissão/leitura e a criação de mundo, uma melhoria de repetibilidade não identifica uma causa histórica única. A decisão final e a matriz da nova revisão são apresentadas no relatório principal.

## Segunda matriz completa

`catch_002` mediu o commit `24b18d760604fffe3455c5b4c9b8b72f37577b4d`. As 32 execuções terminaram sem bloqueios de integridade: 3 isoladas + 3 em sequência + 1 trace OFF + 1 observer antigo OFF em cada combinação de modo/frequência. Todas produziram contacto real e retenção na mesma âncora. A auditoria encontrou 6836 amostras de mãos pendentes com força admitida exatamente nula. A preparação e o teardown ficaram documentados, sem corpos antigos no espaço físico na criação seguinte.

Isto fecha o gate estreito de repetição do outcome binário novo. Não fecha equivalência de pontuação: em dois ensaios renderizados de 120 Hz, o feedback escolheu W+D no tick 419 onde o headless escolheu W+A. O contacto atrasou 438→478 e o progresso caiu para cerca de 0,4506 m, contra 0,5342 m. Não se elimina esta diferença com uma tolerância espacial. A [comparação entre modos](cross_mode_report.md) e a [revisão física independente](physical_review.md) documentam o mecanismo observado e os limites causais.

O novo driver torna possível localizar a divergência efetiva de comando e a sua consequência, que o registo histórico não conseguia resolver. Não demonstra que os fails históricos tinham uma única causa, nem valida os scores de `stage1_r1` para comparação com a revisão nova.

## Limites físicos da captura

`destination_alone` significa que a mão fonte foi largada. Não significa suspensão exclusivamente pela mão de destino: existe contribuição B1 dos pés e contacto transitório com chão em parte dos rastos de 120 Hz. Uma âncora real retida continua a ser uma observação válida, mas o cenário não certifica uma captura sem chão/pés. Uma pega pendente tem de manter carga admitida nula; só contacto real pode admitir carga.

`CONTACT_VALIDATED` e `ATTACHED` são observados juntos no snapshot posterior ao controlador. A ordem dos eventos derivados não representa resolução temporal dentro do solver. `PATH_CLEAR` pode aparecer antes da entrada no alcance e não constitui autorização antecipada de contacto.
