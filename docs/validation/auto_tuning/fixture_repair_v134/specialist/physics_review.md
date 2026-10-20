# v1.3.4 - revisao independente de fisica e viabilidade das fixtures

**Estado: diagnostico R3 confirmado; propostas prospetivas, viabilidade ainda NAO DEMONSTRADA.** Nao ha aprovacao de um novo benchmark, tuning ou defaults. A revisao de implementacao e dos novos recibos sera acrescentada separadamente, sem reescrever R3.

Li integralmente `GRIP_UP_Benchmark_Fixture_Repair_Feasibility_Spec_v1_3_4_EN.md`, o driver/catalogo real e os traces antigos. Trabalho offline no mirror C, sem motor, Git, sync ou alteracoes de fontes/geometria. A unica escrita desta tarefa e este novo documento. O source R3 `7a578995915d56ade2fa447f3adfdd6e19dc0218`, snapshot `a6bd333c5f4fc8f8571d5c907db09f858da9429852befc20e2777f9dc9b36986`, continua evidencia imutavel.

## 1. Clausulas efetivas e evidencia antes de alterar geometria

O driver real e `features/evaluator_virtual_cursor/scripts/benchmark_driver.gd`, com catalogo `features/evaluator_virtual_cursor/resources/benchmark_eval_v133.json`. O gate quiet exige: support.valid; ausencia de hybrid/grounded/native_ground_authority; clearance CLEAR_QUERIED_SEGMENT; duas maos ATTACHED em suportes reais; esforco agregado das maos >1N; velocidade relativa no eixo <=.1m/s em modulo; norma angular <=.2rad/s; Fnfoot>1N apenas no Step. O dwell e tempo decorrido >=.25s. No onset aceito ha revalidacao e historico de quiet/mesmas ancoras. Stop usa antes do release velocidade dirigida [.15,.5]m/s, nao o gate de velocidade quiet.

A tabela seguinte resulta de um recalculo independente nos **ultimos5s da espera quiet** dos captures falhados. Nao mistura aquisicao/preload nem o periodo de medicao. Numeros sao ticks em que a clausula foi falsa; um tick pode violar varias clausulas.

| Caso | Janela/ticks | Clearance falso | Angular falso | Carga maos<=1N | Grounded/authority falso para hanging | Eixo quiet falso | Footload requerido falso | Maior intervalo all-true |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Asym120 |188..787/600|574|13|6|0|0|N/A|.108333s |
| Asym60 |95..394/300|300|0|3|0|0|N/A|0 |
| Vertical60 |97..396/300|300|0|3|0|0|N/A|0 |
| Step120 |191..790/600|0|84|0|600|0|0|0 |
| Step60 |97..396/300|0|31|0|300|0|0|0 |

Em todas estas janelas, support.valid, ausencia de hybrid, duas maos ATTACHED e suportes/ancoras materiais validos passam em todos os ticks. A carga dos pes e observavel mesmo quando nao e requisito: fica<=1N em587/600ticks Asym120 e293/300em Asym60/Vertical60, mas isto **nao e uma clausula falhada desses dominios**. No Step e sempre>1N; nao esconder este esforco so porque a conjuncao falha.

Asym120 tem24ticks all-true, primeiro no195, mas nenhum bloco chega a.25s. O resumo root de todo o trace encontra718falhas de clearance em786ticks; e compativel com574/600da espera quiet aqui delimitada. Nao comparar esses denominadores como se fossem uma contradicao. O principal bloqueador observado nao e um torque insuficiente de estabilizacao: e a certificacao de clearance junto ao pad, com perdas menores adicionais de carga/rotacao durante assentamento.

No fim do Asym120, COMy~1.164226, maos0/10.77N, ground F/Tzero e hit FootBase/SpawnPad com margem.000765743m. Em60, Asym e Vertical terminam com END_OVERLAP contra o SpawnPad alem do primeiro overlap query; portanto nem todas as rejeicoes sao apenas margem rotacional. Nao inferir daqui reacao nativa exata: max_contacts_reported=0 e a verdade do manifold permanece UNKNOWN.

