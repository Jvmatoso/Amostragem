# =============================================================================
# simulacao.R — amostra oficial (etapa 5) e Monte Carlo (etapa 6)
#
# Amostra oficial: um sorteio por plano, semente SEMENTE, no orçamento de
# referência (AAS com n = N_AAS_REFERENCIA) e no cenário central de custo
# (c1/c2 = RAZAO_C1_C2). Tamanhos lidos de resultados/desenho.rds (R/priori.R);
# no plano 3 usa-se o par (m, k, k_SP) de menor margem a priori.
#
# Monte Carlo: B réplicas de cada tarefa, onde uma tarefa é
#   (a) "grade":   plano × orçamento × cenário de custo (5 × 3 × 3 = 45);
#   (b) "curva_m": plano 3 em cada (m, k, k_SP) da grade, orçamento de
#                  referência e cenário central (para a fig-m-vs-k).
# Cada tarefa tem o seu próprio fluxo de números aleatórios (L'Ecuyer-CMRG,
# gerados em ordem fixa a partir de SEMENTE), então o resultado não depende
# do número de processos paralelos.
#
# Regra anti-vazamento: sortear_e_estimar() só vê o quadro, a amostra coletada
# e os totais conhecidos. O gabarito de 2022 só entra na avaliação
# (avaliar(), resumir_mc() e os diagnósticos), depois de todas as réplicas.
#
# Gera resultados/amostra-oficial.rds e resultados/simulacao.rds.
# Rodar a partir da raiz: Rscript R/simulacao.R
# Opções (para testes): Rscript R/simulacao.R B=50 nucleos=2 saida=arq.rds
# =============================================================================
source("R/config.R")
source("R/planos.R")
source("R/estimadores.R")
source("R/priori.R")      # fórmulas de variância de planejamento (diagnósticos)
suppressPackageStartupMessages(library(parallel))

PLANOS <- c("1 AAS", "2 Estrat. proporcional", "2 Estrat. Neyman",
            "3 Dois estágios", "4 Razão com auxiliar 2018")

