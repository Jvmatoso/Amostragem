# =============================================================================
# config.R — configuração central do projeto (ME430, Trabalho Final)
# Única fonte de semente, B, tamanhos de amostra e caminhos.
# O relatorio.Rmd e os scripts fazem source("R/config.R").
# Rodar sempre a partir da raiz do projeto (caminhos relativos).
#
# Em 2026-11-17 o modelo de custo foi retirado (ver docs/registro.md): os
# planos passam a ser comparados com o mesmo número de seções n.
# =============================================================================

# --- Reprodutibilidade --------------------------------------------------------
SEMENTE <- 430                      # semente única do projeto
# A amostra oficial usa o gerador padrão do R (Mersenne-Twister) com SEMENTE.
# O Monte Carlo (paralelo) usa RNGkind("L'Ecuyer-CMRG") + set.seed(SEMENTE),
# com um fluxo independente por tarefa (ver R/simulacao.R).

# --- Monte Carlo --------------------------------------------------------------
B <- 1000                           # réplicas por plano e tamanho (checar estabilidade do EQM)
N_NUCLEOS <- 6                      # processos paralelos no Monte Carlo (o resultado não depende disso)

# --- Tamanhos de amostra (nº de seções, iguais para todos os planos) ----------
N_TAMANHOS   <- c(200, 400, 800)
N_REFERENCIA <- 400                 # tamanho da amostra oficial

# --- Plano 3 (dois estágios) -------------------------------------------------
# Decidido em 2026-11-17: k fixo = 4 seções por sorteio fora da capital em
# todos os n; curva de k em n = N_REFERENCIA.
K_PLANO3 <- 4
K_CURVA  <- c(1, 2, 4, 8)

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
