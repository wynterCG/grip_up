# v1.3.5 — revisão física independente antes do preflight

Estado: **APROVADO PARA TESTE CONDICIONAL; MB1/MB2 AINDA NÃO DEMONSTRADOS**.

Esta revisão autoriza tecnicamente testar a rota de cópia local dos quatro parâmetros e o canary declarado. Não aprova pesquisa, candidato, alteração de defaults ou qualidade humana. Não executei Godot, testes físicos, Git ou sincronização; não li definições privadas de holdout. Apenas este documento novo foi escrito. A implementação nova do avaliador ainda requer revisão após o aviso do responsável.

## 1. Identidade e fronteira da revisão

Li integralmente a spec `GRIP_UP_Minimal_Auto_Tuning_Benchmark_Spec_v1_3_5_EN.md`, SHA256 `42d06fa329d137dc7e9e08543944fb1f32f1a224e5928e1b3767ce8cbae9b6bd`.

O responsável comunicou `BASELINE_READY`. O [baseline_audit.json](../baseline_audit.json), SHA256 `9c98bf20f4314cf70c061832a503bf43c60e5d3d423996bc0fc455ec3f92cbae`, regista:

- commit selecionado `bc619a6bc3fae5f9105077fd34625e0ef9040fd1`, limpo, tag `baseline/pre-v1.3.5-minimal-tuning`;
- Godot `4.7.2.stable.steam.ed1daf0bf`, executável SHA256 `12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38`;
- Python 3.13.13 e Optuna 5.0.0;
- mapas de preservação dos scripts, recursos, evidência histórica e executável anterior.

Esses dados são o registo do responsável; não fiz uma segunda operação Git nem inspecionei E. Consultei os fontes no mirror C. A baseline v1.3.4 e R3 não foi modificada. Os seus resultados são históricos, não medições v1.3.5.

## 2. O que os quatro parâmetros realmente controlam

Os campos estão em [climbing_tuning.gd](../../../../../features/grip_up/resources/climbing_tuning.gd), linhas 89–96. Os valores efetivos do bípede preservam 12 kg, alcance de contacto 0.65708 m, mola 6000 N/m, amortecimento 220 N·s/m, rest length máximo 0.62 m e extensão elástica máxima 0.04 m; ver [biped_tuning.gd](../../../../../features/grip_up/resources/biped_tuning.gd), `_init()`.

| Campo | A0 | Intervalo permitido | Efeito observado no código |
|---|---:|---:|---|
| `traversal_speed_m_s` | 0.25 m/s | 0.18–0.32 | velocidade virtual desejada a partir da intenção e do frame de apoio |
| `traversal_input_ramp_s` | 0.12 s | 0.07–0.20 | rampa da intenção e janela de recência da inversão explícita |
| `traversal_target_max_rate` | 0.24 m/s | 0.16–0.30 | limite de velocidade dos alvos de comprimento existentes |
| `traversal_target_max_acceleration` | 0.90 m/s² | 0.60–1.20 | aceleração/travagem desses alvos |

[intent_locomotion_coordinator.gd](../../../../../features/grip_up/scripts/intent_locomotion_coordinator.gd), `step()`, lê `controller.tuning` em cada passo. Não guarda uma cópia independente dos quatro valores. A intenção passa pelo frame de apoio, pelo envelope geométrico de 0.055 m, pelos guardas de suporte/slip/saturação e pelo integrador existente de comprimento. Os parâmetros não são força, alcance, damping, adesão ou velocidade imposta ao corpo.

O limite `rate²/(2*acceleration) <= 0.055 m` deve permanecer. O mínimo de rampa 0.07 s corresponde a 4.2 passos de 60 Hz. Não é necessário estreitar os intervalos antes de testar; também não há fundamento para os alargar. Combinações como rate 0.30 e aceleração 0.60 devem continuar rejeitadas (0.075 m). O envelope geométrico pode saturar, logo maior velocidade virtual não garante maior progresso físico nem uma superfície de otimização monotónica.