# Sorteia, coleta e estima um plano. 'des' é um elemento de desenho.rds;
# 'p3' é a linha (m, k, k_SP) do plano 3 (por padrão, a escolhida a priori).
sortear_e_estimar <- function(plano, des, d, qm, lin, tot, lin_h = NULL,
                              p3 = des$plano3_escolhido) {
  am <- switch(plano,
    "1 AAS"                  = coletar(d, sel_aas(tot$N, des$aas$n)),
    "2 Estrat. proporcional" = coletar(d, sel_estrat(d, des$proporcional$nh, lin_h)),
    "2 Estrat. Neyman"       = coletar(d, sel_estrat(d, des$neyman$nh, lin_h)),
    "3 Dois estágios"        = coletar(d, sel_plano3(d, qm, lin, p3$m, p3$k, p3$k_SP)),
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

# =============================================================================
# Monte Carlo
# =============================================================================

# Lista de tarefas, em ordem fixa (a ordem define os fluxos aleatórios).
montar_tarefas <- function(desenhos) {
  tarefas <- list()
  nova <- function(grupo, chave, plano, p3) {
    des <- desenhos[[chave]]
    list(id = length(tarefas) + 1L, grupo = grupo, chave = chave,
         razao_c1_c2 = des$c1 / des$c2, n_ref = des$n_ref,
         orcamento = des$orcamento, plano = plano,
         m = if (is.null(p3)) NA_real_ else p3$m,
         k = if (is.null(p3)) NA_real_ else p3$k,
         k_SP = if (is.null(p3)) NA_real_ else p3$k_SP, p3 = p3)
  }
  # (a) grade principal: cenário de custo × orçamento × plano
  for (r in RAZOES_SENSIBILIDADE) for (n in N_AAS_ORCAMENTO) {
    chave <- sprintf("c%d_n%d", r, n)
    for (p in PLANOS) {
      p3 <- if (p == "3 Dois estágios") as.list(desenhos[[chave]]$plano3_escolhido)
      tarefas[[length(tarefas) + 1]] <- nova("grade", chave, p, p3)
    }
  }
  # (b) curva de m do plano 3: orçamento de referência, cenário central
  chave <- sprintf("c%d_n%d", RAZAO_C1_C2, N_AAS_REFERENCIA)
  g3 <- desenhos[[chave]]$plano3
  for (j in seq_len(nrow(g3)))
    tarefas[[length(tarefas) + 1]] <- nova("curva_m", chave, "3 Dois estágios",
                                           as.list(g3[j]))
  tarefas
}

# Um fluxo L'Ecuyer-CMRG por tarefa, a partir de SEMENTE
atribuir_sementes <- function(tarefas, semente = SEMENTE) {
  RNGkind("L'Ecuyer-CMRG")
  set.seed(semente)
  s <- .Random.seed
  for (i in seq_along(tarefas)) {
    s <- nextRNGStream(s)
    tarefas[[i]]$semente <- s
  }
  tarefas
}

# B réplicas de uma tarefa. Devolve uma tabela com uma linha por réplica.
# Recebe só o quadro e os totais conhecidos (nada do gabarito).
replicar <- function(t, B, desenhos, d, qm, lin, lin_h, tot) {
  RNGkind("L'Ecuyer-CMRG")
  assign(".Random.seed", t$semente, envir = globalenv())
  des <- desenhos[[t$chave]]
  R <- v <- li <- ls <- custo <- sec <- mun <- numeric(B)
  for (b in seq_len(B)) {
    r <- sortear_e_estimar(t$plano, des, d, qm, lin, tot, lin_h, p3 = t$p3)
    R[b] <- r$est$R; v[b] <- r$est$var
    li[b] <- r$est$ic_inf; ls[b] <- r$est$ic_sup
    custo[b] <- r$custo; sec[b] <- r$secoes; mun[b] <- r$municipios
  }
  data.table(id = t$id, b = seq_len(B), R = R, var = v, ic_inf = li,
             ic_sup = ls, custo = custo, secoes = sec, municipios = mun)
}

# Chamada nos processos paralelos: usa os objetos carregados em cada um
replicar_no_processo <- function(t, B) {
  replicar(t, B, desenhos, d, qm, lin, lin_h, tot)
}

# Roda todas as tarefas (em paralelo se nucleos > 1)
rodar_mc <- function(tarefas, B, nucleos, desenhos, d, qm, lin, lin_h, tot) {
  if (nucleos <= 1)
    return(rbindlist(lapply(tarefas, replicar, B = B, desenhos = desenhos,
                            d = d, qm = qm, lin = lin, lin_h = lin_h, tot = tot)))
  cl <- makeCluster(nucleos)
  on.exit(stopCluster(cl))
  clusterCall(cl, setwd, getwd())
  clusterExport(cl, "desenhos", envir = environment())
  clusterEvalQ(cl, {
    source("R/simulacao.R")
    data.table::setDTthreads(1)          # paralelismo só entre processos
    d <- carregar_secoes(); qm <- quadro_municipios(d)
    lin <- linhas_por_municipio(d); lin_h <- linhas_por_estrato(d)
    tot <- totais_conhecidos(d)
    NULL
  })
  # balanceamento dinâmico: as tarefas do plano 3 são as mais lentas
  rbindlist(parLapplyLB(cl, tarefas, replicar_no_processo, B = B))
}

# Metadados das tarefas (sem a semente) em formato de tabela
tabela_tarefas <- function(tarefas) {
  rbindlist(lapply(tarefas, function(t)
    data.table(id = t$id, grupo = t$grupo, razao_c1_c2 = t$razao_c1_c2,
               n_ref = t$n_ref, orcamento = t$orcamento, plano = t$plano,
               m = t$m, k = t$k, k_SP = t$k_SP)))
}

# =============================================================================
# Avaliação (aqui, e só aqui, entra o gabarito de 2022)
# =============================================================================

# População de 2022 no formato de priori.R (y = abstenções, x = aptos)
populacao_2022 <- function(d, so_pareadas = FALSE) {
  p <- if (so_pareadas) d[pareada == TRUE] else d
  p <- p[, .(cd_municipio_tse, regiao = nm_regiao_int, capital,
             y = abstencoes, x = aptos, z = abstencoes_2018, x18 = aptos_2018)]
  R <- sum(p$y) / sum(p$x)
  p[, dd := y - R * x]
  p
}

# Variância (de planejamento) do plano 4 numa população: AAS de n seções,
# estimador (ȳ/z̄)·Z / X;  Var ≈ (1 - f) S²_e / (n x̄²), e = y - (Y/Z) z
var_pop_plano4 <- function(pp, n) {
  e <- pp$y - sum(pp$y) / sum(pp$z) * pp$z
  (1 - n / nrow(pp)) * var(e) / (n * mean(pp$x)^2)
}

# Variância "analítica" de cada tarefa com a população de 2022 (mesmas
# fórmulas usadas a priori com 2018). Serve para separar erro de fórmula de
# diferença entre 2018 e 2022.
var_analitica_2022 <- function(tt, desenhos, pp22, pp22_par, qm) {
  sapply(seq_len(nrow(tt)), function(i) {
    t <- tt[i]; des <- desenhos[[sprintf("c%d_n%d", t$razao_c1_c2, t$n_ref)]]
    switch(t$plano,
      "1 AAS"                  = var_priori_aas(pp22, des$aas$n),
      "2 Estrat. proporcional" = var_priori_estrat(pp22, des$proporcional$nh),
      "2 Estrat. Neyman"       = var_priori_estrat(pp22, des$neyman$nh),
      "3 Dois estágios"        = var_priori_plano3(pp22, qm, t$m, t$k, t$k_SP),
      "4 Razão com auxiliar 2018" = var_pop_plano4(pp22_par, des$plano4$n))
  })
}

# Resumo por tarefa e gabarito: viés, variâncias, EQM, cobertura, deff etc.
resumir_mc <- function(rep, tt, g, pp22, pp22_par, desenhos, qm, margens18) {
  q <- qnorm(1 - (1 - CONF) / 2)
  rr <- merge(rep, tt[, .(id, plano)], by = "id")
  # Plano 4 é avaliado contra os dois gabaritos; os demais, contra o total
  alvos <- rbind(data.table(plano = PLANOS, alvo = "total", R0 = g$total),
                 data.table(plano = "4 Razão com auxiliar 2018", alvo = "pareado",
                            R0 = g$pareado))
  rr <- merge(rr, alvos, by = "plano", allow.cartesian = TRUE)
  res <- rr[, .(B = .N, media_R = mean(R), vies = mean(R) - R0[1],
                vies_rel = (mean(R) - R0[1]) / R0[1],
                var_verd = var(R), var_est_media = mean(var),
                eqm = mean((R - R0)^2),
                eqm_ep_mc = sd((R - R0)^2) / sqrt(.N),
                cobertura = mean(ic_inf <= R0 & R0 <= ic_sup),
                margem_empirica = q * sd(R),
                margem_estimada_media = q * mean(sqrt(var)),
                custo_medio = mean(custo), custo_dp = sd(custo),
                secoes_media = mean(secoes), munic_media = mean(municipios),
                gabarito = R0[1]),
            by = .(id, alvo)]
  res <- merge(tt, res, by = "id")
  res[, `:=`(razao_var = var_est_media / var_verd, reqm = sqrt(eqm),
             cobertura_ep_mc = sqrt(cobertura * (1 - cobertura) / B))]
  # deff de Kish: Var verdadeira / Var de uma AAS com o mesmo nº (médio) de
  # seções na mesma população (pareada, no plano 4)
  res[, var_aas_mesmo_n := mapply(function(p, n)
    if (p == "4 Razão com auxiliar 2018") var_priori_aas(pp22_par, n)
    else var_priori_aas(pp22, n), plano, round(secoes_media))]
  res[, deff := var_verd / var_aas_mesmo_n]
  # Eficiência a custo igual: EQM da AAS no mesmo orçamento / EQM do plano
  aas <- res[grupo == "grade" & plano == "1 AAS",
             .(razao_c1_c2, n_ref, eqm_aas = eqm)]
  res <- merge(res, aas, by = c("razao_c1_c2", "n_ref"), all.x = TRUE)
  res[, eficiencia_custo := eqm_aas / eqm]
  # Margens: a priori (2018), analítica com 2022, empírica (entre réplicas)
  res[, margem_analitica_2022 :=
        q * sqrt(var_analitica_2022(res, desenhos, pp22, pp22_par, qm))]
  m18 <- margens18[, .(razao_c1_c2, n_ref, plano, m, k, margem_priori_2018 = margem)]
  res <- merge(res, m18, by = c("razao_c1_c2", "n_ref", "plano", "m", "k"),
               all.x = TRUE)
  setorder(res, grupo, razao_c1_c2, n_ref, plano, m, alvo)
  res[]
}

# EQM acumulado ao longo das réplicas (estabilidade de B)
estabilidade_eqm <- function(rep, tt, g, passos = 100) {
  rr <- merge(rep, tt[grupo == "grade", .(id, plano, razao_c1_c2, n_ref)], by = "id")
  rr[, R0 := g$total]
  setorder(rr, id, b)
  rr[, eqm_acum := cumsum((R - R0)^2) / b, by = id]
  rr[b %% passos == 0, .(id, plano, razao_c1_c2, n_ref, b, eqm_acum)]
}

# Correlação intraclasse (ANOVA, grupos de tamanhos desiguais) de v em grupos g
icc_anova <- function(v, g) {
  medias <- tapply(v, g, mean)
  ni <- tapply(v, g, length)
  G <- length(ni); N <- length(v)
  msb <- sum(ni * (medias - mean(v))^2) / (G - 1)
  msw <- sum((v - medias[as.character(g)])^2) / (N - G)
  n0 <- (N - sum(ni^2) / N) / (G - 1)
  list(rho = (msb - msw) / (msb + (n0 - 1) * msw), n0 = n0, G = G)
}

# Diagnóstico da Neyman a custo igual (cenário central): por estrato, desvios
# de 2018 e 2022, alocações e custo marginal de uma seção a mais.
diag_neyman <- function(d, desenhos, pp22, qm) {
  Nh <- c(table(d$nm_regiao_int))
  Sh18 <- desvios_neyman_2018(d)[names(Nh)]
  Sh22 <- pp22[, .(S = sd(dd)), by = regiao][match(names(Nh), regiao), S]
  munic <- qm[, .N, by = regiao][match(names(Nh), regiao), N]
  rbindlist(lapply(N_AAS_ORCAMENTO, function(n) {
    des <- desenhos[[sprintf("c%d_n%d", RAZAO_C1_C2, n)]]
    pr <- des$proporcional$nh[names(Nh)]; ny <- des$neyman$nh[names(Nh)]
    base_pr <- custo_estrat(pr, qm, Nh); base_ny <- custo_estrat(ny, qm, Nh)
    cm <- function(nh, base) sapply(names(Nh), function(h) {
      nh2 <- nh; nh2[h] <- nh2[h] + 1; custo_estrat(nh2, qm, Nh) - base })
    # Neyman com o mesmo nº de seções da proporcional (comparação a n igual)
    ny_mesmo_n <- alocar(sum(pr), Nh, Nh * Sh18)
    data.table(n_ref = n, regiao = names(Nh), Nh = Nh, municipios = munic,
               Sh_2018 = Sh18, Sh_2022 = Sh22, nh_prop = pr, nh_neyman = ny,
               custo_marginal_prop = cm(pr, base_pr),
               custo_marginal_neyman = cm(ny, base_ny),
               var_prop_2022 = var_priori_estrat(pp22, pr),
               var_neyman_2022 = var_priori_estrat(pp22, ny),
               var_neyman_mesmo_n_2022 = var_priori_estrat(pp22, ny_mesmo_n))
  }))
}

# Diagnóstico do plano 4: o auxiliar z (abstenções 2018) explica y melhor que
# os aptos x? Compara os resíduos de cada estimador de razão no pareado.
diag_plano4 <- function(pp22_par) {
  with(pp22_par, {
    d_x <- y - sum(y) / sum(x) * x          # resíduo da AAS (razão em x)
    e_z <- y - sum(y) / sum(z) * z          # resíduo do plano 4 (razão em z)
    data.table(cor_y_x = cor(y, x), cor_y_z = cor(y, z),
               cor_taxas = cor(y / x, z / x18),
               S2_d_aptos = var(d_x), S2_e_abst2018 = var(e_z),
               razao_variancias = var(e_z) / var(d_x))
  })
}

# =============================================================================
if (sys.nframe() == 0) {
  # Opções de linha de comando (chave=valor), para testes
  args <- commandArgs(trailingOnly = TRUE)
  opc  <- function(chave, padrao) {
    a <- grep(paste0("^", chave, "="), args, value = TRUE)
    if (length(a)) sub(paste0("^", chave, "="), "", a[1]) else padrao
  }
  B_mc    <- as.integer(opc("B", B))
  nucleos <- as.integer(opc("nucleos", N_NUCLEOS))
  saida   <- opc("saida", ARQ_SIMULACAO)

  d     <- carregar_secoes()
  qm    <- quadro_municipios(d)
  lin   <- linhas_por_municipio(d)
  lin_h <- linhas_por_estrato(d)
  tot   <- totais_conhecidos(d)
  desenhos <- readRDS(file.path(DIR_RESULTADOS, "desenho.rds"))
  des <- desenhos[[sprintf("c%d_n%d", RAZAO_C1_C2, N_AAS_REFERENCIA)]]

  # --- Etapa 5: amostra oficial (gerador padrão do R) ---------------------------
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

  # --- Etapa 6: Monte Carlo ------------------------------------------------------
  tarefas <- atribuir_sementes(montar_tarefas(desenhos))
  tt <- tabela_tarefas(tarefas)
  cat(sprintf("\nMonte Carlo: %d tarefas × B = %d réplicas, %d processo(s)\n",
              length(tarefas), B_mc, nucleos))
  tempo <- system.time(
    rep <- rodar_mc(tarefas, B_mc, nucleos, desenhos, d, qm, lin, lin_h, tot))
  cat(sprintf("Tempo: %.1f min\n", tempo[["elapsed"]] / 60))

  # Avaliação (gabarito e populações de 2022 entram só daqui em diante)
  pp22     <- populacao_2022(d)
  pp22_par <- populacao_2022(d, so_pareadas = TRUE)
  margens18 <- fread(file.path(DIR_RESULTADOS, "margem-priori.csv"))
  resumo <- resumir_mc(rep, tt, g, pp22, pp22_par, desenhos, qm, margens18)
  estab  <- estabilidade_eqm(rep, tt, g)
  fora   <- pp22[capital == FALSE]
  icc    <- icc_anova(fora$dd, fora$cd_municipio_tse)
  dn     <- diag_neyman(d, desenhos, pp22, qm)
  d4     <- diag_plano4(pp22_par)

  dir.create(dirname(saida), showWarnings = FALSE, recursive = TRUE)
  saveRDS(list(semente = SEMENTE, B = B_mc, gabarito = g, tarefas = tt,
               replicas = rep, resumo = resumo, estabilidade = estab,
               icc_plano3 = icc, diag_neyman = dn, diag_plano4 = d4,
               tempo_min = tempo[["elapsed"]] / 60), saida)
  cat("Salvo em", saida, "\n")

  # --- Resumo na tela (cenário central, gabarito total) -----------------------------
  pc <- function(x, dig = 3) sprintf(paste0("%.", dig, "f"), 100 * x)
  cat("\nDesempenho (c1/c2 =", RAZAO_C1_C2, ", gabarito total), em p.p.:\n")
  print(resumo[grupo == "grade" & razao_c1_c2 == RAZAO_C1_C2 & alvo == "total",
               .(n_ref, plano, secoes = round(secoes_media), mun = round(munic_media),
                 custo = round(custo_medio), vies = pc(vies), ep = pc(sqrt(var_verd)),
                 reqm = pc(reqm), cob = sprintf("%.3f", cobertura),
                 var_est_verd = sprintf("%.3f", razao_var),
                 deff = sprintf("%.3f", deff), efic = sprintf("%.3f", eficiencia_custo))])
  cat("\nPlano 4 contra o gabarito pareado:\n")
  print(resumo[grupo == "grade" & razao_c1_c2 == RAZAO_C1_C2 & alvo == "pareado",
               .(n_ref, vies = pc(vies), reqm = pc(reqm), cob = sprintf("%.3f", cobertura))])
  cat("\nMargens (p.p.): a priori 2018 / analítica 2022 / empírica / estimada média\n")
  print(resumo[grupo == "grade" & razao_c1_c2 == RAZAO_C1_C2 & alvo == "total",
               .(n_ref, plano, priori18 = pc(margem_priori_2018),
                 anal22 = pc(margem_analitica_2022), empir = pc(margem_empirica),
                 estim = pc(margem_estimada_media))])
  cat("\nCurva de m (plano 3, orçamento", N_AAS_REFERENCIA, "):\n")
  print(resumo[grupo == "curva_m",
               .(m, k, k_SP, reqm = pc(reqm), priori18 = pc(margem_priori_2018),
                 anal22 = pc(margem_analitica_2022), empir = pc(margem_empirica),
                 cob = sprintf("%.3f", cobertura))])
  cat("\nEstabilidade: erro de MC relativo do EQM (máximo por plano):\n")
  print(resumo[grupo == "grade" & alvo == "total",
               .(ep_rel_max = sprintf("%.3f", max(eqm_ep_mc / eqm))), by = plano])
  cat(sprintf("\nCorrelação intraclasse (d_i, municípios fora da capital): %.4f (n0 = %.1f, G = %d)\n",
              icc$rho, icc$n0, icc$G))
  cat("\nDiagnóstico do plano 4 (pareado 2022):\n"); print(d4)
  cat("\nDiagnóstico da Neyman (variâncias analíticas 2022, ×1e6):\n")
  print(unique(dn[, .(n_ref, prop = 1e6 * var_prop_2022, neyman = 1e6 * var_neyman_2022,
                      neyman_mesmo_n = 1e6 * var_neyman_mesmo_n_2022)]))
}
