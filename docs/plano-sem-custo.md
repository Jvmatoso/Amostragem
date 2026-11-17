# Plano: retirar o modelo de custo e comparar os planos a n igual

Decidido pelo grupo em 2026-11-17. Este arquivo é o **documento de passagem** entre as sessões.
Cada sessão executa **uma etapa**, na ordem, e só começa depois que a anterior foi commitada.

## Por que mudar
O modelo de custo (C = c₁·municípios + c₂·seções) não tem base real. A abstenção só existe depois
da votação, e o TSE divulga tudo de uma vez. Ninguém coleta seção por seção, então não há
"custo de visitar um município" para defender diante da banca. A partir de agora os planos são
comparados com o **mesmo número de seções n**.

**Consequência esperada (a confirmar no Monte Carlo):** a conclusão muda. A custo igual, o plano
em dois estágios vencia porque comprava mais seções. A n igual, ele deve ficar **atrás** da AAS:
no Monte Carlo antigo, o deff de Kish dele foi de 1,11 a 2,05. AAS e estratificadas devem ficar
empatadas: a n igual, Neyman e proporcional já tinham a mesma variância, ver registro de
2026-11-05. O plano 4 continua com o viés de cobertura. Nenhum desses números pode ir para o
relatório antes de sair do código novo.

## Decisões
**Tomadas (2026-11-17):**
- Tamanhos n = 200, 400 e 800 seções, iguais para todos os planos; referência n = 400 (amostra oficial).
- Sem cenários de custo: some a grade c₁/c₂ ∈ {5, 10, 20} e a métrica "eficiência a custo igual".
- Métrica de comparação: **eficiência relativa** = EQM da AAS com o mesmo n / EQM do plano, mais
  o deff de Kish, que já é calculado a n igual.
- O número de municípios distintos na amostra continua registrado, só como descrição (sem custo).
- Continua tudo o que não depende de custo: semente 430, B = 1.000, estratos (11 regiões
  intermediárias), capital autorrepresentativa e Hansen–Hurwitz no plano 3, plano 4 no pareado,
  total de aptos conhecido, regra anti-vazamento, validação contra o `survey`.

**Em aberto (perguntar ao usuário no início da etapa 1, antes de qualquer código):**
- **k do plano 3** (seções por município sorteado, fora da capital). Sem custo, a margem a
  priori é sempre menor com k = 1, o que praticamente desfaz o conglomerado.
  - Recomendação: **k fixo = 4** em todos os n, mais uma curva com k ∈ {1, 2, 4, 8} em n = 400
    (substitui a curva de m da `fig-m-vs-k`).
  - Alternativa: k de menor margem a priori com 2018 (provavelmente k = 1).

Registrar a resposta em `docs/registro.md` e no CLAUDE.md ("Decisões tomadas").

## Etapa 1: código (`R/`)
Mudanças:
- `R/config.R`: remover `C1`, `C2`, `RAZAO_C1_C2` e `RAZOES_SENSIBILIDADE`. Renomear
  `N_AAS_ORCAMENTO` → `N_TAMANHOS` e `N_AAS_REFERENCIA` → `N_REFERENCIA`. Acrescentar `K_PLANO3`
  e `K_CURVA` conforme a decisão sobre k.
- `R/planos.R`:
  - Remover `custo_aas`, `orcamento`, `resolver_n`, `custo_estrat`, `custo_plano3`,
    `grade_plano3` (por custo) e os `dimensionar_*` por orçamento.
  - `desenhar(n, d, qm)` passa a devolver o desenho de cada plano para n seções:
    - AAS: n.
    - Estratificadas: `alocar(n, ...)`, conferindo que Σ nₕ = n.
    - Plano 3: k_SP = round(fatia de aptos da capital em 2022 × n), cerca de 26,9%; k comum
      fora da capital; m escolhido para que k_SP + m · E[min(k, Nᵢ)] fique o mais perto possível de n.
    - Plano 4: n seções no pareado.
  - `custo_realizado` vira (ou é trocada por) uma contagem de municípios distintos.
- `R/priori.R`: margens a priori com 2018 para cada n e plano; no plano 3, também para cada k de
  `K_CURVA` em n = 400. Saídas: `resultados/desenho.rds` e `resultados/margem-priori.csv`.
- `R/validar-survey.R`:
  - Manter a parte (a), a comparação com o `survey`.
  - Trocar a parte (b), custo realizado contra orçamento, por uma checagem de que o n realizado
    médio bate com o n planejado.
  - Apagar `resultados/validacao-custo.csv`.
- `R/simulacao.R`:
  - Tarefas: grade com 5 planos × 3 n, mais a curva de k do plano 3 em n = 400. Manter o esquema
    de fluxos L'Ecuyer-CMRG por tarefa, em ordem fixa.
  - Trocar `eficiencia_custo` por `eficiencia`.
  - Retirar o diagnóstico da Neyman por custo marginal. Manter a comparação Neyman × proporcional.
  - Tirar `razao_c1_c2` e `orcamento` das tabelas.
- `R/estimadores.R` e `R/secundarios.R`: não devem precisar de mudança (conferir).

Verificação, com a saída mostrada ao usuário:
- `Rscript R/priori.R` e `Rscript R/validar-survey.R` rodam sem erro. O EP e a estimativa
  continuam idênticos aos do `survey`, e o n realizado bate com o planejado.
