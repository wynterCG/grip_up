# Revisão independente prospetiva PV0 — v1.3.2b

Data: 2026-10-20. Especialista de física/replay. Estado: aprovação condicional do desenho de diagnóstico; **não constitui qualificação nem demonstração causal**. Nenhum motor, ensaio físico, Git, sincronização ou alteração de gameplay foi executado nesta revisão.

## Âmbito e fonte inspecionada

Foi lida integralmente a spec `GRIP_UP_Projection_Viewport_Qualification_Spec_v1_3_2b_EN.md`. A revisão local abrangeu `project.godot`, `grip_targeting.gd`, `grip_up_lab.gd`, `climbing_camera.gd` e a identidade pública da campanha anterior. No momento da inspeção, os 280 ficheiros públicos listados em `builds/eval_virtual_cursor/requal_20261020_r1/source_identity.json` ainda correspondiam ao mirror C. Isto não substitui a verificação de hashes do próximo freeze. O commit de baseline anunciado pelo coordenador é `d87d35c`; não foi executado Git para o verificar.

Valores locais confirmados: viewport lógico 1920×1080, janela override 1440×810, `canvas_items`, aspecto `expand`, renderer `gl_compatibility`, Jolt, interpolação física ligada e configuração normal de 120 Hz. `climbing_camera.gd:24` desliga a interpolação do próprio nó Camera3D; o caminho LIVE continua a seguir o torso interpolado, ao passo que V0 usa a pose global física. Estes dois caminhos não podem ser descritos como a mesma amostragem de câmara.

Permanecem protegidos: perfil 4/A0/B1, massa 12 kg, alcance anatómico existente, 360 N partilhados pelas mãos, 180 N dos pés/120 N por pé, 20 Nm de assistência e 150 Nm combinados. Uma alteração de Window/viewport apenas nesta campanha é uma intervenção de ambiente do ensaio; não autoriza alterar câmara LIVE, geometria, controladores, forças ou contacto.

## Tapes e identidade

É admissível reutilizar as duas tapes legítimas de captura `036a9dc719baef92d9dc41408e20d90ce50bad85`, mantendo **bytes, SHA, frames, referência, captura e identidade do motor originais**. Não devem ser substituídas pelas tapes derivadas `diagnostic_only` de uma campanha anterior.

O novo manifest deve distinguir:

- identidade e SHA do ficheiro original de tape;
- `capture_source_hashes` originais;
- hashes reais do runtime e dos novos observadores;
- delta aprovado por ficheiro, com SHA antigo/novo e descrição estritamente de leitura;
- tamanho solicitado versus tamanho realmente observado, antes da criação do mundo e no picking.

Esta compatibilidade não torna o runtime novo igual ao capturador antigo nem recertifica retroativamente a campanha anterior. Uma divergência de hash não prevista continua a bloquear o ensaio. O resultado pertence a uma nova campanha PV, preservando o NO_GO_INPUT_REPLAY anterior.

## Ponto de autoridade e cobertura mínima

`grip_up_lab.gd:604–637` faz a seleção efetiva no `request_hand`. O hook deve ser adjacente a esta chamada, não à pré-visualização posterior. `grip_targeting.gd:10–25` consulta até sete raios reais em ordem fixa e termina no primeiro collider elegível. Não se deve executar raios adicionais, continuar após o vencedor, mudar máscara/exclusões ou injetar o resultado selecionado.

O audit atual recalcula `project_ray_normal` depois da query (`grip_targeting.gd:16`), enquanto a query foi construída em `:13`. Para a nova evidência, os extremos reais `query.from`/`query.to` e o vetor efetivamente utilizado devem ser registados. A leitura adjacente de local-ray/transform é auxiliar; não deve ser apresentada como se fosse o valor interno já consumido pela primeira chamada. Qualquer pequena reorganização que passe a guardar a primeira chamada precisa constar do delta aprovado e do controlo de não interferência.

Por pick/ray executado, exigir: pixel e offset, ordem, tick/fase, delta real, `Engine.is_in_physics_frame()`, identificação da câmara atual e viewport proprietário, transforms global e `get_camera_transform`, local-ray, origem/world-ray da query, parâmetros de projeção, visible rect, tamanho real, transforms stretch/global-canvas/final, Window/content scale, máscara/exclusões, resultado real, shape, collider estável, transform material, ponto/normal world e local. Valores internos sem API pública devem continuar ausentes com razão explícita; não preencher por reconstrução como se fossem observados.

## Fonte exata do motor e limites da inferência

Foi possível consultar o commit público **exato** `ed1daf0bf001b61586d9930840f2f1394092c079`, correspondente ao hash anunciado do motor, sem recorrer à branch móvel 4.7. Isso fixa o algoritmo publicado, mas não demonstra por si só flags de compilação/precisão do binário instalado.

Em `camera_3d.cpp:247–277,379–425`, a transformação ajusta offsets; a escolha interpolada depende da fase. O local-ray consulta coordenadas e dimensões internas do viewport; o world-ray transforma e normaliza esse vetor. A origem perspetiva deriva da transformação da câmara. Portanto, igualdade de pose global e matriz de projeção publicadas não prova igualdade dos restantes operandos. [Fonte Camera3D fixada](https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf001b61586d9930840f2f1394092c079/scene/3d/camera_3d.cpp).