`traversal_input_ramp_s` também afeta a recência da inversão manual. É obrigatório preservar a regra de inversão existente e verificar contra-comandos fora do score; não interpretar este knob apenas como latência inicial.

## 3. Hook mínimo no avaliador e guardas encontrados

Os caminhos históricos devem continuar baseline-only por defeito. A spec permite uma extensão opt-in do avaliador, não mudanças no controller/coordinator/actuator para aceitar candidatos.

Fontes auditados:

- [optimization_override_loader.gd](../../../../../features/auto_tuning_lab/scripts/optimization_override_loader.gd), `validate`, `apply_to`, `protected_values`, `restore`;
- [optimization_trial_lab.gd](../../../../../features/auto_tuning_lab/scripts/optimization_trial_lab.gd), `load_test`;
- [baseline_lab.gd](../../../../../features/evaluator_reliability/scripts/baseline_lab.gd), `verify_tuning`, `load_test`;
- [reliability_driver.gd](../../../../../features/evaluator_reliability/scripts/reliability_driver.gd), `start` (guard `BASELINE_ONLY_NO_OVERRIDES`);
- [virtual_cursor_driver.gd](../../../../../features/evaluator_virtual_cursor/scripts/virtual_cursor_driver.gd), `_fresh` (factory fixa `BaselineLab`);
- [optimization_trial_driver.gd](../../../../../features/auto_tuning_lab/scripts/optimization_trial_driver.gd), `_frozen_parameters_valid` e `_sample`.

Requisitos para o novo lane:

1. Um hook de factory e uma política de validação opt-in, com comportamento histórico default intacto. Não remover globalmente os guardas `BASELINE_ONLY` nem substituir silenciosamente o Lab de referência.
2. O novo Lab deve duplicar o Resource e instalar apenas o mapa completo dos quatro valores em **cada** `load_test`, após a construção síncrona original e antes de qualquer tick/await. Verificar `_step == 0`, identidade original/local e valores efetivamente resolvidos. O `_ready` inicial cria perfil 2; abrir a arena recria o controller. Validar só a primeira criação seria insuficiente.
3. Não chamar `configure`/`reset_state` após começar a simulação para propagar knobs. O coordinator lê o Resource atual. O motor de chão guarda o Resource recebido em `configure`, mas não lê estes quatro knobs; preservar os seus campos e a sua referência não exige reconfigurá-lo.
4. Revalidar os quatro valores reais e os protegidos durante o episódio. O comparador histórico dos knobs usa `is_equal_approx`; o novo contrato precisa de igualdade da representação efetiva esperada, sem uma aproximação que permita drift. O snapshot completo de propriedades deve ser tomado na configuração efetiva A0/B1 estabilizada antes do primeiro tick; mudanças legítimas de configuração durante a construção não devem ser confundidas com drift em runtime.
5. O loader histórico exclui os quatro campos em `protected_values(original)`. O novo teste de restauro deve incluir também esses valores originais e a identidade do Resource. Além disso, `restore()` histórico só reatribui quando `controller.tuning == local`; uma troca inesperada de ponteiro não pode terminar como sucesso silencioso. Registar/falhar a divergência e restaurar com segurança.
6. Aplicar o mesmo contrato a sucesso, rejeição de setup, timeout, cancelamento e falha física. Verificar os originais intactos, bindings encerrados, provider desligado e ausência do mundo anterior no espaço físico. Uma saída normal do processo não prova o restauro.
7. Validar schema/tipos/finito/ranges/cross-constraints/candidate hash antes da construção. Não aceitar mapa parcial, campo adicional, bool como número ou Resource salvo no disco.

