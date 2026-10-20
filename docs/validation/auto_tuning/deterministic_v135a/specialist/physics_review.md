# v1.3.5a — fronteira física, golden e plano de revisão independente

**Estado: MR0 estático revisto; implementação/revisão do reducer e certificação física novas pendentes.** Não é `CERTIFIED_FOR_LIMITED_SEARCH`. O estudo R4 permanece encerrado como NO_GO, sem reaproveitamento dos objetivos inválidos.

Li integralmente a spec `GRIP_UP_Deterministic_Metric_Reduction_Auto_Tuning_v1_3_5a_EN.md`. O responsável comunicou MR0_READY após criar o [baseline_audit.json](../baseline_audit.json): commit limpo `20ab3431fd76c9518ceeeb907d1f191cf798d40d`, branch `feature/v1.3.5a-deterministic-metrics`, tag `baseline/pre-v1.3.5a-deterministic-metrics`, 204 hashes protegidos e 4 866 entradas históricas. Não fiz operações Git nem inspeção de E. Nenhum motor foi executado por este revisor e nenhum holdout privado foi aberto.

## 1. Golden físico e sequência observada

Reconfirmei offline a partir do `benchmark_audit.json` histórico da execução upper speed R4, não de uma tabela Markdown:

- attempt `vertical_pull_clean_v134_r2_120_headless_r3_ff1cc7a7`;
- SHA256 do audit `3f9248d21cb57862c029e7b20da3e104fc644067a8bb51f012beaaca5cdd7e7b`;
- 121 observações POST consecutivas, ticks425–545, portanto 120 segmentos;
- hash de todos os 120 comprimentos concatenados por `struct.pack('<d', valor)`: `2ef81c7306f293e5d7e22a7d9ad72c30997b9959920dca024e759ba20e8ca104`;
- redução sequencial correspondente à fonte Godot: `0.2245515785359135`, binary64 BE `3fccbe1b2b09d8a6`.

`physics_snapshot.gd`, `direct()`, lê `state.transform.origin + state.center_of_mass` do estado físico. Não lê a pose visual interpolada para este COM. A fase `post_control` do instrumento é após os callbacks de controlo e antes da integração física seguinte; não deve ser renomeada post-solver. O tick439 do diagnóstico R4 é o primeiro prefixo de acumulação diferente, não o primeiro desvio de física/câmara/ray.

`benchmark_driver.gd`, `_derive_runtime_measurement()`, converte explicitamente cada componente do COM para float escalar, calcula diferenças x/y/z, `sqrt(dx*dx+dy*dy+dz*dz)` e faz `distance += segmento` em ordem crescente dos ticks autorizados. O acumulador é float escalar GDScript; os componentes do Vector3 provêm do build float32. O progresso assinado usa a projeção separada de deslocamento final, nunca o path como substituto.

O contrato Python deve corresponder a toda esta definição, não apenas ao `sum()` externo que falhou uma vez. `metrics.py` também reduz norma, dot, carga, impulso e twist; o stop vem de outro caminho. Conferir fonte/ordem/tipo por família. Um golden que corresponde ao agregado mas muda bits de algum segmento é insuficiente. Nunca alterar Godot para acomodar um redutor escolhido por conveniência nem usar epsilon/ULP allowance/quantização.

## 2. Fronteira protegida confirmada

Os seguintes hashes foram relidos e coincidem com R4:

| Fonte | SHA256 |
|---|---|
| Fórmula `benchmark_driver.gd` | `f8799d9c3b1ede93e384a251b300046b9975d97833bb55171e9b8888a3a19c72` |
| Construção `feasibility_fixture.gd` | `d056474b2e41834a9e997a7b7adc01093769034b8b5d0e68780ef0dcff2b9c7a` |
| Preparação `feasibility_driver.gd` | `90743d75f44d19e95f42efefd525a33435f375c082321f7e4201ddf6913d158d` |
| `physics_snapshot.gd` | `c8f873f2908067f449edfc7a7c98cbfd6cc21f7fc96c142a9c38202720745f85` |
| Câmara `climbing_camera.gd` | `6269f222f95492b8da6528a3067e5c1a850e4c53f292e0b8f96e8118f9d7ce5e` |
| Coordinator de movimento | `d72ae7142bc1f94f8a0c26ffc16b5af784080b39fa0becda90dff679e81ca5f0` |
| Resource loader experimental | `c579ad582eef918f88ff49ea89c080a7f8c4bd63f4919c00c6fed434602d4a88` |

Os quatro campos, limites, acoplamento rate²/(2a)<=0.055 e rampa mínima de quatro passos60 continuam os aprovados. A cópia de Resource por load, seal pré-tick restrito, snapshots originais e restauro por ponteiro não requerem alteração. Nenhum novo esforço, alteração de pose/velocidade, capturas forçadas, buffer de força pending ou autoridade hybrid foi autorizado pelo conserto de métricas.

Manter 12 kg, R0.65708, mãos360 N, pés180/120 N, assistência20 N·m, momento150 N·m, mola6000 e damping220. Os monitores runtime e a comparação H/R exata não são relaxados. A query de clearance continua conservadora e distinta de força/torque de chão real. Contacto nativo com reporting desligado continua UNKNOWN. Reação linear publicada não é uma prova universal de conservação angular do modelo virtual.

## 3. Único delta de tooling implementado pelo revisor

Após MR0_READY, alterei apenas os dois ficheiros explicitamente atribuídos:

1. `minimal_driver.gd`: adiciona a lista exata `ADMITTED_CAMPAIGNS = ["minimal_v135_r4", "minimal_v135a_r1"]`, usada apenas nos dois guardas de campanha existentes. Mantém o flag opt-in, schemas, fases de busca e proibição de treinar casos transfer. Não altera a fórmula Godot, aquisição, dados de fixture, clocks ou camera.
2. `tools/benchmark_safety.py`: acrescenta `minimal_v135a_r1` à allowlist de diretórios safety. Nenhum caminho de gameplay muda. As exclusões já existentes cobrem os módulos Godot minimal atuais; o integrador deverá confirmar a exclusão efetiva de tooling Python no pack final.

Hashes desses deltas:

- `minimal_driver.gd`: `88d127276476470546ea953bb77ce27a48885ea73f8f2c421d19829255358689`;
- `benchmark_safety.py`: `d74c6cde677e34af1a4f2bb6412832d9ac355c5bb7bae19153ed5ab8579b5475`.

O AST Python de safety foi validado sem importar/executar o módulo. Não fiz parse Godot nem lancei testes, respeitando o único worker do responsável. Estes hashes não substituem o futuro snapshot congelado da campanha. A admissão do nome antigo preserva o comportamento anterior; não autoriza retomar R4 nem reescrever os seus receipts. O novo orquestrador precisa de namespace/SQLite/proveniência separados.

## 4. Plano finito de validação de um finalista — recomendação prospectiva

Recomendo máximo **um** finalista, A0 e candidato comparados, até24 processos separados dos40 de pesquisa:

| Capacidade | Jobs exatos para A0 e candidato | Processos máximos |
|---|---|---:|
| Swing & Catch | headless/rendered ×120/60 | 8 |
| First Ascent | headless ×120/60 | 4 |
| Stop com duas mãos | headless ×120/60 | 4 |
| Asym120 e Left120 | headless, dois casos | 4 |
| Tape Vertical independente | headless120 | 2 |
| Tape Right independente | headless120, **apenas se já existente e elegível** | 2 |

Total de teto24. A ausência da tape Right não permite fingir que uma definição no catálogo a demonstra: os dois slots ficam NOT_RUN/MISSING e o máximo executável é22, salvo revisão prospectiva explicitamente aprovada antes de resultados. Não substituir slots depois dos outcomes para conseguir uma vitória. Uma alternativa com one-hand120 foi apenas discutida, não constitui autorização automática para trocar estes jobs.