## 2. Vertical120 e as interrupcoes60

Vertical120 certifica onset268, perde clearance no275 e termina a janela autorizada no274. O primeiro hit e apenas OVERLAP_OR_ROTATION_BOUND de FootBase contra EQ132SpawnPad, margem~.766mm; nao ha END_OVERLAP ou SWEPT_GROUND_INTERSECTION nesse tick. Ground predicate=false, motor F/Tzero. COMy1.164214373 e praticamente constante, rawprogress0/path3D2.07e-7m. O null INTERRUPTED nao deve virar zero elegivel.

Reconstruindo o BoxShape FootBase a partir das dimensoes/transforms reais e recortando pela frente do padZ=.32, um ponto ideal fica emY~.249829 face ao topY=.25: proximidade~.17mm. Isto sugere fronteira geometrica muito apertada, nao demonstra colisao nativa nem falso positivo. A consulta conservadora deve permanecer. Os shapes fisicos nao podem ser reduzidos/desativados e nao deve ser adicionado um threshold de tolerancia para aceitar o caso.

As laterais60 certificam onset179 e entram em grounded no200, depois do prefixo autorizado ate199. O suporte observado e EQ132SpawnPad, pontoY~.25. Nesse primeiro tick, applied_force=[0,0,0], applied_torque=[0,0,0] e motor_authority=0. O motivo tipado NATIVE_GROUND_AUTHORITY_CHANGED_TASK inclui a mudanca de predicate de apoio; nao prova que um impulso de marcha causou a deslocacao anterior. O mesmo acontece ao stop60 um tick depois do onset199. O pad entra no envelope do corpo pendurado; a tarefa muda e o intervalo tem de terminar, mesmo com comandos identicos H/R.

O 120Hz lateral completo continua apenas referencia historica: esquerda+.149168m/direita+.149263m, latencia.141667s. Stop120 continua path ate settling.116284m e settling.816667s; nao confundir com path dos5s.168328m ou drift final+.003122m. Nenhum destes numeros e um novo resultado v134.

## 3. Proposta minima: mudar a entrada por contactos reais antes de mover o pad

Recomendacao preferida para um novo catalogo/fixture identity: manter spawn, parede, pad e shapes; usar uma **entrada em dois patamares por regrips ordinarios na mesma parede**.

1. Adquirir os dois entry contacts simetricos `(-.24,2.10,0)` e `(.24,2.10,0)` por picking real.
2. W1.5s, depois neutral. Esta e uma preparacao historicamente capaz de obter um estado de suporte nonground, ainda que a antiga janela60 posteriormente encontre o pad.
3. Regrip esquerdo real para `(-.24,2.25,0)`, mantendo a direita; depois regrip direito real para `(.24,2.25,0)`. No Asym, o segundo contacto final e `(.24,2.13,0)`, conservando desnível material real de.12m.
4. Aplicar apenas o input de preparacao adicional finito declarado no catalogo, se houver; neutral e verificar o dwell original. So depois iniciar W, A/D ou o drive/release de stop definidos.

Nao ha contacto automatizado, forca extra, destino de COM ou translacao de ancora ja agarrada: cada mao tem de viajar e anexar no novo material. Se o primeiro regrip deslocar o corpo e tornar o segundo inviavel, guardar a falha; a estimativa nao autoriza bypass de LOS, anatomia ou raio.

Ha evidencia de alcance necessario em estados R3 reais, imediatamente antes do comando lateral depois deW1.5+quiet:

| Estado R3 | Distancia L paraY2.25 | Distancia R paraY2.25 | Distancia R paraY2.13 |
|---|---:|---:|---:|
| Tick347/120Hz |.523887m|.530369m|.427721m|
| Tick178/60Hz |.558359m|.564255m|.459265m|

A menor margem inicial ateR.65708e~.0928m, em vez de uma tentativa no limite. Sao distancias estaticas de um estado ja medido; **nao provam gesto, novo equilibrio ou retencao depois do primeiro regrip**. O ganho de altura potencial vem de apoios efetivamente mais altos, nao de mais capacidade do personagem. Isto e novo contexto de teste, sem continuidade de scoring com R3 e com novas captures/tapes porHz.

