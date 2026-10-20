# v1.3.3 — parecer independente de física e benchmark

Data: 2026-10-20. Fonte congelada: `3c888c70a0b5a8bc427e3b68058ac744ba002db6`. Baseline preservada: `247f19060f7966a8b5fe547cfc5a91e62fa2c2a5`.

**Decisão recomendada: NO_GO_BENCHMARK nesta campanha.** BQ1 rejeitou o ambiente canónico antes de criar corpos de gameplay. BQ2 e a matriz dos domínios não foram iniciados. Não existe uma falha de escalada ou um resultado de força/controlo novo a atribuir ao Jolt, ao A0/B1 ou ao utilizador.

## Âmbito da revisão

Este especialista leu a spec inteira, realizou as revisões estáticas `specialist/BQ0_review.md` e `specialist/BQ_preflight_review.md`, releu o preflight falhado e os quatro diagnósticos concluídos, incluindo manifests, resultados e scripts temporários. Não executou motor, suites, Git ou sincronização, nem alterou código, tuning, geometria ou tapes. Os únicos ficheiros escritos pelo especialista são relatórios.

Na leitura final, os **292 hashes** em `builds/eval_virtual_cursor/benchmark_v133_r1/source_identity.json` ainda correspondiam aos bytes no mirror C. Os diagnósticos usam scripts próprios arquivados em builds, identificados como diagnóstico, sem remendar o preflight/driver congelado. Não existe `reference_session.json` nem `domains_session.json`. As únicas quatro pastas de attempts são os diagnósticos D1–D4.

## BQ1: rejeição observada, não inferida

Receipt primário: `builds/eval_virtual_cursor/benchmark_v133_r1/preflight/headless_120_1_positive/` e `preflight_session.json`.

O manifest pediu engine `4.7.2.stable.steam.ed1daf0bf`, `--headless --fixed-fps 120 --resolution 1024x576`, 120 Hz e backing esperado 1024×576. O script é `benchmark_preflight.gd`, não uma cena de gameplay. O binário observado tem SHA256 `12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38`.

O resultado devolveu:

- `ENVIRONMENT_NOT_COMPARABLE`, razão `BACKING_SIZE`, exit code 1;
- tamanho real **64×64**, mode 1, screen −1, posição (0,0);
- zero corpos de gameplay e zero outcomes físicos.

O stdout identifica o motor; não há script error ou crash no stderr. O preflight positivo falhou e a sessão permanece `pass=false`. Não é um controlo negativo previamente aprovado que passou: uma execução que devia satisfazer o ambiente foi corretamente rejeitada pelo seu guard.

A spec §5.2 exige usar o estado observado, rejeitar tamanho incorreto e nunca reparar silenciosamente uma comparação. BQ1 é pré-requisito de BQ2 e da expansão de domínios. Por isso, parar aqui está correto. O budget disponível não autoriza continuar uma matriz cujo ambiente canónico ainda não passou.

## Quatro diagnósticos diretamente relacionados

Foram lidos `diagnostics_session.json` e os artefactos individuais em `builds/eval_virtual_cursor/benchmark_v133_r1/attempts/`. Todos são `ENVIRONMENT_DIAGNOSTIC_NOT_QUALIFICATION`, com zero corpos de gameplay e zero outcomes físicos.

| Diagnóstico | Intervenção | Estado após clock | Conclusão limitada |
|---|---|---|---|
| D1 H120 CLI | Mesma CLI, sem atribuição de tamanho | 64×64; logical visible 1920×1920; dois deltas de 1/120 | Esperar por clock válido, isoladamente, não corrigiu o estado da janela |
| D2 rendered120 CLI | CLI 1024×576, sem atribuição explícita | 1024×576; logical 1920×1080; dois deltas de 1/120; posição real (2400,80), screen 0 | O mesmo pedido CLI foi admitido neste ambiente rendered; não prova que a posição pedida foi obedecida literalmente |
| D3 H120 explicit init | `root.size=Vector2i(1024,576)` antes do clock/mundo | Passa de 64×64/logical1920×1920 para 1024×576/logical1920×1080; dois deltas de 1/120 | A API explícita de inicialização altera o estado observado no processo headless sem corpos |
| D4 H60 explicit init | Mesma inicialização, clock 60 | 1024×576/logical1920×1080; dois deltas de 1/60 | O estado esperado foi observado também neste diagnóstico de 60 Hz |

Os scripts lidos criam apenas uma SceneTree e um Node de clock; não instanciam Lab, RigidBody, apoio, solver ou atuador. A atribuição de tamanho em D3/D4 é uma intervenção de Window **rotulada**, não uma correção de pose do jogador. Não houve corpo para teleportar, congelar, acelerar ou suportar.

Os quatro processos terminam com exit 0 porque completam a observação diagnóstica. Isso **não significa que D1 tenha passado o ambiente canónico**, nem transforma D3/D4 em preflights positivos do protocolo primário. O marcador `primary_campaign_stays_stopped=true` está correto.

## O que se pode concluir da causa

Há evidência de uma diferença do ciclo de inicialização entre um root Window headless de SceneTree custom e o root rendered: o pedido CLI não se refletiu no estado headless medido, mesmo depois de callbacks válidos. A atribuição explícita de tamanho antes de criar um mundo produz o tamanho/visible rect esperado nos dois diagnósticos headless.

