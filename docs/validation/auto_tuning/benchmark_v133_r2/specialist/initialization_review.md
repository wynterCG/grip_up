# Revisao independente da inicializacao e admissao R2

**Decisao: PASS da correcao de inicializacao e do encaminhamento estatico para a nova campanha.** Isto permite submeter R2 aos seus gates prospetivos; nao qualifica um dominio fisico, uma metrica, um catch novo ou um otimizador. A campanha `benchmark_v133_r1` conserva o seu NO_GO.

Revisao offline do mirror C, em 2026-10-20. Nao executei Godot, Git, sincronizacao, pesquisa de parametros ou ensaios fisicos. A unica escrita desta revisao e este documento. Foram lidos os callers, o helper, os launchers, o plano R2 e os recibos da correcao de admissao; nao se trata de uma nova auditoria integral dos controladores.

## Correcao observada no codigo

- `features/evaluator_virtual_cursor/scripts/benchmark_backing.gd:3`: so o backend headless recebe a atribuicao explicita de `Window.size`. Exige `--backing-size 1024x576` nos argumentos visiveis ao script. Um pedido ausente, malformado ou nao canonico e rejeitado antes da atribuicao. Em rendered, o helper apenas verifica o tamanho real. Depois verifica backing 1024x576 e viewport logico 1920x1080.
- `benchmark_preflight.gd:17`: invoca o helper antes do clock de admissao e antes de criar a camera de observacao. Os dois deltas consecutivos corretos continuam obrigatorios; amostras iniciais com outro delta nao sao omitidas nem aceites como prontidao.
- `benchmark_driver.gd:20`: exige flag explicita de benchmark, campanha com namespace permitido, um cenario conhecido e tamanho de manifest canonico. Invoca o mesmo helper. `virtual_cursor_driver.gd:42` chama esta validacao antes da admissao da tape e antes da entrada no driver que cria o mundo.
- O helper nao modifica corpos, velocidades, forcas, geometrias, camera, conteudo de escala, tuning ou frequencia fisica. A afirmacao `BEFORE_GAMEPLAY_WORLD` depende da ordem dos callers, que foi revista; o helper isolado nao e uma prova generica da ausencia de corpos. O caminho herdado conserva a configuracao de janela preworld e os guards de resize/ambiente durante o episodio.
- `tools/auto_tuning/benchmark_qualification/campaign.py:56` e `tools/benchmark_preflight.py:18` passam `--resolution 1024x576` ao motor e `--backing-size 1024x576` depois de `--`. Assim o pedido nao depende de recuperar uma opcao que Godot ja consumiu.

A mudanca e uma inicializacao explicita do ambiente de teste, nao uma alteracao da autoridade de locomocao. Nao ha relaxamento de colisoes, alcance, budgets ou tolerancias de comparacao nesta correcao.

## Evidencia de admissao ja existente

O relatorio `../../benchmark_v133_headless_init/report.md`, a verificacao e os recibos raw de `builds/eval_virtual_cursor/benchmark_v133_headless_init_r2` referem o source medido `486e03afdb9d169c1d2c7528fbd656660cc3d521`. A leitura dos recibos confirma:

- 12 preflights positivos: H/R x 60/120 Hz x tres processos. Backing e viewport canonicos, dois deltas finais corretos e zero corpos de gameplay.
- Sete assertions de rejeicao/admissao delimitada: um pedido headless errado, dois drivers headless canonicos que param intencionalmente em `TAPE_HASH`, dois pedidos headless sem argumento e dois rendered com tamanho errado. Os pedidos invalidos nao foram corrigidos silenciosamente.
- Os dois checks canonicos que chegam a `TAPE_HASH` demonstram apenas passagem pelo gate de ambiente, nao replay V0, gesto finito, contacto, retencao ou dinamica.
- Nos rendered 60 Hz existem amostras iniciais a 120 Hz antes dos dois deltas corretos a 60 Hz. O handshake continua necessario; nao se pode construir o mundo imediatamente depois de alterar a frequencia.
- O primeiro desenvolvimento falhado, que tentou ler a opcao consumida `--resolution`, esta preservado. As 19 assertions positivas da correcao incluem rejeicoes esperadas; nao sao 19 ambientes aceites nem 19 tarefas fisicas concluidas.