O responsável descreveu uma implementação nova de subclass experimental, mapa exato dos quatro valores, snapshot completo e restauro por ponteiro. **Esse desenho é apropriado; não equivale a uma auditoria já concluída dessa implementação nova.** A revisão de código e os contratos reais ainda estão pendentes.

## 4. Fixtures, tape e onset

Admitir apenas Vertical e Lateral Right r2 da v1.3.4 para treino. Copiar/verificar identidades explicitamente; não alterar pad, paredes, apoios, contactos, horizonte ou preparação para acomodar candidatos. Os resultados históricos de Vertical (~0.206/0.210 m) e Right (~0.145/0.144 m) justificam testar a repetibilidade, mas não satisfazem MB2.

O caminho [feasibility_driver.gd](../../../../../features/evaluator_virtual_cursor/scripts/feasibility_driver.gd) usa aquisição real, W durante 1.5 s e regrips normais 15 cm mais altos. O [benchmark_driver.gd](../../../../../features/evaluator_virtual_cursor/scripts/benchmark_driver.gd) verifica duas mãos ATTACHED, suporte real, ausência de autoridade do chão/hybrid, clearance conservadora e onset aceite. Na reprodução, o onset congelado é revalidado no seu tick real. Um candidato não pode ganhar um novo onset adaptado, uma espera extra ou um retry para resgatar a tape.

O picker, raycasts e trajecto finito da mão devem permanecer reais. Inputs fixos não implicam contacto fixo: parâmetros podem alterar pose/câmara antes de um clique. Se isso impedir aquisição ou produzir um suporte inválido, preservar a falha. Não copiar a âncora A0 para o candidato. Comparar H/R estritamente entre **o mesmo candidato**, tape e frequência; o candidato não tem de reproduzir PHYSICS do A0. Não mudar a tape ou tolerância para obter a comparação.

Os dois apoios reais não autorizam chamar as células arm-only: B1 continua ativo e pode contribuir. A força e o trabalho dos pés devem ser descritos separadamente. A query de clearance conservadora não é um relatório de impulso nativo; `max_contacts_reported == 0` continua a deixar esse contacto UNKNOWN. Não transformar interrupção da fixture em falha do solver.

MB2 só pode passar com 24 processos novos, 12 pares estritos e as quatro células task/Hz completas. A falha de uma célula obrigatória impõe NO_GO; não escolher depois apenas a célula favorável.

## 5. Autoridade e limites físicos

Manter os limites existentes: mãos 360 N partilhados; pés 180 N totais/120 N por pé; assistência partilhada 20 N·m; momento combinado 150 N·m. Manter K/D, massa, colisores, gravidade, alcance, elasticidade, captura e slip. [climbing_controller.gd](../../../../../features/grip_up/scripts/climbing_controller.gd) aplica a alocação final e reserva a contribuição real do chão no perfil 4. O observer do avaliador deve medir os esforços admitidos após essa alocação.

Verificar por POST: valores finitos; mãos FREE/REACHING/pending sem força; ATTACHED com suporte/âncora válidos; contacto e retenção separados; ausência de autoridade aérea sem apoio; pés unilaterais/fricção e estado legítimo; ausência de autoridade dinâmica durante hybrid. Não alargar as allowances numéricas históricas.

O motor aplica força no ombro e reação oposta no anchor para apoios dinâmicos, com a assistência angular reagida nos apoios. Isto preserva o modelo virtual existente, mas não permite afirmar conservação angular exata do par completo de forças com braços de alavanca diferentes. Não alterar esse mecanismo neste trabalho. Qualidade em duas paredes estáticas também não certifica a transferência para vigas móveis.

Não confundir aceleração/jerk do corpo com violação: o proxy pode incluir gravidade e colisões. Trabalho parcial de contactos não é energia total nem custo muscular. Sem velocidade do ponto/força real ou eixo válido, o valor continua null com motivo.

## 6. Canary e critérios de qualidade prospectivos

O responsável declarou antes de medir o canary combinado:

