# GRIP UP — v1.3.4 Fixture Repair & Feasibility

**Decisão final: FEASIBILITY_NO_GO.** A correção de picking está validada. Os novos fixtures permitem medir movimentos que antes falhavam, mas o assimétrico e a lateral esquerda a60Hz continuam interrompidos; o Foot Step não obtém onset válido em nenhuma frequência. Não foi iniciada uma nova qualificação completa nem afinação automática.

| Item | Resultado |
|---|---|
| Desenvolvimento |8/8 processos; sem crédito no piloto |
| Piloto final |34/48 processos, todos RUN_VALID |
| Capturas / replays fixos / referências / N1 |12 /16 /4 /2 |
| Comparações H/R |10/10 STRICT_MATCH, incluindo2 referências |
| Janelas de domínio, incluindo replays |24 MEASURED;2 INTERRUPTED;2 PRECONDITION_NOT_MET |
| Regressões separadas |34/34 processos;1.146 checks PASS |
| Jogo, LIVE e export |Preservados nas verificações efetuadas |
| Scoring, Optuna, ML, RL, Jev, M7 |Não executados/não autorizados |

## Fonte e isolamento

Fonte final congelada: `6cc47db32fccbc0998383c2da6fda6d17c093af6`. Snapshot composto: `00b1a8cccbee79f1b8525e0878d6668e5278e658ff104b5d387be281ad65dbf1`, cobrindo303 fontes públicas e5 helpers. O manifesto individual conserva também o hash do mapa público, com âmbito diferente do composto. O plano, catálogo e tapes originais têm guards próprios. Nenhum byte medido foi alterado durante ou depois do piloto.

Godot `4.7.2.stable.steam.ed1daf0bf`/Jolt; binário SHA256 `12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38`. Backing1024×576, viewport lógico1920×1080, seed101, profile4/A0/B1. Frequências60/120Hz, sem exigir trajetórias iguais entre elas. O arranque normal permanece profile2/LIVE.

Os1.873 ficheiros de evidência R3 inventariados permaneceram byte-iguais. A antiga R3 continua preflight CERTIFIED / benchmark NO_GO, com o seu N1 RUN_INVALID. Não recebeu resultados novos. Todos os195 ficheiros protegidos de gameplay/projeto, Janga, presets e rollback conservaram os hashes. As alterações são de avaliação/testes, não de locomoção, forças, alcance, damping, timestep, aquisição ou geometria de produção.

## Picking reparado

O novo contrato distingue decisão lógica, supressão e dispatch real. Cada query tem ID composto por sessão/tick/mão/ordinal e correspondência cronológica exata com um sidecar. Sete raios candidatos continuam a representar uma chamada do picker, não sete dispatches. A entrada sem mira não fabrica um raio.

Os49 casos JSON passaram em Python e em Godot, com128 checks Godot. Cobrem mãos, ordinais, `(0,0)`, MISS, hits materiais, ausência/duplicação de sidecar, offsets, dados inválidos e streams incompletas. A representação de endpoint foi validada pelos bits nativos originais; o parser Godot pode alterar um último bit do scalar64 sem alterar o `Vector3` medido. Esta exceção nomeada não introduz epsilon nem arredonda campos físicos gerais. Os três batches puros falhados de desenvolvimento foram preservados.

No N1 físico final a120 **e**60Hz:4 decisões lógicas,3 dispatches,9 raios reais e1 supressão;9 checks internos PASS e cleanup válido. As referências originais Swing & Catch conservaram os contactos/âncoras e deram um novo par H/R STRICT_MATCH por frequência. Os reviewers verificaram os resultados reais e mutações negativas, não apenas contagens.

## O que mudou nos fixtures

A preparação usa inputs reais: adquirir as mãos, W1,5s e regrips15cm mais altos pela sequência normal release/request/reach/contact. O assimétrico mantém12cm de desnível. Não há escrita de pose/velocidade, ATTACHED artificial ou torque adicional.

Na revisão finalr2, a frente do pad de teste recuou deZ0,32 para0,39; topo, largura e traseira permaneceram iguais. Só o Foot Step substituiu quatro pequenos apoios por um lip de0,95×0,16×0,22m, topoY0,65/frontZ0,10. O recesso de1cm foi exigido pela revisão física para evitar uma intersecção prevista com o calf numa pose antiga. Essas folgas eram estimativas, não critérios relaxados de aceitação. Os queries conservadores mantiveram-se intactos.

IDs novos `_v134_r2`, nova geometria declarada e novas tapes por cenário/Hz. O desenvolvimento consumiu8 processos:1 N1,4 referências e3 preparações. O vertical60r1 foi útil, mas não foi reutilizado como passe final. Os dois reviewers aprovaram os bytes r2 para ensaio antes do congelamento, sem antecipar viabilidade.

## Resultado por cenário

Os números abaixo são capturas físicas finais. Cada célula completa recebeu ainda um replay fixo H e um R, ambos com janela válida e comparação estrita. Células falhadas não receberam replays desnecessários.

| Domínio |120Hz |60Hz |
|---|---|---|
| Vertical Pull |MEASURED, +0,206309m |MEASURED, +0,209522m |
| Asymmetric Pull |MEASURED, +0,189690m |INTERRUPTED, clearance no tick238 |
| Lateral Left |MEASURED, +0,146509m |INTERRUPTED, ground authority no tick265 |
| Lateral Right |MEASURED, +0,145331m |MEASURED, +0,143510m |
| Foot Step, diagnóstico |PRECONDITION_NOT_MET |PRECONDITION_NOT_MET |
| Release-Stop, diagnóstico |Path0,112680m; settling0,833333s |Path0,118185m; settling0,866667s |

