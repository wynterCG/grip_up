# v1.2 — checkpoint técnico, experiência interrompida

O utilizador pediu para parar a exploração e manter a melhor locomoção disponível: A0/B1. Nenhuma variante foi promovida e M7 não começou. Esta pasta preserva o trabalho técnico, incluindo resultados adversos; não constitui aceitação humana da v1.2.

- Nova suite opcional T01–T10 e três arenas de mastery; controladores físicos existentes preservados.
- Matriz antiga: 4 356 verificações / 139 execuções. Revalidação de integração: 738 / 20. Suite final: 308 / 8, em `automated/attempt_003/results.json`. Todas estas verificações técnicas passaram a 60/120 Hz.
- Capturas visíveis finais: `native/attempt_003/`; build ID `4302c858bfef02e6a6ead50b96401788953350494ce4e2f55482c22736dccf44`. Gráficos offline: `analysis/final_capture/index.html`.
- A captura parada de 600 s é de uma revisão anterior, identificada em `native/attempt_001/`: 12 307 amostras, buffers limitados, aproximadamente 167 KB de crescimento de memória estática. A instrumentação tem custo de CPU mensurável e permanece OFF no jogo normal.
- Windows UI smoke: `export/result.json`, 5/5; não é um percurso mastery completo na build exportada.
- [Estudo físico](physics/STUDY.md): A1 mantém regressões; B2 falha o benefício numa inclinação. [Mastery](mastery.md): viabilidade isolada demonstrada, robustez mista em execução sequencial; três arenas/checkpoints separados, não um mundo contínuo.
- Sessões humanas medidas: **zero**. Não há evidência nova de preferência, aprendizagem ou melhoria de feel. O protocolo humano e o relatório consolidado planeados ficaram por concluir quando o utilizador interrompeu a fase.

O relatório v1.1 em `baseline/v11_report.md` é uma cópia literal histórica de `docs/validation/v11/report.md`; os links relativos devem ser consultados no original. O tag `baseline/pre-v1.2-tests` permite recuperar a versão anterior à suite.
