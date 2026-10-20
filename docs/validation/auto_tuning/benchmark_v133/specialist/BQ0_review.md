# BQ0 — auditoria independente de física e reuso v1.3.3

2026-10-20. Foi lida integralmente `GRIP_UP_Auto_Tuning_Benchmark_Qualification_Spec_v1_3_3_EN.md`. Revisão estática no mirror C, sem Godot, testes, Git, acesso a E, sincronização, tuning ou resultados privados. O coordenador confirmou a criação do baseline antes da escrita desta nota.

**Parecer prospetivo:** a fronteira de auditoria e o reuso mínimo abaixo são adequados. Isto aprova o desenho técnico a preparar, não os gates BQ0–BQ7 como já passados. Nenhum novo domínio é considerado qualificável só pelo nome ou pelo histórico de uma suite antiga.

## 1. Identidade e valores efetivos

Foi lido `docs/validation/auto_tuning/benchmark_v133/baseline_manifest.json`: baseline `247f19060f7966a8b5fe547cfc5a91e62fa2c2a5`, engine `4.7.2.stable.steam.ed1daf0bf`, SHA256 do binário `12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38`. A varredura própria dos 285 hashes de fonte do manifest encontrou correspondência em todos os ficheiros do C no momento da revisão. O manifest inventaria 4249 ficheiros de evidência anterior e 749 raw; estas duas contagens são do manifest/coordenador, não novas execuções deste especialista.

Os valores efetivos encontram-se no perfil bípede e no recurso base herdado, não nos defaults do antigo robô:

| Quantidade | Fonte | Valor preservado |
|---|---|---:|
| Massa | `features/grip_up/resources/biped_tuning.gd:4` | 12 kg |
| Alcance ombro→palma | mesmo ficheiro, 22–23/40 | 0.54708 + 0.11 = 0.65708 m |
| Rest length máxima/mínima e elasticidade | mesmo ficheiro, 39–42 | 0.62 / 0.18 / 0.04 m |
| Rigidez/damping radial | mesmo ficheiro, 43–44 | 6000 N/m / 220 Ns/m |
| Gesto da mão | mesmo ficheiro, 48 | 4 m/s relativo ao workspace, com transporte/sweep já existente |
| Mãos, força partilhada | `features/grip_up/resources/climbing_tuning.gd:53` | 360 N |
| Momento combinado / assistência | mesmo ficheiro, 55/78 | 150 / 20 Nm |
| Traversal speed/ramp/rate/accel | mesmo ficheiro, 89–96 | 0.25 m/s / 0.12 s / 0.24 m/s / 0.9 m/s² |
| Pés total / um pé / atrito | `features/grip_up/resources/foot_tuning.gd:3–4,12` | 180 N / 120 N / 0.85 |

Cada run novo deve continuar a observar estes valores no runtime, juntamente com A0/B1, perfil 4 e ownership. O startup normal continua perfil 2/LIVE. O facto de serem constantes na fonte não substitui verificar o recurso real usado por cada cena. `features/evaluator_reliability/scripts/baseline_lab.gd` já verifica o Resource original sem instalar duplicados/overrides; é preferível reutilizar essa fábrica.

## 2. Inventário de fixtures reais

### Arenas originais de intenção

`features/grip_up/scripts/intent_test_level.gd` implementa Step/Hang/Traverse/Corner. Step usa parede frontal z=0, duas escolhas iniciais ±0.24/y2.10 e lip real centrada em y0.51, tamanho 0.95×0.16×0.22 m. O topo da lip é y0.59 e termina em z0.11, atrás do lower proxy do corpo. O chão é largo e nativo; não é um fixture de suspensão só porque existem mãos ATTACHED.

Traverse usa a mesma parede, chão largo e quatro footholds. Pode servir para uma puxada assimétrica ou contexto de aquisição; os seus clean/counter windows exigem observar eventual contacto com o chão. A geometria antiga não pode ser declarada equivalente ao fixture de clearance mais recente. Hang e Mastery C têm suportes inferiores e uma plataforma inicial: devem continuar a reportar contribuição real de chão/pés, como mostrou a campanha anterior.

### Fixture simétrico v1.3.2

`features/evaluator_qualification/fixtures/qualification_fixture.gd:10–41` é a opção mínima para novas medições L/R/stop. `apply` exige controller step/time zero, velocidades zero ainda não avançadas, mãos FREE, nenhuma assistência/freeze e spawn já igual ao arena 8. Retira o nível antigo sincronicamente e constrói o novo sem atribuir posição ou velocidade ao corpo.

