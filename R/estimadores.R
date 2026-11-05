# =============================================================================
# estimadores.R — estimativa de R = soma(abstenções) / soma(aptos) e variância
# estimada em cada plano (linearização de Taylor).
#
# Regra anti-vazamento: as funções recebem SÓ a amostra coletada (y, x, z e as
# informações de desenho de cada unidade) e totais do quadro conhecidos
# (N, Nh, N da capital, totais do subconjunto pareado). O gabarito de 2022
# nunca entra aqui; só na avaliação (simulacao.R).
#
# Notação: y = abstenções 2022, x = aptos 2022, z = abstenções 2018.
# Linearização: d_i = y_i - R̂ x_i;  Var̂(R̂) = Var̂(soma w_i d_i) / X̂².
# =============================================================================
source("R/config.R")

# Estimativa, variância, EP e IC normal (nível CONF)
resultado <- function(R, v) {
  q <- qnorm(1 - (1 - CONF) / 2)
  ep <- sqrt(v)
  list(R = R, var = v, ep = ep, ic_inf = R - q * ep, ic_sup = R + q * ep)
}

# --- Plano 1: AAS sem reposição ---------------------------------------------------
# R̂ = ȳ / x̄;  Var̂(R̂) = (1 - f) s²_d / (n x̄²)
est_aas <- function(am, N) {
  n <- nrow(am)
  R <- mean(am$y) / mean(am$x)
  d <- am$y - R * am$x
  resultado(R, (1 - n / N) * var(d) / (n * mean(am$x)^2))
}

# --- Plano 2: estratificada, estimador de razão combinado --------------------------
# R̂ = Σ Nh ȳh / Σ Nh x̄h;  Var̂(R̂) = Σ Nh² (1 - fh) s²_{d,h} / nh / X̂²
# Nh: vetor nomeado com o nº de seções de cada estrato no quadro.
est_estrat <- function(am, Nh) {
  g <- split(am, am$estrato)
  Nh <- Nh[names(g)]
  nh <- sapply(g, nrow)
  Y <- sum(Nh * sapply(g, function(u) mean(u$y)))
  X <- sum(Nh * sapply(g, function(u) mean(u$x)))
  R <- Y / X
  s2d <- sapply(g, function(u) var(u$y - R * u$x))
  resultado(R, sum(Nh^2 * (1 - nh / Nh) * s2d / nh) / X^2)
}

# --- Plano 3: dois estágios ------------------------------------------------------------
# Capital (certeza): Ŷc = N_SP ȳc, variância de AAS com fpc.
# Demais (PPT com reposição, Hansen–Hurwitz): para o sorteio j do município i,
#   Ŷj = (Ni / kj) Σ y;  Ŷo = (1/m) Σ Ŷj / pj;
#   Var̂ = Σ (D̂j/pj - mean(D̂j/pj))² / [m (m - 1)], com D̂j = Ŷj - R̂ X̂j.
# Var̂(R̂) = (Var̂ capital + Var̂ demais) / X̂²  (sorteios independentes).
# Colunas de desenho usadas: parte, sorteio, Ni, pj (conhecidas do quadro).
est_plano3 <- function(am, N_SP) {
  cc <- am[am$parte == "capital", ]
  oo <- am[am$parte == "outros", ]
  k_SP <- nrow(cc)
  Yc <- N_SP * mean(cc$y); Xc <- N_SP * mean(cc$x)

  # Totais por sorteio j (rowsum, mais rápido que split no Monte Carlo)
  s  <- rowsum(cbind(y = oo$y, x = oo$x, n = 1), oo$sorteio, reorder = TRUE)
  j1 <- match(as.numeric(rownames(s)), oo$sorteio)   # 1ª linha de cada sorteio
  m  <- nrow(s)
  Yj <- oo$Ni[j1] / s[, "n"] * s[, "y"]
  Xj <- oo$Ni[j1] / s[, "n"] * s[, "x"]
  pj <- oo$pj[j1]
  Yo <- mean(Yj / pj); Xo <- mean(Xj / pj)

  X <- Xc + Xo
  R <- (Yc + Yo) / X
  v_c <- N_SP^2 * (1 - k_SP / N_SP) * var(cc$y - R * cc$x) / k_SP
  Dj <- (Yj - R * Xj) / pj
  v_o <- sum((Dj - mean(Dj))^2) / (m * (m - 1))
  resultado(R, (v_c + v_o) / X^2)
}

# --- Plano 4: razão com auxiliar de 2018 (AAS no subconjunto pareado) ---------------
# Ŷ_R = (ȳ / z̄) Z, com Z = total de abstenções de 2018 no pareado (conhecido);
# R̂ = Ŷ_R / X, com X = total de aptos de 2022 no pareado (conhecido).
# Var̂(Ŷ_R) = (Z / z̄)² (1 - f) s²_e / n, e_i = y_i - (ȳ/z̄) z_i.
# Atenção: o alvo deste plano é R do subconjunto pareado; a diferença para o
# R de todas as seções é erro de cobertura (avaliado na simulação).
# tot: lista com N, X e Z do subconjunto pareado.
est_plano4 <- function(am, tot) {
  n <- nrow(am)
  r <- mean(am$y) / mean(am$z)
  e <- am$y - r * am$z
  v_Y <- (tot$Z / mean(am$z))^2 * (1 - n / tot$N) * var(e) / n
  resultado(r * tot$Z / tot$X, v_Y / tot$X^2)
}

# Totais do quadro que os estimadores podem receber (nenhum envolve y de 2022)
totais_conhecidos <- function(d) {
  p <- d[d$pareada, ]
  list(N = nrow(d),
       Nh = c(table(d$nm_regiao_int)),
       N_SP = sum(d$capital),
       pareado = list(N = nrow(p), X = sum(p$aptos), Z = sum(p$abstencoes_2018)))
}