Este ledger não certifica one-hand60, braking de uma mão, nem Step inválido v134. Stop2H não substitui esses casos. First Ascent pode verificar contactos reais dos pés e a transição grounded→grip que efetivamente ocorrerem, mas não gera um score contínuo de foot support inexistente. Hybrid não entra como subida dinâmica. Cobertura relevante em falta limita a recomendação e pode bloquear o gate de produto; não declarar todos os unseen skills aprovados.

Dentro dos40 processos de candidatos, reservar explicitamente capacidade para V/R60 de um promissor antes de shortlist; só120 é insuficiente. O agente de integração propôs dez configurações (8sensibilidade+2random), cada uma com V/R em120/60: se adotado, são exatamente40 processos e nenhuma confirmação extra cabe. Falhas/setup/timeouts continuam consumindo slots reais; não acrescentar retries por inferência.

O préflight8 também necessita de ledger fechado: duas referências Catch, quatro tapes de treino novas e dois dry-runs já gastariam oito, sem capacidade para capturas unseen adicionais. Reusar tapes históricas de entrada verificadas pode reduzir capturas, mas exige identidade/admissão novas e nunca transforma resultados antigos em baseline nova. Captura adaptativa é um episódio/processo real, não uma tape gratuita.

## 5. Gates ainda não cumpridos por esta revisão

- **Reducer:** aguardo o aviso de pronto para revisar o módulo novo e o vínculo aos golden bits/phase/ordem. A fonte Godot já tem sequência definida e não precisa de edição.
- **MR5/preflight:** manifests reais, erro schema/source, A0 candidate-shaped end-to-end sob um só Python, ambiente antes do mundo, Catch real, restauro e zero mistura de intérpretes.
- **Baseline:** 24 processos novos, 12 pares H/R estritos e within-mode; full windows, contactos/apoios reais, sem chão/hybrid; métricas tipadas e nulls corretos. Nenhum valor R4 satisfaz este gate.
- **Negativos/canary:** força pending0, N1 dispatch real, sidecars, mudança de suporte/clearance e perda de elegibilidade preservadas. Canary não vira objetivo de treino nem pode ser retunado para passar.
- **Search:** dois tasks reais por configuração e ambosHz antes de shortlist, orçamento ≤40, first-hard-stop, A0 incluído; nenhum score raw de execução inválida. Aprovação de medição e física independentes ainda necessárias.
- **Finalista/produto:** ledger reservado, capacidades protegidas, cobertura em falta explícita e depois pessoas reais. Não há aprovação de default nem alegação de melhoria humana.

Não executei ensaios novos para preencher lacunas. A correção do redutor só permitirá avaliar de novo o programa de pesquisa sob identidade nova; não reabilita os candidatos speed0.22/0.28 do estudo R4.

## 6. Releitura independente do reducer Python e integração

Li `metric_binary64.py`, o golden JSON autêntico, os testes novos, as importações em `benchmark_qualification/metrics.py`, `metric_contracts.py`, `minimal_v135/engine.py` e os norm guards de `campaign.py`. Não modifiquei estes ficheiros nem executei as suites/interpretes; os resultados de testes comunicados pelo responsável não são execuções minhas.

Constatações estáticas:

- `sum_binary64_ordered` começa em +0.0 e adiciona em ordem, valida float genuíno/finito em cada entrada e acumulado, e pode proibir segmentos negativos. Não usa compensação, reordenação, float32 ou epsilon.
- `dot3` calcula os três produtos e a soma `((p0+p1)+p2)` sem +0 inicial extra, preservando a expressão da fonte; `norm3` usa sqrt dessa expressão. Isto evita corrigir apenas o agregado externo e deixar uma redução interna dependente do intérprete.
- Os vetores são convertidos apenas na fronteira numérica já permitida; bool/string/NaN são recusados. O produtor de segmentos exige que cada componente COM observado corresponda exatamente a um float32 promovido para binary64, sem escrever o vetor ou alterar picks/forças.
- O stream inclui janela, ticks crescentes, phase POST, unidades, bits e float.hex dos segmentos, identidade sequencial e proveniência. Ordem/valores/phase/hash/resultado inconsistentes são recusados. O payload não medido não recebe zero como resultado.
- Path e progresso assinado continuam separados. Para intervalos interrompidos, a auditoria pode conferir os valores **raw** disponíveis, mas o receipt oficial mantém `value=null` e `EXACT_MATCH_RAW_PARTIAL_NOT_SCORE`. Sem janela autorizada, números não nulos são recusados.
- Os usos restantes de `sum()` vistos no adaptador são contagens inteiras/bools de processos/rays/samples de saturação. Não são reduções float dependentes do intérprete. Impulsos acumulados com `+=` e a soma de paths stop já são sequenciais; as normas/projeções foram ligadas ao módulo comum.
- A identidade exigida pelo adaptador novo é `source.python_environment == manifest.python_environment`, com `manifest.metric_reducer` exatamente igual ao dicionário de `canonical_metric_contract_id()`. O fingerprint inclui executável, versão, pacotes/lock, locale/plataforma/float/SQLite e fonte do reducer. A campanha exige o venv 3.13.13/Optuna5.0.0; o segundo intérprete é só evidência de teste e não uma opção de execução intercambiável.

Comparei independentemente os 121 `points` do golden JSON com o raw histórico: ticks, phase e COM coincidem. A concatenação LE dos120valores continua `2ef81c7306f293e5d7e22a7d9ad72c30997b9959920dca024e759ba20e8ca104`; fórmula Godot real `f8799d9c3b1ede93e384a251b300046b9975d97833bb55171e9b8888a3a19c72` coincide com a proveniência. Não identifiquei mudança da definição física de input ou necessidade de alterar a fórmula Godot.

### Achados corrigidos ou pendentes de contrato

Foi comunicado um bloqueio de horizonte na primeira versão de `audit_path_against_godot`: assumia1segundo para toda a janela MEASURED, o que rejeitaria Stop5s válido. A releitura confirma que já recebe `observe_s` explícito da definição e valida o número de ticks desse horizonte, sem alterar o tempo físico. Recomendei um contrato focado de Stop5s e raw partial para verificar esta API, além do golden1s. Não se deve inferir o horizonte pretendido a partir dos endpoints observados.

O novo helper de terminação `run_trial.terminate_owned_process` trata apenas um subprocesso/árvore owned por PID, portanto está fora da autoridade de gameplay. Foi apontado um caso de erro: se a chamada `taskkill` lançar timeout/OSError, a primeira implementação saía antes do fallback kill/wait. Recomendei `try/finally` para tentar sempre reaping e falhar explicitamente o isolamento caso não consiga; não permitir outro ensaio do único worker assumindo que o filho terminou. Isto é um guarda de infraestrutura, não uma mudança de física ou justificação para relaxar restauro. A releitura dessa correção/receipt final ainda está pendente neste parágrafo.

**Parecer deste passe:** nenhuma alteração de mecanismo físico, pose, força, colisão, aquisição, câmara ou clock foi identificada no reducer. A sequência aritmética corresponde à fonte no envelope observado, com validação exata por run ainda ativa para inputs futuros. Aprovação estática física condicionada aos contratos/cleanup acima; MR5 e a pesquisa nova continuam sem signoff runtime.

## 7. Fecho estático e revisão do scheduler final

