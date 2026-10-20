# GRIP UP — relatório de qualificação do avaliador v1.3.2

Data:20 outubro2026. **Decisão final:NO_GO / EVALUATOR_NOT_READY.**
O sistema jogável A0/B1 foi preservado. Esta entrega acrescenta replay fixo,
auditoria de três camadas de input, fixtures de preparação/clearance e contratos
de métricas, mas não certifica o avaliador para otimização. O motivo determinante
é uma divergência real do pipeline cursor/câmara/alvo em R0; há também uma barreira
cosmética de IDs no comparador e cobertura física final em falta.

## O que mudou

LaneR0 envia eventos reais de rato/botões e ações pelo Input normal, em ticks
inteiros. Mantém os píxeis gravados, sem reprojetar um alvo mundial com o estado
corrente e sem forçar ATTACHED. LaneA conserva a política adaptativa histórica,
incluindo angular_phase_threshold−.04. AContext de sequência é explicitamente
adaptativo; não é rotulado replay. R0 de cenários não suportados é recusado.

Cada tape tem hash canónico e de ficheiro, trace/manifest/source/engine/scenario
de origem, bindings, focus/gates, cursor, câmara/ray/materialtarget, accepted e
effective actions. Requested permanece separado de emitted_observed. A janela
de comparação termina no primeiro desvio, mesmo com hash de fita igual.

R1 ficouUNSUPPORTED_SEAM: nenhum seam existente foi demonstrado que permitisse
injetar intent aceite sem alterar a produção ou contornar regras físicas.
O clock só cria corpos depois de observar dois deltas corretos sem mundo. O
teardown desliga subárvores/RIDs sincronamente. PRE−100 ePOST+100 são fases nomeadas,
não uma alegação de post-solver. A física continua a ser o rigidbody original/Jolt.

O fixture novo usa geometria simétrica e o spawn existente, sem escrever pose ou
velocidade do corpo. Três scripts reais de preparação e queries conservadoras das
proxies físicas foram congelados. O novo catálogo distingue settling full-norm,
path3D e brake de velocidade dirigida; as fórmulas v131 permanecem intactas.

## Orçamento e execução efetiva

O orçamento foi declarado antes das medições finais:8 launches físicos de
desenvolvimento;24 screens de preparação;2 referências;48 processos catch;
36 controles extra de probe;12 processos de controles, n3 por célula primária;
após gate duro, no máximo4 diagnósticos diretamente relacionados.

Execução congelada:a06a882,25 processos =2 referências +19 primários +4 diagnósticos.
O19.º primário reprovou fidelidade; os29 catch restantes e as matrizes de preparação,
probes completos e novos controles foram cancelados. Esta paragem é intencional e
exigida pela spec. Testes de baseline/restauração são verificação de preservação,
não continuação da qualificação de score.

Falhas de desenvolvimento ficaram guardadas:rejeição correta de tape após mudança
de fonte, transporte JSON de handID corrigido, parse de um teste de fixture corrigido,
expectativa sintética na fronteira float corrigida e ambiente Python sem dependência
seguido de execução no venv pinado. Um prelaunch0f111bf não lançou motor porque
override.cfg opcional estava ausente; a06a882 registaABSENT sem criar/mudar config.
Nenhuma dessas tentativas é rebatizada como referência final.

## Resultado de catch e primeiro desvio

