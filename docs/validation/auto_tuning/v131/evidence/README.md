# Arquivos de evidência

Os ZIP conservam bytes originais, incluindo rastos gzip, falhas e manifestos. Foi verificado `testzip()` e o SHA256 de **cada membro recuperado**, além dos `checksums.json` dos ensaios. Não se apagaram falhas para apresentar apenas passes.

| Arquivo / índice | Conteúdo |
|---|---|
| [archive_index_initial.json](archive_index_initial.json) | Baseline inicial, reprodução histórica de 12 execuções, desenvolvimentos de 2+4+1 execuções e primeira matriz interrompida de 25 |
| [catch_002.zip](catch_002.zip) / [índice](catch_002.archive.json) | 32 execuções qualificadas, 104 linhas de cenário; inclui os sete episódios das sequências |
| [archive_index_controls.json](archive_index_controls.json) | Quatro arquivos de `lateral_stop_001`, separados por modo/Hz: 12 execuções, 144 observações |
| [archive_index_final_smoke.json](archive_index_final_smoke.json) | Segunda auditoria de baseline e demonstração MCP suplementar |
| [source_1b0a862.zip](source_1b0a862.zip) / [índice](source_1b0a862.archive.json) | 239 fontes públicas brutas da reprodução histórica, verificadas contra o manifesto original |
| [source_e13a846.zip](source_e13a846.zip) / [índice](source_e13a846.archive.json) | 254 fontes públicas da primeira matriz, incluindo a falha de arranque |
| [source_24b18d7.zip](source_24b18d7.zip) / [índice](source_24b18d7.archive.json) | 254 fontes públicas exatas da qualificação final |

Os quatro arquivos de controlos repetem os dois pequenos ficheiros de sessão, intencionalmente, para que cada parte mantenha contexto. Os seus hashes coincidem. Nenhum ZIP excede o limite individual de ficheiro do GitHub. Os snapshots de fonte pública não incluem definições privadas de holdout nem o executável/licença do plugin.

Os fontes brutos permitem reconstruir o mapa de hashes apesar da conversão CRLF/LF do Git. Usar um checkout **isolado** do commit indicado, os assets desse checkout e o executável Godot com SHA256 indicado no relatório. Nunca extrair sobre o projeto de trabalho para apagar alterações posteriores. Os caminhos absolutos dos manifestos originais são recibos desta máquina, não parâmetros portáveis a reutilizar sem criar um novo manifesto/diretório.

`stage1_r1` mantém-se no seu [arquivo histórico original](../../evidence/stage1_r1.zip), intocado. Não foi retomado. Os desenvolvimentos não commitados conservam rastos e hashes de proveniência; os snapshots exatos fornecidos aqui correspondem aos três commits identificados, não a uma alegação de reconstrução de todos os estados intermédios de edição.

Os logs iniciais de contratos, incluindo uma asserção de fronteira float32 falhada, ficam em [early_contract_receipts](../development/early_contract_receipts/). As revisões anteriores de catálogo e script de análise continuam em `development/`. A análise final é [control_analysis_002](../reports/control_analysis_002/controls.md); o 001 preserva a rotulagem de onset corrigida, sem alterar recibos físicos ou fórmulas.
