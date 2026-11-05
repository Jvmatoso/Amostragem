# =============================================================================
# simulacao.R — amostra oficial (etapa 5) e Monte Carlo (etapa 6)
#
# Amostra oficial: um sorteio por plano, semente SEMENTE, no orçamento de
# referência (AAS com n = N_AAS_REFERENCIA) e no cenário central de custo
# (c1/c2 = RAZAO_C1_C2). Tamanhos lidos de resultados/desenho.rds (R/priori.R);
# no plano 3 usa-se o par (m, k, k_SP) de menor margem a priori.
#
# Regra anti-vazamento: sortear_e_estimar() só vê o quadro, a amostra coletada
# e os totais conhecidos. O gabarito de 2022 só entra em avaliar().
#
# Gera resultados/amostra-oficial.rds (e, na etapa 6, resultados/simulacao.rds).
# Rodar a partir da raiz: Rscript R/simulacao.R
# =============================================================================
source("R/config.R")
source("R/planos.R")
source("R/estimadores.R")

PLANOS <- c("1 AAS", "2 Estrat. proporcional", "2 Estrat. Neyman",
            "3 Dois estágios", "4 Razão com auxiliar 2018")

# Sorteia, coleta e estima um plano. 'des' é um elemento de desenho.rds.
sortear_e_estimar <- function(plano, des, d, qm, lin, tot) {
  am <- switch(plano,
    "1 AAS"                  = coletar(d, sel_aas(tot$N, des$aas$n)),
    "2 Estrat. proporcional" = coletar(d, sel_estrat(d, des$proporcional$nh)),
    "2 Estrat. Neyman"       = coletar(d, sel_estrat(d, des$neyman$nh)),
    "3 Dois estágios"        = with(des$plano3_escolhido,
                                    coletar(d, sel_plano3(d, qm, lin, m, k, k_SP))),
    "4 Razão com auxiliar 2018" = coletar(d, sel_plano4(d, des$plano4$n)))
  est <- switch(plano,
    "1 AAS"                  = est_aas(am, tot$N),
    "2 Estrat. proporcional" = est_estrat(am, tot$Nh),
    "2 Estrat. Neyman"       = est_estrat(am, tot$Nh),
    "3 Dois estágios"        = est_plano3(am, tot$N_SP),
    "4 Razão com auxiliar 2018" = est_plano4(am, tot$pareado))
  list(amostra = am, est = est,
       custo = custo_realizado(am, des$c1, des$c2),
       secoes = nrow(am), municipios = uniqueN(am$cd_municipio_tse))
}

# Gabarito (só para avaliação): R de todas as seções e do subconjunto pareado
gabarito <- function(d) {
  p <- d[pareada == TRUE]
  list(total = sum(d$abstencoes) / sum(d$aptos),
       pareado = sum(p$abstencoes) / sum(p$aptos))
}

# Compara uma estimativa com o gabarito
avaliar <- function(est, R0) {
  list(erro = est$R - R0, cobre = est$ic_inf <= R0 && R0 <= est$ic_sup)
}

if (sys.nframe() == 0) {
  d   <- carregar_secoes()
  qm  <- quadro_municipios(d)
  lin <- linhas_por_municipio(d)
  tot <- totais_conhecidos(d)
  des <- readRDS(file.path(DIR_RESULTADOS, "desenho.rds"))[[
    sprintf("c%d_n%d", RAZAO_C1_C2, N_AAS_REFERENCIA)]]

  # --- Etapa 5: amostra oficial --------------------------------------------------
  set.seed(SEMENTE)
  oficial <- setNames(lapply(PLANOS, sortear_e_estimar,
                             des = des, d = d, qm = qm, lin = lin, tot = tot), PLANOS)

  g <- gabarito(d)
  tab <- rbindlist(lapply(PLANOS, function(p) {
    o <- oficial[[p]]
    alvo <- if (p == "4 Razão com auxiliar 2018") c("pareado", "total") else "total"
    rbindlist(lapply(alvo, function(a) {
      av <- avaliar(o$est, g[[a]])
      data.table(plano = p, gabarito_usado = a, secoes = o$secoes,
                 municipios = o$municipios, custo = o$custo,
                 orcamento = des$orcamento,
                 R = o$est$R, ep = o$est$ep, ic_inf = o$est$ic_inf,
                 ic_sup = o$est$ic_sup, gabarito = g[[a]],
                 erro = av$erro, cobre = av$cobre)
    }))
  }))

  saveRDS(list(semente = SEMENTE, razao_c1_c2 = RAZAO_C1_C2,
               n_ref = N_AAS_REFERENCIA, orcamento = des$orcamento,
               plano3 = des$plano3_escolhido, gabarito = g,
               amostras = lapply(oficial, `[[`, "amostra"), tabela = tab),
          ARQ_AMOSTRA)

  cat("Amostra oficial — orçamento", round(des$orcamento, 1),
      "(AAS n =", N_AAS_REFERENCIA, "), c1/c2 =", RAZAO_C1_C2, "\n")
  cat(sprintf("Plano 3: m = %d, k = %d, k_SP = %d\n",
              des$plano3_escolhido$m, des$plano3_escolhido$k,
              des$plano3_escolhido$k_SP))
  print(tab[, .(plano, gab = gabarito_usado, secoes, municipios,
                custo = round(custo, 1),
                R = sprintf("%.3f", 100 * R), ep = sprintf("%.3f", 100 * ep),
                ic = sprintf("[%.2f; %.2f]", 100 * ic_inf, 100 * ic_sup),
                gabarito = sprintf("%.3f", 100 * gabarito),
                erro_pp = sprintf("%+.3f", 100 * erro), cobre)])

  # --- Etapa 6: Monte Carlo -------------------------------------------------------
  # A IMPLEMENTAR.
}