Uma alternativa ainda menor de input seria W2.5s +S.25s +neutral, sem regrips. Deve ser registada como variante prospetiva separada se escolhida, nao combinada livremente depois de ver resultados. O S curto procura recuperar curso para o W de medicao: W longo sozinho pode atingir o alvo minimo e deixar uma vertical quiet mas sem curso de subida. Nem esta variante nem a entrada de dois patamares estao certificadas. Prefiro a segunda por conservar margem de curso e obter clearance por contacto real numa altura conhecida, sem uma plataforma movel.

Nao mover simplesmente a frente do pad paraZ>=.48 mantendo spawnZ=.4: o COM inicial ficaria fora do poligono de suporte e so a ponta traseira do sole tocaria o pad. Isso pode criar uma queda/tombamento antes da primeira aquisicao, trocando um problema por outro. Tambem nao remover o pad durante a simulacao, desativar colisoes ou fazer um reset de velocidade para fabricar hanging.

## 4. Step: fixture alternativa declarada se o OriginalStep continuar grounded

O R3 OriginalStep possui um Start de5x.3x5m a(0,.1,1), top.25, muito mais amplo que o SpawnPad da fixture simetrica. No fim120, o corpo continua grounded no Start com authority~.1618e torque nao nulo, apesar deFnfoot~36.66N; em60Fnfoot~33.18N. E esforco B1 real num contexto que nao satisfaz nonground, nao prova de um pe ficticio nem de uma janela valida.

Se a entrada por regrips nao resolver o contacto com este grande Start, propor **nova fixture Step** combinando partes ja existentes, antes da primeira simulacao:

- spawn `(0,1.17,.4)` e parede simetrica existentes;
- SpawnPad da qualification_mirror: centro `(0,.10,.56)`, size `(.48,.30,.48)`, top.25;
- SafetyFloor existente, top-1.25;
- um unico broad foothold originalStep: centro `(0,.51,0)`, size `(.95,.16,.22)`, top.59 e fimZ.11;
- os contactos de medicao elevados adquiridos pela sequencia real acima, nao pre-attached.

Esta nova composicao substitui apenas o grande Start no novo laboratorio; nao edita o nivel de produto nem os colliders. Com hip~1.4 e ankle de apoio~.694, a distancia estimada de perna fica~.71-.76m, abaixo do maximo medido~.83m. Pode existir simultaneamente clearance do sole sobre o pad e compressao B1 util, mas a geometria estimada nao e evidencia de Fn, trabalho ou onset: verificar actual hip/ankle/reach/friccao/carga e queries. Se falhar, manter PRECONDITION_NOT_MET ou excluir/redesenhar o contexto. Nao relaxar a condicao nonground nem contar um pe apenas PLANTING.

## 5. Revisao do debugger FR1 novo

Li `tools/fixture_prerequisites.py` novo. O funnel reproduz as clausulas quiet instantaneas, acrescentando ancora runtime nao zero (redundante nos traces R3 validos), tempo decorrido correto e native_contact_truth UNKNOWN quando o limite de reporte e zero. Guarda todos os predicados falsos e os dados fisicos; isto e preferivel a apresentar apenas o primeiro em ordem de codigo. Meus numeros independentes acima concordam com o seu resumo quando se alinham as janelas.

Limite importante: o funnel de quiet nao e o certificado de onset aceito. A condicao quiet<=.1nao equivale ao accepted-onset de stop com velocidade[.15,.5]; tambem faltam neste simples funnel o comando aceito e o historico de mesmas ancoras verificado por `_raw_quiet_before`. Recomendo rotular a conjuncao como **quiet preparation prerequisites** e juntar o certificado real do driver para drive/release/onset. O texto `onset_authority` ja declara corretamente que o debugger nao redefine a autoridade. Nao transformar all-true num onset sintetico nem usar trechos depois do comando para alegar preparacao anterior.