O registro público `features/evaluator_qualification/resources/fixture_registry_v132_r1.json` fornece `symmetric_clearance_r1`: parede x±2.4, face z0; spawn (0,1.17,0.4); contactos (±0.24,2.10,0); yaw inicial 0; startpad x±0.24; safety-floor com topo −1.25; footholds em x±0.15/±0.45, topo y0.59. Não é necessário inventar nova geometria para obter uma primeira tentativa simétrica.

`audit_clearance` em `qualification_fixture.gd:43–90` usa os proxies reais com queries conservadoras contra **layer 1, chão/startpad**. Inclui cast translacional, bound de rotação e overlap no fim. Não certifica toda a parede/footholds nem todo o futuro percurso. Possível interseção é conservadora; não é motivo para corrigir o corpo. O buffer de contactos nativo pode ser incompleto/saturado: ausência de pares reportados não prova ausência de colisão.

### Mastery e risco de copiar um reset

`features/locomotion_test_suite/resources/mastery_course_r1.json` contém geometrias públicas M-A/M-B/M-C e objetivos de gameplay. São bons dados de referência, mas esses objetivos não substituem contratos de onset e métricas técnicas.

**Cuidado concreto:** `mastery_course.gd:60–90`, `apply_segment`, abre uma arena e depois escreve `torso.global_position`, `linear_velocity=ZERO`, `angular_velocity=ZERO` e reseta interpolação. É o reset histórico explícito, fora da medição. Não se deve copiar esta chamada como preparação de um novo benchmark e descrevê-lo como «sem body writes». Para novos domínios, reutilizar apenas a geometria/construção ou `qualification_fixture.apply` no spawn original. As tapes catch já qualificadas mantêm o seu contexto histórico e não são reescritas por esta observação.

## 3. Subset mínimo recomendado

| Domínio | Reuso mínimo | Certificado e limites |
|---|---|---|
| Vertical | Parede real Step ou parede simétrica já existente; duas seleções finitas | Duas mãos ATTACHED válidas, carga e comprimentos reais; direção UP fixa. Declarar B1 e eventual chão. Não rotular como hand-only. |
| Assimétrico | Parede existente, contactos em alturas diferentes já declarados no v1.3 (`contact_y_offsets=[0,-0.12]`) | Não mudar holds/colliders. Guardar âncoras reais selecionadas/resolvidas, spin e carga por mão; signed progress UP. |
| Lateral esquerda/direita | `symmetric_clearance_r1`, duas mãos, mesma geometria e yaw 0 | Espelhar mão/ordem de aquisição e A/D, não só trocar o sinal do resultado. Exigir nenhum chão/ground motor durante janela válida; B1 continua contabilizado. |
| Foot-supported step | Step original, lip real e B1 ON | Pé SUPPORTING/SLIDING carregado, normal/força/contacto real e mãos reais. Medir progresso e transferência; PLANTING/visual não contam como carga. |
| Two-hand release-stop | Mesmo fixture simétrico e prep de duas mãos já existente | Gerar velocidade por input, manter os dois grips ao neutralizar a direção. Não confundir release do comando com soltar ambas as mãos. |

Isto recomenda entradas de geometria e semântica, **não promete que todos os onsets ou objetivos sejam atingíveis**. Se a baseline não atingir o certificado no tempo máximo, o resultado correto é PRECONDITION_NOT_MET/DIAGNOSTIC_ONLY, sem tentar variantes até aparecer um número favorável.

Para vertical, não reutilizar indiscriminadamente o W de preparação de 1.5–2.5 s dos estudos de swing. Essa preparação pode consumir a contração disponível antes do onset e produzir um teste de equilíbrio/saturação em vez de resposta vertical. O catálogo novo deve declarar preparação finita antes dos resultados e guardar rest/current/min/max, carga, progresso já obtido e velocidade no onset. Não se autoriza repor comprimentos ou zerar velocidade para fabricar curso.

Para o espelho, `symmetric_clearance_r1` é simétrico, mas uma aquisição esquerda→direita em ambos os lados não é uma preparação espelhada. Trocar a ordem e os IDs físicos, além de A/D e as coordenadas X, mantendo uma orientação/câmara coerente e sem escala negativa dos bodies. Se o estado inicial real não for o espelho esperado, registar a diferença; não corrigi-lo em execução.

Counter-swing e one-hand 60 Hz continuam fora do subset primário. O registro de preparações v1.3.2 tem três scripts finitos úteis para diagnóstico, mas não há autorização para escolher retrospectivamente o que pontua melhor nem promover os antigos screens como qualificação nova.

## 4. Preparação, fase e input a reutilizar

`reliability_driver.gd:311–341` já contém os critérios de referência:

- clean lateral: |v·eixo| ≤0.10 m/s e |omega| ≤0.20 rad/s durante **0.25 s decorridos**, máximo 5 s; não são N amostras que abrangem N−1 intervalos;
- low-energy: norma completa da velocidade relativa ≤0.10, não só componente lateral;
- stop/brake: velocidade dirigida [0.15,0.50] m/s, gerada por input em até 2 s;
- counter separado: velocidade dirigida oposta [−0.50,−0.02] m/s;
- todos revalidados no tick de input **aceite**, com apoio real e sem força/momento de ground motor indevido.

O clean lateral é quietude lateral e angular, não quietude 3D garantida: preservar velocidade vertical/profundidade no certificado. Pé B1 carregado pode ser apoio legítimo sem chão nativo; isso não torna o ensaio arms-only. O `_valid_support` herdado conta mãos ATTACHED/carga, e o v1.3.2 reforça clearance e contagem no onset. Guardar cargas por mão evita alegar partilha equivalente quando uma mão está quase sem tensão.

O caminho antigo `optimization_trial_driver.gd:87–127` usa `Input.action_*`, `Input.parse_input_event` e espera `physics_frame`. Não é o contrato V0 recente. Não criar uma segunda implementação de replay a partir dele. O novo wrapper deve reutilizar o provider V0, request_hand real, picks e CaptureEvaluator existentes, mantendo o scheduler PRE/POST qualificado.

Existe um guard concreto em `virtual_cursor_driver.gd:33–46`: apenas `swing_catch_train` e a identidade de benchmark antiga são admitidos. `_fresh` também constrói Mastery C. Novos domínios necessitam de uma extensão de infra explicitamente versionada; mudar só os nomes no manifest não os torna suportados. O driver novo deve distinguir captura/adaptive setup de replay fixo e não alterar silenciosamente esse guard histórico.

A captura pode usar uma política limitada para obter o onset; o replay fixo reproduz os comandos/ticks capturados. Não voltar a esperar por uma janela de estado dentro do replay e continuar a chamar-lhe input fixo. Certificar o onset real no replay e rejeitar a célula se já não for elegível. Guardar requested/emitted/accepted/applied separadamente.

## 5. Leitura de estado, forças e métricas

`physics_snapshot.gd:20` lê COM por direct-state (`transform.origin + center_of_mass`), pose, v/omega e contactos. `_post_tick` do driver em `:117` observa após callbacks de controlo e antes da próxima integração. É **POST_CONTROL_BEFORE_NEXT_INTEGRATION**, não prova de uma nova solução Jolt causada pelo input que acabou de ser aceite. A latência deve respeitar essa fase real e não subtrair um tick para parecer mais rápida.

O mesmo reader classifica um pé como carregado apenas em SUPPORTING/SLIDING com força >1 N e suporte válido. O coordenador legado só usa SUPPORTING para certas decisões; isso é mecanismo existente, não autorização para omitir a força de SLIDING no audit nem para corrigir o controlador nesta campanha. Pending selecionado pode ter um target/support material no trace, mas não é apoio carregado nem fonte de força.

Para os suportes estáticos destes domínios há um referencial comum exato; zeros de velocidade são legítimos quando provêm desse contrato, não quando faltam dados. Moving-platform/effective-mass e reação dinâmica continuam fora do subset principal. Os testes antigos de pares reativos são preservação de mecanismo, não cobertura nova de moving-platform.

O módulo Python existente `tools/auto_tuning/metric_contracts.py` já separa MEASURED/CENSORED/INTERRUPTED/PRECONDITION/INVALID/NOT_APPLICABLE. Reutilizar esta semântica e a análise de reversal/brake, em vez de um segundo detector. Não transformar null em zero. A perda de apoio posterior não apaga uma reversão já confirmada; a desaceleração depois de terminar o comando oposto não conta como active brake.

Interpretações físicas a preservar:

- Progresso é COM real projetado numa direção congelada no onset, não movimento do target virtual. Negativo permanece negativo.
- Stop path integra a trajetória 3D depois do comando aceite; distância final ao ponto de partida não é path. Overshoot começa no release/target declarado, não penaliza a fase voluntária anterior.
- Twist axial e oscilação pendular não são a mesma variável. Não penalizar toda a rotação como má qualidade.
- Foot load contribution precisa de forças reais e janela definida. Uma razão entre módulos de mãos/pés é uma fração de esforço desses atuadores, não automaticamente uma fração do peso total suportado; chão nativo deve continuar explícito.
- Trabalho parcial só com força aplicada e velocidade real no ponto de aplicação. Pode ser reconstruída de v/omega/COM/contact-point na mesma fase; `force.dot(COM_velocity)` isolado ignora o termo angular. Sem esses dados, trabalho é null, não zero nem custo metabólico.
- Mão em REACHING/pending/FREE não pode receber crédito de força/contacto; retenção é mesma âncora após contacto e carga reais, não nova seleção nem soma de cadeias diferentes.

