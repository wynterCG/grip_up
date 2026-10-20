# R4 — revisão física independente de MB1/MB2 e negativos

**Decisão: APPROVED_FOR_TWO_DOMAIN_SEARCH, exclusivamente no envelope declarado.** Esta é uma aprovação física para a pesquisa limitada em Vertical/Right com as tapes fixas qualificadas. Não aprova candidato, defaults, generalização, fun, holdouts ou o benchmark integral antigo. Mantêm-se a aprovação independente de medição e os restantes gates de integração/orçamento do responsável.

## Identidade e método

- Fonte R4: commit `7d56a6db9f467df92cd002aee8494e98ae6399ee`.
- Snapshot: `cbe93f29aa2f6e47e4aa3fd784bbc1055cfa36bacaa385f7e07baa2bc262d54d`.
- Motor: Godot `4.7.2.stable.steam.ed1daf0bf`; executável SHA256 `12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38`.
- Evidência: `builds/eval_virtual_cursor/minimal_v135_r4/{source_identity,preflight_session,baseline_session,negative_session,raw_negative_contracts}.json` e os `benchmark_audit.json`, manifests, resultados e sidecars dos respetivos attempts.

A revisão foi offline: leitura independente de **16 719 POST** de 39 processos (7 preflight, 24 baseline e 8 negativos/canary), sem motor, Git, sync ou edição de fontes. Conferi 324 hashes públicos de fontes/helpers do snapshot e os 204 hashes protegidos do baseline: nenhum drift encontrado. Não abri definições privadas de holdout. Os receipts anteriores R2/R3/R4 de infra não foram reclassificados nem usados como sucessos novos.

## Baseline física

As 24 execuções são RUN_VALID e têm a janela autorizada completa. Há 12 pares H/R STRICT_MATCH e 16 comparações adicionais within-mode STRICT_MATCH, com `first_difference=null`. Não exijo igualdade de trajetórias entre frequências diferentes.

| Tarefa | Hz | Onset→fim | Progresso COM assinado | Path 3D | Eficiência | Latência |
|---|---:|---|---:|---:|---:|---|
| Vertical | 120 | 425→545 | 0.206309199333 m | 0.213680091348 m | 0.965505013 | 0.091666667 s |
| Vertical | 60 | 236→296 | 0.209521651268 m | 0.214433874754 m | 0.977092129 | 0.083333333 s |
| Right | 120 | 425→545 | 0.145331233740 m | 0.146084983352 m | 0.994840335 | null — ALREADY_MOVING_BEFORE_ONSET |
| Right | 60 | 236→296 | 0.143510375172 m | 0.144423299556 m | 0.993678829 | null — ALREADY_MOVING_BEFORE_ONSET |

Cada linha corresponde aos mesmos valores nas seis execuções locais dessa célula. São três repetições por modo de uma tape/start, não seis starts independentes. A diferença exata entre repetições não é incerteza populacional nula nem evidência de significância estatística.

Em todas as janelas:

- 121 POST a 120 Hz ou 61 a 60 Hz, separados por exatamente 1 segundo;
- duas mãos ATTACHED, mesma âncora runtime por mão, mesmo suporte semântico e ponto material local desde onset até fim;
- suporte válido, nenhuma ownership hybrid, nenhum grounded/força/torque de chão admitido na janela;
- `CLEAR_QUERIED_SEGMENT` durante toda a janela;
- perfil 4, A0, B1, quatro valores A0 exatos em todos os POST.

B1 não é ficticiamente desligado. A fração de impulso compressivo dos pés sobre pés+mãos-up é cerca de 0.0022623 em V120, 0.0020577 em V60, zero em R120 e 0.0016908 em R60. Os picos de pés na janela são respetivamente 5.02373, 1.99143, 0 e 2.61434 N. São células predominantemente suportadas pelas mãos, mas não todas arm-only.

## Limites, contactos e restauro

Máximos independentes sobre todos os 16 719 POST, incluindo preparação e negativos:

| Quantidade | Máximo observado | Limite congelado |
|---|---:|---:|
| Soma de magnitudes das mãos | 254.947982788 N | 360 N |
| Pés total | 64.226564407 N | 180 N |
| Um pé | 51.266456762 N | 120 N |
| Assistência angular | 20.000001395 N·m | 20 N·m, allowance histórica de representação |
| Momento combinado | 76.760712056 N·m | 150 N·m |

O resíduo de ~1.4 micro-N·m da norma publicada de assistência permanece na allowance histórica, sem tolerância nova. Massa 12 kg e alcance de pedido 0.65708 m permanecem exatos. A maior distância de ombro com mão ATTACHED/SLIPPING observada foi 0.654083252 m. Não se misturou o alcance de pedido com a margem elástica do solver.

Verifiquei 5 191 samples de mãos FREE e 2 791 REACHING: todos com força exatamente zero. Não encontrei força de pé fora de SUPPORTING/SLIDING, pé carregado sem suporte semântico ou compressão negativa além do guarda histórico. As observações de corpo/forças verificadas são finitas. As invariantes runtime publicadas são falsas em todos os resultados; isto é ausência de violações observadas no escopo do monitor, não detector universal de body writes.

Os vetores de força/reação das mãos verificaram `F + reaction = 0` exatamente nos campos publicados. Nos negativos/canary, mão ATTACHED coincide exatamente com o seu endpoint material publicado. O modelo virtual baseline aplica força no ombro e reação no ponto de anchor; não reivindico conservação angular exata do wrench completo nem desempenho de vigas móveis a partir destas paredes estáticas.

