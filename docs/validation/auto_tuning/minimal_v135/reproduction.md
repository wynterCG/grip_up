# Reprodução v1.3.5

O projeto guardado é `E:\Godot Games\grip_up`. As execuções desta campanha usam o espelho `C:\Users\Wynter\grip_up`, sem o `override.cfg` local do editor/MCP. O sincronizador verifica os bytes públicos dos dois projetos; o plugin licenciado permanece local e não é incluído na exportação.

O snapshot de medição é guardado em `r4/source_identity.json`, com o arquivo verificável em `r4/evidence/`. Os snapshots R1–R3 e as respetivas falhas continuam preservados. O tag `baseline/pre-v1.3.5-minimal-tuning` identifica a revisão original antes das alterações. Não executar comandos para retomar uma fase física já encerrada nem reutilizar diretórios de resultado.

## Entradas implementadas

```powershell
python tools/minimal_benchmark.py freeze
python tools/minimal_benchmark.py pure
python tools/minimal_benchmark.py --preflight-only
python tools/minimal_benchmark.py --baseline-only
python tools/minimal_benchmark.py quality-freeze
python tools/minimal_benchmark.py negatives
python tools/minimal_benchmark.py gate
```

`freeze` é exclusivo de uma nova campanha: recusa substituir a identidade existente. A admissão usa o manifesto completo Python → JSON → Godot. Os testes de transporte e ambiente criam zero mundos de gameplay; são registados separadamente das tentativas físicas. Qualquer repetição física necessita de um diretório novo e continua a consumir o orçamento declarado; os comandos acima não autorizam uma nova qualificação depois de NO_GO.

Só após um GO ligado ao snapshot, contrato de qualidade, referência e pareceres atuais:

```powershell
& tools/auto_tuning/.venv/Scripts/python.exe tools/minimal_benchmark.py --sensitivity-only
& tools/auto_tuning/.venv/Scripts/python.exe tools/minimal_benchmark.py --random-only --resume
& tools/auto_tuning/.venv/Scripts/python.exe tools/minimal_benchmark.py --tpe-only --resume
& tools/auto_tuning/.venv/Scripts/python.exe tools/minimal_benchmark.py --validate-shortlist
```

`search` sem um limite de fase percorre a sequência condicional completa. O ambiente fixado usa Python 3.13.13 e Optuna 5.0.0. A retoma exige a mesma identidade e recibos completos; trials pendentes ou dados alterados são rejeitados. TPE também exige sinal útil nas propostas anteriores. Os testes unitários usam dados sintéticos e bases SQLite temporárias; não são medições físicas nem um estudo de tuning executado.

## Limites e interpretação

Treino: apenas Vertical Pull e Lateral Right, em FIXED_TAPE a 120 Hz. A baseline de qualificação tem 24 processos novos, a 60/120 Hz, com três pares headless/renderizado por célula. A pesquisa está limitada prospectivamente a oito perturbações, seis propostas aleatórias e quatro propostas TPE, com reserva total máxima de 40 lançamentos. As configurações repetidas ou inválidas ficam no histórico e não são redesenhadas para obter um resultado melhor.

Uma falha de aquisição, onset ou janela não vira progresso zero. O resumo original pode guardar aritmética parcial em `scenario_metrics_raw.json`; a projeção oficial mantém `value: null` quando o estado não é MEASURED e conserva a evidência parcial num campo separado. Torção axial sem referencial válido permanece NOT_APPLICABLE. Velocidade angular total não substitui essa medida.

O finalista máximo é um. A validação primária prevê 48 episódios A0/finalista em 24 processos com dois mundos independentes por processo; exige limpeza e igualdade estrita reais. As capacidades protegidas nunca dão recompensa ao otimizador. A tape independente adicional de travessia direita ficou fora do orçamento após uma tentativa de preflight falhada; não se pode afirmar generalização nesse arranque.

Não há escrita automática em recursos do jogo. Um resultado numérico favorável continua dependente de capacidades protegidas, revisão independente e teste humano combinado separadamente.