```json
{"traversal_speed_m_s":0.18,"traversal_input_ramp_s":0.20,"traversal_target_max_rate":0.16,"traversal_target_max_acceleration":0.60}
```

**Aprovado para teste de sensibilidade condicionado aos guardas.** Está nos ranges, rampa de 12 ticks a 60 Hz e distância de travagem 0.021333… m. Reduz o pedido e a rapidez de progressão dos alvos sem alterar força ou alcance. Não está demonstrado que seja pior: saturação e estado inicial podem ocultar ou inverter o efeito. São quatro processos declarados (2V + 2R a 120 Hz), não treino/seed. Deve ser distinguível em pelo menos uma tarefa por um efeito medido e pré-declarado; caso contrário, reportar sensibilidade não demonstrada. Não reparar fixture ou retunar o canary após observar esse resultado.

As seguintes margens foram propostas por mim como revisão de engenharia, **ainda não como contrato adotado pelo responsável**. Devem ser aprovadas e congeladas com a variação fresh A0 antes da primeira proposta:

| Medida | Proposta de limite de regressão |
|---|---|
| Progresso | Ganho e não perda conforme §8 da spec: `max(10 mm,5%)` numa tarefa, perda não superior a `max(5 mm,3%)` na outra |
| Excursão para trás | no máximo +5 mm sobre o pior A0 comparável |
| Eficiência direcional | perda máxima de 0.05 absoluta |
| Latência realmente medida | aumento máximo `max(2 ticks,15% A0)` |
| Twist axial com frame válido | RMS até A0 + `max(0.03 rad,10%)`; peak até A0 + `max(0.05 rad,10%)` |
| Fiabilidade | nenhuma nova perda necessária de aquisição/âncora/retenção/janela/suporte |

A latência Right histórica é null por `ALREADY_MOVING_BEFORE_ONSET`; não criar latência zero nem comparar percentagens de null. `benchmark_extra` histórico declara `twist_frame_valid=false` e `twist_rad=null`: não usar roll/Euler total como substituto silencioso. Se a nova projeção não tiver uma medida axial válida, marcar qualidade angular não demonstrada/limitar a decisão; a aprovação física não preenche o dado.

Saturação, máximos de carga e jerk são outputs separados e canaries de plausibilidade, sem reward por chegar ao cap. Uma progressão maior com retenção pior ou autoridade do chão é ineligible. Não usar SD=0 da mesma tape como significância estatística.

## 7. Capacidades protegidas

Antes de qualquer integração, verificar Swing & Catch em ambos Hz: destino material real, carga admitida, source FREE, mesma âncora retida por pelo menos 0.6 s e alcance inicial além de R conforme o contrato existente. Não substituir a âncora final pelo centro selecionado quando houve resolução de superfície. Preservar a separação entre pending e load.

Outros canaries devem manter a sua elegibilidade própria: assimetria/Left120 úteis, mas as células60 historicamente interrompidas não são score zero nem PASS; Step v134 não é reclassificado como onset válido; stopping/inversão só em janelas autorizadas; uma mão60 ausente não é implicitamente aprovada. O percurso First Ascent deve preservar contacto nativo, ownership do hybrid e walking real; nunca pontuar o transporte assistido como subida dinâmica. Novas tapes independentes de validação devem ser congeladas antes de testar finalistas, sem otimização sobre os seus resultados.

## 8. Decisão e trabalho pendente

O plano reduzido comunicado é de 18 configurações (8 sensibilidade, 6 random, 4 TPE), até 36 processos de treino mais 4 confirmações, com apenas um eventual finalista. É compatível com o teto de propostas/processos da spec se cada lançamento/episódio, timeout e confirmação for contabilizado e a fase TPE continuar condicional. Não gastar pesquisa antes de GO MB2.

**Estático confirmado:** campos reais e ranges, leitura por passo, necessidade de três extensões avaliadoras explícitas, guardas existentes e limitações do restauro histórico, ausência de necessidade de novo solver ou reset em runtime.

