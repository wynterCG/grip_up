# Physics Auto-Tuning Lab — v1.3

Laboratório offline, independente do jogo normal e de M7. O objetivo é encontrar e comparar pequenas afinações do planeador A0, respeitando a física existente. Uma métrica melhor não promove uma configuração ao jogo.

[Relatório final da experiência](report.md): manter A0/B1. O piloto fez três repetições de referência, duas propostas Random e uma confirmação; parou por perda reproduzida de captura no headless. Nenhum candidato passou a seleção. A própria referência falhou a captura na revisão nativa, pelo que a consistência entre modos permanece por diagnosticar. Não se demonstrou melhoria de feel.

## Referência recuperável

- Checkpoint anterior ao laboratório: `f865ebf3a95eac983329d43df1a90dd1b7952bbd`, tag `baseline/pre-v1.3-auto-tuning`.
- [Freeze AT0](baseline/freeze.json): hashes de 202 ficheiros existentes, engine e Janga.
- Backup local: `builds/GripUp-v1.2-pre-v1.3.exe`, SHA256 `fb018cfbf8ac57dac83c43af6590f2107bede466d56053e1218583f03564e33d`.
- O arranque normal continua no perfil 2. A comparação explícita usa perfil 4, A0, pés físicos B1. A1 é controlo negativo; B2 fica fora da pesquisa inicial.
- A v1.2 existe como suite técnica opcional. O utilizador interrompeu a avaliação; não há sessões humanas medidas nem melhoria de feel demonstrada. Ver [checkpoint v1.2](../v12/README.md).

## Espaço inicial

| Campo real | Referência | Intervalo de pesquisa | Unidade |
|---|---:|---:|---|
| `traversal_speed_m_s` | .25 | .18–.32 | m/s |
| `traversal_input_ramp_s` | .12 | .07–.20 | s |
| `traversal_target_max_rate` | .24 | .16–.30 | m/s |
| `traversal_target_max_acceleration` | .90 | .60–1.20 | m/s² |

Combinações também têm de respeitar a distância de travagem `rate² / (2 × acceleration) ≤ .055 m`. Estes são limites para o experimento, não garantia de conforto. Horizonte de planeamento, aceleração virtual, K/D, damping físico e todos os caps ficam congelados.

Massa de 12 kg, alcance de .65708 m, mãos de 360 N, pés de 180 N total/120 N por pé, assist de 20 N·m e momento combinado de 150 N·m permanecem iguais. Os overrides usam recursos de sessão; os ficheiros e o modo normal não são afinados pelo otimizador.

## Fronteiras

`features/auto_tuning_lab/` contém apenas a avaliação explícita. `tools/auto_tuning/` contém Python/Optuna e ambiente com dependências fixadas. A exportação normal exclui ambos. Estudos e resultados brutos ficam em `builds/auto_tuning/`; apenas evidência selecionada entra nesta pasta.

O avaliador separa input scripted de input humano, contacto de retenção, e subida física de top-out assistido. Falhas, timeouts, crashes e candidatos inválidos têm de permanecer no estudo. Holdouts só são abertos depois de congelar a shortlist. Nunca se treina um agente que escolha a rota do jogador.

## Avaliação humana e decisão

As comparações humanas são uma etapa separada. Nenhum teste automático pode aprovar AT6. A0/B1 permanece a configuração de referência até existir benefício percebido repetível e aprovação explícita. RL e M7 não fazem parte desta entrega.

O [arquivo integral](evidence/stage1_r1.zip), o [manifesto de hashes](evidence/stage1_r1_manifest.json), as [tabelas e Pareto](reports/stage1_r1/report.md) e a [verificação final](final_verification.json) acompanham o relatório. O código medido é o commit `1b0a86272a2939452dbe14130df25cde40278a82`. TPE, sensibilidade, holdout e A/B humano não foram executados; não houve integração de candidatos. Os [comandos de reprodução](../../../tools/auto_tuning/README.md) continuam sujeitos aos gates.
