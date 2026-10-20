# v1.3.1 — contrato prospetivo de métricas de movimento

Estado: implementação Python e testes sintéticos; **não demonstra travagem do jogo**.
Versão da fórmula: `benchmark_eval_v131_stop_v1`. Não é equivalente aos scores ou
ao `overshoot_m` histórico de v1.3. Não executa Optuna, não escreve no jogo e não
abre holdouts.

## API mínima

`tools/auto_tuning/metric_contracts.py` expõe:

```python
analyze(samples: list[dict], contract: dict, transition: dict) -> dict
precondition_outcomes(reason: str, contract: dict, kind: str) -> dict
```

Exemplo de estrutura, sem representar medições reais:

```json
{
  "tick": 0,
  "physics_time_s": 0.0,
  "delta_s": 0.008333333333333333,
  "sample_phase": "post_control",
  "body": {
    "com_m": [0.0, 0.0, 0.0],
    "linear_velocity_m_s": [0.0, 0.0, 0.0],
    "angular_velocity_rad_s": [0.0, 0.0, 0.0]
  },
  "command_accepted": {"intent_world": [0.0, 0.0, 0.0]},
  "support": {
    "valid": true,
    "frame_id": "declared-stable-material-frame",
    "point_m": [0.0, 0.0, 0.0],
    "point_velocity_m_s": [0.0, 0.0, 0.0],
    "angular_velocity_rad_s": [0.0, 0.0, 0.0],
    "grounded": false,
    "hybrid_owned": false
  }
}
```

Os zeros do exemplo são ilustrativos. O adaptador só pode fornecer velocidades
de apoio zero se tiver uma referência estática explícita e verificada. Não se
presume velocidade nula para um apoio móvel ou para múltiplos apoios sem frame
comum. `valid` descreve apoio físico real, não proximidade/IK. O frame pode ser
um ponto material rastreado; uma referência estática comum tem de ser declarada.

`command_accepted.intent_world` é o comando aceite **sem filtro de rampa**, não
a velocidade virtual do motor. Tem de ficar zero quando o neutral foi aceite.

O contrato requer `physics_hz`, `sample_phase`, `direction_world` e `deadline_s`.
Se a fixture falhou a preparação antes de existir um comando aceite, usar
`precondition_outcomes` com a razão real. Não inventar um tick de transição para
obter o estado: o helper devolve pré-condição falhada e preserva os campos não
aplicáveis como tal, sem duração/caminho fictícios.
`deadline_s` é duração depois de `t0`, não tempo absoluto. A transição requer
`kind` (`release`, `brake`, `reverse` ou `none`), `tick` e `physics_time_s` do
comando realmente aceite. Pode incluir `stop_target_progress_m`, relativo ao COM
em `t0`, para medir overshoot espacial depois do pedido de stop.

Campos prospetivos opcionais e defaults:

| Campo | Default | Significado |
|---|---:|---|
| `settle_linear_m_s` | 0,1 | Norma da velocidade relativa máxima |
| `settle_angular_rad_s` | 0,2 | Norma da velocidade angular relativa máxima |
| `settle_hold_s` | 0,25 | Intervalo contínuo de confirmação |
| `reverse_speed_m_s` | 0,02 | Velocidade projetada na direção oposta |
| `reverse_hold_s` | 0,05 | Confirmação contínua da reversão |
| `movement_epsilon_m` | 0,000001 | Caminho mínimo para definir eficiência |
| `intent_epsilon` | 0,000001 | Distingue neutral de comando ativo |
| `time_tolerance_s` | 0,000001 | Tolerância numérica do relógio fixo |
| `min_initial_speed_m_s` | 0 | Pré-condição opcional por fixture; declarar quando necessária |
| `allow_ground` | false | Chão nativo interrompe, salvo controlo separado explícito |
| `require_support` | true | Requer apoio físico |
| `brake_fractions` | [0,5; 0,1] | Frações da norma da velocidade inicial |
| `fixed_horizons_s` | [] | Horizontes explícitos dentro do deadline |
| `stop_target_corridor_m` | 0 | Margem espacial explícita do alvo de stop |

