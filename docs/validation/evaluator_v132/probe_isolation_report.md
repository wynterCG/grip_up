# Instrumentação / isolamento

**DIAGNOSTIC_ONLY, não equivalência qualificada.** A matriz planeada de três
repetições por combinação foi interrompida. Os quatro diagnósticos diretamente
ligados ao gate não a substituem. A120Hz rendered há um ON/ON primário e um run
para cada um dos três toggles; n1 é descritivo, não demonstra invariância.

| Modo | Hz | Trace | Observer | PRE médio ms | POST médio ms | Wall s | Gap tick máximo ms | Retido |
|---|---|---|---|---|---|---|---|---|
| headless | 120 | ON | ON | 1.33247 | 1.35774 | 6.015 | 18.45 | True |
| headless | 120 | ON | ON | 1.28538 | 1.32879 | 5.969 | 15.509 | True |
| headless | 120 | ON | ON | 1.27726 | 1.33301 | 5.718 | 15.327 | True |
| rendered_scripted | 120 | ON | ON | 1.3743 | 1.31772 | 7.609 | 146.75 | True |
| rendered_scripted | 120 | OFF | ON | 0.424232 | 0.382951 | 7.829 | 153.502 | True |
| rendered_scripted | 120 | ON | OFF | 1.35478 | 1.2614 | 7.609 | 154.93 | True |
| rendered_scripted | 120 | OFF | OFF | 0.403734 | 0.337955 | 7.609 | 157.493 | True |
| rendered_scripted | 60 | ON | ON | 1.56533 | 1.36933 | 7.39 | 36.352 | False |


PRE mede reader/pre-snapshot, emissão de inputs e serialização PRE. POST usa o
contador original, que inclui snapshot/event derivation/serialização POST antes
da continuação. Custo do controller/solver/observador original não é isolado por
esses contadores. Wall inclui processo e postprocessamento, não a compactação
lossless posterior. Render cadence máxima, frames e dt real estão em analysis.json
e nos resultados brutos. A backlog/pending steps não é exposta pela API usada;
max_physics_steps_per_frame não é uma medição dessa backlog.

TraceOFF não desliga o reader. ObserverOFF desliga a observação diagnóstica
original, mantendo monitor de segurança e audit compacto. Mesmo ambosOFF não é
simulação sem instrumentação; não retiramos segurança para melhorar o tempo.

Nos três toggles120, o desvio do cursor continuou no tick13; contacto437/438/437
e retenção525. Desligar estes componentes não eliminou o gate. Os tempos menores
de hook com traceOFF demonstram custo local, não a causa do alvo diferente nem
equivalência de inputs/contactos. O diagnóstico60 ON/ON falhou o contacto direito,
com alvo efetivo diferente e clock válido. Não há atribuição causal ao scheduler
do sistema operativo, à capturaPNG ou à frequência isoladamente.