## 6. Instrumentacao, autoridade e fronteiras de aceite

O N1 antigo deve permanecer RUN_INVALID. O defeito observavel e4decisoes logicas versus3queries reais: tick1 invalida aim sem dispatch; ticks3/55/282dispatch real, e o primeiro tem sete MISS. A reparacao deve correlacionar identidades e ordem de dispatch/sidecar, nao adicionar rays nem simplesmente ignorar qualquer falta. Um evento suprimido nao cria suporte. Nenhuma mudanca ao picker, mascara3 ou ordem dos sete rays e necessaria pela evidencia lida.

Para aceitar uma fixture nova: actual hands/anchors, pendingforcezero, apoio apropriado, clearance conservador e dwell original; depois movimento assinado nao nulo ou stop corretamente medido durante horizonte completo. Grounded, query, contacto nativo e motor aplicado permanecem quatro factos diferentes. Native manifold desconhecido nao vira 'sem contacto'. Suporte estatico nao prova conservacao dinamica nova; comparar esforcos/reacoes reais sem inventar trabalho total. B1load>1N nao e por si fracao do peso ou beneficio causal.

Manter12kg,R.65708,360Nmaos,180Npes/120Nindividual,20Nmassist e150Nmcombinado. A0 valores.25/.12/.24/.9, perfil4/A0/B1 e startup2/LIVE nao mudam. Novos contextos requerem revision/hash/tape novos; pares H/R usam a mesma tape porHz e nao exigem igualdade entre frequencias.

O budget e limitado: desenvolvimento ate8processos (root informa um ja gasto emN1120, restando ate7); piloto final teto48, separado das34regressoes. Nao gastar replays fixos de uma preparacao sem onset. Um unico par viavel porHz nao e n3 nem autorizacao de tuning. O resultado pode legitimamente ser FEASIBILITY_NO_GO.

**Parecer atual:** o diagnostico existente sustenta testar primeiro uma entrada por regrips reais mais altos, com Step de clearance separado apenas se necessario. Nenhuma alteracao de solver, threshold, damping, forca ou gameplay e justificada. Aprovacao fisica da nova implementacao e decisao FEASIBILITY_READY_FOR_REQUALIFICATION ficam PENDENTES dos diffs e recibos novos.

## 7. Revisao da primeira implementacao - aprovada apenas para ensaio

Revi `features/evaluator_virtual_cursor/scripts/feasibility_driver.gd` e `resources/fixture_feasibility_v134.json` novos. **APPROVED_FOR_DEVELOPMENT_TEST**, sem aprovacao antecipada de viabilidade. O source revisto conserva o controller/solver, normal spawn e shapes; `Fixture.apply` continua antes do primeiro tick e nao escreve no corpo. O opt-in exige flags de feasibility/benchmark, campanha/versao de pick e hash do novo catalogo. O catch de referencia usa o caminho original, nao a preparacao nova.

Nos seis dominios, a preparacao usa aquisicao normal dos entry_contacts; W1.5s; neutral; por mao, release via `_button(false)`, um tick real e `_grip` para o contacto mais alto. O catalogo mantem a ordem espelhada de aquisicao/regrip da lateral esquerda. Nao vi ancoras deslocadas enquanto presas, overrides de forca, escrita de targets fisicos/manuais, pose/velocidade ou nova estabilizacao. Uma falha de aquisicao termina com motivo explicito. Quiet, accepted-onset, historico e os gates de stop/horizontes sao herdados sem relaxamento. A flag score_eligible permanece false.

Diferencas em relacao as propostas anteriores, que devem permanecer visiveis:

- O Asym implementado conserva **entry** L2.10/R1.98, seguido de **measurement** L2.25/R2.13. E assimetrico antes e depois, com.12m de desnivel; nao usa a entrada simetrica que propus como alternativa. Isto e licito, mas as minhas distancias historicas calculadas a partir da entrada simetrica nao provam o estado futuro deste entry assimetrico. Verificar ambos os regrips e as coordenadas materiais reais nos novos recibos.
- O Step implementado usa a mesma mirror com **quatro footholds pequenos**, nao o broad foothold do OriginalStep nem a composicao alternativa sugerida na secao4. Continua um teste B1 legitimo se obtiver compressao/friccao real, Fn>1N e a janela nonground; e um novo contexto de apoio, sem alegacao de equivalencia ou continuidade numerica com o antigo TheStep. O campo `original_geometry_unchanged=true` so pode significar que a mirror reutilizada nao foi editada, nunca que a antiga fixture Step permanece igual.
- `preload_s` legado ainda existe como metadado no JSON, mas a preparacao nova usa explicitamente `entry_pull_s=1.5`. A prova do input real vem do trace/catalogo versionado, nao da interpretacao do campo legado como uma segunda fase executada.

O alcance estatico previamente calculado nao certifica a trajetoria depois de soltar uma mao. O corpo tambem pode tocar footholds/parede com os proxies compostos; a query ground layer1 nao certifica essas colisoes como ausentes. Preservar contactos disponiveis, ground predicate, forcas reais e UNKNOWN quando nao reportados. Nao interpretar uma eventual falha como permissao para desativar colliders ou reduzir constraints.

O plano comunicado consome no desenvolvimento: N1120(1) +referencias H/RxHz(4) +no maximo tres captures de fixture60(vertical/asym/Step), total8. O piloto final e outro ledger com teto48 e nao recebe passes de desenvolvimento. O ensaio proposto e pequeno e prioritiza as falhas antigas, mas resultados positivos somente60nao autorizam assumir120ou todos os outros dominios. Sem ciclo adicional escondido quando o budget acabar.

| Source revisto nesta fronteira | SHA256 |
|---|---|
| `features/evaluator_virtual_cursor/scripts/feasibility_driver.gd` | `84ac0ba14cacaaaee35b4c8f261d2b2c3dade2634abaf389959d189eb090300e` |
| `features/evaluator_virtual_cursor/resources/fixture_feasibility_v134.json` | `dfbfffcbf9e542aab873691489e39eb3237dcdea5b69b9c12c4819cb3c8dde05` |

Aprovacao restrita ao desenho para testar estes bytes/propostas sob os gates. FEASIBILITY_READY_FOR_REQUALIFICATION e qualquer novo benchmark continuam PENDENTES. Esta revisao nao executou o motor nem alterou fontes.

## 8. Revisao estatica da candidata final r2

**APPROVED_FOR_FINAL_FEASIBILITY_TEST**, com os riscos abaixo; nao e FEASIBILITY_READY_FOR_REQUALIFICATION. O desenvolvimento esgotou os8processos declarados e nao se autoriza outro episodio de desenvolvimento por este parecer. Os resultados r1 ficam historicos, nunca unidos aos novos r2 como se fossem a mesma fixture/tape.

Li os snapshots finais dos captures de desenvolvimento60: Verticalr1 chega a uma observacao valida; Asymr1 termina junto ao pad com END_OVERLAP do FootBase e sem ground motor; Stepr1 conserva contacto dos pes na parede mas Fn~0. Os pontos de pe no Step ficamY~.597508e.592033, acima do top.59dos pequenos footholds. Isto sustenta experimentar uma alteracao geometrica declarada; nao justifica mudar o sampler, aumentar compressao ou aceitar um pe sem carga. O progresso Verticalr1 comunicado/arquivado de+.205777m nao e um resultado da nova r2.

### Pad revisto e suporte inicial

O novo pad conserva X[-.24,.24], Ytop.25 e Zback.80, mudando apenas a frenteZ.32para.39: centroZ.595e sizeZ.41. Na pose inicial medida, FootBase ocupaZ~.225..505 e o COMZ.4fica10mm dentro do poligono do pad. E diferente da proposta demasiado recuadaZ.48: existe suporte inicial geometricamente plausivel, embora a margem seja pequena e nao prove equilibrio dinamico.

