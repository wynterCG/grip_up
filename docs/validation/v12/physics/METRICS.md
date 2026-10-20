# v1.2 — contrato e validação das métricas físicas

Código novo, separado do gameplay: `features/locomotion_test_suite/scripts/movement_metrics.gd`. O acumulador é `RefCounted` e só recebe dicionários numéricos; não acede a nodes, servidores físicos, input, câmara ou mundo. Não altera os snapshots recebidos. Não é um segundo observador físico.

## API congelada

```gdscript
configure(options: Dictionary = {}) -> void # configura e limpa estado
start(snapshot: Dictionary, direction: Vector3, config: Dictionary = {}) -> bool
push(snapshot: Dictionary) -> bool
record_event(event: Dictionary) -> bool
finish() -> Dictionary                      # consulta; não modifica a simulação
recent_samples() -> Array[Dictionary]       # cópia do ring limitado
recent_events() -> Array[Dictionary]
reset() -> void
```

`start` limpa a tentativa anterior. A referência é `config.reference = "com"` por defeito, ou `"body"`. O snapshot tem de conter `com_position: Vector3` ou `body_position: Vector3` conforme essa escolha. Não há fallback silencioso de COM para corpo/IK. `direction` fica normalizada e congelada nesse início. Direção zero produz progresso/eficiência indisponíveis.

Chaves canónicas e aliases aceites:

| Grandeza | Chaves |
|---|---|
| tempo em segundos / tick físico inteiro | `time` / `tick`, ou `time_s` / `physics_tick` |
| movimento físico | `com_position`, `body_position`; alias `position` apenas para referência body |
| velocidade mundial física | `velocity` ou `linear_velocity` |
| comando mundial observado | `movement_intent_world` ou `intent_world` |
| twist axial medido | `twist_rad` ou `twist` escalar; eixo definido pelo produtor |
| saturação real conhecida | `saturated: bool`; não inferida de uma pose |
| autoridade assistida | `assisted: bool` |
| transporte material | `support_displacement: Vector3` acumulado, ou `support_point_world: Vector3` + `support_id` |
| forças aplicadas | `contacts: Array[Dictionary]`, descrito abaixo |

O produtor de `support_point_world` tem de manter o **mesmo ponto material**, não apenas o mesmo collider. Regrip noutra coordenada local do mesmo corpo não é transporte. IDs diferentes invalidam o resultado relativo da tentativa. Sem referência material válida a métrica relativa é `null`; velocidade isolada não é integrada para inventar uma posição material.

## Definições

- Progresso: `(posição_atual − posição_inicial) · direção_inicial`, sem truncar valores negativos.
- Caminho: soma dos módulos dos segmentos físicos amostrados na referência escolhida. Eficiência = progresso/caminho quando caminho ≥ 0.01 m, por defeito. Caso contrário `null`; a razão é `NO_MOVEMENT_OR_NO_DIRECTION`.
- Progresso relativo: subtrai o deslocamento mundial do mesmo ponto material, projetado na direção inicial. Inclui transporte rotacional se o produtor fornecer esse ponto corretamente.
- Janelas de 0.25/0.5/1.0 s: interpolação linear entre os dois snapshots físicos que atravessam a janela, com os ticks dessa interpolação guardados. Não são frames renderizados.
- Twist RMS: raiz de `Σ(twist² × dt)/Σdt` sobre intervalos conhecidos. Pico = máximo módulo observado. Não é roll, tilt ou amplitude pendular disfarçada; o eixo é responsabilidade do snapshot e a cobertura conhecida é registada.
- Saturação: duração e fração de intervalos com booleano conhecido. O produtor tem de identificar se o booleano representa mãos ou todos os orçamentos; o acumulador não inventa um limite global.
- Correções: mudança de direção de comando superior a 20°; reversões: produto escalar entre comandos normalizados < −0.2. Neutro não conta como correção nem apaga o último comando para contar duas vezes. Oscilação do corpo sem mudança de comando não é correção manual.