Em `viewport.cpp:3431–3439`, coordenadas de câmara são calculadas a partir do produto stretch/global-canvas, e o tamanho de câmara usa o membro size. `get_final_transform()` isolado não é prova de igualdade desses valores internos. Uma reconstrução a partir de APIs públicas deve chamar-se `INFERRED_FROM_PINNED_SOURCE`, e não `OBSERVED_INTERNAL_VALUE`. [Fonte Viewport fixada](https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf001b61586d9930840f2f1394092c079/scene/main/viewport.cpp).

Não se recomenda compilar um motor instrumentado nesta fase. Se as APIs públicas não separarem as hipóteses, a conclusão correta pode continuar a ser diagnóstico parcial.

## Plano finito e contagem inequívoca

O plano final confirmado pelo coordenador após esta revisão cabe na spec. A confirmação reutiliza o preliminar como repetição 1 e acrescenta duas repetições novas por célula P2/P3:

| Bloco | Desenho | Pares | Processos físicos |
|---|---|---:|---:|
| Preliminar | P1/P2/P3 × 60/120 Hz | 6 | 12 |
| Confirmação | P2/P3 × 60/120 Hz × 2 repetições novas | 8 | 16 |
| Não interferência | ON/OFF, mesmo modo/Hz/tamanho | 4 | 8 |
| Diagnóstico após hard gate | no máximo quatro processos individuais | — | 4 |
| Máximo normal | sem contar regressões/contratos | 18 | 36 |
| Máximo incluindo diagnósticos | 36 normais + 4 individuais | — | 40 |

Assim, P2/P3 ficam com **n=3 total por modo/Hz/tamanho**, não quatro. Não estão autorizadas novas tentativas ilimitadas. P4 é análise derivada dos mesmos runs P2/P3: não soma processos nem réplicas independentes. Regressões anunciadas de 34 processos/1146 checks e os testes de contrato são uma conta separada. A interpretação inicial desta revisão (três novas repetições, 48 processos máximos) foi substituída explicitamente por este plano menor antes dos ensaios.

P1 compara o ambiente original: headless 1024×576 e rendered 1440×810. P2 iguala ambos ao tamanho pequeno e P3 ao grande, mantendo o lógico 1920×1080. Dentro de cada modo, P2 versus P3 isola a intervenção de tamanho; entre modos continuam possíveis outras diferenças do backend/Window. Só tamanho solicitado igual não basta: tamanho real, rect, escala e fase devem ser verificados. Se o headless não admitir o mesmo estado real, não declarar equivalência.

Para quatro pares observer ON/OFF, é apropriado um tamanho pré-fixado × modos H/R × 60/120. Não comparar H-ON a R-OFF, pois mistura duas variáveis. O controlo OFF pode omitir deliberadamente o novo probe, mas deve conservar o audit mínimo de inputs/contacto/física. A ausência esperada deve ser identificada como controlo sem probe, não PV1 aprovado nem falha inesperada de logger. Confirmar resultados físicos e custos observados; não presumir custo ou efeito zero.

## Interpretação e gates prospetivos

1. Mesmos inputs/câmara, mas local-rays diferentes: localizar primeiro a cadeia coordenadas/dimensões/projeção. Não atribuir automaticamente a Jolt nem apenas ao tamanho da janela.
2. Local-ray igual e world-ray diferente: investigar basis efetiva, fase, offsets e normalização.
3. World-query igual e hit diferente: investigar mundo/query e sincronização; registar miss/face/shape sem os corrigir.
4. Hit world igual mas ponto material diferente: investigar transform material e fase da sua leitura.
5. Âncora idêntica e forças/estado posteriores diferentes: só então há evidência a seguir a jusante na física.

Guardar o primeiro desvio estrito e também a primeira mudança discreta com consequência, como offset vencedor, face, shape, material, seleção, contacto, slip ou retenção. Um primeiro erro de micrómetros não prova sozinho a causa de um contacto que diverge vários ticks depois. A campanha deve conservar ambos os factos, sem tolerância retrospectiva.

Mismatch numérico de ray/projeção pode continuar apenas pela branch diagnóstica previamente autorizada. Falha de identidade/input, clock/fase, ownership da câmara, campos obrigatórios, alteração de fonte, face/collider não seguro ou caps/autoridade mantém hard gate. Após esse gate, só os quatro diagnósticos individuais diretamente relacionados; não completar a matriz como qualificada.

Uma eventual comparação funcional exige raiz causal sustentada, confirmação independente e envelope local pré-declarado. Não está aprovada uma tolerância global, mudança de ray, nova pose capturada, nova geometria ou relaxamento de alcance. Mesmo um GO_LIMITED_PROJECTION não qualifica ranking ML, holdouts, one-hand 60 Hz, lateral/stop, minimização, interrupções arbitrárias ou toda a experiência LIVE.

## Parecer PV0

**Desenho aceitável de forma condicional** à contagem final congelada, rastreabilidade das tapes/deltas, observação no ponto de autoridade e controlos ON/OFF separados. Os ensaios ainda não foram analisados nesta nota; não se emite GO de projeção ou replay. Não foi encontrado motivo para alterar qualquer parâmetro ou mecanismo físico nesta fase.
