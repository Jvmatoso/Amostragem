# CLAUDE.md — Trabalho Final ME430 (Técnicas de Amostragem)

Projeto acadêmico em R + R Markdown (IMECC/Unicamp, 2º semestre de 2026, grupo de até 4 pessoas).
O enunciado completo do professor está em `docs/enunciado.md`: **seguir sua estrutura de relatório e suas regras do .Rmd** (set.seed, R inline, legendas, referências cruzadas, rótulos de chunk, entrega). Este arquivo traz o que o enunciado não diz. O livro-base (Bolfarine & Bussab) **não está no repositório**; o essencial está em "Base conceitual". Não inventar citações, páginas ou fórmulas atribuídas ao livro.

## Problema
**Pergunta:** com orçamento limitado, qual plano amostral estima melhor a **taxa de abstenção** no 1º turno de 2022 no estado de SP?

- Trabalho **metodológico e politicamente neutro**: nenhum candidato ou partido é analisado.
- Dados públicos e agregados por seção, sem dados pessoais (dizer isso no relatório).
- **Por que amostrar se a população é conhecida:** cenário controlado, previsto no enunciado. Supomos que obter cada seção tem custo e que só o orçamento limita a amostra. A população completa serve de **gabarito**.
- Duas frentes:
  1. **Amostra oficial:** um sorteio por plano, semente fixa, no orçamento de referência. Estimativa, variância estimada e IC 95%, comparados ao gabarito.
  2. **Monte Carlo:** B réplicas por plano e orçamento para avaliar viés, variância, EQM e cobertura.

## Definições
- **População-alvo:** todas as seções eleitorais de SP no 1º turno de 2022 (02/10/2022).
- **Sistema de referência (quadro):** cadastro de seções do arquivo do TSE "Detalhe da votação por seção".
- **População amostrada:** seções do quadro após os filtros (UF = SP, turno 1, um único cargo). Registrar critérios e quantas seções saíram em cada filtro.
- **UE / unidade respondente:** seção eleitoral / seu registro no arquivo do TSE. Na prática, seção **principal**: as 555 seções agregadas de SP em 2022 não têm linha própria (seus eleitores entram na principal); ver registro de 2026-11-05.
- **Instrumento de coleta:** o script de extração (`R/preparar-dados.R` + função que busca os valores das seções sorteadas). "Coletar" = extrair do TSE os valores das seções sorteadas, depois do sorteio.
- **Variáveis por UE:** aptos, comparecimento, abstenções (2022); abstenções e aptos de 2018 (auxiliar); município, zona, região.
- **Parâmetro principal:** R = Σ abstenções / Σ aptos.
- **Secundários (extra, só tabela):** proporção de brancos e de nulos sobre o comparecimento.
- **Auxiliar:** abstenção de 2018 na mesma seção (pareamento por município + zona + seção). Seções sem par = falha de cobertura (erro não amostral).

## Custo e orçamento
Os planos são comparados **a custo igual**, não a n igual.
- **Modelo:** C = c₁·(nº de municípios distintos na amostra) + c₂·(nº de seções), com c₁ > c₂. Hipóteses justificadas no relatório; sensibilidade com c₁/c₂ ∈ {5, 10, 20}.
- **Orçamentos:** custo esperado de uma AAS com n = 200, 400 e 800 (referência: 400). Os outros planos têm tamanho ajustado para o mesmo custo esperado.
- **Margem de erro a priori:** calcular para cada orçamento com a variabilidade de **2018** como proxy, antes de olhar 2022.

## Planos a comparar
1. **AAS** de seções.
2. **Estratificada** por região: alocação proporcional vs. Neyman.
3. **Conglomerados em 2 estágios:** municípios (UPA, PPT pelo nº de aptos) → seções (AAS na UPA). Variar nº de UPAs (m) vs. seções por UPA (k) a custo fixo.
4. **Estimador de razão com auxiliar** (abstenção de 2018). R já é uma razão de totais; "razão" no plano 4 se refere ao auxiliar. Deixar a distinção clara no texto.