Todos os 39 resultados confirmam instalação pré-tick, originais intactos incluindo os quatro knobs, restauro exato do ponteiro, sources estáveis, relógio restaurado e perfil de startup preservado. As cópias e seals separados no receipt foram lidos juntamente com os mapas de parâmetros efetivos. Não foi necessário instalar um Resource salvo ou alterar mecanismos. A preservação Git/E e o safety/export final continuam responsabilidades separadas do integrador.

**Limite de contacto nativo:** a baseline reporta `native_contact_limit=0`. As queries de clearance certificam o segmento no contrato conservador declarado e a autoridade de chão publicada é zero, mas não provam ausência de todo o contacto/impulso nativo em todos os layers. Não atribuo uma eventual microinterseção a Jolt nem a contabilizo como força inexistente.

## Negativos e canary

Os oito processos são RUN_VALID. N1 em ambos Hz tem 9 checks internos PASS, 4 decisões lógicas, 3 dispatches reais, 9 rays reais e 1 supressão. A mira inválida não gera novo contacto; o corner válido `(0,0)` percorre o picker real. As corrupções read-only de sidecar ausente/duplicado foram recusadas sem processo físico adicional. O controlo publicado de 228 samples sem apoio corresponde a uma fonte específica; a auditoria acima cobre todos os samples FREE/REACHING dos 39 processos.

As referências Catch e os N1 mantêm o destino real `catch`, normal underside, carga admitida e mesma âncora retida depois de source FREE:

| Hz | Contacto | Source FREE | Retenção confirmada | Distância no pedido |
|---|---:|---:|---:|---:|
| 120 | 440 | 455 | 527 | 0.814921677 m |
| 60 | 215 | 223 | 259 | 0.807716429 m |

As distâncias excedem R+0.02; a retenção decorre por pelo menos 0.6 s após source FREE e mantém-se ao fim. Estas são referências headless de preflight/N1, não a validação futura H/R de um finalista. O contexto B1/chão da preparação permanece explícito.

O canary congelado `.18/.20/.16/.60` não viola invariantes. Vertical120 em ambas as repetições mantém onset/window completos e mede 0.124524235725 m, contra A0 0.206309199333 m: perda de 0.081784963608 m, cerca de 39.64%. Demonstra sensibilidade contínua no domínio exigido, sem força nova ou retune do canary.

Right120 do canary interrompe no tick449 por `GROUND_CLEARANCE_NOT_CERTIFIED`, último POST autorizado448. Progresso oficial permanece null/INTERRUPTED; o prefixo raw −0.000262263231 m não é score nem gradiente contínuo. No tick da interrupção, grounded e força/torque de chão são zero, mas a query é `POSSIBLE_GROUND_INTERSECTION`: motivo de elegibilidade conservadora, não prova de impulso nativo ou violação do solver.

Os controlos públicos reproduzem as fronteiras conhecidas: Asym60 interrompe em238 por clearance com chão/força/torque zero; Left60 interrompe em265 por autoridade real de chão, com força `[-6.404648781,0,-0.207128704]` N e torque `[0.985188901,2.132928371,0.791752577]` N·m. Left ainda tem query CLEAR; são condições independentes. Os resultados permanecem null tipados, não são promovidos a treino.

## Qualidade e âmbito autorizado

O `quality_contract.json`, SHA256 `279f739e74674e11b695fb8e15592e883c680ebb9c8869c055b0629aeb5fb496`, está marcado frozen antes das propostas e vinculado ao mesmo snapshot. Mantém floors prospectivos de 5 mm para backwards/off-axis, 0.05 para eficiência e 2 ticks120 para latência; a latência Right já não elegível continua null com o motivo exato permitido. Twist RMS permanece NOT_APPLICABLE/NOT_DEFINED_FOR_TASK, não zero. Velocidade angular total descritiva não substitui twist axial nem prova que todo o swing está preservado.

A ausência de twist axial limita a conclusão sobre qualidade angular; não impede esta pesquisa restrita de parâmetros com gates explícitos de contacto, suporte, progressão, fidelidade observável e transferência posterior. Nenhum vencedor pode ser chamado globalmente melhor ou integrado sem os testes protegidos e decisão humana correspondentes.

**Signoff físico:** o preflight, baseline e canary observados satisfazem a admissão física ao estudo limitado nas duas tarefas. A autorização não cobre as células históricas inválidas, Step, scoring hybrid, fixtures novas, mecanismos alterados, tapes adaptativas para score, tolerância relaxada ou pesquisa sobre holdouts. Uma proposta que perca a elegibilidade recebe a rejeição tipada prevista; uma falha de invariantes/infraestrutura exige parar conforme o plano.

## Hashes da evidência lida

| Artefacto | SHA256 |
|---|---|
| `source_identity.json` | `996ee4eb1297b36dbc671377a5de2d8dec2b73640b6818aedc80d1c09679c6f1` |
| `baseline_session.json` | `f8bad043a50e240cfab4b65edfa1713f4119dcecc047d62dc2dbc77d17516649` |
| `preflight_session.json` | `cabd67d657ebc1fcd83b0919f859ad886890fcdc3f21a748f0e5b5dc0d27673d` |
| `negative_session.json` | `468e58c828f398dc6521634dff270963456963309a197ffc687d3b2ec09daee9` |
| `raw_negative_contracts.json` | `0b7fd44619a4aebb9c28ffb7ed6c9736a7ba316dce9b2f87036b40e68ca62a2d` |