Estes resultados anteriores sao suporte da correcao. Nao substituem o novo BQ1 de R2 nem as seis pairs de referencia BQ2. As 34 regressoes/1146 checks comunicadas pelo root sao validacao separada, nao cobertura dos novos dominios.

## Namespace e limites da repeticao autorizada

`tools/benchmark_repeat.py:14-15,54-59` fixa `campaign.BASE`, `campaign.DOC` e `benchmark_preflight.BASE` nos novos caminhos R2 antes de despachar qualquer etapa. `campaign_id` deriva agora de `BASE.name`. O launcher direto legado conserva defaults R1; a entrada autorizada de R2 e o wrapper novo. Nao usar o launcher legado como se fosse R2.

`prepare()` recusa um destino ja preparado; `freeze()` recusa uma identidade ja existente e exige source limpo, paridade e igualdade com a baseline preparada. Os stages e os caminhos de novas tapes recusam sobrescrita. O plano identifica explicitamente `benchmark_v133_r1_NO_GO_UNCHANGED` e `previous_outcomes_are_not_new_passes=true`.

O plano R2 observado mantem o teto prospetivo de 96: 72 novos processos de dominio incluindo captures adaptivos, 12 referencias, ate 8 negativos e ate 4 diagnosticos pos-hard-stop. As regressoes sao separadas por autorizacao explicita. Os captures adaptivos nao contam como replicas fixas. Foot/stop possuem uma pair fixa por Hz e controlo probe OFF, permanecendo DIAGNOSTIC_ONLY e excluidos de ranking. Os quatro dominios primarios requerem n3 de pairs fixas em ambos Hz e todos os canais obrigatorios exatos.

Nao foram autorizados tuning, holdout, pesquisa, reclassificacao de falhas antigas ou alocacao automatica de budget nao utilizado. Um novo erro de ambiente, input, trace, clock, integridade ou divergencia obrigatoria continua a disparar o hard stop. Um onset legal inexistente continua PRECONDITION_NOT_MET, nao progresso zero nem sucesso fisico.

## Identidade revista e limites do parecer

Baseline preparada R2: `cb46b08c4891fbef1428948e6aab4f6908273df8`; baseline fisica original declarada: `247f19060f7966a8b5fe547cfc5a91e62fa2c2a5`. O manifest preparado lista 293 source hashes, 4378 documentos historicos e 954 ficheiros raw historicos. Sao identidades prospetivas/contagens lidas do manifest, nao uma nova verificacao independente de E.

| Ficheiro revisto | SHA256 |
|---|---|
| `features/evaluator_virtual_cursor/scripts/benchmark_backing.gd` | `ff0aa14fa9654039fe0cb284ee8ad5c0a1c1b88d6705e448d249b9c9f2f1fdc7` |
| `features/evaluator_virtual_cursor/scripts/benchmark_preflight.gd` | `8286dc30a27e017e69b76f93cddc1b1b6adbfcfbe5146e5912a8c335363d748d` |
| `features/evaluator_virtual_cursor/scripts/benchmark_driver.gd` | `9361fcc37521d2561bad283c006a2a0411a28e62320c22be356dcc2a0bfb4b43` |
| `tools/auto_tuning/benchmark_qualification/campaign.py` | `aee9b544e9cf851227cc53f21aa74fdbcfee424a100e46c7e4c212944b0a89f2` |
| `tools/benchmark_preflight.py` | `55c990292bf00b2b40559fd2e1650686e94511ea5c85f3016f7408adc2b233d8` |
| `tools/benchmark_repeat.py` | `429f1c4263928e8d1323e100ca42f6cf77c608109d422e1d2f646dc894f264d8` |
| R2 `run_plan.json` | `87990a644ef943896ce10839925a6b9df42ab5cb504be7b041ba681832d1a62f` |
| R2 `baseline_manifest.json` | `80db7896360164418ebb60581f3b5d7586ee2827cf812d51d89ece988135c9c3` |

Nao encontrei bloqueador estatico na correcao delimitada ou no novo encaminhamento. A aprovacao e de inicializacao/admissao para prosseguir com os gates, condicionada ao freeze e aos novos recibos. A igualdade de projecao, contacto real, retencao, reacoes, caps e elegibilidade de metricas so pode ser decidida a partir dos novos ensaios; este parecer nao antecipa esses resultados.
