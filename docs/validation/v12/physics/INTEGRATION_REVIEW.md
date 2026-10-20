# v1.2 — revisão física read-only dos componentes da raiz

Scope: `locomotion_test_harness.gd`, `session_recorder.gd` e extensão do `locomotion_observer.gd`, lidos durante a integração em C. Sem edições desses ficheiros pelo especialista. Como a raiz continua a integrar, estes achados são comunicação de revisão e não afirmação sobre o estado de um futuro commit.

## Verificado na leitura

- O acumulador recebe snapshots; o recorder serializa/streama dados. Nenhum dos dois aplica esforço ou muda body/hand/camera.
- O caminho de preparação do harness seleciona explicitamente cenário/variante antes da medição. Grava A/B, feet/feedback, fonte real versus scripted, Hz, bindings, estado inicial e identidade. Preparação não é apresentada como percurso físico.
- O observer novo calcula COM como `direct.transform.origin + direct.center_of_mass`, adequado ao offset mundial Jolt, e conserva body origin separado. A velocidade de ponto contém `v + omega × (point−COM)`.
- As forças dos contactos vêm dos vetores admitidos pelo controller, não do pedido de input; `applied` e `assisted` permitem impedir crédito a caches de mão/pé durante ownership híbrida. São medições parciais de forças, não energia completa do sistema.
- O recorder chama métricas por tick e pode escrever samples a20Hz; métricas agregadas não usam apenas os samples escritos. O ring do acumulador é limitado e as linhas são streamadas para disco.
- Retenção é emitida depois de um intervalo contínuo no mesmo anchor, distinta de SUCCESS/contact. Observação não autoriza novas pegas.

## Achados comunicados à raiz

1. Na versão lida, `finish()` só restaurava flags globais de observer/journal quando `_watched == app.controller`. Após R/substituição de controller, isso podia deixar instrumentação ON. O reset pode abandonar o corpo antigo sem abandonar a reposição das opções globais da sessão.
2. A assinatura de configuração incluía profile/A/B/feet/feedback/Hz/level ID, mas não todos os flags de distant/buffer/advisory/postura/hybrid/vault registados na metadata. Uma comparação não deve aceitar alteração desses flags durante a mesma tentativa sem a identificar.
3. T10 `material_tracking` tinha conclusão por duração+alguma mão no fim, sem avaliar `anchor_error_m` ou continuidade do contacto material. Essa condição é evidência de duração, não certificação de tracking. `fixed/dynamic` também precisava ser uma escolha realmente aplicada ou uma condição manual cuja realização fosse verificada.
4. O campo `saturated` inicial representava só aproximação ao orçamento de mãos360N. Deve ser rotulado como tal ou incluir explicitamente os restantes limites se chamado global. A métrica pura não deduz essa semântica.
5. Os contactos iniciais fornecidos eram mãos+pés. A fração de carga dos pés exclui ground nesse caso; o trabalho exclui ground/torques não fornecidos. Esse scope deve acompanhar o resultado.
6. A metadata Hz não configura automaticamente o acumulador: `options.physics_hz=info.physics_hz` permite a verificação time/tick do fluxo real. A tarefa precisa passar `target_progress_m`/corredor quando quiser overshoot/settling espacial.
7. Onset inferido de `movement_intent_world` pode estar depois do filtro. Está explicitamente identificado como `first_observed_nonzero_intent`; para latência desde aceitação de input, o harness pode emitir `command_onset` antes do filtro com tempo/tick/velocidade reais.

Os pontos foram enviados diretamente à raiz para correção/rotulagem. Os testes de integração, overhead OFF/ON, export, soak e inspeção de warnings do editor são responsabilidade da raiz; não foram substituídos por esta revisão.

## Limites que continuam a importar

Mesmo com correção das métricas, uma execução scripted de8 segundos não prova agência humana, aprendizagem ou energia limitada para sempre. Um contacto escolhido por B2 não prova ganho de locomoção. Um top-out assistido é ownership cinemática certificada, não trabalho físico gerado pelas mãos. O caso inclinado novo de B2 e as regressões A1 permanecem resultados adversos reais; não foram alterados os seus mecanismos para melhorar a apresentação.
