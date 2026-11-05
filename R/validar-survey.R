# =============================================================================
# validar-survey.R — valida as funções próprias de planos.R e estimadores.R
#   (a) estimativa e EP de cada plano contra o pacote survey (mesma amostra);
#   (b) custo realizado médio de R réplicas contra o orçamento de referência.
# Gera resultados/validacao-survey.csv e resultados/validacao-custo.csv.
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
des <- desenhar(N_AAS_REFERENCIA, d, qm)
M3  <- 10                                    # m usado só nesta validação
p3  <- des$plano3[m == M3]

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

# --- (b) Custo realizado médio vs orçamento ---------------------------------------
REP <- 300
custos <- function(f) mean(replicate(REP, custo_realizado(f())))
cus <- data.table(
  plano = c("1 AAS", "2 Estrat. proporcional", "2 Estrat. Neyman",
            sprintf("3 Dois estágios (m=%d)", p3$m), "4 Razão com auxiliar 2018"),
  n_secoes = c(des$aas$n, des$proporcional$n, des$neyman$n,
               round(p3$secoes_esperadas), des$plano4$n),
  custo_esperado = c(des$aas$custo, des$proporcional$custo, des$neyman$custo,
                     p3$custo, des$plano4$custo),
  custo_medio_realizado = c(
    custos(function() coletar(d, sel_aas(tot$N, des$aas$n))),
    custos(function() coletar(d, sel_estrat(d, des$proporcional$nh))),
    custos(function() coletar(d, sel_estrat(d, des$neyman$nh))),
    custos(function() coletar(d, sel_plano3(d, qm, lin, p3$m, p3$k, p3$k_SP))),
    custos(function() coletar(d, sel_plano4(d, des$plano4$n))))
)
cus[, orcamento := des$orcamento]

dir.create(DIR_RESULTADOS, showWarnings = FALSE)
fwrite(val, file.path(DIR_RESULTADOS, "validacao-survey.csv"))
fwrite(cus, file.path(DIR_RESULTADOS, "validacao-custo.csv"))
print(val, digits = 6)
print(cus, digits = 6)