### Overshoot e settling, extensão numérica final

`target_progress_m` é opcional; sem alvo, `movement.overshoot_m=null` e razão `NO_TARGET`. Com alvo, `target_corridor_m` define meia largura não negativa (default .02 m) no eixo de progresso fixo. Overshoot é o máximo excesso positivo para lá de alvo+meia largura durante a tentativa; uma posição 1.10 m para alvo1.00/corredor.02 produz .08 m, sem alterar a trajetória.

`settle_linear_m_s=.1`, `settle_angular_rad_s=.2` e `settle_hold_s=.25` são thresholds configuráveis. É obrigatório ter velocidade física linear **e** `angular_velocity:Vector3`; falta de uma não é tratada como repouso. A observação de settling é armada no primeiro target-entry, ou num stop real (comando passa de nãozero a neutro, ou evento `stop_command`). Uma prelude em repouso sem alvo/stop não recebe crédito.

O intervalo estável exige ambas velocidades abaixo do limiar e, se houver alvo, posição dentro do corredor. Um spike/interrupção reinicia a persistência. `settling.time_s` é o início do intervalo estável atual, relativo ao instante em que se armou a observação; fica null até confirmar o intervalo completo. `currently_settled` e `first_confirmed_at_s` distinguem estado atual do primeiro episódio confirmado. Sair depois do corredor ou deixar de estar estável invalida `time_s` atual, sem apagar o histórico da primeira confirmação. Isto não é um novo objetivo de gameplay, nem implica que uma tarefa foi concluída.

As integrações são quadraturas por snapshot no extremo direito de cada intervalo, não medição exata de impulso/contacto contínuo. Caminhos subamostrados podem subestimar a distância percorrida; a frequência de análise e a de escrita do trace devem ser distinguidas. O recorder da raiz chama `push` por tick físico e pode escrever JSONL a 20 Hz, conservando os agregados físicos.

## Latência

Sem evento explícito, o onset é o primeiro snapshot com intenção não zero (epsilon 0.001); `response.onset.source = first_observed_nonzero_intent`. Uma prelude neutra não entra na latência. Este onset não deve ser chamado latência de hardware/tecla: o produtor pode já ter filtrado o comando.

Se o harness tiver o instante aceite antes do filtro, pode chamar:

```gdscript
record_event({"type":"command_onset", "time":t, "tick":tick,
              "velocity":actual_velocity})
```

O onset passa a `explicit_accepted_input_event`. Um evento explícito anterior/coincidente tem prioridade sobre o fallback já criado pelo primeiro snapshot; limpa a resposta inferida anterior. Um input que já estava premido antes do início da medição é `PREHELD_INPUT` com latência null, não zero. O limiar numérico de coincidência do início é10µs. Um evento explícito de input já aceite não é substituído por novos comandos da mesma tentativa.

A primeira resposta tem de superar o limiar durante a persistência configurada. Defaults: incremento de velocidade projetada relativamente à velocidade no onset ≥ 0.05 m/s; persistência 0.05 s. O modo opcional `response_mode="acceleration"` usa derivada das velocidades físicas, com limiar 0.5 m/s². O tempo devolvido é o início do intervalo sustentado depois de a persistência ter sido verificada, não o instante em que se confirmou o resultado. Um pico de um tick não basta. Ausência de velocidade/resposta é `null` com razão.

## Carga e trabalho

Cada contacto é `{kind, state, force:Vector3, applied:bool, point_velocity:Vector3, support_velocity:Vector3}`. `point_velocity` é a velocidade real do corpo no **ponto de aplicação** da força, incluindo rotação. Não usar só velocidade do COM para forças fora dele. `applied:true` é obrigatório; a configuração `contacts_are_applied=true` só pode ser usada por um produtor que garanta isso para todos os contactos.

Estados válidos: mãos ATTACHED/SLIPPING; pés SUPPORTING/SLIDING; ground explícito. Um pé carregado requer força de módulo > 1 N por defeito. SEARCHING/PLANTING não contam; uma força não zero nesses estados é um erro diagnosticado. Durante `assisted=true`, caches não zero de mão/pé são diagnosticadas e não recebem crédito de trabalho.

