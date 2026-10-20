# R3 — decisão final

```text
preflight_status: CERTIFIED
primary_qualification_status: NO_GO_BENCHMARK
optimization_permitted: false
```

As quatro células PC2 e seis pares primários de Swing & Catch passaram. As 34 regressões/1.146 checks passaram. Os domínios obrigatórios não qualificam em ambos Hz: vertical e assimétrico sem cobertura válida; laterais 120 úteis, mas 60 interrompidas por mudança de suporte. Foot-step sem onset; stop120 medido apenas n1 e stop60 interrompido. Nenhum domínio elegível para ranking.

O negativo `swing_catch_train_120_headless_r1_e0310d17` acionou hard stop com `MISSING_REAL_PICK_RECORDS`: contagem de quatro entradas lógicas, incluindo a sentinel de mira inválida no tick1, contra três queries reais. A causa foi identificada offline; o recibo continua RUN_INVALID e não houve reparação da fonte congelada.

Contas finais: preflight físico4/12; primário61/96=12referências+48domínios+1negativo+0diagnósticos; regressões34 separadas. As cinco execuções de controlo restantes registadas não foram executadas após a falha. Fontes protegidas, LIVE e release preservados nas verificações descritas. Sem avaliação humana de feel, ML/Optuna/RL/Jev ou M7.

Revisão futura exige nova fonte certificada e nova autorização de campanha. Esta R3 está fechada. Consulte o [relatório completo](result_report.md), a [decisão por célula](domain_eligibility.json) e os pareceres independentes em `specialist/`.
