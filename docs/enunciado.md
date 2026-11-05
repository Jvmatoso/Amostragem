# Enunciado — Trabalho Final ME430 (Técnicas de Amostragem)

> Texto do enunciado do professor, transcrito para consulta. Em caso de dúvida, vale o original no Moodle.

## 1. Propósito
O projeto deverá envolver:
- o desenvolvimento de um plano amostral para um problema de estimação no qual amostragem seja uma ferramenta adequada a ser utilizada;
- seleção de uma amostra seguindo o plano amostral proposto;
- coleta de dados apropriados a partir da amostra;
- aplicação de fórmulas apropriadas para produzir todas as estimativas e respectivas variâncias necessárias para o problema escolhido;
- um relatório descrevendo os métodos e resultados;
- apresentação em classe.

## 2. Grupos
Os grupos devem ser indicados no Moodle, respeitando o limite de no máximo 4 membros por grupo.

## 3. Tópicos para o projeto
Um projeto apropriado seria qualquer problema onde a teoria de amostragem é uma ferramenta lógica adequada para estimar alguma característica de uma população real. Deve-se, no entanto, considerar um problema que possa ser finalizado até o final do semestre.

É possível usar simulação de dados e propor diferentes planos amostrais. Nesse caso, vocês devem propor diferentes planos amostrais em cenários controlados e compará-los (avaliando viés, variância, erro quadrático médio, etc.). O grupo pode desenvolver um aplicativo interativo usando Shiny (em R).

## 4. Relatórios e Notas
Cada projeto será avaliado baseando-se na apresentação do seminário e no conteúdo do relatório em que o problema de amostragem/estimação e os métodos utilizados estejam descritos com detalhes suficientes para serem avaliados e em que as conclusões da pesquisa sejam apresentadas. Resumindo, o grupo deve preparar:

- **Relatório:** uma descrição da população amostrada, do problema de estimação, do plano amostral e da estratégia de estimação. Uma descrição do que realmente foi feito com relação à amostragem e à coleta de dados, além das conclusões da pesquisa. Esta parte corresponderá a **80%** da nota referente ao projeto. Caso o grupo desenvolva um Shiny App, o relatório deverá conter os detalhes da metodologia utilizada e um manual de uso.
- **Apresentação:** uma apresentação (**máximo 10 minutos**) do problema considerado, métodos usados para amostragem, estimação, e conclusões finais. Esta parte corresponderá a **20%** da nota referente ao projeto. Todo o grupo deve estar presente em todas as apresentações.

A nota do Relatório e da Apresentação será a mesma para todos os membros de um mesmo grupo, mas a nota do aluno poderá ser diferente de acordo com a presença nos 3 dias de apresentação:

Nota do aluno i = 0,8 × Relatório + 0,2 × Apresentação × (total de presenças do aluno i nos 3 dias de apresentação / 3)

*(Fórmula reconstruída a partir do texto original; confirmar no Moodle.)*

Os relatórios devem conter informações sobre todos os tópicos listados a seguir.

### 4.1 Planejamento Metodológico

**Definição do problema**
- Qual a pergunta de interesse? O que será estimado neste projeto?
- Qual a população a ser amostrada? (Defina explicitamente o critério de inclusão de uma UE na população alvo e na população amostrada. Se você planeja coletar a amostra ao longo do tempo, não se esqueça de incluir a data/período na sua definição de população alvo e na população amostrada. Por exemplo, pessoas visitando uma loja num período de dois dias.)
- Qual é a UE desse projeto?
- Quais medidas/informações das UEs serão coletadas?
- Baseando-se no "custo" do seu tamanho amostral (tempo disponível do seu grupo para amostragem e coleta de dados), qual seria um tamanho de amostra factível? Qual margem de erro você espera para suas estimativas?

**Delineamento Amostral**
- Descreva seu plano amostral proposto de maneira concisa.
- Estratificação será empregada para seleção da amostra? Se sim, como e com qual propósito?
- Utilizará amostra por conglomerados? Quantos estágios?
- Defina a UE e como ela será selecionada.
- A probabilidade de amostragem será a mesma para cada UE da amostra? Caso não seja, descreva como calcular a probabilidade de seleção para cada UE.
- Qual o tamanho da amostra e como ela será alocada entre os estratos e estágios amostrais? No que você se baseará para fazer as decisões de alocação da amostra?

**Protocolo de Coleta e Métodos de Estimação**
- Como as observações serão coletadas?
- Descreva seu método de estimação do(s) parâmetro(s) populacional(is) e da variância associada às estimativas.

### 4.2 Execução e Resultados

**Amostragem**
- Quais os passos do procedimento que você acabou realmente utilizando para coletar sua amostra?
- Como esses procedimentos diferem (se for o caso) do plano amostral proposto originalmente?
- Você encontrou problemas ao coletar os dados? Se sim, descreva brevemente como você lidou com esses problemas.

**Coleta de dados**
- Como as observações/medidas foram feitas na amostra coletada?
- Houve algum problema de medição? Se sim, como você lidou com esses problemas?
- Quais suas considerações sobre o efeito de erros não amostrais na sua pesquisa?

**Análise e Estimativas Obtidas**
- Como o(s) parâmetro(s) populacional(is) foi (foram) estimado(s) (apresente a fórmula exata utilizada)?
- Como você estimou a variância associada à(s) estimativa(s) (apresente a fórmula exata utilizada)?
- Se você utilizou algum software, apresente em detalhes o código.

