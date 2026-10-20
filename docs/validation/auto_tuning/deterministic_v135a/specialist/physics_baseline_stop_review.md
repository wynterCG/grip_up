# v1.3.5a — revisão física terminal da baseline interrompida

**REJECTED_BASELINE_NO_GO / BASELINE_NO_GO.** O gate obrigatório falhou no segundo processo; não há autorização física para pesquisa ou finalistas. A falha observada é de continuidade temporal/input-stream do avaliador, sem violação física observada no prefixo disponível. Não é admissível repetir, relaxar o guarda ou usar o preflight como substituto da baseline.

## Identidade e âmbito

- Fonte: `fccd68b47696f78f8eee6b3cb3291dc8375f2259`.
- Snapshot: `f81b0b58f966b99ff79415edf856d6c2439c5826ccb9127cdf69246c9f8dd270`.
- Ambiente Python: `93880dfde2cb42fd3ab0fcd6b96b964d3dcc237b37d25f9e01e2f86976cb82f5` (campanha fixada em3.13.13).
- Reducer: `ordered_binary64_sequential_v1`, fonte SHA256 `8264957f3acc818256055f61f6c94aa28d4fc85490713e430982948e730f7342`.
- Diretório de evidência: `builds/eval_virtual_cursor/minimal_v135a_r1`.

Esta revisão foi apenas leitura/análise offline. Não executei Godot, Git, sync ou novos testes, não abri holdout privado e não alterei fontes. Os 329 hashes públicos/helpers do snapshot e204protegidos no mirror C foram relidos, sem mismatch. A verificação C/E/external/histórico foi comunicada separadamente pelo responsável, não repetida por mim.

## Contagem e fronteira da decisão

O preflight teve seis processos RUN_VALID: Catch em ambosHz e quatro A0 candidate-shaped completos. O dry-run A0 chegou a métricas/SQLite/report/cleanup. A minha auditoria anterior desses seis leu2481POST sem anomalias físicas observadas; essa aprovação de preflight não satisfaz a matriz mandatory.

A baseline tinha24processos previstos. Executou apenas:

1. `vertical_pull_clean_v134_r2_120_headless_r1_edaa4afc`: RUN_VALID, janela completa;
2. `vertical_pull_clean_v134_r2_120_rendered_scripted_r2_deb07f25`: RUN_INVALID, paragem obrigatória.

Ficam22NOT_RUN, nenhum par H/R completo dos12exigidos, nenhuma repetição within-mode completa. Negativos, canary novo, otimização e finalistas não foram iniciados. Nenhum valor histórico ou preflight pode preencher essas células. O study não tem candidato ou resultado humano.

## Causa primária e erro secundário

No attempt rendered, o cenário reporta **`RUNTIME_SUSPENDED:TICK_GAP`**. O maior gap de parede foi257360microsegundos, acima do guarda inalterado250000. O motivo final do engine/parent é `PICK_CONTRACT_FAILURE:INCOMPLETE_PICK_STREAM`, com exitcode1. É o erro secundário de completude depois da interrupção; não demonstra falha de um raycast legítimo ou contacto recusado.

O artefacto contém11POST, mas só10frames instalados e zero sidecars/picks. No POST11, `input_source_sequence` e `tick_index` ainda são10. A lógica pré-controlo invalidou antes de instalar o frame11; o callback POST ainda registou o estado disponível. Não é um tick qualificado, nem prova de emissão normal do input11. O registo `virtual_input.cleanup` é vazio: **cleanup do provider não certificado**, apesar do restauro de Resource/clock/source declarado verdadeiro.

A origem OS/render do gap permanece UNKNOWN. Não atribuo causalidade a Jolt, GPU, observador, rato humano ou processo externo sem evidência específica. O guarda cumpriu o contrato fail-closed; não autoriza aumentar o limiar depois do resultado.

## Primeiro desvio e física efetivamente observada

A revisão de medição relata o primeiro desvio de INPUT no tick11 (`requested/input_source_sequence`: esperado11, observado10) e o primeiro desvio na camada PICK/câmara no mesmo tick (componente de pose da câmara), sem queries reais. Não chamar esse componente de uma direção de raycast medida: não há pick nesta execução.