| Modo | Hz | Lane | Contexto | n/3 | Contacto | Retenção | Tick contacto | Comparação |
|---|---|---|---|---|---|---|---|---|
| headless | 120 | A | isolated | 3 | 3/3 | 3/3 | 438–438 | {'MATCHED_INPUTS_TO_TICK_N': 3} |
| headless | 120 | A | sequence | 3 | 3/3 | 3/3 | 438–438 | {'NOT_COMPARABLE': 3} |
| headless | 120 | R0 | isolated | 3 | 3/3 | 3/3 | 438–438 | {'MATCHED_INPUTS_TO_TICK_N': 3} |
| headless | 120 | R0 | sequence | 3 | 3/3 | 3/3 | 438–438 | {'NOT_COMPARABLE': 3} |
| headless | 60 | A | isolated | 0 | NOT_RUN | NOT_RUN | — | MISSING_COVERAGE / EARLY_STOP |
| headless | 60 | A | sequence | 0 | NOT_RUN | NOT_RUN | — | MISSING_COVERAGE / EARLY_STOP |
| headless | 60 | R0 | isolated | 0 | NOT_RUN | NOT_RUN | — | MISSING_COVERAGE / EARLY_STOP |
| headless | 60 | R0 | sequence | 0 | NOT_RUN | NOT_RUN | — | MISSING_COVERAGE / EARLY_STOP |
| rendered_scripted | 120 | A | isolated | 3 | 3/3 | 3/3 | 438–478 | {'REQUEST_MISMATCH': 3} |
| rendered_scripted | 120 | A | sequence | 3 | 3/3 | 3/3 | 438–438 | {'NOT_COMPARABLE': 3} |
| rendered_scripted | 120 | R0 | isolated | 1 | 1/1 | 1/1 | 439–439 | {'NOT_COMPARABLE': 1} |
| rendered_scripted | 120 | R0 | sequence | 0 | NOT_RUN | NOT_RUN | — | MISSING_COVERAGE / EARLY_STOP |
| rendered_scripted | 60 | A | isolated | 0 | NOT_RUN | NOT_RUN | — | MISSING_COVERAGE / EARLY_STOP |
| rendered_scripted | 60 | A | sequence | 0 | NOT_RUN | NOT_RUN | — | MISSING_COVERAGE / EARLY_STOP |
| rendered_scripted | 60 | R0 | isolated | 0 | NOT_RUN | NOT_RUN | — | MISSING_COVERAGE / EARLY_STOP |
| rendered_scripted | 60 | R0 | sequence | 0 | NOT_RUN | NOT_RUN | — | MISSING_COVERAGE / EARLY_STOP |


As duas referências reais passaram. A120 passou6/6 em cada modo, R0headless120
passou6/6. Contudo, o primeiroR0render120 tinha cursor[960,540] quando a tape pedia
[0,0] no tick13, sem gesto pedido nesse instante. Os534 comandos lógicos coincidiram;
o primeiro ponto de contacto diferiu1.256634mm no tick55. Spin/velocidade/COM
divergiram mais tarde92/94/125. Logo, não se provou 'mesma excitação/contacto e
resposta Jolt diferente'.

Os quatro diagnósticos repetiram a quebra; no de60Hz o destino142 foi selecionado
na frente+Z em vez da face inferior−Y, distância material109.669mm, e nunca ficou
ATTACHED. O clock60 estava correto antes da criação. Não se atribui a falha a uma
causa única nem se aumentou reach/força/tolerância para resgatar a captura.

Uma falha adicional do comparador é o nome automático de CollisionShape3D em
sequência. Os restantes campos de shapes são iguais offline, mas o resultado
originalSETUP_MISMATCH permanece publicado. Nenhuma destas conclusões permite
qualificação contínua ou uma tolerância global15cm.

## Paragem, pernas, apoios e cobertura

Os nove two-hand release A_CONTEXT anteriores ao gate foram recomputados do trace:
9/9 cenários coincidem com o runtime nos novos campos. Há18valoresMEASURED e18NA;
no parser legacy72MEASURED/9NA. É evidência120Hz de contexto, não a matriz nova.

| Modo | Hz | Caso de contexto | n | 3D stop path m | Settling s |
|---|---|---|---|---|---|
| headless | 120 | stop_release_v1 | 6 | 0.111254–0.111254 | 1.075–1.075 |
| rendered_scripted | 120 | stop_release_v1 | 3 | 0.111154–0.111239 | 1.075–1.075 |


