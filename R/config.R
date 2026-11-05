# =============================================================================
# config.R — configuração central do projeto (ME430, Trabalho Final)
# Única fonte de semente, B, orçamentos, custos e caminhos.
# O relatorio.Rmd e os scripts fazem source("R/config.R").
# Rodar sempre a partir da raiz do projeto (caminhos relativos).
# =============================================================================

# --- Reprodutibilidade --------------------------------------------------------
SEMENTE <- 430                      # semente única do projeto
# A amostra oficial usa o gerador padrão do R (Mersenne-Twister) com SEMENTE.
# O Monte Carlo (paralelo) usa RNGkind("L'Ecuyer-CMRG") + set.seed(SEMENTE),
# com um fluxo independente por tarefa (ver R/simulacao.R).

# --- Monte Carlo --------------------------------------------------------------
B <- 1000                           # réplicas por plano e orçamento (checar estabilidade do EQM)
N_NUCLEOS <- 6                      # processos paralelos no Monte Carlo (o resultado não depende disso)

# --- Orçamentos ---------------------------------------------------------------
# Orçamento = custo esperado de uma AAS com estes tamanhos de amostra
N_AAS_ORCAMENTO <- c(200, 400, 800)
N_AAS_REFERENCIA <- 400             # orçamento da amostra oficial

# --- Modelo de custo: C = c1 * (nº de municípios distintos) + c2 * (nº de seções)
# Decidido em 2026-11-05: visitar um município custa o equivalente a obter 10 seções.
C2 <- 1                             # custo por seção (unidade de custo)
RAZAO_C1_C2 <- 10                   # cenário central
C1 <- RAZAO_C1_C2 * C2              # custo por município
RAZOES_SENSIBILIDADE <- c(5, 10, 20)

# --- Nível de confiança -------------------------------------------------------
CONF <- 0.95

# --- Caminhos -----------------------------------------------------------------
DIR_BRUTOS     <- "dados-brutos"
DIR_DADOS      <- "dados"
DIR_RESULTADOS <- "resultados"
ARQ_SECOES     <- file.path(DIR_DADOS, "secoes-sp-2022.csv")
ARQ_DICIONARIO <- file.path(DIR_DADOS, "dicionario.csv")
ARQ_AMOSTRA    <- file.path(DIR_RESULTADOS, "amostra-oficial.rds")
ARQ_SIMULACAO  <- file.path(DIR_RESULTADOS, "simulacao.rds")
