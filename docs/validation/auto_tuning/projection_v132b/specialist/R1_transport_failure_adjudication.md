# Adjudicação independente — falha de transporte R1

2026-10-20. Revisão apenas de fonte e receipts já existentes. Nenhuma execução de motor ou edição de fonte por este especialista.

Foi lido `builds/eval_virtual_cursor/projection_v132b_r1/session_state.json` e o stdout/stderr da tentativa `P1_H_120_r1_ebf4f43f`. Existe uma única tentativa, exit code 1. O stdout contém `Invalid resolution '1024,576', it should be e.g. '1280x720'.` Não existem `engine_result.json` nem `virtual_audit.json`. A falha ocorreu na admissão CLI, sem evidência de criação do mundo ou execução do benchmark. O receipt automático preserva `failed_runtime` pela ausência do resultado; a causa mais específica é o argumento CLI malformado, e não uma falha física ou de qualificação da projeção.

A linha lida em `tools/auto_tuning/virtual_cursor/run.py:95` constrói `--resolution` com `','.join(...)`. A alteração proposta para `'x'.join(...)` só corrige a sintaxe de transporte para o mesmo tamanho solicitado. Não altera tapes, coordenadas, câmara, solver, parâmetros, geometrias ou objetivos. É compatível com Case 1 da spec, mediante novo freeze e novo diretório/campaign R2. Não é admissível retomar R1, apagar o erro, recapturar tapes ou reinterpretar a tentativa falhada como um par PV1 válido.

O orçamento prospetivo revisto é inequívoco: **1 processo R1 falhado + 36 processos normais R2 + no máximo 3 diagnósticos individuais = 40 processos globais**. As regressões continuam separadas. A tentativa pré-boot consome orçamento por decisão conservadora, apesar de não ter criado um mundo.

Na primeira leitura, o guard de `run.py:71` contava 40 por `campaign_id`, e `projection_campaign.py`/plano ainda apontavam R1. Antes de novo freeze, é necessário:

- separar explicitamente OUT e campaign R2, mantendo R1 imutável;
- publicar a sucessão de identidade e o delta de transporte;
- reduzir diagnósticos posteriores para três;
- contar as tentativas R1/R2 no mesmo limite global, em vez de permitir 40 adicionais por cada ID;
- manter o gate de tamanho realmente observado antes do mundo e de cada pick.

**Parecer:** a correção CLI proposta e uma campanha R2 nova são aceitáveis, condicionadas a estes guards e ao freeze correspondente. Isto não emite GO de replay/projeção nem atribui causalidade ao tamanho da janela: nenhum mundo PV produziu dados nesta tentativa R1.