Na pose final real Asym60r1, FootBase maxZ~.385717108. O novo front.39 produz4.282892mm de separacao nominal. E maior que a antiga margem de query~.766mm nessa amostra, mas nao certifica o sweep completo nem as novas poses: mudar o pad altera a evolucao dinamica. Manter a consulta conservadora sem mudar mask, inflacao ou thresholds. Um eventual contacto/queda de entrada deve ficar no trace como falha, nao ser corrigido por setter ou impulso.

### Lip Step e verificacao do LowerCapsule

A primeira proposta de broad lip, centro(0,.57,0),size(.95,.16,.22), top.65/endZ.11, tinha uma interseccao geometrica ideal com o LowerCapsule na pose final Stepr1. Recalculei offline a distancia minima entre o segmento central da capsule transformada e a caixa proposta: .147873m face ao raio.150000m, cerca de2.127mm de overlap. Isto nao e um manifold nativo medido, mas e uma objecao geometrica concreta: poderia introduzir apoio adicional do calf que nao deve ser confundido com esforco B1.

O root aceitou o recesso minimo de1cm. A candidata final tem lip centro **(0,.57,-.01)**, size **(.95,.16,.22)**, top **.65**, frente **.10**. Na mesma pose antiga a separacao ideal fica~7.87mm. Isto retira o overlap previsto sem diminuir colliders do jogador, alterar forcas ou fabricar contacto. Continua a nao garantir ausencia de contacto nas poses futuras: layer1clearance nao verifica lip/wall layer2, e o native manifold nao reportado continua UNKNOWN. Exigir Fn/trabalho/load observados e divulgar qualquer contacto disponivel, em vez de atribuir toda a subida ao pe.

### Codigo e identidade da revisao

Revi `feasibility_fixture.gd` ja com lip recuado, o driver que o chama e o catalogo r2. O wrapper chama o Original.apply antes do primeiro passo, confirma step/timezero e muda apenas **StaticBody3D** e os seus shapes/meshes de teste. Pad e lip sao registados com antes/depois e transforms/dimensoes/layers efetivos. No Step remove sincronicamente os quatro footholds antigos da arvore, faz queue_free, limpa a lista e acrescenta o lip. Os resources de shapes/meshes das caixas originais sao criados por instancia; nao se modifica um shape do ator. Nao ha escrita de pose/velocidade do ator ou solver.

O driver passa a usar FinalFixture somente para os seis dominios; Swing & Catch conserva a fixture separada original. Os novos IDs terminam_v134_r2 e os fixture IDs distinguem pad_clearance de pad_clearance_foot_lip. O recibo deixa corretamente original_geometry_unchanged=false. Entry/regrips reais, W1.5, assimetria.12m e os gates de quiet/onset/stop permanecem os da implementacao anterior. Require_foot_load continua true somente no Step. Nao ha rescoring ou continuidade com R3/r1.

| Bytes revistos para aprovacao de ensaio final | SHA256 |
|---|---|
| `features/evaluator_virtual_cursor/scripts/feasibility_fixture.gd` | `d056474b2e41834a9e997a7b7adc01093769034b8b5d0e68780ef0dcff2b9c7a` |
| `features/evaluator_virtual_cursor/scripts/feasibility_driver.gd` | `90743d75f44d19e95f42efefd525a33435f375c082321f7e4201ddf6913d158d` |
| `features/evaluator_virtual_cursor/resources/fixture_feasibility_v134.json` | `5ac75d6ce44a62e494d8bfe3076d6d0568e71dc3105eca246d5ca96c0451b7a8` |

A aprovacao e para ensaiar esta candidata congelada no piloto separado declarado: novos12captures e pares condicionais, referencias/N1novos e reserva explicita, teto48. Nao reutilizar o sucesso Verticalr1 ou as referencias de desenvolvimento como passes do source final. Se um capture r2 nao obtiver onset/janela completa, parar o dominio e preservar a falha; sem novas revisoes de desenvolvimento dentro do budget ja esgotado. O resultado global pode continuar FEASIBILITY_NO_GO. Sem execucao de motor ou alteracao de fontes por este revisor.
