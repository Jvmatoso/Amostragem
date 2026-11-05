# =============================================================================
# planos.R — dimensionamento a custo igual e seleção de cada plano amostral
#   Plano 1: AAS de seções
#   Plano 2: estratificada por região intermediária (proporcional e Neyman)
#   Plano 3: 2 estágios — capital autorrepresentativa (AAS de seções) +
#            PPT com reposição de municípios (aptos) e AAS de k seções por sorteio
#   Plano 4: AAS no subconjunto pareado (estimador de razão com auxiliar 2018)
#
# Modelo de custo: C = c1 * (nº de municípios distintos) + c2 * (nº de seções)
# Orçamento = custo esperado de uma AAS com n seções (N_AAS_ORCAMENTO).
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

# --- Custo esperado ------------------------------------------------------------

# Nº esperado de municípios distintos numa AAS de n seções de um quadro com
# Ni seções por município: soma de P(município i aparece) = 1 - C(N-Ni, n)/C(N, n).
n_munic_esperado_aas <- function(Ni, n) {
  N <- sum(Ni)
  sum(1 - exp(lchoose(N - Ni, n) - lchoose(N, n)))
}

custo_aas <- function(n, Ni, c1 = C1, c2 = C2) {
  c1 * n_munic_esperado_aas(Ni, n) + c2 * n
}

# Orçamento de referência: custo esperado de uma AAS de n seções (quadro completo)
orcamento <- function(n, qm, c1 = C1, c2 = C2) custo_aas(n, qm$Ni, c1, c2)

# Busca binária do menor inteiro n com custo >= orc; devolve o mais próximo
resolver_n <- function(f_custo, orc, lo = 2, hi = 20000) {
  while (hi - lo > 1) {
    meio <- (lo + hi) %/% 2
    if (f_custo(meio) < orc) lo <- meio else hi <- meio
  }
  if (abs(f_custo(lo) - orc) <= abs(f_custo(hi) - orc)) lo else hi
}

# --- Plano 1: AAS ----------------------------------------------------------------

dimensionar_aas <- function(orc, Ni, c1 = C1, c2 = C2) {
  n <- resolver_n(function(n) custo_aas(n, Ni, c1, c2), orc)
  list(n = n, custo = custo_aas(n, Ni, c1, c2))
}

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