**Considerações Finais**
- Apresente as estimativas geradas a partir do estudo.
- Quão boas você as considera, levando em conta a precisão estatística e outros problemas que você suspeita ou pode detectar?

## 5. Sequência típica de decisões de um plano amostral
1. Definir explicitamente a população da qual se está retirando a amostra.
2. Qual é a UE?
3. Qual é a medida/observação de interesse obtida a partir da UE?
4. Estabeleça a hierarquia (com as UEs formando a base) na qual a amostra será coletada.
5. Decidir em quantos estágios e quais as UEs em cada estágio.
6. Quão grande será a amostra total?
7. Caso a amostra seja estratificada, explicar como isso será feito.
8. Como a amostra será coletada em cada estágio?
9. Como a amostra será escolhida em cada estrato amostral?
10. Quais serão os tamanhos amostrais/alocação entre estágios e/ou estratos?
11. Quão boas são as estimativas obtidas a partir do plano amostral proposto?

## 6. Instruções para Elaboração e Entrega dos Relatórios
Antes de iniciar a implementação das análises e a redação, é fundamental ler com atenção as seções 1.6 a 1.10 do livro Bolfarine & Bussab. Esse conteúdo servirá como embasamento metodológico e conceitual necessário para a execução e fundamentação do projeto.

- **Plataforma de entrega:** exclusivamente via Moodle.
- **Arquivos necessários:**
  - O arquivo principal do relatório obrigatoriamente no formato **.Rmd** (R Markdown).
  - Todos os arquivos auxiliares necessários para a compilação do relatório (conjuntos de dados .csv / .xlsx, imagens externas, scripts adicionais ou arquivos de bibliografia .bib).
- Verifique com cuidado as dependências de pacotes e os caminhos relativos para garantir que o documento execute sem erros em outro ambiente.
- Caso produzam Shiny app, enviar todos os códigos.
- Baixe o arquivo `template.zip` e abra no RStudio clicando no arquivo `template.Rproj`.
- Seu envio deve conter todos os arquivos necessários em uma pasta zipada.

Para assegurar a reprodutibilidade integral das análises, siga as diretrizes abaixo:

- **Reprodutibilidade de processos aleatórios (set.seed):** se o seu código utilizar funções que envolvam amostragem, simulações ou qualquer geração de números aleatórios (ex.: `sample()`, `rnorm()`, `runif()`), você deve definir a semente usando a função `set.seed()`. Garanta que a semente esteja devidamente configurada antes das rotinas estocásticas para que o código produza sempre os mesmos resultados.
- **Uso de R inline para valores numéricos no texto:** nenhum valor numérico resultante de cálculos, modelos ou estatísticas descritivas deve ser inserido manualmente no texto. Utilize código R inline para apresentar médias, desvios padrão, tamanhos amostrais, p-valores e demais métricas dinamicamente a partir dos objetos calculados nos chunks.
- **Legendas (captions) e referências cruzadas:** todas as tabelas e gráficos apresentados devem possuir legenda e ser formalmente citados ao longo do texto usando referências cruzadas.
- **Rótulos dos chunks:** nomeie cada chunk de gráfico ou tabela de forma única e sem o uso de underscores (`_`). Prefira hífens (`-`). Exemplos: `{r fig-distribuicao-idade}` ou `{r tab-resumo-estatistico}`.
- **Legendas:**
  - Gráficos: utilize a opção de chunk `fig.cap = "Sua legenda aqui"`.
  - Tabelas: defina a legenda no argumento da função de formatação (ex.: `knitr::kable(dados, caption = "Sua legenda aqui")`).
- **Referências cruzadas no texto:**
  - Gráficos/Figuras: `\@ref(fig:nome-do-chunk)`.
  - Tabelas: `\@ref(tab:nome-do-chunk)`.

## 7. Ideias de Projetos sem Dados Pessoais
Para evitar necessidade de anonimização complexa ou submissão a comitês de ética, recomenda-se fortemente que os projetos do plano amostral tenham como foco populações físicas, infraestruturas, acervos, dados espaciais ou simulações computacionais.

- **Estado de conservação do mobiliário acadêmico:** estimar a proporção de tomadas operacionais, assentos danificados ou projetores em perfeito estado nas salas de aula do campus.
- **Taxa de ocupação de estacionamentos e bicicletários:** estimar a taxa média de ocupação de vagas em diferentes períodos do dia.
- **Acessibilidade e distância até pontos de ônibus:** estimar a distância média de caminhada (em metros) ou a proporção de casas/edifícios localizados a mais de um limite recomendado (ex.: 300 m) do ponto de ônibus mais próximo.
- **Saúde e biometria de árvores em parques urbanos:** estimar a altura média, diâmetro à altura do peito (DAP) ou incidência de pragas na arborização de um parque público.
- **Preservação de acervo bibliográfico:** estimar a proporção de obras físicas que demandam restauração ou a distribuição do ano de publicação do acervo de uma biblioteca.
- **Inspeção de controle de qualidade de produtos comercializados:** estimar a variabilidade de peso, volume real ou integridade de rotulagem em lotes de produtos em supermercados.
- **Preço do metro quadrado de imóveis:** estimar o valor médio de locação ou venda por m² em um município a partir de anúncios em portais imobiliários.
- **Avaliação de desempenho de estimadores:** criar populações simuladas (com diferentes níveis de assimetria, variância heterocedástica ou autocorrelação espacial) e comparar o desempenho dos estimadores sob diferentes planos amostrais. Demonstrar usando Shiny app.
