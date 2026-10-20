# Qualificação entre modos e frequências

**NO_GO / EVALUATOR_NOT_READY. Nenhum envelope contínuo aprovado.**

| Célula | Cobertura real antes/depois da paragem | Elegibilidade |
|---|---|---|
| Headless120 | A6, R0 6, referênciaA1 | Diagnóstico positivo; R0 isolado repete534ticks, sequência tem barreira cosmética no comparador |
| Rendered120 | A6; R0 primário1 rejeitado; três toggles diagnósticos | R0QUARANTINED; A DIAGNOSTIC_ONLY |
| Headless60 | ReferênciaA1 | MISSING_COVERAGE para a matriz n3 |
| Rendered60 | Um R0 diagnóstico rejeitado sem contacto direito | QUARANTINED / MISSING_COVERAGE; não é n3 |

NativeMCP_A120 é suplemento com plugin temporário e snapshots PNG; não preenche
uma célula desta matriz nem permite misturar a sua distribuição com a referência.

## O que é igual e o que não foi certificado

Hashes de tape/engine/source e a grade dt/phase são verificados separadamente dos
hashes de comandos aceites. Os três R0 isolados H120 coincidem com a referência
nos534ticks, incluindo native COM/v/spin. Uma repetição exata neste domínio é
evidência local; não estabelece um envelope para rendered,60Hz ou outras tarefas.

Em R0 rendered120 os534 comandos lógicos coincidem, mas cursor13 e materialpoint55
divergem. A equivalência do pipeline completo fica bloqueada; não se publica
SAME_ACCEPTED_COMMANDS_DIFFERENT_NATIVE_RESPONSE como diagnóstico de solver.

## Barreira cosmética de setup

O comparador congelado devolve SETUP_MISMATCH em sequências porque o nome automático
`body.shapes[2].name` muda de `@CollisionShape3D@457` para `@CollisionShape3D@889`.
O especialista verificou offline que, retirando apenas esse nome, os restantes
campos de shapes são exatamente iguais. É uma limitação do comparador, não uma
prova de geometria diferente. A rejeição original foi preservada; o relatório não
reescreve resultados nem altera a normalização depois de observar outcomes.

## Envelopes e incerteza

A prospectiva aprovou apenas identidades e epsilon1e-6 de **localização**, não uma
margem física. n3 por célula é piloto, não garantia de falhas raras. Com gateR0
reprovado e células ausentes, nenhuma faixa COM/velocidade/path/tempo de contacto
pode ser congelada para ranking. Não foi usado um intervalo global15cm nem os
ranges da v131 como tolerâncias. Frequências60/120 não são alinhadas pelo mesmo
tick nem têm de produzir trajetórias idênticas.

Os comparadores de setup/cursor e a cobertura em falta são razões separadas do
estado do controlador jogável. A regraearly-stop foi mantida; não se repetiu uma
matriz inteira para procurar um lote mais favorável.