# Custo esperado da estratificada: dentro do estrato h é uma AAS de nh seções;
# cada município pertence a um único estrato (regiões são uniões de municípios).
custo_estrat <- function(nh, qm, Nh, c1 = C1, c2 = C2) {
  n_i <- nh[qm$regiao]; N_i <- Nh[qm$regiao]
  c1 * sum(1 - exp(lchoose(N_i - qm$Ni, n_i) - lchoose(N_i, n_i))) + c2 * sum(nh)
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

dimensionar_estrat <- function(orc, tipo = c("proporcional", "neyman"),
                               qm, Nh, Sh = NULL, c1 = C1, c2 = C2) {
  tipo <- match.arg(tipo)
  w <- if (tipo == "proporcional") Nh else Nh * Sh[names(Nh)]
  f <- function(n) custo_estrat(alocar(n, Nh, w), qm, Nh, c1, c2)
  n <- resolver_n(f, orc, lo = 2 * length(Nh))
  nh <- alocar(n, Nh, w)
  list(n = sum(nh), nh = nh, custo = custo_estrat(nh, qm, Nh, c1, c2))
}

sel_estrat <- function(d, nh) {
  Nh_obs <- table(d$nm_regiao_int)
  rbindlist(lapply(names(nh), function(h) {
    linhas <- which(d$nm_regiao_int == h)
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
# Custo: c1 é cobrado uma vez por município distinto (capital incluída);
# c2 por seção sorteada (contagem nominal: k_SP + soma dos k_i).

custo_plano3 <- function(m, k, k_SP, qm, c1 = C1, c2 = C2) {
  o <- qm[capital == FALSE]
  p <- o$Mi / sum(o$Mi)
  munic <- 1 + sum(1 - (1 - p)^m)              # capital + distintos esperados
  secoes <- k_SP + m * sum(p * pmin(k, o$Ni))  # seções esperadas
  c1 * munic + c2 * secoes
}

# Para cada m, escolhe o k que deixa a fração de seções da capital mais perto
# da fatia de aptos da capital; k_SP absorve o restante do orçamento.
# Combinações em que a fração da capital fica a mais de 'tol' da fatia de aptos
# são descartadas (k saturado: municípios pequenos já entram inteiros).
grade_plano3 <- function(orc, qm, c1 = C1, c2 = C2,
                         ms = c(3:10, 12, 15, 20, 25, 30, 40, 50, 60, 80,
                                100, 120, 150, 200, 250, 300),
                         ks = NULL, tol = 0.05) {
  o <- qm[capital == FALSE]
  if (is.null(ks)) ks <- 2:max(o$Ni)
  p <- o$Mi / sum(o$Mi)
  fatia <- qm[capital == TRUE, Mi] / sum(qm$Mi)
  N_SP <- qm[capital == TRUE, Ni]
  res <- lapply(ms, function(m) {
    munic <- 1 + sum(1 - (1 - p)^m)
    sec_o <- sapply(ks, function(k) m * sum(p * pmin(k, o$Ni)))
    k_SP <- round((orc - c1 * munic) / c2 - sec_o)
    ok <- k_SP >= 2 & k_SP <= N_SP
    if (!any(ok)) return(NULL)
    dif <- abs(k_SP / (k_SP + sec_o) - fatia); dif[!ok] <- Inf
    j <- which.min(dif)
    if (dif[j] > tol) return(NULL)
    data.table(m = m, k = ks[j], k_SP = k_SP[j],
               secoes_esperadas = k_SP[j] + sec_o[j],
               munic_esperados = munic,
               fracao_capital = k_SP[j] / (k_SP[j] + sec_o[j]),
               custo = custo_plano3(m, ks[j], k_SP[j], qm, c1, c2))
  })
  rbindlist(res)
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
  parte_o <- rbindlist(lapply(seq_len(m), function(j) {
    u <- sorteados[j]
    L <- linhas[[as.character(o$cd_municipio_tse[u])]]
    kj <- min(k, length(L))
    # pi aproximada (m p_i k_i / N_i); o peso coincide com o de Hansen–Hurwitz
    data.table(i = L[sample.int(length(L), kj)], estrato = "outros",
               parte = "outros", sorteio = j, Ni = o$Ni[u], pj = p[u], kj = kj,
               pi = m * p[u] * kj / o$Ni[u], peso = o$Ni[u] / (m * p[u] * kj))
  }))
  rbind(parte_c, parte_o)
}

# --- Plano 4: AAS no subconjunto pareado ----------------------------------------

dimensionar_plano4 <- function(orc, qm, c1 = C1, c2 = C2) {
  n <- resolver_n(function(n) custo_aas(n, qm$Ni_par, c1, c2), orc)
  list(n = n, custo = custo_aas(n, qm$Ni_par, c1, c2))
}

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

# Custo realizado de uma amostra (municípios distintos e seções nominais)
custo_realizado <- function(am, c1 = C1, c2 = C2) {
  c1 * uniqueN(am$cd_municipio_tse) + c2 * nrow(am)
}

# --- Desenho completo para um orçamento ---------------------------------------------
# Devolve os tamanhos de todos os planos para o orçamento de uma AAS de n_ref seções.
desenhar <- function(n_ref, d, qm, c1 = C1, c2 = C2) {
  Nh <- c(table(d$nm_regiao_int))
  Sh <- desvios_neyman_2018(d)
  orc <- orcamento(n_ref, qm, c1, c2)
  list(n_ref = n_ref, c1 = c1, c2 = c2, orcamento = orc,
       aas = dimensionar_aas(orc, qm$Ni, c1, c2),
       proporcional = dimensionar_estrat(orc, "proporcional", qm, Nh, NULL, c1, c2),
       neyman = dimensionar_estrat(orc, "neyman", qm, Nh, Sh, c1, c2),
       plano3 = grade_plano3(orc, qm, c1, c2),
       plano4 = dimensionar_plano4(orc, qm, c1, c2))
}