## Estimadores e variâncias (referência; conferir notação antes de escrever)
Notação: yᵢ = abstenções, xᵢ = aptos, zᵢ = abstenções de 2018, f = n/N, wᵢ = 1/πᵢ.

- **Geral:** R̂ = Σ wᵢ yᵢ / Σ wᵢ xᵢ. Linearização: dᵢ = yᵢ − R̂ xᵢ; Var̂(R̂) = Var̂(Σ wᵢ dᵢ) / X̂², com a variância do total calculada pelo plano.
- **AAS:** R̂ = ȳ/x̄; Var̂(R̂) = (1 − f) s²_d / (n x̄²), s²_d = Σ dᵢ² / (n − 1).
- **Estratificada (razão combinada):** R̂ = Σₕ Nₕ ȳₕ / Σₕ Nₕ x̄ₕ; Var̂(R̂) = Σₕ Nₕ² (1 − fₕ) s²_{d,h} / nₕ / X̂².
- **Neyman:** nₕ ∝ Nₕ Sₕ, com Sₕ calculado em **2018** (ou piloto). Nunca usar 2022. Como o parâmetro é uma razão, Sₕ é o desvio-padrão de dᵢ = zᵢ − R₂₀₁₈ · aptos₂₀₁₈,ᵢ no estrato, não o da abstenção bruta.
- **2 estágios, PPT com reposição no 1º estágio (Hansen–Hurwitz), se adotado:** pᵢ = Mᵢ/M (Mᵢ = aptos do município); Ŷᵢ = (Nᵢ/kᵢ) Σⱼ yᵢⱼ; Ŷ = (1/m) Σᵢ Ŷᵢ/pᵢ; Var̂(Ŷ) = Σᵢ (Ŷᵢ/pᵢ − Ŷ)² / [m(m − 1)]. Aplicar a Ŷ e X̂ e linearizar para R̂.
- **Plano 4:** usar Z (total de 2018, conhecido no subconjunto pareado), ex.: Ŷ_R = (Ŷ/Ẑ)·Z. Forma exata depende das decisões em aberto.
- **Probabilidades e pesos (documentar):** AAS π = n/N; estratificada πₕ = nₕ/Nₕ; 2 estágios π ≈ m·pᵢ·kᵢ/Nᵢ (exato conforme o esquema).
- **"Erro técnico":** se uma variância usar fórmula mais simples que o plano (com reposição, sem fpc), informar e discutir a distorção.
- Validar as funções próprias contra o pacote `survey` numa amostra pequena.

## Métricas
- Viés, variância, EQM, cobertura do IC 95%, deff em todos os planos; correlação intraclasse **só no plano 3**.
- Distinguir **variância verdadeira** (empírica entre réplicas) de **variância estimada** (fórmula em cada amostra). A cobertura depende da estimada.
- B: começar com 1.000 e checar a estabilidade do EQM. **Bootstrap fora do escopo.**
- **Regra anti-vazamento:** funções de estimação recebem só a amostra e totais auxiliares conhecidos. O gabarito só entra na avaliação.

## Dados
- Fonte: Portal de Dados Abertos do TSE (dadosabertos.tse.jus.br), "Detalhe da votação por seção", 2022 e 2018. Padrão de link: `https://cdn.tse.jus.br/estatistica/sead/odsele/...` (conferir no portal). Alternativa: pacote `electionsBR` (conferir a documentação da versão instalada).
- Separador `;`, Latin-1, arquivos grandes: `data.table::fread()` com `select =`.
- **Atenção:** o arquivo costuma repetir cada seção por cargo. Filtrar um cargo e o turno antes de agregar. Conferir nomes das colunas no layout do TSE antes de escrever o código.
- **Consistência (rodar e registrar):** aptos = comparecimento + abstenções; brancos + nulos ≤ comparecimento; duplicatas; ausentes; total de aptos de SP comparado com outra tabela do TSE.
- **Fluxo:** `R/preparar-dados.R` gera `dados/secoes-sp-2022.csv` (uma linha por seção, com o auxiliar de 2018) e `dados/dicionario.csv` (nome, descrição, unidade, origem). O `.Rmd` lê **apenas** `dados/` e `resultados/`. Nunca editar o CSV à mão.
- `dados-brutos/` está no `.gitignore`. Se `dados/secoes-sp-2022.csv` passar de ~50 MB, avisar antes de commitar (limite do GitHub: 100 MB por arquivo) e propor alternativa (ex.: `.csv.gz`, que `fread` lê direto).

