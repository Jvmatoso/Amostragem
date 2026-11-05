# =============================================================================
# priori.R — desenho de todos os planos por orçamento e cenário de custo, e
# margem de erro a priori calculada com 2018 como proxy (antes de olhar 2022).
#
# População proxy: seções pareadas, com y = abstenções 2018 e x = aptos 2018.
# Variâncias de planejamento (populacionais, por linearização):
#   AAS:     (1 - f) S²_d / (n x̄²)
#   Estrat.: Σ Wh² (1 - fh) S²_{d,h} / nh / x̄²
#   Plano 3: [N_c² (1 - f_c) S²_{d,c} / k_SP
#             + (1/m) Σ p_i (D_i/p_i - D_o)²                 (1º estágio, HH)
#             + (1/m) Σ N_i² (1 - k_i/N_i) S²_{d,i} / (k_i p_i)] / X²  (2º estágio)
#   com d = y - R2018 x.  Margem = z_{0,975} · EP.
# Plano 4: não há margem a priori com este proxy (y e o auxiliar seriam a
# mesma variável de 2018).
#
# Gera resultados/desenho.rds e resultados/margem-priori.csv.
# Rodar a partir da raiz: Rscript R/priori.R
# =============================================================================
source("R/planos.R")
source("R/estimadores.R")

# População proxy de 2018
proxy_2018 <- function(d) {
  p <- d[pareada == TRUE, .(cd_municipio_tse, regiao = nm_regiao_int, capital,
                            y = abstencoes_2018, x = aptos_2018)]
  R <- sum(p$y) / sum(p$x)
  p[, dd := y - R * x]
  p
}

var_priori_aas <- function(pp, n) {
  N <- nrow(pp)
  (1 - n / N) * var(pp$dd) / (n * mean(pp$x)^2)
}

var_priori_estrat <- function(pp, nh) {
  N <- nrow(pp)
  s <- pp[, .(Nh = .N, S2 = var(dd)), by = regiao]
  s[, nh := nh[regiao]]
  sum((s$Nh / N)^2 * (1 - s$nh / s$Nh) * s$S2 / s$nh) / mean(pp$x)^2
}

var_priori_plano3 <- function(pp, qm, m, k, k_SP) {
  cc <- pp[capital == TRUE]
  N_c <- nrow(cc)
  v_c <- N_c^2 * (1 - k_SP / N_c) * var(cc$dd) / k_SP
  # p_i vem do quadro de 2022 (o desenho real); D_i, N_i e S²_i, do proxy
  o <- qm[capital == FALSE, .(cd_municipio_tse, p = Mi / sum(Mi))]
  s <- pp[capital == FALSE, .(Ni = .N, D = sum(dd),
                              S2 = if (.N > 1) var(dd) else 0), by = cd_municipio_tse]
  o <- merge(o, s, by = "cd_municipio_tse", all.x = TRUE)
  o[is.na(Ni), `:=`(Ni = 0L, D = 0, S2 = 0)]
  D_o <- sum(o$D)
  v1 <- sum(o$p * (o$D / o$p - D_o)^2) / m
  o2 <- o[Ni > 0]
  ki <- pmin(k, o2$Ni)
  v2 <- sum(o2$Ni^2 * (1 - ki / o2$Ni) * o2$S2 / (ki * o2$p)) / m
  (v_c + v1 + v2) / sum(pp$x)^2
}

if (sys.nframe() == 0) {
  d  <- carregar_secoes()
  qm <- quadro_municipios(d)
  pp <- proxy_2018(d)
  q  <- qnorm(1 - (1 - CONF) / 2)

  desenhos <- list(); linhas <- list()
  for (r in RAZOES_SENSIBILIDADE) for (n in N_AAS_ORCAMENTO) {
    ds <- desenhar(n, d, qm, c1 = r * C2, c2 = C2)
    desenhos[[sprintf("c%d_n%d", r, n)]] <- ds
    base <- data.table(razao_c1_c2 = r, n_ref = n, orcamento = ds$orcamento)
    linhas[[length(linhas) + 1]] <- rbind(
      cbind(base, plano = "1 AAS", m = NA, k = NA, n_secoes = ds$aas$n,
            margem = q * sqrt(var_priori_aas(pp, ds$aas$n))),
      cbind(base, plano = "2 Estrat. proporcional", m = NA, k = NA,
            n_secoes = ds$proporcional$n,
            margem = q * sqrt(var_priori_estrat(pp, ds$proporcional$nh))),
      cbind(base, plano = "2 Estrat. Neyman", m = NA, k = NA,
            n_secoes = ds$neyman$n,
            margem = q * sqrt(var_priori_estrat(pp, ds$neyman$nh))),
      ds$plano3[, cbind(base, plano = "3 Dois estágios", m = m, k = k,
                        n_secoes = round(secoes_esperadas),
                        margem = q * sqrt(mapply(function(m, k, kc)
                          var_priori_plano3(pp, qm, m, k, kc), m, k, k_SP)))],
      cbind(base, plano = "4 Razão com auxiliar 2018", m = NA, k = NA,
            n_secoes = ds$plano4$n, margem = NA_real_))
  }
  margens <- rbindlist(linhas)
  margens[, margem_pp := round(100 * margem, 3)]

  dir.create(DIR_RESULTADOS, showWarnings = FALSE)
  saveRDS(desenhos, file.path(DIR_RESULTADOS, "desenho.rds"))
  fwrite(margens, file.path(DIR_RESULTADOS, "margem-priori.csv"))

  # Resumo: planos 1, 2 e o melhor m do plano 3, cenário central
  cat("Margem de erro a priori (p.p.), c1/c2 =", RAZAO_C1_C2, "\n")
  cen <- margens[razao_c1_c2 == RAZAO_C1_C2]
  print(cen[plano != "3 Dois estágios", .(n_ref, plano, n_secoes, margem_pp)])
  print(cen[plano == "3 Dois estágios", .(n_ref, m, k, n_secoes, margem_pp)])
  cat("\nMelhor m do plano 3 por cenário:\n")
  print(margens[plano == "3 Dois estágios", .SD[which.min(margem)],
                by = .(razao_c1_c2, n_ref)][, .(razao_c1_c2, n_ref, m, k, margem_pp)])
  cat("\nAAS e Neyman por cenário:\n")
  print(dcast(margens[plano %in% c("1 AAS", "2 Estrat. Neyman")],
              razao_c1_c2 + n_ref ~ plano, value.var = "margem_pp"))
}