Uma mão60 e bilateralidade nova continuamMISSING_COVERAGE. Desenvolvimento120
com P1/P2 mostrou preparação low-energy possível na parede/B1; P0stop não atingiu
velocidade dirigida. Não se transforma esse smoke em qualificação60Hz, de Hang
ou de stop/brake/reverse. Os controlosR0 fora de catch ainda são não suportados.
Queries de clearance podem rejeitar conservadoramente; não são prova de contacto
nativo. max_contacts_reported0 original limita alegações sobre ausência de manifold.

## Custo e segurança

TraceOFF reduziu os hooks locais, mantendo reader/monitor. Os quatro toggles120
rendered têm apenas n1 cada e todos mantêm a falha do cursor. Não há prova causal
de que overhead origine as divergências, nem uma distribuição de simulação sem
instrumentação. Wall, PRE/POST, render cadence e tick gaps ficam nos recibos;
backlog nativa não está disponível pela API utilizada.

O especialista leu12844 snapshots de catch nos25 processos congelados: nenhum
REACHING ganhou força. Picos reportados:mãos253.384N,pés69.498N,assist20.0000022Nm
(arredondamento float),momento76.767Nm. Todos os flags de invariante permaneceram
falsos. Isto verifica os canais publicados e a implementação auditada, não todos
os wrenches internos do solver. Catch inclui ground/B1; nunca foi chamadoarm-only.

## Verificação e reposição

24 regressões a120/60Hz passaram884checks:physics,pending_contact,intent integration/
reversal,ground locomotion,frame signs,FirstAscent público,hybrid mantle,vault
resilience/restore,allocation eintentfeet. Passaram35 testes Python novos,75 antigos
no ambiente pinado,13 checks de fixture,9 de driver e43 contratos antigos Godot.

GodotMCPPro1.17.1 executou um reviewA120 no monitor0:contacto455,origemFREE470,
retenção542,doisPNG. O plugin/PNG altera a condição de instrumentação; esse run é
SUPPLEMENTARY_ONLY e não preenche a matriz. Depois foi aberto o main normal e
confirmado profile2,120Hz,A0.25/.12/.24/.9,massa12,reach.65708,holdtrue,feetfalse,
observer/capturefalse ebindingsoriginais. O MCP devolveu0 erros novos.

O editor foi fechado antes de repor project.godot byte a byte. O arranque CLI
ordinary voltou a passar. Os815 ficheiros históricos, fonte pública C/E, Janga,
rollback e configuração original foram verificados novamente. Não foi criado ou
promovido novo build distribuível; o baseline jogável fica preservado.

## Elegibilidade e decisão de produto

benchmark_eval_v132 r1 mantém scoringdesativado. R0completo/catchcontínuo estão
QUARANTINED; A120 eprobes sãoDIAGNOSTIC_ONLY; novos domínios em falta são
MISSING_COVERAGE. Nenhuma métrica contínua recebeu envelope aprovado pelo
especialista. Privateholdouts ficaram fechados; zero novas tentativas de
Random/TPE/CMA/sensitivity/RL/Jev,promoções ouM7. Feel humano não foi avaliado.

A próxima decisão deve ser de produto:playtests humanos e prioridade de gameplay/
M7, ou autorização separada de uma correção pontual de replay/normalização.
Não se iniciou automaticamente outra cadeia de versões de fiabilidade.

## Documentos e evidência

Ver baseline_audit,replay_contract,catch_replay_report,one_hand_60hz_report,
lateral_mirror_report,stopping_braking_report,probe_isolation_report,
cross_mode_qualification,benchmark_migration,metric_eligibility e decisão.
O parecer independente está em specialist/final_independent_review.md.
verification.json e evidence/archive_index.json ligam hashes, fontes e os recibos
completos, incluindo falhas. As fontes e tapes são recuperáveis; outputs antigos
não foram sobrescritos. Os arquivos foram verificados contra os bytes originais.
