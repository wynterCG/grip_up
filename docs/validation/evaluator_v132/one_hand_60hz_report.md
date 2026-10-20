# Uma mão / 60 Hz

**ONE_HAND_60HZ_UNQUALIFIED / MISSING_COVERAGE.** Zero screens finais dos24
previstos e zero células de qualificação de uma mão a60Hz foram executados.
Esta ausência resulta da paragem no gateR0 antes da fase de preparação; não é
uma taxa de insucesso0/0, nem uma demonstração de falha do movimento do personagem.

## Implementação entregue

`preparation_registry_v132_r1.json` congela três scripts de inputs existentes:

1. P0_DIRECT_R1: adquirir a mão retida; W1.5s; neutral.15s.
2. P1_DUAL_NEUTRAL_RELEASE_R1: adquirir as duas; W1.75s; neutral.25s; largar a outra
   com botão real e verificar no máximo.3s; neutral.5s.
3. P2_DUAL_LOADED_RELEASE_R1: adquirir as duas; W2.5s; largar a outra mantendoW,
   verificar no máximo.3s; W.35s; neutral.25s.

Os contactos são os pontos reais da parede; a mão complementar tem de estarFREE,
sem âncora e com força zero. O mesmo torso e Resource originais permanecem em uso.
Não se escreve pose, velocidade, reach, massa ou força para preparar o corpo.

Quiet: norma completa da velocidade≤.10m/s e spin≤.20rad/s durante.25s decorridos,
máximo5s. Stop/brake/reverse: velocidade dirigida.15–.50m/s, máximo2s de preparação.
As bandas são novamente verificadas no tick realmente aceite. Ground e autoridade
nativa de caminhada invalidam o onset; B1 é medido, não omitido.

Cada screen planeado teria uma janela quiet.25s seguida do sufixo fixo de drive≤2s
e um tick neutral aceite. Quiet e motion seriam selecionados separadamente por
modo/Hz/lado; motion exige também quiet válido. A escolha seria o primeiro script
elegível, nunca o melhor score. Nenhuma seleção final foi produzida ou adotada.

## Evidência disponível, sem a promover

No desenvolvimento não certificado, a120Hz headless/lado esquerdo:
P0 para stop não entrou na condição dirigida; a mão retida estavaATTACHED, a outra
FREE/força0, groundfalse e queryCLEAR. P1 eP2 entraram no screen low-energy;
P1 não confirmou uma nova estabilidade em toda a curta janela observada e foi
CENSORED; P2 confirmou settling0 com path0 após a confirmação futura exigida.
São duas tentativas low-energy de desenvolvimento, de fonte anterior ao freeze;
não são repetições finais, cobertura bilateral ou prova a60Hz.

O novo domínio é parede/B1 com geometry symmetric_clearance_r1. Mesmo que se
qualificasse, não repararia retroativamente o antigo Hang/underside: a v131 teve
24/24 preparações relevantes60Hz com PRECONDITION_NOT_MET. Esse histórico permanece
intacto. Não se alteraram bandas nem scripts depois da paragem para obter umPASS.