Não foram alteradas as bandas 0,1 / 0,2 / 0,25 para obter resultados medidos.
As condições de entrada de velocidade, suporte e energia de cada fixture são
responsabilidade do seu contrato físico, congelado antes dos resultados.

## Estado tipado e integridade

Cada resultado tem `metric`, `unit`, `status`, `value`, `reason`, duração/caminho
observados e deslocamento parcial com sinal. Só `MEASURED` tem `value` finito.
`CENSORED_TIMEOUT`, `INTERRUPTED`, `PRECONDITION_NOT_MET`,
`INVALID_MEASUREMENT` e `NOT_APPLICABLE` têm `value: null`; não há penalidade nem
conversão implícita para zero. Um zero medido é permitido quando os dados o
demonstram, por exemplo um controlo realmente estacionário depois de confirmar
0,25 s de estabilidade.

O analisador seleciona a fase explicitamente declarada e conta as amostras de
outras fases ignoradas. Não mistura `pre_control` com `post_control`. Na fase
selecionada exige ticks consecutivos, tempo estritamente crescente, delta fixo,
vetores finitos, estado de autoridade e frame material explícito. O tick/tempo
de transição tem de existir exatamente dentro da tolerância. Buracos, duplicados,
NaN/Inf, fase em falta e referências incompletas são erros de medição.

Uma mudança real de frame material, perda de apoio, contacto com chão proibido,
mudança para híbrido ou interrupção explícita termina a janela. O evento inclui
tick e tempo; o caminho parcial termina na última amostra válida anterior ao
evento. Uma métrica já confirmada antes desse evento mantém `MEASURED`; os
horizontes posteriores ficam interrompidos. Um rasto terminado antes do deadline
sem evento explícito não simula um timeout válido: as métricas não confirmadas
ficam `INVALID_MEASUREMENT` com `TRACE_ENDED_BEFORE_DECLARED_DEADLINE`.

## Fórmulas e janelas

O eixo mundial unitário é fixado em `t0`. As posições relativas são
`COM_world - material_point_world`; as velocidades são diferenças entre corpo e
apoio material. Não se roda o eixo continuamente com o corpo. O caminho é a soma
das normas 3D dos incrementos de posição relativa; progresso é a projeção com
sinal desde a posição relativa inicial. Não se interpola um evento entre ticks.

| Resultado | Definição |
|---|---|
| `settling_time_s` | Início da primeira janela que satisfaz ambas as bandas durante 0,25 s. `confirmation_time_s` regista separadamente o fim observado dessa janela. |
| `stop_distance_m` | Caminho 3D entre `t0` aceite e a **confirmação** do settling. Só se aplica a release/brake. |
| `release_signed_drift_m` | Projeção com sinal entre neutral aceite e settling confirmado. |
| `release_absolute_directional_drift_m` | Soma dos módulos dos incrementos projetados no eixo, até confirmação. |
| `release_path_length_m` | Caminho 3D até confirmação; não é o módulo do deslocamento final. |
| `reversal_time_s` | Início da primeira janela de velocidade ≥0,02 m/s na direção do novo comando aceite, mantida por 0,05 s. Mede desde o comando oposto aceite; a confirmação tem campo próprio. |
| `post_stop_overshoot_m` | Máxima excursão além do alvo/corredor espacial, usando apenas amostras desde `t0` de stop até confirmação. Não inclui o percurso anterior sob comando mantido. |
| `useful_progress_m` | Projeção final no deadline declarado, sem clamp de valores negativos. |
| `directional_efficiency` | Progresso com sinal / caminho 3D, apenas acima do epsilon; caso contrário `UNDEFINED_NO_MOVEMENT`. |

Se settling não acontecer até ao deadline, as métricas de stop/drift dependentes
da confirmação são censuradas; o deslocamento, caminho e excursão parcial
continuam explícitos em `observed_*`. Não se apresenta essa observação parcial
como distância final de paragem.

Brake/reverse exigem que a velocidade inicial se oponha ao comando realmente
aceite. O eixo de reversão é esse comando normalizado em `t0`, registado em
`accepted_effort_direction_world_at_onset`; o eixo de progresso do contrato fica
separado e fixo. Assim, um balanço inicial negativo pode inverter para um comando
positivo, e o espelho também é válido, sem trocar sinais silenciosamente.