Comparei independentemente os11POST comuns com o headlessH120 da baseline em COM, velocidades linear/angular, pose física, massa, estados/posições/forças/rest lengths das mãos e budget admitido: **nenhuma desigualdade observada nesses campos físicos**. A revisão de medição também não encontra desvio CONTACT/PHYSICS no prefixo. Isto limita-se a11linhas; não certifica equivalência da execução inteira nem estado interno Jolt.

Todas as22observações de mãos são FREE. Forças de mãos, pés, assistência, momento combinado e força/torque do motor de chão são zero em todo esse prefixo. Não encontrei não finitos nem força pending. As oito invariantes publicadas do cenário são falsas. Nenhuma aquisição, retenção ou onset de treino foi alcançado. Assim, este prefixo não testa integridade de uma garra carregada e não demonstra que o percurso completo passaria.

O engine declara instalação antes do primeiro tick, originais/ponteiro restaurados, clock restaurado, perfil de startup preservado e source unchanged. Esses resultados são compatíveis com os hashes relidos. **Não substituir por eles o receipt de cleanup ausente**, nem declarar tarefa válida porque o corpo permaneceu finito.

Nenhuma métrica de progresso/path/latência deste processo é elegível. O novo reducer não foi a origem do stop e a evidência golden continua uma prova de aritmética, não de robustez temporal do avaliador rendered. Não ocorreu a primeira proposta de otimização desta campanha.

## Segurança normal do produto — ledger separado

O responsável comunicou posteriormente34regressões/1146checks PASS, normal startup exato A0/profile2/LIVE, replay/capture/observer OFF, MCP com fresherrors0 e screenshot normal, export-release executável/smoke e inspeção de pack com23exclusões. Também confirmou que o plugin temporário e `project.godot` emE foram restaurados, C/E320fontes+9helpers e204protegidos/3externos/4866históricos sem alteração.

Esses são resultados de QA do jogo normal, separados da baseline fracassada. Não completam os22processos ausentes. A inspeção isolada de pack em host editor tem `release_template=false`; o smoke do executável produzido por `--export-release` é a evidência de execução release correspondente. Não confundir as duas modalidades.

## Veredicto

**BASELINE_NO_GO terminal; nenhum search GO.** Preservar os receipts, fonte, orçamento não gasto e A0. Não há evidência de regressão física observada nos11POST, mas a execução não é qualificada e a cobertura obrigatória está ausente. Este parecer não pede nem autoriza reparo/retry/campanha adicional. O jogo normal e a pesquisa ficam com decisões distintas.

## Hashes dos artefactos lidos

Todos os paths abaixo são relativos ao diretório de evidência; `failed/` designa o attempt rendered `vertical_pull_clean_v134_r2_120_rendered_scripted_r2_deb07f25`.

| Artefacto | SHA256 |
|---|---|
| `source_identity.json` | `cbf7160ab19962d5d8e52e2e216b413dd50e41319fd3cce4fa994723325e6a95` |
| `baseline_session.json` | `0c7ffce7c681ecbd7e393f3a9321b43ea1ecf80110559b1915ab9d773b8b998d` |
| failed `benchmark_audit.json` | `ccfb50dad274a6410cfa28ac1f0172fa2c523b37b71e0f801fc62ac4afc9f1c0` |
| failed `virtual_audit.json` | `1d17ddb60d9850797b915db20a447da7a09d5432bc103150f9af51b1e3198efc` |
| failed `engine_result.json` | `04baafa7f13fc31f1ac236a04a428d6949b93a0251b92b3add3586a6207f24a4` |
| failed `receipt.json` | `ed3d31fda50fcfcfc1fba314ec073cc2ce4cd70baf873541e5772199f6d2c31c` |
| failed `pick_dispatch_contract.json` | `911f0538f1e37fdcd5e7ec95d565df2a9ef81b38900cfa2565768b046204e029` |
| failed `manifest.json` | `dd012ac07fc518a88a0d98faffaf830e85d40528aa63dfa12bb600afc4d1c164` |
