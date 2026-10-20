# Stop / brake / reverse e métricas

**Novos domínios de qualificação MISSING_COVERAGE; observações existentes DIAGNOSTIC_ONLY.**
A matriz de controles novos não foi executada por causa da paragem antecipada.
Existem9 controles two-hand release do cenário histórico público, usados como
episódio anterior da sequência catch antes do gate. Esses9, a120Hz, tiveram
recomputação independente a partir do trace POST e comparação com o GDScript
runtime:9/9 pass, diferença permitida de transporte1e-6, sem diferença observada
acima desse limite. Não são uma distribuição R0 de stop ou cobertura60Hz.

| Modo | Hz | Caso de contexto | n | 3D stop path m | Settling s |
|---|---|---|---|---|---|
| headless | 120 | stop_release_v1 | 6 | 0.111254–0.111254 | 1.075–1.075 |
| rendered_scripted | 120 | stop_release_v1 | 3 | 0.111154–0.111239 | 1.075–1.075 |


## Fórmulas e estados

Settling exige norma completa de velocidade≤.10m/s e spin≤.20rad/s por.25s
decorridos. O tempo reportado é o início do intervalo, reconhecido só depois da
confirmação. Zero pode ser uma medição válida; null indica não medido.
Stop path integra a trajetória3D do COM até esse início confirmado, separada
de drift assinado, deslocamento final ou excursão relativamente ao onset.
O zero de referência de overshoot não é um alvo escolhido pelo jogador.

`v132_full_norm_settle_directed_brake_v1` requer COMMON_STATIC_WORLD. Um suporte
móvel/sem frame fica INVALID_MEASUREMENT; não substituímos velocidade desconhecida
porzero. Ground/ownership/âncora perdida/clearance não certificado interrompem a
janela; um milestone anterior válido é preservado, sem crédito após interrupção.

Os novos brake50/10 usam **velocidade dirigida inicial**, apenas durante comando
oposto realmente aceite. A v131 usava norma completa para essas frações; o parser
e os resultados antigos continuam sob o ID antigo. Não se reescreveu a fórmula
histórica nem se tratou settling passivo como sucesso de brake ativo.

Os quatro campos novos nos9 controles de contexto produzem18MEASURED e18NOT_APPLICABLE
(brake não pedido). Os nove campos legacy por cenário produzem72MEASURED e9NOT_APPLICABLE.
Isso não significa que outros estados não existam: PRE/INTERRUPTED/CENSORED/INVALID
são cobertos pelos contratos sintéticos e por recibos de desenvolvimento, mas não
ganham denominadores físicos finais inexistentes.

Um two-hand brake de desenvolvimento120Hz mediu frações dirigidas50% em.191667s
e10% em.241667s, com settling1.416667s e path.274310m. Não foi promovido a
comparador qualificado. Release/brake/reverse/low-energy one-hand60 continuam sem
cobertura. O R0 implementado aceita apenas catch e o seu A_CONTEXT explícito;
fitas R0 de stop/brake/reverse **não foram implementadas/qualificadas nesta entrega**.
Pedidos R0 de outros cenários são recusados, sem fallback silencioso paraA.