## Estrutura
A estrutura abaixo já foi montada a partir do `template.zip` (o `output:` é `bookdown::html_document2`, então `\@ref` funciona). **Não reorganizar sem perguntar.**
```
template.Rproj          # do template (não renomear)
relatorio.Rmd           # era template.Rmd no zip do professor; renomeado
_bookdown.yml           # do template: rótulos "Figura "/"Tabela " em português. ENTREGAR
referencias.bib         # do template (Bolfarine & Bussab 2005; Cochran 1977)
CLAUDE.md, docs/        # não entregar (mas ficam no git)
docs/enunciado.md       # enunciado do professor
docs/registro.md        # diário de decisões e ocorrências (ver "Registro")
R/
  config.R              # SEMENTE, B, orçamentos, C1, C2, caminhos (já criado)
  preparar-dados.R      # download + limpeza + pareamento (roda uma vez)
  planos.R              # seleção de cada plano
  estimadores.R         # estimativas e variâncias
  priori.R              # desenhos a custo igual + margem a priori (2018)
  validar-survey.R      # validação contra o survey e do custo realizado
  simulacao.R           # amostra oficial + Monte Carlo
  secundarios.R         # brancos e nulos na amostra oficial (extra)
dados/                  # secoes-sp-2022.csv, dicionario.csv
resultados/             # amostra-oficial.rds, simulacao.rds (o .Rmd lê, não refaz)
dados-brutos/           # não entregar; no .gitignore
app/                    # Shiny (opcional)
```
O zip original do professor trazia `__MACOSX/` e `.Rproj.user/`: são lixo do macOS/RStudio, ficam no `.gitignore` e nunca entram na entrega.

**Código dentro do .Rmd.** O template diz: "Se você utilizou algum software, o código deve estar contido neste .rmd (echo=FALSE)". Por isso o `relatorio.Rmd` tem um apêndice (`# (APPENDIX) Apêndice {-}`) que exibe cada script de `R/` com `{r codigo-xxx, file="R/xxx.R", eval=FALSE, echo=TRUE}`. O código aparece no relatório sem ser executado de novo. Se criar um script novo em `R/`, acrescentar o chunk correspondente no apêndice. Chunks de análise no corpo continuam com `echo=FALSE` (padrão do setup).

```bash
Rscript R/preparar-dados.R
Rscript R/priori.R
Rscript R/validar-survey.R
Rscript R/simulacao.R
Rscript R/secundarios.R
Rscript -e 'rmarkdown::render("relatorio.Rmd")'
```
Rodar a partir da raiz. Só caminhos relativos.

**Pacotes:** `data.table`, `dplyr`, `survey`, `srvyr`, `sampling`, `samplingbook`, `TeachingSampling`, `ggplot2`, `knitr`, `bookdown`; Shiny: `shiny`, `bslib`.

## Complementos às regras do .Rmd
- Semente única: `SEMENTE` em `R/config.R` (`RNGkind("L'Ecuyer-CMRG")` se paralelizar). O chunk `setup` do `.Rmd` faz `source("R/config.R")` e `set.seed(SEMENTE)`; o `set.seed(42)` original do template foi removido. Scripts estocásticos (`simulacao.R`) chamam `set.seed(SEMENTE)` antes de sortear.
- Valores de configuração (n, B, c₁, c₂) também vêm de `config.R` via R inline. Anos e datas podem ser digitados.
- Rótulos com prefixo `fig-` ou `tab-`, e o prefixo aparece na citação: `{r fig-distribuicao-abstencao}` → `\@ref(fig:fig-distribuicao-abstencao)` (mesmo padrão do exemplo do template, `tab-resumo-estatistico`). Sem underscore em rótulos.
- O YAML já usa `bookdown::html_document2`; não trocar o formato sem perguntar.
- Os exemplos genéricos do template (`simulacao-exemplar`, `tab-resumo-estatistico`, `fig-distribuicao-amostral`) servem de modelo; remover quando o conteúdo real entrar. Os comentários `<!-- -->` com as perguntas do enunciado ficam até a seção estar escrita, para conferir que cada pergunta foi respondida.
- Autores e RAs no YAML: deixar os placeholders; o grupo preenche.

