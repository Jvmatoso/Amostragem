# =============================================================================
# secundarios.R — parâmetros secundários na amostra oficial (extra, só tabela)
#   proporção de votos brancos = Σ brancos / Σ comparecimento
#   proporção de votos nulos   = Σ nulos   / Σ comparecimento
# (votos para Governador, 1º turno de 2022).
#
# Usa as MESMAS seções sorteadas na amostra oficial (resultados/amostra-oficial.rds)
# dos planos 1 a 3: "coleta" as variáveis brancos, nulos e comparecimento dessas
# seções e aplica o mesmo estimador de razão de cada plano, trocando
# y → brancos (ou nulos) e x → comparecimento. O plano 4 fica de fora: o seu
# auxiliar (abstenção de 2018) não se relaciona com estes parâmetros.
#
# Gera resultados/secundarios.csv. Rodar a partir da raiz: Rscript R/secundarios.R
# (depois de R/simulacao.R).
# =============================================================================
source("R/config.R")
source("R/planos.R")
source("R/estimadores.R")

d   <- carregar_secoes()
tot <- totais_conhecidos(d)
of  <- readRDS(ARQ_AMOSTRA)

PARAMETROS <- c(brancos = "Proporção de brancos", nulos = "Proporção de nulos")
PLANOS_SEC <- c("1 AAS", "2 Estrat. proporcional", "2 Estrat. Neyman", "3 Dois estágios")

estimar <- function(plano, am) {
  switch(plano,
    "1 AAS"                  = est_aas(am, tot$N),
    "2 Estrat. proporcional" = est_estrat(am, tot$Nh),
    "2 Estrat. Neyman"       = est_estrat(am, tot$Nh),
    "3 Dois estágios"        = est_plano3(am, tot$N_SP))
}

sec <- rbindlist(lapply(names(PARAMETROS), function(v) {
  gab <- sum(d[[v]]) / sum(d$comparecimento)   # gabarito: só para comparação
  rbindlist(lapply(PLANOS_SEC, function(pl) {
    am <- copy(of$amostras[[pl]])
    # coleta das variáveis secundárias nas mesmas seções (linha a linha)
    j <- match(am$id_secao, d$id_secao)
    am[, `:=`(y = d[[v]][j], x = d$comparecimento[j])]
    e <- estimar(pl, am)
    data.table(parametro = PARAMETROS[[v]], plano = pl,
               R = e$R, ep = e$ep, ic_inf = e$ic_inf, ic_sup = e$ic_sup,
               gabarito = gab, cobre = e$ic_inf <= gab & gab <= e$ic_sup)
  }))
}))

fwrite(sec, file.path(DIR_RESULTADOS, "secundarios.csv"))
print(sec[, .(parametro, plano, R = round(100 * R, 3), ep = round(100 * ep, 3),
              gabarito = round(100 * gabarito, 3), cobre)])
