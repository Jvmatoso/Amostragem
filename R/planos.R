# =============================================================================
# planos.R — dimensionamento por n e seleção de cada plano amostral
#   Plano 1: AAS de seções
#   Plano 2: estratificada por região intermediária (proporcional e Neyman)
#   Plano 3: 2 estágios — capital autorrepresentativa (AAS de seções) +
#            PPT com reposição de municípios (aptos) e AAS de k seções por sorteio
#   Plano 4: AAS no subconjunto pareado (estimador de razão com auxiliar 2018)
#
# Todos os planos são dimensionados para o mesmo número de seções n
# (N_TAMANHOS em config.R). O modelo de custo foi retirado em 2026-11-17; o
# número de municípios distintos na amostra segue registrado só como descrição.
#
# As funções de seleção só usam o quadro (município, região, aptos de 2022,
# que é tratado como conhecido). Os valores de y (abstenções) e z (abstenções
# de 2018) só entram depois do sorteio, em coletar().
# =============================================================================
source("R/config.R")
suppressPackageStartupMessages(library(data.table))

# --- Dados e quadro ----------------------------------------------------------

carregar_secoes <- function(arq = ARQ_SECOES) {
  fread(arq, encoding = "UTF-8")
}

# Quadro de municípios: nº de seções (Ni), seções pareadas (Ni_par),
# aptos de 2022 (Mi, medida de tamanho), região e capital.
quadro_municipios <- function(d) {
  d[, .(Ni = .N, Ni_par = sum(pareada), Mi = sum(aptos),
        regiao = nm_regiao_int[1], capital = capital[1]),
    by = cd_municipio_tse]
}

# Linhas da base por município (para o 2º estágio do plano 3)
linhas_por_municipio <- function(d) split(seq_len(nrow(d)), d$cd_municipio_tse)

# Nº esperado de municípios distintos numa AAS de n seções de um quadro com
# Ni seções por município: soma de P(município i aparece) = 1 - C(N-Ni, n)/C(N, n).
# (Só descritivo.)
n_munic_esperado_aas <- function(Ni, n) {
  N <- sum(Ni)
  sum(1 - exp(lchoose(N - Ni, n) - lchoose(N, n)))
}

# --- Plano 1: AAS ----------------------------------------------------------------

sel_aas <- function(N, n) {
  i <- sample.int(N, n)
  data.table(i = i, estrato = "unico", parte = "unico", sorteio = seq_len(n),
             pi = n / N, peso = N / n)
}

# --- Plano 2: estratificada ------------------------------------------------------

# Aloca n entre estratos proporcionalmente a w (Nh na proporcional, Nh*Sh na
# Neyman), com teto Nh, piso 'minimo' e arredondamento pelos maiores restos.
alocar <- function(n, Nh, w, minimo = 2) {
  aloc <- rep(NA_real_, length(Nh)); livre <- rep(TRUE, length(Nh))
  repeat {
    resto <- n - sum(aloc[!livre])
    a <- resto * w[livre] / sum(w[livre])
    estourou <- a > Nh[livre]
    if (!any(estourou)) { aloc[livre] <- a; break }
    idx <- which(livre)[estourou]; aloc[idx] <- Nh[idx]; livre[idx] <- FALSE
  }
  nh <- floor(aloc)
  falta <- n - sum(nh)
  if (falta > 0) {
    ordem <- order(aloc - nh, decreasing = TRUE)[seq_len(falta)]
    nh[ordem] <- nh[ordem] + 1
  }
  nh <- pmin(pmax(nh, minimo), Nh)
  setNames(as.integer(nh), names(Nh))
}

# Desvio-padrão por estrato para a Neyman, calculado em 2018 (nunca em 2022):
# Sh = dp de d_i = z_i - R2018 * aptos2018_i nas seções pareadas do estrato.
desvios_neyman_2018 <- function(d) {
  p <- d[pareada == TRUE]
  R18 <- sum(p$abstencoes_2018) / sum(p$aptos_2018)
  p[, d18 := abstencoes_2018 - R18 * aptos_2018]
  s <- p[, .(Sh = sd(d18)), by = nm_regiao_int]
  setNames(s$Sh, s$nm_regiao_int)
}

# Alocação de n seções entre os estratos; confere que a soma dá n
dimensionar_estrat <- function(n, tipo = c("proporcional", "neyman"), Nh, Sh = NULL) {
  tipo <- match.arg(tipo)
  w <- if (tipo == "proporcional") Nh else Nh * Sh[names(Nh)]
  nh <- alocar(n, Nh, w)
  stopifnot(sum(nh) == n)
  list(n = sum(nh), nh = nh)
}

# Linhas da base por estrato (pré-calculadas uma vez para acelerar o Monte Carlo)
linhas_por_estrato <- function(d) split(seq_len(nrow(d)), d$nm_regiao_int)

# lin_h: saída de linhas_por_estrato(); se omitida, é calculada aqui.
# Os sorteios (sample.int, na ordem de names(nh)) não dependem de lin_h.
sel_estrat <- function(d, nh, lin_h = NULL) {
  if (is.null(lin_h)) lin_h <- linhas_por_estrato(d)
  rbindlist(lapply(names(nh), function(h) {
    linhas <- lin_h[[h]]
    i <- linhas[sample.int(length(linhas), nh[[h]])]
    data.table(i = i, estrato = h, parte = "unico", sorteio = NA_integer_,
               pi = nh[[h]] / length(linhas), peso = length(linhas) / nh[[h]])
  }))
}

