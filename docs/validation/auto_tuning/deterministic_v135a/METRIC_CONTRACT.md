# Contrato de aritmética v1.3.5a

`ordered_binary64_sequential_v1`, schema `metric_binary64_audit_v1`.
Implementação única: `tools/auto_tuning/metric_binary64.py`.

O consumidor aceita segmentos escalares `float` finitos. Começa com `+0.0`
e executa `total = total + value` por ordem de tick POST. Rejeita bool,
inteiro, texto, null, NaN, infinito, segmento negativo de percurso e overflow.
Não há arredondamento, tolerância, soma compensada, reordenação, FMA ou
conversão dos resultados físicos para float32. A camada de vetores mantém
a autorização anterior de componentes JSON int/float, promovidos apenas
para calcular a expressão escalar; os dados originais não são reescritos.

A norma usa `sqrt(((x*x)+(y*y))+(z*z))`. O produto escalar usa
`((ax*bx)+(ay*by))+(az*bz)`, sem um zero inicial adicional. Isto conserva
inclusive o sinal do zero da expressão publicada. As diferenças dos
componentes COM são binary64 a partir do Vector3 nativo float32 promovido
sem perda, lido do DirectBodyState, sem interpolação.

POST significa depois de aplicar o controlo, antes da integração física
seguinte. O percurso inclui a observação inicial e a final, com um segmento
por par consecutivo. O horizonte vem da definição congelada: 1 segundo
para progresso, 5 segundos para o teste de paragem correspondente. O
contador exige 120/60 ou 600/300 segmentos, respetivamente, quando a
observação completa está disponível. Não se exige igualdade entre Hz.

O recibo contém estado, motivo, unidade, janela, número e hash dos segmentos
little-endian originais, hash da sequência/proveniência, bits big-endian
publicados/recalculados e `float.hex()`. A comparação não usa `==` numérico:
compara todos os 64 bits. O hash da sequência vincula a ordem, endpoints,
fase, unidade e proveniência. Tipos/schema/reducer desconhecidos falham.

Sem onset não há percurso numérico. Interrupções conservam o motivo e
`value: null`; o cálculo parcial é identificado como evidência bruta,
nunca como medição completa ou objetivo. A pontuação exige separadamente
RUN_VALID, sucesso da tarefa, janela completa e os critérios de qualidade.

## Inventário dos consumidores

| Família | Algoritmo e consumidor |
|---|---|
| Percurso COM publicado | `metrics.summarize`: segmentos norm3 e redução ordenada; `engine.audit_execution` chama o auditor exato |
| Progresso, velocidade dirigida e onset | dot3 explícito; mesmo cálculo em `metric_contracts` e quality enrichment |
| Distância de paragem e deriva | recorrências escalares existentes por tick, com norm3/dot3 partilhados; endpoints de confirmação preservados |
| Eficiência | progresso assinado / percurso; floor existente preservado, sem substituir percurso por deslocamento |
| Carga das mãos e impulso | redução escalar ordenada dentro do tick; integração temporal escalar existente |
| Carga dos pés | compressão não negativa, acumulação explícita por pé e por tick; contacto/suporte continuam obrigatórios |
| Twist RMS | soma ordenada dos quadrados / contagem e raiz; sem frame válido continua indisponível |
| Excursão adversa | projeção explícita, máximo e recorrência de máximo anterior; não se usa média |
| Excursão lateral e velocidade angular | norma explícita por tick e máximo na mesma janela completa |
| Limites de força/momento | norma explícita; limites históricos de auditoria preservados |
| Saturação, contactos, budgets | contagens inteiras/bools; restantes `sum()` são inteiros, sem redução float |
| Pareto e seleção | comparações elemento a elemento e mínimos/máximos; A0 incluído, sem recompensa escalar inventada |
| Comparador de projeção | norm3/dot3 para distâncias e ângulos descritivos; comparação de campos/bits continua estrita |

Godot publica independentemente progresso e percurso. As medidas adicionais
de qualidade são algoritmos Python documentados; não se afirma que Godot
publica uma segunda cópia independente de cada uma. A definição semântica
de métricas e stop tem nova versão. A política histórica de qualidade,
incluindo a sua margem já existente nas comparações de qualidade, é
preservada; essa margem não se aplica à recomputação exata do percurso.

Os runners antigos `aggregate`, `validate_candidates` e
`evaluator_qualification/run` não são caminhos de pontuação ou relatório
da nova campanha. As suas estatísticas/somas antigas não são usadas para
certificar o novo contrato. O comparador atual continua a preservar campos
de cursor, contactos e física sem normalização numérica dos dados brutos.

## Evidência histórica e ambiente

O fixture contém 121 observações COM autênticas, ticks 425–545, e os 120
segmentos reconstruídos. Hash da concatenação little-endian original:
`2ef81c7306f293e5d7e22a7d9ad72c30997b9959920dca024e759ba20e8ca104`.
Resultado Godot e redução explícita: bits `3fccbe1b2b09d8a6`,
`0x1.cbe1b2b09d8a6p-3`. O sum legado Python 3.13 produz os bits
`3fccbe1b2b09d8a7`; a primeira diferença de prefixo termina em 439.
É uma diferença de auditoria aritmética offline, não uma divergência física.

O novo programa usa exclusivamente Python 3.13.13 da venv do projeto,
Optuna 5.0.0 e o lock existente. Python 3.11 é apenas uma comparação
offline adicional. O fingerprint vincula caminho/hash do executável,
versão completa, dependências, lock, locale/plataforma/arquitetura,
formato float e hash da implementação do reducer. Uma mudança exige
nova identidade de estudo. R4 permanece fechado e NO_GO.