**Pendente:** revisão dos novos hooks; testes de instalação/restauro/recusa; preflight real; N1/negativos/canary; 24 processos MB2; auditoria independente dos POST e comparações; limiares finais adotados; pesquisa condicional; validação de transferência; segurança/export/restauro normal novos; feedback humano. Nenhum desses pontos recebe PASS por este documento.

Veredicto presente: **PROSSEGUIR APENAS PARA PREFLIGHT/BASELINE SOB GUARDAS; NÃO HÁ GO_MINIMAL_BENCHMARK OU CANDIDATO APROVADO AINDA.**

## 9. Releitura dos hooks novos — achados antes do freeze

Revisão estática solicitada após a criação de `minimal_driver/lab/override_loader/runner/batch_runner`, os dois catálogos e o plano. Não executei o motor. Os hooks default em `qualification_driver._candidate_policy_error()` e `virtual_cursor_driver._make_virtual_lab()` preservam, respetivamente, A0-only e `BaselineLab`. O override novo é opt-in, sem alteração de solver ou autoridade. O catálogo de treino contém exatamente V/R e mantém os valores físicos/preparação r2; a lista pública de transferências é separada e rejeitada nas fases de busca.

**Bloqueio identificado na primeira versão:** `minimal_override_loader.apply_to()` guardava o snapshot efetivo completo ainda dentro de `load_test`. A seguir, `_fresh()` ativa distant targeting e a configuração final. `allow_out_of_reach_grip_targets` muda legitimamente false→true antes do primeiro tick, pelo que `exact_effective_valid()`/`restore()` acusariam drift. O controller inicial profile2, retirado antes da arena, pode também receber `physical_feet=false→true`. Não é falha de física nem razão para enfraquecer o comparador.

Foi comunicado o contrato mínimo de correção: instalar os quatro knobs e guardar o original imediatamente; certificar/seal o mapa efetivo apenas após a configuração final, ainda com `_step==0`, validando o diff em vez de aceitar o estado observado indiscriminadamente. Só dois campos podem diferir do snapshot de instalação nesta sequência:

- controller ativo: `physical_feet=true` e `allow_out_of_reach_grip_targets=true`;
- controller profile2 inicial retirado sem física: `physical_feet` pode tornar-se true; distant permanece false. Deve ser identificado como startup retirado, não como episódio medido.

`predictive_grip=false`, `capture_intent_buffer_duration=0.15`, os quatro knobs e todas as restantes propriedades continuam exatos. Não incluir predictive/buffer numa whitelist genérica de alterações. Os sliders de drag/rate são definidos antes da instalação e não justificam alterações posteriores neste replay. Os originais completos devem permanecer intactos, incluindo os quatro knobs. O seal final não permite modificar física durante o episódio nem reseal de um controller já avançado.

Outra inconsistência de evidência comunicada: o `MinimalLab` da primeira versão herdava a gravação `verification_only=true` do `BaselineLab`, embora tivesse aplicado uma cópia. O modo `MBQ_SESSION_LOCAL_COPY` e `identity_unchanged=false` já indicavam a operação real; o booleano deve ser corrigido no lane novo para não declarar uma operação só de leitura.

Não encontrei outro bloqueio físico estático no conjunto lido. O plano de batches usa drivers, mundos, tapes e relógios independentes por episódio; continua a precisar de prova real de ausência de corpos/RIDs ativos e restauro entre episódios. Subárvore ausente e contagem de objetos ativos são sinais distintos e não uma prova universal de libertação de todos os RIDs.

**Estado desta releitura: REVISÃO COM BLOQUEIO PRÉ-TICK COMUNICADO; CORREÇÃO/CONTRATOS AINDA PENDENTES.** A implementação estava em alteração pelo responsável; este parágrafo não certifica uma revisão futura nem um hash final. Os contratos a verificar antes de freeze são: seal restrito aos dois campos/valores esperados; drift de knob, protegido e ponteiro recusado; original completo intacto; restauro dos bindings startup/ativo; rejeição de instalação tardia; teardown em erro. MB2 continua pendente.