`foot_loaded_time_fraction` usa tempo conhecido de contactos. `foot_upward_load_fraction` usa a integral de componentes positivas para cima dos pés dividida pela soma dessas componentes dos contactos **fornecidos**. Se o produtor só fornecer mãos/pés, o denominador não inclui apoio nativo do chão. Não é pressão da sola, nem soma de módulos, nem fração de toda a carga gravitacional do mundo.

Trabalho parcial de forças = `Σ F · velocidade_ponto × dt`, preservando sinal negativo. Trabalho relativo usa `F · (velocidade_ponto − velocidade_suporte)`. Velocidade/força ausente produz `null` para trabalho completo. `observed_partial_work_j` permite ver o subtotal conhecido, separado da cobertura. Não são energia metabólica, energia total do sistema ou trabalho de torques. Gravidade, impulso de colisão, ground/torques não fornecidos e movimento assistido ficam fora desta soma.

## Eventos, integridade e memória

`attempt`, `contact`, `retained`, `release`, `slip` usam `time/tick`, `hand_id`, `attempt_id`. Contacto nunca implica retenção; `retained` sem contacto prévio é rejeitado e diagnosticado. Contactos/retenções do mesmo par mão/tentativa são contados uma vez enquanto essa tentativa estiver no histórico limitado. Não se deve reproduzir eventos antigos depois de saírem desse histórico como se fossem novos.

Amostras com tempo/tick duplicado ou decrescente são rejeitadas. `physics_hz`, quando fornecido, permite verificar alinhamento de tempo/tick de amostras e eventos; saltos de ticks são assinalados. Os rings têm defaults de 512 amostras e 128 eventos, com limites máximos de 8192/1024. A expulsão de amostras não reinicia progresso, caminho ou integrais. Resultados e cópias de rings não partilham estruturas mutáveis com o chamador.

## Validação congelada

`tests/test_measurement_metrics.gd`: **56 checks / 0 falhas a 120 Hz e 56 / 0 a 60 Hz**, ambos com exit 0. Os48 anteriores estão preservados; seis adicionais cobrem overshoot e settling contínuo/missing e dois cobrem prioridade de onset explícito/PREHELD. Testes numéricos sintéticos; não são sessões físicas/humanas. Abrangem METRIC_01–05, transforms equivalentes, referência body/COM nomeada, carry translacional/rotacional, prelude/onset explícito, persistência, sinais de trabalho, falta de dados, pés PLANTING versus SLIDING carregado, cache híbrido, contacto versus retenção, timestamp e rings limitados.

Logs iniciais48: `measurement_metrics_120hz.txt`, `measurement_metrics_60hz.txt` nesta pasta. Os finais56 e JSON estão em `warning_cleanup/`, além de `builds/measurement_metrics_<hz>hz.json`. O aviso Windows de store de certificados não altera os resultados; não houve SCRIPT ERROR.

Hashes SHA256 congelados:

- `movement_metrics.gd`: `9d31ab8eff7e80af59a9acf532087708a81a90b98596157c82cc85f41463e783`.
- `test_measurement_metrics.gd`: `c057d792e19538737811abb13a182c7a521be6a1087638623d0f0223cf950a99`.

`warning_cleanup/movement_metrics_before.gd.txt` preserva a fonte48 anterior à correção dos warnings de ternários numérico/null e variável local `load` que ocultava função nativa. Foram usados if explícitos e nome `current_load`, preservando null e as definições anteriores. A extensão overshoot/settling ocorreu a pedido da raiz nesse mesmo checkpoint; não alterou controladores.

Nenhum teste deste acumulador prova comfort, domínio humano, preferência ou autorização para M7. Os thresholds espaciais, ratings e objetivos de curso pertencem ao autor de tarefa, não são inventados pelo acumulador genérico.