`active_braking` contém um objeto por fração, com tempo e distância tipados. Mede
a primeira amostra cuja norma de velocidade relativa atravessa essa fração da
velocidade inicial enquanto vigora o comando oposto. A amostra na passagem para
neutral é o limite inclusivo: o seu corpo observado ainda contém a integração
anterior sob comando oposto. Uma fração não alcançada antes desse limite fica
`INTERRUPTED`, com o evento `OPPOSITE_COMMAND_WINDOW_ENDED`. O simples botão
oposto não prova trabalho negativo nem remoção causal de energia; esse trabalho
é uma observação física separada.

Um brake pode terminar em neutral e continuar a observar settling. Novo comando
depois de release, fim de reverse antes da confirmação ou reativação do brake
depois de neutral interrompem a tarefa correspondente. Reverse não é um pedido
de paragem: os seus campos de stop ficam `NOT_APPLICABLE`.

`fixed_horizons` mantém progresso medido em tempos físicos prospetivos mesmo
quando o stop é censurado. Cada horizonte tem de cair numa amostra da grelha;
o código não inventa uma posição interpolada. Em 60/120 Hz deve usar-se o mesmo
tempo representável nas duas grelhas, e não o mesmo número de ticks.

## Validação sintética

```powershell
uv run --frozen --project tools/auto_tuning python -m unittest discover -s tools/auto_tuning/tests -p test_metric_status.py -v
```

27 testes passaram: onset aceite, desaceleração monotónica, oscilação amortecida,
chatter, settling temporário e sustentado, bandas angulares, zero medido legítimo,
frações de brake, reversão persistente, censura, interrupções e pré-condições,
frame móvel explícito, ausência de frame, NaN/Inf, relógio/delta/ticks/fase,
horizontes e tempos de confirmação a 60/120 Hz. São construções sintéticas com
valores conhecidos, não jogadores nem resultados do Godot. O controlo físico de
baixa energia e os episódios reais nas duas frequências ainda têm de validar o
pipeline antes de afirmar ER4 concluído.

## Auditoria da integração em desenvolvimento

O recibo `development_lateral_stop_001` usa o contrato de desenvolvimento de
revisão 1; não constitui qualificação do contrato de revisão 2. A revisão 2
exige preparação do stop fora da banda de settling e controlo de baixa energia
pela norma completa da velocidade relativa. Não se devem reinterpretar os
recibos antigos com o catálogo atual nem misturar as duas distribuições.

Uma verificação independente das amostras desse recibo reproduziu as seis
distâncias de stop medidas, com erro numérico máximo de 5,6e-17 m. Todas as
confirmações respetivas abrangem 0,25 s físicos e respeitam ambas as bandas.
Isto valida a aplicação das fórmulas àquele registo, sem estabelecer repetição,
equivalência entre modos ou aceitação do benchmark completo.

Nesse desenvolvimento, ambos os brakes terminaram a janela ativa de 0,5 s sem
atingir as frações pedidas: os tempos/distâncias dessas frações ficam
`INTERRUPTED`, embora possa existir settling posterior. Em três episódios,
uma reversão medida precede contacto com o chão; a reversão conserva o seu
valor, mas progresso final e sucesso da tarefa inteira não ficam confirmados.
Todos os controlos clean, release, brake e low-energy tinham pés carregados
durante a observação. Uma só mão agarrada não demonstra suspensão só pelos
braços nem separa causalmente a contribuição dos pés.

A elegibilidade deve ser conferida também na amostra do comando aceite: há uma
fronteira de um tick depois da preparação. O mínimo de movimento do analisador
protege o stop; a qualificação de baixa energia exige verificar explicitamente
velocidade completa e velocidade angular nessa amostra. Preparação baseada em
contar N amostras consecutivas abrange N-1 intervalos; não equivale por si só a
0,25 s decorridos. O detetor de settling usa tempo físico decorrido.

Na revisão 2, o alvo espacial de overshoot é o COM no onset aceite, declarado
como referência de medição com progresso zero. Não representa um alvo pedido
pelo jogador nem uma alteração do controlador. Valores de overshoot têm de
manter esta definição explícita ao serem comparados.
