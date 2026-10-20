# BQ v1.3.3 — revisão independente pré-freeze

2026-10-20. Revisão apenas de fontes, sem motor, suites, Git, E ou sincronização. Foram lidos `benchmark_driver.gd`, runner/preflight, catálogo r1, `campaign.py`, `comparison.py`, `metrics.py` e os caminhos herdados. Nenhum resultado de qualificação novo foi usado para esta revisão.

## Autoridade e arquitetura

O novo driver reutiliza o scheduler V0, provider, câmara, picking e safety monitor existentes. O setup novo é síncrono antes do primeiro callback do mundo. Para quatro domínios e stop usa `Fixture.apply` sem body-state writes; Step usa a geometria original. Não foi encontrado novo atuador, mudança de força, alcance, forma, atrito, damping, input de gameplay, assistência de corpo ou captura forçada.

O encadeamento `_snapshot` chama o reader original; o pai acrescenta o POST ao array, e o novo driver substitui esse último elemento por uma cópia enriquecida. As queries de clearance são novas observações reais por POST dos domínios novos, apenas contra ground layer 1. Catch não recebe essas queries. Não são um solver, não modificam shapes e não certificam ausência de colisão com toda a parede.

O espelho lateral troca aquisição [0,1] por [1,0] e direção/tecla; geometria e câmara yaw 0 são as mesmas simétricas. Clean usa .10 m/s no eixo e .20 rad/s durante .25 s decorridos, com recheck no onset. Stop gera [.15,.50] m/s com direção real, neutraliza a direção e mantém os dois grips. Não foi alterado nenhum desses thresholds. Vertical/assimétrico/foot usam preload .55 s declarado antes de qualquer outcome; não foi demonstrado que esse preload produz um onset útil, nem deve ser retocado para produzir um score positivo.

O comparador acrescenta comprimentos, planner rate/accel, apoios dos pés, contactos reportados, ground authority e reações, além dos canais legados. `frame.support_ids` é mapeado para cadeias de bodies reais semanticamente identificados, não simplesmente apagado. Isso evita comparar IDs de processo sem perder trocas de suporte. Nomes automáticos de shapes são removidos; classe/dimensões/transforms/shape indexes permanecem.

Os estados de métricas são tipados, sem score de otimização. Twist sem frame válido permanece ausente; não há alegação de medição axial a partir de Euler. Foot contribution é explicitamente compressão dos pés versus essa compressão mais tração vertical positiva das mãos, não peso/energia total com chão. Os traces de performance distinguem monitor de engine de um stopwatch do tick atual.

## Achados concretos comunicados ao coordenador

| ID | Local inicial | Risco | Correção mínima recomendada |
|---|---|---|---|
| BP1 | `campaign.py:tape_check` | Não valida `scenario_id`, `scenario_catalog_sha256` nem identidade de benchmark/lane dos novos domínios. Uma tape vertical podia ser admitida como assimétrica na mesma parede e direção UP, ocultando a ausência de assimetria. | Guardar/validar domínio, catálogo/revisão, benchmark e proveniência da captura antes do motor; testar troca de tapes entre domínios. |
| BP2 | `campaign.py:execute`, métricas | O resultado só rejeita os invariantes do driver antigo; a nova contagem `hard_physical_violations` não é promovida a hard gate. Além disso, `summarize` retorna cedo quando falta onset, antes de varrer esses checks. | Varredura global de POST/forças independente do onset; qualquer violação adicional rejeita, mesmo quando a tarefa/métrica não existe. Não permitir compensação por progresso. |
| BP3 | `benchmark_driver._run_scenario` / `_derive_runtime_measurement` | Replay reobserva um tick congelado e declara `valid_observation` sem validar a elegibilidade física desse onset. O runtime pode medir um valor enquanto Python retorna PRECONDITION_NOT_MET/null; a igualdade de recomputação transforma isso num erro de infraestrutura. | Distinguir tick reobservado de onset elegível. Revalidar apoio/comando/bands e manter runtime null quando inelegível, com motivo tipado. Não preencher zero nem alterar thresholds. |
| BP4 | `_run_scenario` após `_fresh` | Um retorno antecipado de fresh por Window/fixture pode deixar app nulo ou setup inválido; o caller continua para `_benchmark_prepare`/grip. | Guard de integridade, cancelamento, app/controller válidos e `override_error` antes de qualquer preparação/gesto; resultado BLOCKED_SETUP e cleanup normal. |
| BP5 | `metrics.py`, latency | Clean admite até .10 m/s no eixo, mas useful começa acima de .02 m/s. Um onset já a +.08 m/s podia receber latency 0 sem distinguir movimento herdado da preparação de uma nova resposta. | Manter progresso observado; identificar movimento já útil no onset e não o qualificar como nova latência de resposta para ranking. Não alterar bands físicas ou fabricar velocidade zero. |

BP3 também pede verificar o comando aceite no capture, não apenas presumir que um `_tick` bastou: o verificador Python já o faz e deve concordar com a classificação runtime. Um onset indisponível é uma falha física/semântica de preparação ou uma cobertura em falta, não uma nova autorização para tocar no corpo.

## Limites a manter mesmo após fechar os achados