**Assimétrico60:** onset232, fim autorizado237; no238, FootBase/pad produziu apenas `OVERLAP_OR_ROTATION_BOUND`, margem1,326mm. Sem END_OVERLAP/sweep nesse tick; forças de chão zero. Não é prova de colisão nem de falso positivo: os contactos nativos continuam UNKNOWN, pois o limite de reporte é0. O progresso oficial permanece null.

**Esquerda60:** onset242, fim264; no265 o apoio mudou para o novo pad. Nesta revisão havia força de chão não nula, aproximadamente(−6,405,0,−0,207)N, além de torque/authority. Este caso difere da primeira transição R3 com força zero. A janela hanging foi interrompida e nada posterior foi creditado.

**Foot Step:** houve contactos e compressão intermitente, mas sem os0,25s simultâneos de carga/quiet/clearance exigidos. Na espera final120,79/600 ticks tiveram carga>1N; a maior sequência válida durou0,075s. A60,7/300 ticks tiveram carga>1N e nenhum reuniu todas as cláusulas. Remover o conflito persistente com chão não bastou. A quase tangência analítica calf/lip e o manifold não reportado também impedem alegar ausência de contactos nativos. Não há benefício B1 ou work de tarefa validado.

Latência lateral permanece null com `ALREADY_MOVING_BEFORE_ONSET`, apesar de progresso válido nas células completas. Não é0s. Stop usa path3D até confirmação do repouso; não substitui esse valor pelo path dos cinco segundos ou pela deriva final. O revisor recompôs os28 resumos métricos,26 intervalos com onset e os10 pares. Os raw prefixes interrompidos e o work de preparação são apenas diagnóstico, sem score.

## Gates e preservação

| Gate formal da spec |Estado |
|---|---|
| FR0 baseline / FR1 picking / FR2 diagnóstico |PASS |
| FR3 fixtures |PARTIAL:6/8 células obrigatórias e2/4 diagnósticas viáveis |
| FR4 pairing |PARTIAL de cobertura;10 pares executados STRICT_MATCH |
| FR5 métricas / FR6 segurança |PASS no âmbito verificado |
| FR7 decisão |FEASIBILITY_NO_GO |

As34 regressões frescas/1.146 checks passaram. O arranque headless normal corresponde exatamente à baseline. Godot MCP Pro1.17.1 confirmou profile2/LIVE, provider desligado, bindings e valores A0 originais, sem erros frescos. A advertência inicial de um projeto antigo numa pasta de builds é preexistente. Screenshot inspecionado; não foi um playtest humano de feel.

O editor criado para QA foi fechado e `project.godot` restaurado exatamente em C/E. Export release Windows e startup smoke passaram; inspeção isolada do pack confirmou16 paths de evaluator/fixtures ausentes. Essa inspeção usa o motor debug de ferramentas e é distinguida do executável release. O rollback anterior não foi substituído.

O [ledger auxiliar de QA](auxiliary_qa_ledger.json) enumera quatro arranques de mundo normal, sem crédito de benchmark: startup, release smoke, inspeção isolada e main pelo MCP. Mesmo agregando-os conservadoramente ao piloto, são38 processos, abaixo de48. Compilação/exportação, editor e consultas de versão são tooling; não substituem células físicas.

## Encerramento e evidência

Foram usados34/48 slots finais;8 replays ficaram por executar por falha dos quatro captures e6 de reserva não foram necessários. Não houve hard stop de infraestrutura ou violação física observada; houve falhas reais de onset/janela. Não se gastou uma reserva para retocar o candidato. Um par n=1 não demonstra n=3 ou scoring.

Não recomendo já uma qualificação completa: continuam por resolver os envelopes de clearance/apoio de Asymmetric60/Left60 e a coexistência de compressão B1 e quiet onset. Um novo esforço tem de ter nova identidade e orçamento autorizado. Esta campanha está fechada; não se retoma após uma correção.

- [Decisão e células](decision.md), [CSV por domínio](domain_feasibility.csv), [métricas tipadas](metrics.csv), [matriz48](test_matrix.json).
- [Contrato de picks](pick_event_contract.md), [onsets/métricas](metric_contract_audit.md), [geometria antes/depois](fixture_geometry_diff.md).
- [Review físico final](specialist/final_physics_review.md), [review de medição final](specialist/final_measurement_review.md). Os pareceres de pré-piloto permanecem separados.
- [Comparações](replay_pair_results.json), [negativos](negative_controls.json), [ledgers](budget_ledgers.json), [regressões](regression_index.json), [QA e hashes](verification.json).
- [Arquivos e SHA/CRC](evidence_manifest.json), incluindo fontes candidatas, tentativas falhadas, manifestos, CLI exato, stdout/stderr, traces e sidecars. Raiz bruta: `builds/eval_virtual_cursor/fixture_feasibility_v134_r1/`.

Os comandos efetivos por tentativa estão em `execution.json`. O CLI recusa repetir a fase final existente, preservando os resultados. Os ficheiros de fonte congelados estão nos arquivos de candidatos; o publicador posterior apenas lê dados. Não foram consultados resultados privados de holdout.
