# Fixture lateral simétrico

**Construção e contratos DIAGNOSTIC_ONLY; qualificação MISSING_COVERAGE.**
O catálogo entrega clean/counter left/right e controles two-hand/one-hand em uma
geometria nova e nomeada. Nenhuma célula lateral final foi executada após a
paragem do gateR0; não há números positivos inventados nem simetria física certificada.

## Geometria declarada antes dos ensaios

`qualification_mirror_v1` e `qualification_onehand_v1` partilham
`symmetric_clearance_r1`: spawn existente(0,1.17,.4); parede4.8×6.8×.4m centrada
em(0,2.1,−.2); contactos(−.24,2.1,0)/(+.24,2.1,0); quatro ledges iguais em
x±.15/±.45, topo.59; pequeno pad inicial x±.24, z.32–.80, topo.25;
piso de segurança com topo−1.25. Câmara inicial yaw0, elevation−.06, distance6;
o follow normal continua. Não existe escala negativa de rigidbody.

A substituição do nível exige controller step/time0, mãosFREE, velocidadeszero,
spawn exato e ausência de ownership híbrido. Nem uma pose inicial é reescrita:
o fixture usa arena8 porque já nasce no spawn pretendido. O pad permanece no
mundo; não é retirado quando o corpo sobe. Recursos físicos e colliders do corpo
continuam originais. A construção não se declara um contacto/clearance nativo.

## Clearance e referência espelhada

O audit observa as proxies reais cápsula/esfera/box, overlaps iniciais/finais e
casts de translação, subdivididos até2cm/2graus, limite128. Uma margem de query
conservadora cobre o arco rotacional; não altera o collider físico. São consultados
pad/ground layer1, sem fingir que a parede/footholds também foram declarados livres.
POSSIBLE_GROUND_INTERSECTION produz CLEARANCE_NOT_CERTIFIED, não uma alegação de
contacto real. Os canais de ground-motor e pares nativos, quando reportados,
permanecem separados.

O max_contacts_reported original pode ser0 e não foi aumentado. Uma lista nativa
vazia com reporting desligado é UNKNOWN; queryCLEAR não prova ausência universal
de manifold/contact skin. Este limite impede uma certificação que exigisse isso.

Uma comparação bilateral correta usaria o referencial local da parede e reflexão
X dos pontos/velocidades, troca das mãos e a transformação axial correta do spin
(detR·Rω), mantendo Y/Z e as identidades de suporte. Apenas trocar o sinal de
world-X não certifica duas histórias iguais. Como a matriz não correu, essa
comparação bilateral não foi declarada medida.

Treze checks puros passaram: dados simétricos, IDs novos, bandas, orçamento,
bounds das proxies e recusa de construção depois de avançar a física. No smoke
de desenvolvimento, two-hand release obteve queryCLEAR e observação válida;
isso não substitui clean/counter left/right com n3 em ambos modos/rates.
Os 12 counter-left históricos v131 interrompidos por ground continuam visíveis e
não são reclassificados como sucesso deste novo fixture.