## Base conceitual (Bolfarine & Bussab, 1.6–1.10)
- **Itens mínimos do relatório (1.10):** propósitos, populações, sistema de referência, unidades amostrais, plano de seleção, procedimento de coleta, desempenho da amostra (planejado vs. obtido, perdas), tamanho, sistema de ponderação, fórmulas dos erros amostrais e efeito dos erros não amostrais. Separar descritivo da amostra de inferência para a população.
- **Erros não amostrais (1.9.2):** para cada um, (i) etapa, (ii) causas, (iii) correção, (iv) efeito. Aqui: cobertura (seções sem par), comissão (seções indevidas no quadro), inconsistências na base. O gabarito sai da mesma base, então erro de medição nela não é detectável.
- **Plano tabular a priori (1.8):** `tab-amostra-oficial` (estimativa, EP, IC, gabarito por plano); `tab-desempenho-planos` (viés, variância, EQM, cobertura, deff por plano e orçamento); `fig-eqm-custo`; `fig-m-vs-k`; `fig-distribuicao-estimativas` (com linha no gabarito).
- **Registro (1.6):** anotar decisões, ocorrências e desvios do plano à medida que acontecem; alimentam a seção "o que realmente foi feito". **Sempre que uma decisão for tomada ou algo inesperado acontecer (filtro que removeu seções, link do TSE diferente, % de pareamento, mudança de fórmula), acrescentar uma linha datada em `docs/registro.md`** no formato indicado lá. Não reescrever linhas antigas.

## Decisões em aberto (perguntar ao usuário antes de implementar)
Há uma sugestão para cada item, mas **nada está decidido**: confirmar com o usuário, registrar em `docs/registro.md` e então mover o item para "Decisões tomadas".
- Nenhuma no momento.

## Pendências para verificar adiante
- Nenhuma. As três da etapa 6 (margens a priori, Neyman atrás da proporcional, EP do plano 4 igual ao da AAS) foram resolvidas no Monte Carlo; causas e números em `docs/registro.md` (2026-11-05).
- Etapa 7: relatório escrito (aguarda revisão do grupo); faltam os slides (`slides/apresentacao.Rmd` → .pptx, fora do zip) e o teste do zip depois que nomes e RAs forem preenchidos.
- Compilar fora do RStudio exige `RSTUDIO_PANDOC="C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools"` (o pandoc não está no PATH).