A releitura confirma o fallback `finally` no helper de terminação: poll/kill/wait são tentados mesmo se `taskkill` falhar; uma árvore não certificada continua erro, sem declarar cleanup fictício. O teste novo de `audit_path_against_godot` inclui Stop5s a60/120, horizonte errado recusado, partial com `value=None` e ausência de janela não convertida em zero. Li o teste, sem o executar. O responsável reportou8testes golden, reanálises R4 e contratos adicionais; a evidência runtime nova permanece separada desta leitura.

`projection_comparison.py` usa norm/dot comuns apenas para diferenças/ângulos diagnósticos. A comparação estrita de bits continua inalterada. A fórmula Godot continua SHA `f8799d9c3b1ede93e384a251b300046b9975d97833bb55171e9b8888a3a19c72`.

O scheduler novo `minimal_v135/deterministic_campaign.py` substitui a proposta preliminar de dez configurações por **cinco** (4 OAT, índices1/2/4/6 da fila congelada, e1random; TPE0). Cada proposta executa V/R em120 e60, quatro processos: máximo20. Reserva antecipadamente20processos adicionais para confirmar apenas um promissor. A confirmação reutiliza os quatro H iniciais com fonte/mapa de parâmetros/tape/ambiente iguais e completa os20H/R ausentes. O candidato terá então24processos, três repetições H/R por cada uma das quatro células, com12comparações H/R e16within-mode antes de shortlist. Total de pesquisa≤40, sem retries ou segundo finalista por inferência.

A elegibilidade e o ganho prático são exigidos nas duas frequências, sem compensar uma célula pior com a média da outra. Erro de infraestrutura/invariante para a pesquisa; precondition/task failure permanece rejeição tipada de candidato. A reserva consumida e os processos realmente lançados são contagens distintas. Identidade e fontes são verificadas antes das fases; as duas tarefas de treino são as únicas admitidas no score.

O plano protegido mantém o teto24 da secção4, com Right independente reservado e sem execução quando ausente. O scheduler executável conhecido tem22processos; termina em KEEP_A0 se cobertura requerida continuar em falta, sem forçar uma recomendação humana. Stop usa a definição5s original e compara path/settling/overshoot apenas medidos. First Ascent chama o helper existente de rota/hybrid, só após shortlist confirmada e freeze, e requer resultado de cenário realmente completed. A leitura desta função não abriu o catálogo privado. Não atribui recompensa de progresso à parte assistida. One-hand60 e o wrapper one-hand/braking continuam MISSING, não cobertos por Stop2H.

**STATIC_PASS físico da alteração aritmética e do plano relido.** Não identifiquei outro bloqueio de autoridade ou definição física neste delta. Este PASS permite avançar para o freeze/contratos/preflight já autorizados; não é o signoff MR5 de uma baseline ainda não medida, nem uma aprovação de busca/finalista/default.

Hashes de referência da releitura (o futuro snapshot congelado prevalece se a implementação ainda mudar):

| Fonte | SHA256 |
|---|---|
| `metric_binary64.py` | `8264957f3acc818256055f61f6c94aa28d4fc85490713e430982948e730f7342` |
| `benchmark_qualification/metrics.py` | `b044fc1a34ecb7c85b7f20f255bf24e3de1efd7b1c013879dcebd29ecc74a841` |
| `metric_contracts.py` | `a84efcd793fd60121126c6b7e63e5b8a57206b7fb033efe332b65d93301f8cb2` |
| `minimal_v135/engine.py` | `73809dd7d5a8f5a4cc952753ac361f9266de93877dcc10f8c97a1b2773397d31` |
| `projection_comparison.py` | `9fab84cb79368c0a4154aa2447df0be26a12731e72e4deab32a4530b385f33a3` |
| `run_trial.py` | `f3370a6984ef94bc29eb31a89c8711543dccdcf56ba39e78e3707f9e74b87e86` |
| `deterministic_campaign.py` | `c2ebdcbc8f7f49b0ddf27d016ef06d72dcf23fae488fa8133180f0d405e80c3a` |