Não foi demonstrada a operação interna exata do display-server que ignorou/adaptou a CLI. Não se deve chamar a isto bug Jolt, alteração das forças ou falha de determinismo dos contactos: nenhum desses mecanismos foi exercitado. Também não contradiz a v1.3.2b: o seu driver verificava/inicializava Window antes do mundo, e os seus resultados continuam com a identidade e o âmbito próprios.

É tecnicamente plausível uma futura correção de inicialização de harness, declarada antes do mundo e seguida do mesmo guard observado. **Esta campanha não a implementou nem a qualificou.** Não se recomenda retomar ou substituir o preflight R1 falhado, criar retry oculto, relaxar o tamanho ou reciclar D3/D4 como passes BQ1. Qualquer continuação requer decisão/protocolo novo explicitamente autorizado, novo freeze e evidência própria; não exige nem justifica modificar física.

## Estado por domínio/capacidade

| Capacidade | Revisão estática | Evidência nova de qualificação | Parecer físico/benchmark |
|---|---|---|---|
| Preservação do kernel A0/B1, anatomia e budgets | PASS da fronteira auditada; hashes congelados correspondem | Regressões separadas do coordenador | PASS estático; não confundir com domínio novo |
| BQ1 ambiente CLI canónico | Guard adequado, rejeitou tamanho incorreto | Um preflight positivo rejeitado | **REJECT do contrato de execução nesta campanha**, não da física do jogo |
| Diagnóstico de lifecycle Window | Leitura pura, sem autoridade de corpo | D1–D4 concluídos | PARTIAL / diagnóstico apenas |
| Swing & Catch BQ2 fresco | Caminho de referência preservado | 0/12 processos novos; 0/6 pares | **MISSING_COVERAGE**; o GO_LIMITED_PROJECTION anterior não soma passes aqui |
| Vertical clean | Reuso/setup e contratos revistos | Nenhum mundo/nenhuma captura | **MISSING_COVERAGE**, não falha de subida |
| Asymmetric clean | Parede/seleções reais revistos | Nenhum mundo/nenhuma captura | **MISSING_COVERAGE**, não simetria ou ganho demonstrado |
| Lateral clean esquerda | Geometria/ordem espelhada revistas | Nenhum mundo | **MISSING_COVERAGE** |
| Lateral clean direita | Mesmo âmbito | Nenhum mundo | **MISSING_COVERAGE** |
| Foot-supported step | Contacto/carga/SLIDING e budgets revistos | Nenhuma planta ou transferência nova medida | **MISSING_COVERAGE**; sem benefício B1 novo inferido |
| Two-hand release-stop | Band/dwell/typed metrics revistos | Nenhum onset/stop físico novo | **MISSING_COVERAGE**; testes sintéticos não são stops reais |
| One-hand60/counter/moving/offsets novos | Fora do subset limitado | Não executados | MISSING_COVERAGE / continuam abertos |
| First Ascent/hybrid | Integração/validação apenas | Nenhuma qualificação nova por esta campanha | Não é fitness puro; rota hybrid não alterada |

Nenhum domínio recebe `ELIGIBLE_FOR_RANKING`. Nenhum recebe `EXCLUDED_SAFETY` por um incidente físico que não aconteceu. A política de métricas pode estar correta em testes sintéticos enquanto a sua capacidade de medir estas tarefas reais permanece por qualificar.

## Contagens e invariantes: o que não alegar

- Primário: **1 processo puro de preflight tentado/rejeitado**, 0 corpos/outcomes, 0 pares de replay ou novas capturas.
- Reserva pós-stop: **4/4 diagnósticos puros**, concluídos e diretamente ligados à admissão de ambiente. Não preenchem células primárias.
- BQ2 e novos domínios: todos não executados. Não substituir o denominador por estes cinco processos nem por resultados históricos.
- Os 34 processos/1146 checks de regressão e startup normal reportados pelo coordenador são preservação independente, separados do teto dos novos benchmarks por autorização do utilizador. Não foram reexecutados por este especialista.
- Não existem máximos físicos de mãos/pés/assistência/COM desta campanha a reportar como novos: **não medido não é zero**. Não se declara que caps passaram em novos cenários só porque nenhum body existiu.
- Tapes antigas, private holdout outcomes e otimizadores não foram usados para obter um score novo. Não houve ensaio humano nem melhoria de feel inferida.

## Decisão final

**NO_GO_BENCHMARK — ENVIRONMENT_NOT_COMPARABLE antes de BQ2.** O caso não satisfaz os pré-requisitos de GO_LIMITED_BENCHMARK e tampouco um GO_NARROW_DIAGNOSTIC de domínios: nenhum domínio físico novo foi qualificado. Existe apenas conhecimento diagnóstico útil sobre a inicialização da janela.

Próxima ação desta campanha: concluir o relatório/arquivo, verificar rollback normal e manter A0/B1 jogável. Não lançar Random/TPE/CMA/Optuna/RL/JEV, sensibilidade, novos tapes ou uma matriz substituta automaticamente. A evidência antiga de projeção continua limitada aos seus perfis efetivos, e a evidência nova não a amplia nem a apaga.
