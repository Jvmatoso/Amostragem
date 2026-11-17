# =============================================================================
# validar-survey.R — valida as funções próprias de planos.R e estimadores.R
#   (a) estimativa e EP de cada plano contra o pacote survey (mesma amostra);
#   (b) nº médio de seções realizadas em R réplicas contra o n planejado
#       (e nº médio de municípios distintos, só descritivo).
# Tudo no tamanho de referência n = N_REFERENCIA.
# Gera resultados/validacao-survey.csv e resultados/validacao-n.csv.
# Rodar a partir da raiz: Rscript R/validar-survey.R
# =============================================================================
source("R/planos.R")
source("R/estimadores.R")
suppressPackageStartupMessages(library(survey))

set.seed(SEMENTE)
d   <- carregar_secoes()
qm  <- quadro_municipios(d)
lin <- linhas_por_municipio(d)
tot <- totais_conhecidos(d)
des <- desenhar(N_REFERENCIA, d, qm)
p3  <- des$plano3

# --- (a) Comparação com o survey -------------------------------------------------
comparar <- function(plano, proprio, R_sv, ep_sv) {
  data.table(plano = plano, R_proprio = proprio$R, R_survey = R_sv,
             ep_proprio = proprio$ep, ep_survey = ep_sv,
             dif_rel_ep = proprio$ep / ep_sv - 1)
}

# Plano 1
a1 <- coletar(d, sel_aas(tot$N, des$aas$n)); a1$fpc <- tot$N
s1 <- svyratio(~y, ~x, svydesign(ids = ~1, fpc = ~fpc, data = a1))

# Plano 2 (proporcional e Neyman)
a2p <- coletar(d, sel_estrat(d, des$proporcional$nh)); a2p$fpc <- tot$Nh[a2p$estrato]
s2p <- svyratio(~y, ~x, svydesign(ids = ~1, strata = ~estrato, fpc = ~fpc, data = a2p))
a2n <- coletar(d, sel_estrat(d, des$neyman$nh)); a2n$fpc <- tot$Nh[a2n$estrato]
s2n <- svyratio(~y, ~x, svydesign(ids = ~1, strata = ~estrato, fpc = ~fpc, data = a2n))

# Plano 3: estrato "capital" (AAS com fpc, cada seção é uma UPA) e estrato
# "outros" (UPA = sorteio, com reposição: fração amostral 0, só 1º estágio).
a3 <- coletar(d, sel_plano3(d, qm, lin, p3$m, p3$k, p3$k_SP))
a3$upa <- ifelse(a3$parte == "capital", paste0("c", seq_len(nrow(a3))),
                 paste0("o", a3$sorteio))
a3$fpc <- ifelse(a3$parte == "capital", p3$k_SP / tot$N_SP, 0)
s3 <- svyratio(~y, ~x, svydesign(ids = ~upa, strata = ~parte, weights = ~peso,
                                 fpc = ~fpc, data = a3))

# Plano 4: survey estima r = Y/Z; R̂ = r Z / X
a4 <- coletar(d, sel_plano4(d, des$plano4$n)); a4$fpc <- tot$pareado$N
s4 <- svyratio(~y, ~z, svydesign(ids = ~1, fpc = ~fpc, data = a4))
k4 <- tot$pareado$Z / tot$pareado$X

val <- rbind(
  comparar("1 AAS", est_aas(a1, tot$N), coef(s1), SE(s1)),
  comparar("2 Estrat. proporcional", est_estrat(a2p, tot$Nh), coef(s2p), SE(s2p)),
  comparar("2 Estrat. Neyman", est_estrat(a2n, tot$Nh), coef(s2n), SE(s2n)),
  comparar(sprintf("3 Dois estágios (m=%d, k=%d, k_SP=%d)", p3$m, p3$k, p3$k_SP),
           est_plano3(a3, tot$N_SP), coef(s3), SE(s3)),
  comparar("4 Razão com auxiliar 2018", est_plano4(a4, tot$pareado),
           coef(s4) * k4, SE(s4) * k4))

# --- (b) n realizado médio vs n planejado -------------------------------------------
REP <- 300
medias <- function(f) {
  r <- replicate(REP, { am <- f(); c(nrow(am), n_municipios(am)) })
  list(secoes = mean(r[1, ]), secoes_dp = sd(r[1, ]), munic = mean(r[2, ]))
}
sorteios <- list(
  "1 AAS"                  = function() coletar(d, sel_aas(tot$N, des$aas$n)),
  "2 Estrat. proporcional" = function() coletar(d, sel_estrat(d, des$proporcional$nh)),
  "2 Estrat. Neyman"       = function() coletar(d, sel_estrat(d, des$neyman$nh)),
  "3 Dois estágios"        = function() coletar(d, sel_plano3(d, qm, lin, p3$m, p3$k, p3$k_SP)),
  "4 Razão com auxiliar 2018" = function() coletar(d, sel_plano4(d, des$plano4$n)))
r_b <- lapply(sorteios, medias)
val_n <- data.table(
  plano = names(sorteios),
  n_planejado = N_REFERENCIA,
  secoes_esperadas = c(des$aas$n, des$proporcional$n, des$neyman$n,
                       p3$secoes_esperadas, des$plano4$n),
  secoes_media_realizada = sapply(r_b, `[[`, "secoes"),
  secoes_dp_realizado = sapply(r_b, `[[`, "secoes_dp"),
  munic_media_realizada = sapply(r_b, `[[`, "munic"))
val_n[, dif_rel_n := secoes_media_realizada / n_planejado - 1]

dir.create(DIR_RESULTADOS, showWarnings = FALSE)
fwrite(val, file.path(DIR_RESULTADOS, "validacao-survey.csv"))
fwrite(val_n, file.path(DIR_RESULTADOS, "validacao-n.csv"))
print(val, digits = 6)
print(val_n, digits = 6)
