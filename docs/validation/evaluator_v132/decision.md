# GRIP UP v1.3.2 — decisão

**NO_GO / EVALUATOR_NOT_READY.** A qualificação parou no primeiro gate de
fidelidadeR0 rendered; os quatro diagnósticos previstos confirmaram o bloqueio.

- Baseline:0f1a4bf7c6c74c381301475bfcbc18f686e094aa.
- Fonte medida:a06a882bbedbb30c4dd2fe3a795504361eb388de,270 hashes públicos.
- Gameplay A0/B1:sem alterações;815 ficheiros históricos protegidos intactos.
- R0:534 comandos lógicos iguais no primeiro render120, mas cursor13 e ponto
  material55 diferentes. R0completo QUARANTINED; R1 UNSUPPORTED_SEAM.
- A120:12/12 capturas/retenções reais no piloto; DIAGNOSTIC_ONLY, sem envelope contínuo.
- Diagnóstico60:clock correto e alvo numa face diferente; sem contacto direito.
- Uma mão60, novo lateral espelhado e stop/brake/reverseR0: MISSING_COVERAGE.
  Não foram declarados concluídos por testes sintéticos ou desenvolvimento.
- Probes:quatro combinações120 observadas com n1 rendered; diagnóstico apenas.
- Regressões:24 execuções,884checks PASS; Python35novos/75existentes PASS;
  Godot22novos/43existentes checks puros PASS.
- GodotMCPPro:reviewA120 com captura real,2PNG, monitor0; main normal confirmado,
  erros novos0, config reposta byte a byte, profile2/120Hz/A0/bindings originais.
- Benchmark:benchmark_eval_v132 r1; scoring desativado, zero métricas contínuas elegíveis.
- Holdouts:fechados. Random/TPE/CMA/RL/Jev/promotions/M7:zero.
- Feel humano:não avaliado por esta automação.

Nenhuma pesquisa nova é autorizada por esta entrega. A próxima decisão é de produto:
testar o gameplay com pessoas e decidir a prioridade de jogabilidade/M7, ou autorizar
separadamente uma correção pontual do pipeline de input/target e da normalização de
IDs. Não se iniciou outra revisão de fiabilidade nem se mudou a física para obterPASS.