## Decisões tomadas
- **Monte Carlo** (2026-11-05): 66 tarefas × B = 1.000 (grade 5 planos × 3 orçamentos × 3 cenários de custo + curva de m do plano 3 no orçamento 400). Um fluxo L'Ecuyer-CMRG por tarefa a partir de `SEMENTE` (resultado independe de `N_NUCLEOS`); a amostra oficial segue no gerador padrão. Saída: `resultados/simulacao.rds` (réplicas, `resumo`, `estabilidade`, diagnósticos). Figuras e tabelas finais ficam para a etapa 7.
- **Plano 3, par (m, k)** (2026-11-05): "melhor a priori", o (m, k, k_SP) de menor margem a priori em cada orçamento e cenário (`plano3_escolhido` em `resultados/desenho.rds`; grade de m até 500). Central: 200 → 120 × 2; 400 → 160 × 4 (amostra oficial); 800 → 350 × 3. O Monte Carlo inclui também uma curva de m no orçamento 400 (`fig-m-vs-k`).
- **Plano 3, capital e grade m × k** (2026-11-05): k_SP proporcional à fatia de aptos da capital (±5 p.p.); k comum fora da capital; subamostra independente por sorteio. Ver `docs/registro.md`.
- **Plano 4** (2026-11-05): AAS no pareado, Ŷ_R = (ȳ/z̄)·Z, R̂ = Ŷ_R / X_pareado; avaliado contra gabarito pareado e total.
- **Capital na estratificada** (2026-11-05): município de São Paulo **não** é estrato próprio (ganho desprezível em 2018: 0,959 → 0,957); estratos = 11 regiões intermediárias.
- **Seções sem par em 2018** (confirmado em 2026-11-05): tratadas à parte. Plano 4 no subconjunto pareado (94,48% das seções de 2022, 94,88% do eleitorado); as sem par são discutidas como erro de cobertura, sem imputação. Ver `docs/registro.md`.
- **Estratos** (2026-11-05): regiões geográficas intermediárias do IBGE (justificativa: divisão oficial, fácil de defender). Confirmar com 2018 que a abstenção varia mais entre regiões do que dentro delas.
- **PPT no plano 3** (2026-11-05): 1º estágio com reposição, estimador de Hansen–Hurwitz e sua variância. Declarar no relatório que é uma aproximação do sorteio sem reposição ("erro técnico") e discutir a distorção. O município de São Paulo (27,4% dos aptos) é **autorrepresentativo**: entra com certeza (π = 1 no 1º estágio, AAS de seções dentro dele); o PPT com reposição é feito só entre os demais municípios. O total estimado é a soma das duas partes, e a variância também (sorteios independentes).
- **Total de aptos de 2022** (2026-11-05): tratado como conhecido em todos os planos (o plano 3 já o usa como medida de tamanho). Estimador padrão: razão R̂ = Σ wᵢ abstenções / Σ wᵢ aptos da amostra.
- **Custos** (2026-11-05): c₂ = 1, c₁ = 10 no cenário central; sensibilidade c₁/c₂ ∈ {5, 20}. Justificativa: visitar um município custa o equivalente a obter 10 seções.

## Ordem de trabalho
1. Teste de pareamento 2018 ↔ 2022 (maior risco; reportar % pareado).
2. `preparar-dados.R`, consistência, dicionário e gabarito.
3. Fechar as decisões em aberto.
4. `planos.R` e `estimadores.R`, validados contra o `survey`.
5. Amostra oficial.
6. Monte Carlo.
7. Relatório e slides (10 min).
Se o prazo apertar, o plano 4 vira seção menor. Extras por último: brancos/nulos, Shiny.

## Como trabalhar nesta pasta
- Uma etapa da "Ordem de trabalho" por vez. Antes de escrever código de uma etapa, apresentar um plano curto e esperar aprovação.
- Ao terminar uma etapa: rodar o que foi feito, mostrar a saída que comprova (tabela, contagem, comparação com `survey`), registrar em `docs/registro.md` e sugerir uma mensagem de commit.
- Não marcar uma etapa como concluída se algo falhou ou não foi verificado.

## Convenções
- Responder em português. Código R claro, reprodutível, comentado em português.
- Foco metodológico; escopo enxuto (um parâmetro principal, quatro planos, três orçamentos).
- Não inventar números, resultados ou referências. Todo número do relatório vem de código executado.
- Perguntar antes de baixar arquivos grandes ou mudar a estrutura do template.

## Entrega
- Compilar do zero em sessão limpa antes de zipar (`Rscript -e 'rmarkdown::render("relatorio.Rmd")'` num processo novo, sem objetos carregados).
- Zip: `relatorio.Rmd`, `template.Rproj`, `_bookdown.yml`, `referencias.bib`, `R/`, `dados/`, `resultados/` (e `app/`, se houver). Fora: `dados-brutos/`, `docs/`, `CLAUDE.md`, `.gitignore`, `.Rproj.user/`, `__MACOSX/`, `relatorio.html` e `relatorio_files/`.
- Testar o zip: descompactar numa pasta temporária, compilar lá e confirmar que roda sem erro.