## 6. Ambiente e comparações

1024×576 efetivo/1920×1080 lógico, mesmo Hz, engine e fase verificados constituem a configuração primária. A última campanha mediu headless screen −1/mode 1 e rendered pequeno screen 0/mode 0/DPI120/scale1.0; não assumir que a CLI força esse screen em qualquer run. Não misturar 1440×810 como dados de score. Tamanho e câmara reais são guardados antes do mundo e no pick, com pixel válido (0,0) preservado.

Os contratos de clock, retirada síncrona dos mundos antigos e boundary post_completed já existem no driver de reliability. Reutilizá-los sem descartar ticks divergentes depois de o mundo existir. Um preflight sem RigidBody não prova um onset ou um domínio físico; comprova só ambiente.

Para declarar STRICT_MATCH num domínio novo, o comparador deve incluir todos os seus canais obrigatórios: pés, chão/autoridade, comprimentos atual/rest, estado/âncora/carga, COM/pose/v/omega e budgets, além do picking. A camada física antiga de `layered_comparison.py` não cobre sozinha todos os campos de pé/onset/target-length agora exigidos. Estender a comparação de infra versionada, sem dizer que a prova antiga já os certificava.

Repetições baseline iguais medem repetibilidade local. Não provam seeds, hardware, novos pixels, offsets 1–6, poses ou candidatos de tuning. Futuramente, candidato versus baseline pode legitimamente ter física diferente; a comparação estrita é entre repetições **do mesmo candidato**, ambiente e input. Um resultado diferente do A0 não é automaticamente uma violação, e uma melhoria num cenário não pode compensar a falta do pior domínio.

## 7. Orçamento antes de qualquer matriz

O teto literal da spec é 96 processos físicos: 72 domínio +12 catch +8 negativos +4 diagnósticos. Capturas adicionais não são gratuitas. BQ1 pode usar checks de ambiente sem RigidBody separados, identificados como tal; não contam como tarefas concluídas.

O coordenador propôs, antes de resultados novos:

- quatro domínios primários: 8 capturas (4×2 Hz) +48 replays fixos (4×2 Hz×2 modos×3) =56 processos;
- foot-step e stop: 16 processos adicionais de captura/pares/controlos =72 novos;
- catch preservado: 12; negativos até8; diagnósticos até4, total máximo96 antes de considerar as regressões pedidas separadamente.

É honesto **não contar a captura adaptiva como uma repetição de replay fixo**. Contudo, os 16 processos restantes não estabelecem automaticamente n=3 por modo/Hz de foot-step/stop. Esses domínios devem ficar DIAGNOSTIC_ONLY ou ser explicitamente excluídos da elegibilidade, com consequências, se não tiverem a matriz requerida. Não promover um controlo como réplica independente de uma célula.

A interpretação de o teto incluir ou excluir os 34 processos de regressão foi enviada pelo coordenador ao utilizador e está pendente nesta nota. Não se assume autorização extra. A decisão e o plano final devem reconciliar todas as contagens antes do freeze, sem retry oculto nem ultrapassar o teto. Se o teto impedir cobertura, usar MISSING_COVERAGE, não reduzir o denominador silenciosamente.

## 8. Recomendações por domínio e gate BQ0

| Domínio | Parecer estático | Estado de qualificação nesta nota |
|---|---|---|
| Vertical | PASS do reuso proposto, onset/carga/curso por validar | PENDING / não medido |
| Assimétrico | PASS do reuso de parede e seleções, sem mudar geometria | PENDING / não medido |
| Lateral L/R | PASS condicional ao fixture simétrico, espelho real e ausência de ground authority | PENDING / não medido |
| Foot-step | PASS do fixture; PARTIAL da prova sem planta/carga/work reais e réplica suficiente | PENDING / não medido |
| Two-hand release-stop | PASS do mecanismo de prep/detector a reutilizar; PARTIAL até onset, censura e repeatability válidos | PENDING / não medido |
| One-hand 60 / counter / moving / offsets novos | MISSING_COVERAGE; não expandir automaticamente | Fora do subset limitado |
| First Ascent | Validação de integração apenas, intervalo hybrid separado | Não é fitness de escalada física pura |

**BQ0 estático aceite quanto à preservação de fontes e fronteira física.** O coordenador ainda deve concluir startup normal/regressões e fechar o plano de budget; esta nota não declara esses ensaios executados. BQ1/BQ2 são pré-requisitos da expansão. Um eventual GO_LIMITED_BENCHMARK exige os quatro domínios primários qualificáveis em ambos Hz; não resulta apenas de mais catches ou números finitos. Nenhum tuning, holdout privado, promoção de A1/B2, melhoria de feel ou aprovação humana foi inferido.