# --- Plano 3: dois estágios -------------------------------------------------------
# Capital: entra com certeza; AAS de k_SP seções.
# Demais 644 municípios: m sorteios PPT com reposição (p_i = Mi / M_outros);
# em cada sorteio, AAS de k_i = min(k, Ni) seções, independente das outras
# vezes em que o mesmo município for sorteado (padrão Hansen–Hurwitz).

# Desenho para n seções (decidido em 2026-11-17):
#   k_SP = round(fatia de aptos da capital × n);
#   m    = round((n - k_SP) / E[min(k, Ni)]), E sob p_i, para que as seções
#          esperadas k_SP + m E[min(k, Ni)] fiquem o mais perto possível de n.
dimensionar_plano3 <- function(n, k, qm) {
  o <- qm[capital == FALSE]
  p <- o$Mi / sum(o$Mi)
  fatia <- qm[capital == TRUE, Mi] / sum(qm$Mi)
  k_SP <- round(fatia * n)
  e_k  <- sum(p * pmin(k, o$Ni))           # seções esperadas por sorteio
  m    <- max(2, round((n - k_SP) / e_k))  # m >= 2 (variância de HH)
  sec  <- k_SP + m * e_k
  data.table(n_ref = n, m = m, k = k, k_SP = k_SP,
             secoes_esperadas = sec,
             munic_esperados = 1 + sum(1 - (1 - p)^m),   # capital + distintos
             fracao_capital = k_SP / sec)
}

sel_plano3 <- function(d, qm, linhas, m, k, k_SP) {
  # Parte 1: capital (certeza no 1º estágio)
  cap <- qm[capital == TRUE]
  L <- linhas[[as.character(cap$cd_municipio_tse)]]
  i_c <- L[sample.int(length(L), k_SP)]
  parte_c <- data.table(i = i_c, estrato = "capital", parte = "capital",
                        sorteio = NA_integer_, Ni = cap$Ni, pj = NA_real_,
                        kj = k_SP, pi = k_SP / cap$Ni, peso = cap$Ni / k_SP)
  # Parte 2: PPT com reposição entre os demais municípios
  o <- qm[capital == FALSE]
  p <- o$Mi / sum(o$Mi)
  sorteados <- sample.int(nrow(o), m, replace = TRUE, prob = p)
  # 2º estágio: um sorteio por vez, na ordem j = 1..m (vetores, sem montar
  # uma tabela por sorteio, para acelerar o Monte Carlo)
  L_o <- linhas[as.character(o$cd_municipio_tse[sorteados])]
  kj  <- pmin(k, lengths(L_o))
  i_o <- unlist(lapply(seq_len(m), function(j)
    L_o[[j]][sample.int(length(L_o[[j]]), kj[j])]))
  u   <- rep(sorteados, kj)
  kk  <- rep(kj, kj)
  # pi aproximada (m p_i k_i / N_i); o peso coincide com o de Hansen–Hurwitz
  parte_o <- data.table(i = i_o, estrato = "outros", parte = "outros",
                        sorteio = rep(seq_len(m), kj), Ni = o$Ni[u], pj = p[u],
                        kj = kk, pi = m * p[u] * kk / o$Ni[u],
                        peso = o$Ni[u] / (m * p[u] * kk))
  rbind(parte_c, parte_o)
}

# --- Plano 4: AAS no subconjunto pareado ----------------------------------------

sel_plano4 <- function(d, n) {
  linhas <- which(d$pareada)
  N <- length(linhas)
  i <- linhas[sample.int(N, n)]
  data.table(i = i, estrato = "pareado", parte = "unico", sorteio = seq_len(n),
             pi = n / N, peso = N / n)
}

# --- Coleta ----------------------------------------------------------------------
# "Coletar" = buscar na base os valores das seções sorteadas (instrumento de coleta).
coletar <- function(d, sel) {
  cbind(sel, d[sel$i, .(id_secao, cd_municipio_tse, y = abstencoes, x = aptos,
                        z = abstencoes_2018, x18 = aptos_2018)])
}

# Nº de municípios distintos numa amostra coletada (só descritivo)
n_municipios <- function(am) uniqueN(am$cd_municipio_tse)

# --- Desenho completo para n seções -------------------------------------------------
# Devolve os tamanhos de todos os planos para n seções; no plano 3, com k
# seções por sorteio fora da capital.
desenhar <- function(n, d, qm, k = K_PLANO3) {
  Nh <- c(table(d$nm_regiao_int))
  Sh <- desvios_neyman_2018(d)
  list(n_ref = n,
       aas = list(n = n, munic_esperados = n_munic_esperado_aas(qm$Ni, n)),
       proporcional = dimensionar_estrat(n, "proporcional", Nh),
       neyman = dimensionar_estrat(n, "neyman", Nh, Sh),
       plano3 = dimensionar_plano3(n, k, qm),
       plano4 = list(n = n, munic_esperados = n_munic_esperado_aas(qm$Ni_par, n)))
}