## 10. Fecho estático do delta de seal

A releitura seguinte confirma a correção: `MinimalLab.load_test()` certifica o controller startup retirado antes da construção seguinte, com os valores esperados do estado do Lab; o hook default `_seal_virtual_lab()` é no-op nos caminhos históricos. No driver minimal, o hook certifica flags true/true após a configuração final e antes de `_scenario_enabled`, sem qualquer tick de preparação entre instalação e seal. O loader exige `_step==0`, ponteiro original/local consistente, original completo intacto e igualdade de todas as outras propriedades, incluindo os quatro knobs. As duas chamadas reais fornecem valores booleanos esperados; não foi acrescentada uma whitelist de propriedades arbitrárias. `verification_only=false` corrige a descrição da operação no Lab novo.

O responsável forneceu `pure_development/override_stdout.txt`, que li: **11 checks, 0 failures; zero gameplay bodies**. O teste cobre o default A0-only, cópia/restauro, valor protegido, knob, flag inesperada, instalação tardia, troca de ponteiro e mutação de um knob no original. Não o executei. Estes checks não provam que um episódio físico com todos os callbacks complete; essa prova pertence aos novos processos preflight/baseline.

Os receipts misturam instalações e seals. Uma leitura intermediária do adaptador Python ainda indexava `copied` em todos os records; a versão atual já trata esse campo apenas quando existe, valida step0/original intacto para todos e exige o seal `MEASURED_WORLD_PRE_STEP`. Esse possível erro de transporte não permanece como bloqueio da versão relida.

`engine.enrich_quality()` apenas lê os POST da mesma janela certificada completa; preserva null fora dela. O backwards excursion é drawdown máximo a partir do pico de progresso já alcançado. Off-axis é a distância ao eixo unitário declarado dos dois cenários. A velocidade angular total é descritiva e não substitui twist axial. A fração de saturação é uma fração dos samples POST selecionados; não é trabalho/energia nem um novo esforço.

Hashes da releitura (não substituem o futuro snapshot congelado da campanha):

| Ficheiro | SHA256 |
|---|---|
| `minimal_override_loader.gd` | `c579ad582eef918f88ff49ea89c080a7f8c4bd63f4919c00c6fed434602d4a88` |
| `minimal_lab.gd` | `9a03b5c70215ed807771f9f4bbdfa43ca01ffeda5c2135169e2ce2b547b22698` |
| `minimal_driver.gd` | `d7b1cd0210f6e8dad125a15e37f84e8ffb9c15dde7cf5b4f6dfa25522ee38054` |
| `virtual_cursor_driver.gd` | `e6992e0c0b79ca755b61a78ea177025b48f6a5e1069b143d964e65b22b9e06ff` |
| `qualification_driver.gd` | `543538fa4044aca6984360792a836a6cf6ce3e23eabd2308ca680c9e20efab66` |
| `minimal_v135/engine.py` | `ee557b0f2cb929e7d0e70c8a2f01beee18d6f95cac1d2d694224b83e94a8fbc5` |
| `test_minimal_overrides.gd` | `97a516e35c7005f43cc65acfec84072e50a016cb7b4c7ddd0e7c482b07bc6392` |

**Decisão atual: SEM BLOQUEIO FÍSICO ESTÁTICO IDENTIFICADO NESTE DELTA; APROVADO PARA O PREFLIGHT/BASIS DE TESTE PLANEADO.** Mantêm-se todos os gates runtime, MB2 e pesquisa condicional. Isto não é GO_MINIMAL_BENCHMARK. Não houve execução do motor, edição de fontes ou reapreciação das falhas históricas.