- Teste rápido da simulação com B = 20 (sem gravar em `resultados/simulacao.rds`), em 1 e em 3
  processos: as réplicas devem ser idênticas.
- `grep -n -i "custo\|orcamento\|orçamento\|c1\|c2" R/` não deve achar sobras, salvo um
  comentário explicando a retirada.

Não mexer em `relatorio.Rmd` nem em `slides/`: eles quebram até as etapas 3 e 4, e isso é
esperado. Commit sugerido: `Etapa 8.1: planos dimensionados por n, sem modelo de custo`.

## Etapa 2: resultados
- Rodar, nesta ordem: `Rscript R/priori.R`, `Rscript R/validar-survey.R`, `Rscript R/simulacao.R`
  (o Monte Carlo inteiro, em segundo plano) e `Rscript R/secundarios.R`.
- Conferir:
  - Estabilidade do EQM com B = 1.000 (como em 2026-11-05).
  - Variância estimada / verdadeira e cobertura por plano.
  - Viés do plano 4 contra os gabaritos pareado e total.
  - Margens a priori contra a variância empírica.
- Mostrar a tabela de desempenho a n igual: viés, REQM, cobertura, deff e eficiência por plano e n.
- Registrar os números em `docs/registro.md`, sem reescrever linhas antigas.
- Commit sugerido: `Etapa 8.2: amostra oficial e Monte Carlo a n igual`.

## Etapa 3: relatório (`relatorio.Rmd`)
Pode rodar em paralelo com a etapa 4, porque as duas mexem em arquivos diferentes. Pontos a mudar:
- **Resumo** e **pergunta de interesse**: tirar "orçamento limitado" e "custo". A pergunta passa
  a ser qual plano estima melhor a abstenção com n seções.
- **"Custo e tamanho da amostra"** e `tab-desenho-priori`: justificar n pela margem de erro a
  priori de 2018. O enunciado (item 4.1) pede um "tamanho de amostra factível" e a margem
  esperada. Dizer com franqueza que o cenário é controlado, sem coleta real, e que n é escolhido
  pela precisão.
- **Delineamento**:
  - Tirar "mesmo orçamento".
  - Plano 3: explicar por que ainda se estuda o conglomerado, que é comum quando a coleta é
    concentrada geograficamente. Mostrar que, sem economia de custo, a correlação intraclasse
    só faz perder.
  - Atualizar `tab-probabilidades` com os novos m e k.
- **Execução**: tirar a frase "custo médio realizado ficou a no máximo …".
- **Registrar o desvio do plano**: a seção "o que realmente foi feito" (Bolfarine & Bussab 1.6)
  deve contar que o modelo de custo foi abandonado e por quê.
- `tab-amostra-oficial`: tirar a coluna Custo e manter Seções e Municípios.
- **Métricas do Monte Carlo**: trocar "eficiência a custo igual" por "eficiência relativa".
- Figuras e tabelas:
  - `fig-eqm-custo` vira `fig-eqm-n`, com o REQM em função de n.
  - `tab-sensibilidade-custo` sai.
  - `fig-m-vs-k` vira a curva de k a n = 400.
  - Atualizar as citações `\@ref`.
- **Considerações finais**: reescrever com a conclusão nova.
- **Apêndice**: os chunks de código continuam, porque os arquivos de `R/` têm os mesmos nomes.
- Compilar em processo novo:
  `RSTUDIO_PANDOC="C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools" D:/R-4.5.1/bin/Rscript.exe -e 'rmarkdown::render("relatorio.Rmd")'`.
  Conferir 0 referências quebradas e que toda tabela e figura é citada.
- `grep -n -i "custo\|orçamento\|c_1\|c1"` no `.Rmd` só pode achar o trecho sobre a mudança de plano.
- Commit sugerido: `Etapa 8.3: relatório a n igual, sem custo`.

## Etapa 4: slides (`slides/`)
Usar a skill `pptx`. O `gerar-slides.js` precisa de `NODE_PATH` (com o `pptxgenjs`) e de
`PPTX_SKILL` (o diretório da skill), como diz o cabeçalho do arquivo.
- `slides/extrair-numeros.R`: tirar `razao_c1_c2`, `orcamento`, `custo` e `eficiencia_custo`;
  ler a curva de k; gerar o boxplot em n = 400.
- `slides/gerar-slides.js`:
  - Remover o slide 4 (custo) e o 16 (sensibilidade ao custo).
  - Reescrever a capa e o slide 2 (sem "orçamento limitado").
  - Slide 6: "Quatro planos, mesmo n".
  - Slide 8: dois estágios sem "barateia a seção".
  - Slides 11 e 12: tabela sem custo.
  - Slide 15: REQM por n.
  - Slide 17: curva de k.
  - Slide 18: conclusões novas.
  - Atualizar as notas do orador de cada slide alterado.
- Manter os ajustes já pedidos pelo grupo (registro de 2026-11-17): nomes só na capa, orador nas
  notas, sem slides de transição, grafia "Matheus Pierri".
- Gerar o `slides/apresentacao.pptx`, renderizar os slides em imagem e conferir visualmente
  (texto cortado, gráfico vazio).
- Commit sugerido: `Etapa 8.4: slides a n igual, sem custo`.

## Como abrir cada sessão
Na raiz do projeto, pedir:
> Leia `docs/plano-sem-custo.md` e execute a etapa N. Siga o CLAUDE.md.

Depois de cada etapa, conferir a saída, commitar e só então abrir a próxima.
