# Swing & Catch — replay e robustez

**Resultado: R0 QUARANTINED; A DIAGNOSTIC_ONLY; decisão global NO_GO.**
Foram executados 19 dos 48 processos primários previstos. Os primeiros18 terminaram
sem rejeição de integridade. O19.º terminou no motor, adquiriu o destino e reteve-o,
mas foi rejeitado pelo validador de fidelidade do cursor. A matriz parou nesse ponto;
os29 processos restantes não foram usados para acumular resultados positivos.
Só seguiram os quatro diagnósticos do gate previstos no orçamento.

## Referências e significado da captura

As primeiras referências headless A0/B1, sem seleção best-of, passaram a120 e60Hz.
Contacto direito:438/213; origem FREE:453/221; primeira confirmação de .6s com a
mesma âncora e origem livre:525/257. Distância ao alvo no pedido:.811911/.805061m,
alcance anatómico:.65708m. O destino correto é o collider `catch`, com carga real
admitida e retenção ainda válida no fim. Não se reaproveitou ATTACHED como comando.

Os episódios completos incluem ground e B1:163/97 ticks grounded e26/24 ticks com
pelo menos um pé carregado nas referências120/60. Estas contagens incluem preparação;
não localizam, por si, ground no instante de captura. Nenhum resultado é arm-only.

## Matriz executada e ausências

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


A120 teve6/6 contactos e retenções em headless e6/6 em rendered, divididos entre
isolado e sequência, n3 por célula. São resultados da mesma política adaptativa
versionada, não uma certificação de comandos ou trajetórias iguais. O R0 headless120
teve6/6 capturas; os três isolados coincidiram com a referência nos534ticks de inputs
aceites e estado nativo. Na sequência, o comparador congelado recusou o setup por
um nome automático de shape; o detalhe está no relatório cross-mode.

## Primeira rejeição R0 renderizada

Run `catch_rendered_scripted_120_R0_isolated_r1_t1o1_b1fa9d76`:

- Tick13: pedido `[0,0]`; cursor observado `[960,540]`, viewport1920×1080, sem gesto
  pedido nesse tick. A fidelidade completa termina antes desse desvio. Isto não
  demonstra uma emissão perdida: não havia evento pedido para emitir nesse tick.
- Todos os534 comandos locomotores/holds/owner/blocked aceites coincidem com a
  referência. Esse hash igual não prova o mesmo estado de cursor ou contacto.
- Tick55: primeiro alvo material no collider `source` difere1.256634mm. A fita
  envia píxeis pelo Input normal e a câmara corrente faz o raycast; não corrigimos
  a mira para forçar o ponto histórico.
- Primeiras diferenças nativas acima do epsilon de localização1e-6: spin92,
  velocidade94, COM125. O contacto diferente antecede-as; não há prova de causa única.
- Contacto direito439, origem FREE453, retenção525. O motor devolveu `completed`;
  o transporte `failed_runtime / REQUEST_MISMATCH:EMITTED_CURSOR` é uma rejeição
  de fidelidade, não um crash do motor nem uma violação física.

Há ainda uma diferença de cerca de um ULP float32 entre coordenadas do gesto e
cursor observado no primeiro gesto. Não se aumentou a tolerância para aprovar.

## Diagnósticos após a paragem

| Diagnóstico | Hz | 1.º cursor diferente | Prefixo lógico aceite | 1.º alvo diferente |
|---|---|---|---|---|
| direct_input_diagnostic_1_rendered_120_t0o1 | 120 | 13 | 534 | 55 |
| direct_input_diagnostic_2_rendered_120_t1o0 | 120 | 13 | 534 | 55 |
| direct_input_diagnostic_3_rendered_120_t0o0 | 120 | 13 | 534 | 55 |
| direct_input_diagnostic_4_rendered_60_t1o1 | 60 | 14 | 261 | 28 |


Os três toggles120 conservaram contacto/retenção, com contacto437/438/437 e
retenção525, mas todos reprovaram a fidelidade no tick13. No diagnóstico60 o
desvio inicial surge14; o pedido direito142 seleciona a face frontal+Z de `catch`,
enquanto a referência seleciona a face inferior−Y. A distância material é109.669mm.
Não houve contacto direito; o estado REACHING não adquiriu força. A libertação da
origem foi apenas a ação agendada na fita, não uma transferência bem-sucedida.

Não se atribui o miss exclusivamente ao cursor, ao Jolt, à frequência ou ao custo
do recorder. A transição histórica profile2 capturado→profile4 visível é uma
hipótese de origem do cursor central, sustentada pelo código, sem identificação
do evento de origem. Os dados não qualificam equivalência física após o desvio.
