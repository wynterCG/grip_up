# GRIP UP — Fiabilidade do avaliador v1.3.1

Revisão de diagnóstico anterior a qualquer nova afinação. A0/B1, física, geometria, pegas e arranque normal ficam preservados. A [spec arquivada](../../../specs/grip_up_v1.3.1.md) define os gates ER0–ER7; um resultado `EVALUATOR_NOT_READY` é permitido quando os dados não sustentam uma certificação.

## Identidade

O [manifesto de preservação](baseline_manifest.json) congela 594 ficheiros históricos e o engine observado. `stage1_r1` e `train_tape_r3` permanecem intactos. Os resultados novos usam diretórios únicos; nenhuma chamada retoma o estudo Optuna anterior. Os holdouts não fornecem resultados para esta revisão.

## Comandos de diagnóstico

Da raiz da cópia de trabalho, com os caminhos locais de `tools/project_config.py`:

```powershell
uv run --frozen --project tools/auto_tuning python tools/auto_tuning/reliability.py --suite baseline --output builds/auto_tuning/reliability_v131/baseline_001
uv run --frozen --project tools/auto_tuning python tools/auto_tuning/reliability.py --suite catch --output builds/auto_tuning/reliability_v131/catch_001
uv run --frozen --project tools/auto_tuning python tools/auto_tuning/reliability.py --suite lateral-stop --output builds/auto_tuning/reliability_v131/lateral_stop_001
uv run --frozen --project tools/auto_tuning python -m unittest discover -s tools/auto_tuning/tests -v
```

`--mode` seleciona `headless`, `rendered_scripted` ou `both`; `--hz` pode repetir 120/60. `--repeats` identifica explicitamente repetições de desenvolvimento ou qualificação. A matriz de catch inclui episódio isolado/sequência, trace OFF e observer antigo OFF como condições distintas. A matriz lateral/stop inclui espelhos e variantes de uma/duas mãos. Não existe seleção de parâmetros ou chamada a Optuna neste comando.

`--suite historical-catch` é uma reprodução separada do driver antigo, usando o worktree `E:\Godot Games\grip_up\builds\reference_v13_reliability` no commit histórico. Exige os 239 hashes públicos e o engine originais. A reconstrução de bytes, normalização de linhas e importação de assets podem produzir um worktree marcado dirty; esse estado é registado, nunca apresentado como checkout limpo. Esta reprodução não tem um rasto antigo de inputs por tick que nunca foi gravado.

O novo driver usa probes ordenadas antes/depois dos callbacks físicos existentes. `post_control` significa depois do controlador e antes da integração seguinte; não significa post-solver. Não se misturam amostras de fases diferentes. O comparador localiza diferenças, mas não inventa uma tolerância física ou certificação de igualdade a partir de diferenças pequenas.

As condições de entrada e os estados de métricas fazem parte do contrato, não de uma tentativa de fazer passar todas as metas. Se não houver uma entrada válida ou o corpo não estabilizar, o resultado tem de o dizer. Ver [migração](migration_from_v13.md).

## Revisões preservadas

`catch_001` parou corretamente na primeira execução renderizada de 60 Hz, por delta físico efetivo incorreto durante o arranque. Os 25 recibos e as sete condições por executar não são uma matriz completa. Ver a [investigação de captura](catch_investigation.md) e o [relatório dessa tentativa](reports/phase_startup_001/comparison.md).

A revisão 3 confirma o relógio em mundo vazio, normaliza a criação dos cenários e exige 0,25 s decorridos na preparação quieta. A repetição usa um diretório novo `catch_002`; não retoma nem reetiqueta a primeira matriz. As revisões anteriores dos catálogos e todos os desenvolvimentos continuam arquivados. A definição de `destination_alone` não exclui pés ou contacto transitório com chão.

As [regressões originais](reliability_regression/attempt_001/results.json) passaram nas 24 execuções a 60/120 Hz, com 884 verificações. Não são evidência de melhor feel nem substituem a qualificação do novo avaliador.
