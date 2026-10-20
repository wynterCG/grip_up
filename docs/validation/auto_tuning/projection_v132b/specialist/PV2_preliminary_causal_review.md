# PV2 — revisão causal preliminar e correção de referências

2026-10-20. Leitura offline dos seis pares preliminares R2, sem motor e sem alterações de fonte. Runtime anunciado: `da7ed73d3cb9832319eda9c78ae6393a01f34f76`. Fontes, repetições e controlos permanecem sob freeze do coordenador. Esta nota analisa **n=1 por célula**; não antecipa a confirmação nem o gate final.

## Correção das referências de fonte do motor

A leitura anterior através do browser devolveu números de linha que não coincidem com os ficheiros brutos arquivados localmente. Não é correto usar aquelas linhas como se tivessem sido verificadas nos bytes fixados. Para esta revisão, os ficheiros locais são a autoridade de referência, e os seus SHA256 foram recalculados independentemente:

| Ficheiro, em `builds/eval_virtual_cursor/projection_v132b_r1/engine_source/` | SHA256 |
|---|---|
| `camera_3d.cpp` | `d0abe5ffd9bd294faf4f965097b06d6132d7e7ac308d6c63baa72b75e3cd7ff6` |
| `viewport.cpp` | `db949779da96c93cbbdd3d97976efe00211fe900ca2e1283d67ce44671c4a652` |
| `window.cpp` | `1e94ba6ccef7fea34b00aab4e40d06730e796471f232d21ced7255d06d45f9fb` |

O manifest `engine_source_identity.json` identifica os downloads no commit `ed1daf0bf001b61586d9930840f2f1394092c079`. As referências corrigidas são:

- Camera3D: transformação ajustada em 266–280; construção de projeção em 282–301; world-ray em 406–409; local-ray em 411–428; origem em 429–456.
- Viewport: `get_final_transform()` em 1391–1394; mapeamento de coordenadas em 3705–3709; dimensões internas em 3711–3714.

Correção de nuance da nota PV0: a fonte local mostra que `get_final_transform()` devolve **o mesmo produto stretch × global-canvas** usado no mapeamento interno de coordenadas. Esse valor público é, portanto, evidência relevante do operador de mapeamento, quando lido na mesma fase. Continua a não ser observação direta do resultado intermédio camera-coordinates, do tamanho interno ou dos arredondamentos de cada operação. Não se deve confundir as duas afirmações.

## Dados preliminares realmente lidos

Artefactos: `builds/eval_virtual_cursor/projection_v132b_r2/comparisons/P{1,2,3}_{60,120}_r1.json`, traces `projection_picks.jsonl`, audits e receipts dos primeiros 12 processos. Para os quatro contrastes P4 foi usado offline o comparador congelado sobre os runs P2/P3 já existentes; não foram criados novos mundos nem réplicas.

| Hz | P1: H pequeno / R grande | P2: ambos pequenos | P3: ambos grandes |
|---:|---|---|---|
| 120 | STRICT_MISMATCH, primeiro local-ray no tick 282 | STRICT_MATCH, incluindo física publicada | STRICT_MATCH, incluindo física publicada |
| 60 | STRICT_MISMATCH, primeiro local-ray no tick 28 | STRICT_MATCH, incluindo física publicada | STRICT_MATCH, incluindo física publicada |

Em ambos os modos, os contrastes dentro do mesmo modo pequeno→grande reproduzem o primeiro desvio P1. Isto é mais informativo do que comparar apenas H pequeno com R grande: o valor acompanha a intervenção de tamanho, não a etiqueta headless/rendered.

No primeiro desvio de 120 Hz, os operandos públicos verificados eram: pixel igual, transformação efetiva de câmara igual, matriz de projeção igual, visible rect lógico 1920×1080 e global-canvas identidade. O tamanho real/publicado era 1024×576 versus 1440×810; stretch/final diagonal era `0.5333333611488342` versus `0.75`. A componente x local era `0.11701402813196182` versus `0.11701391637325287`.

| Hz/tick | Norma Δ local-ray | Norma Δ world-ray | Ângulo entre world-rays | Distância entre pontos materiais |
|---|---:|---:|---:|---:|
| 120 / 282 | 1.1175870895385742e−7 | 1.543187735766767e−7 | 1.0999956027977528e−7 rad | 0.8107108180961278 µm |
| 60 / 28 | 3.725290298461914e−8 | 2.9802322387695312e−8 | 2.9593465797594898e−8 rad | 1.4745374771181323 µm |

120 Hz: P2-R pequeno reproduz exatamente o raio/material de H pequeno; P3-H grande reproduz exatamente R grande. O mesmo padrão foi verificado a 60 Hz. Os pontos materiais continuam estritamente diferentes entre tamanhos; não se aplicou tolerância.

## Consequência física observada

Nos primeiros 12 processos, os receipts reportam contacto real, alvo além do alcance inicial, face inferior esperada e retenção final. Os contactos de 120 Hz ocorrem todos no tick 440. Em 60 Hz, os contactos agrupam-se por tamanho: **pequeno H/R no tick 215; grande H/R no tick 210**. A mudança de cinco ticks acompanha a intervenção de tamanho também dentro de cada modo.

P1-120 publica o primeiro desvio físico no tick 440 e de source-body-pose no tick 443, depois do desvio de seleção no tick 282. P1-60 publica o primeiro desvio de momento no tick 46 e source-body-pose no tick 48, depois do primeiro ray/material diferente no tick 28. A ordem temporal é incompatível com atribuir a primeira diferença observada apenas ao Jolt a jusante, ignorando o picking já diferente. Não é uma prova geral de determinismo Jolt.

## O que já é sustentado e o que falta

Há **evidência causal local de que a intervenção backing-size/scale muda a cadeia de projeção observada nesta tape/câmara**, e evidência preliminar de que igualar o tamanho remove a diferença entre modos nas células medidas. A mudança já aparece no local-ray, antes da transformação pela basis para world-space. O padrão e a fonte são compatíveis com arredondamentos no mapeamento e na normalização local.

Ainda não está observada a operação interna exata que produz o primeiro bit diferente: camera-coordinates e camera-rect internos não têm API pública; os local-rays são leituras adjacentes e os temporários internos da primeira chamada não foram intercetados. Não se afirma que a multiplicação, divisão ou normalização específica esteja isolada, nem que a fórmula manual substitua a API real.

Não há base para declarar os dois tamanhos funcionalmente equivalentes para scoring: mesmo com contactos finais preservados, existe diferença de timing a 60 Hz e dados contínuos diferentes. Nenhuma margem de erro de raio/âncora/COM foi proposta ou aceite. As comparações de tamanho diferente continuam STRICT_MISMATCH e os seus dados contínuos ficam quarentenados.

As repetições n=3 e os controlos ON/OFF ainda precisam da revisão final. Mesmo que passem, o domínio será somente esta configuração, fonte, motor, tape, frequência e fase V0 documentados. Não qualifica modos LIVE, outros viewports, resize durante execução, fronteiras de contacto arbitrárias, one-hand 60 Hz, lateral/stop ou otimização.

**Parecer preliminar:** a ablação responde à hipótese de tamanho com evidência de intervenção, sem necessidade de alterar física ou picking. Ainda não se emite GO final; aguarda-se replicação, controlos, autoridade/caps e preservação dos defaults.