- Runtime válido, onset válido, tarefa concluída, métrica medida e domínio elegível são contagens distintas. `ranking_eligible=false` no acumulador está correto; só o gate da campanha pode qualificar um domínio nomeado.
- O path/progresso raw de um intervalo parcial é diagnóstico, não substituto de um valor tipado interrompido/null. Uma nova diferença numérica na física não recebe tolerância para passar.
- Há apenas uma captura adaptiva por domínio/Hz; o input produzido fica congelado para os replays. Captura adaptiva não conta como terceira repetição fixa.
- Foot-step e stop recebem apenas um par e um controlo por Hz neste budget. Isso não satisfaz n=3 por célula: conservar a elegibilidade como diagnóstica/excluída se faltar replicação.
- Os quatro domínios primários recebem três pares por Hz. Igualdade baseline é repetibilidade local de mesmo seed/policy, não prova de outros candidatos/pixels/seeds/hardware.
- Regressões estão separadas do teto de 96 por confirmação do utilizador registada no plano; não contam como outcomes novos. Preflights sem RigidBody são checks de ambiente, não ensaios de escalada.

## Releitura e fechamento antes do freeze

Foi feita nova leitura dos patches, ainda sem motor:

- **BP1 fechado:** `tape_check` exige cenário, SHA do catálogo, benchmark e lane de origem para os domínios novos, além de source/engine/Hz/content hash. Catch permanece no seu ramo histórico explícito. A admissão Python antecede qualquer lançamento.
- **BP2 fechado:** a campanha varre massa/alcance, força de FREE/pending e caps publicados de todos os POST antes de avaliar onset/métricas. A contagem de hard violations medida pelo acumulador também é hard reject. Logo, onset ausente não evita esse audit global.
- **BP3 fechado:** `_row_onset_valid` verifica comando realmente aceite, apoio/carga e bands; `_raw_quiet_before` confirma o dwell registado e a mesma cadeia. O replay recertifica o estado no tick congelado ou publica onset null/PRECONDITION_NOT_MET com snapshot reobservado. O runtime não calcula um valor de sucesso a partir de um onset inelegível.
- **BP4 fechado:** há guard depois de `_fresh` para integridade/cancelamento/invariantes, app válido e erro de Resource antes de preparar grips.
- **BP5 fechado:** se a velocidade dirigida no POST anterior ao onset já excedia .02 m/s, a latência fica PRECONDITION_NOT_MET/null, `ALREADY_MOVING_BEFORE_ONSET`, com evidência do tick/velocidade e do eventual evento útil. O progresso físico continua disponível conforme a sua validade; não se fabrica uma latência zero de resposta nova.

O coordenador reportou 27 testes de métricas e três testes de admissão de tapes, além das suites anteriormente anunciadas. Não foram executados por este especialista e não são resultados de escalada. Os 34 processos/1146 checks de regressão e o startup normal são igualmente evidência separada do coordenador. A qualificação física nova ainda não começou nesta revisão.

Identidades recalculadas dos ficheiros revistos:

| Ficheiro | SHA256 |
|---|---|
| `benchmark_driver.gd` | `877328b6b809d4d62db3baeb9e54ab10aa6fbef8582722e42df82010863fbcdc` |
| `benchmark_runner.gd` | `dec65a1411bccf0941fbdea1eeb9d4cd5939761424d36289d420cdbc0250c758` |
| `benchmark_preflight.gd` | `423aef71784ac45709fbe8210e89d902d6aec4c2bbf0c01ff9bb4cae27c84152` |
| `benchmark_eval_v133.json` | `47462fac8b3340dd0426c631d64ea19b13fb07bf3c6dee89ec80d213bedc2f5d` |
| `benchmark_qualification/campaign.py` | `ac97bc379c37e2a0ec6f4f276aac92499e387e8ecc38ea779569db43a4355457` |
| `benchmark_qualification/comparison.py` | `dcf6eacdc75d5cb52eb372baa23ec3b87f48dd76ab1fc2b8f9f150ad7e87e036` |
| `benchmark_qualification/metrics.py` | `3535f707236dc929a4a0cf64afa1249cf5e8dbd90a666692f8d958f73f9cacd1` |
| `virtual_cursor_driver.gd` | `a66bf63e1a7bb67d1d31007cfe62f3abf3d8b878c59f86c6d9efae686c5bf9f5` |
| `qualification_driver.gd` | `581220ecec566db81a7169073128f472e02118b7c4a879c209f712871d096e32` |
| `projection_probe.gd` | `35c0ce94fe0ae1dd8722494a5b5196905a8f89f2652c7b386d6b0b50b1a646f4` |
| `run_plan.json` | `5965fc907a7b0b93fdce11af48d7d6702b332ea8c681159662654d1b3ffba82f` |

A comparação com os 285 ficheiros da baseline encontra mudanças em três scripts de infra antigos (`qualification_driver`, `virtual_cursor_driver`, `projection_probe`) e um teste Python (`test_projection`), além dos módulos novos. Não se encontrou diferença nos ficheiros protegidos de gameplay/solver/tuning/geometry dessa lista. Os hooks herdados mantêm a lógica antiga como default e introduzem override apenas na infra nova; não atribuem autoridade física.

## Estado final do preflight

**BP1–BP5 fechados por revisão de fonte; nenhum bloqueador estático pendente nesta releitura.** Arquitetura física/autoridade e contratos são adequados ao freeze e aos gates prospetivos. Isto não declara BQ1/BQ2, onsets, equivalência, métricas reais ou domínio algum como passados. As limitações e os hard stops permanecem; nenhum parâmetro/fixture foi ajustado a um resultado físico novo por este especialista.
