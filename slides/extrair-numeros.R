# Extrai de resultados/ os números e a figura usados nos slides (não refaz sorteios)
source("R/config.R")
library(data.table); library(ggplot2)
of  <- readRDS(ARQ_AMOSTRA); sim <- readRDS(ARQ_SIMULACAO)
res <- sim$resumo
out <- list(
  oficial = of$tabela[, .(plano, gabarito_usado, secoes, municipios, custo, R, ep, ic_inf, ic_sup, gabarito, cobre)],
  gabarito = of$gabarito,
  grade = res[grupo == "grade" & alvo == "total", .(plano, n_ref, razao_c1_c2, orcamento, reqm, cobertura, deff, eficiencia_custo, secoes_media, munic_media)],
  p4par = res[grupo == "grade" & alvo == "pareado" & razao_c1_c2 == 10, .(n_ref, vies, cobertura)],
  curva = res[grupo == "curva_m", .(m, k, reqm, cobertura)],
  icc = sim$icc_plano3$rho, B = sim$B)
jsonlite::write_json(out, "slides/numeros.json", digits = 8, auto_unbox = TRUE)
# Boxplot das estimativas (orçamento 400, c1/c2 = 10)
ROT <- c("1 AAS"="AAS", "2 Estrat. proporcional"="Estrat. proporcional", "2 Estrat. Neyman"="Estrat. Neyman",
         "3 Dois estágios"="Dois estágios", "4 Razão com auxiliar 2018"="Razão (aux. 2018)")
ids <- sim$tarefas[grupo == "grade" & razao_c1_c2 == 10 & n_ref == 400, .(id, plano)]
rr <- merge(sim$replicas, ids, by = "id"); rr[, Plano := factor(ROT[plano], levels = rev(ROT))]
p <- ggplot(rr, aes(100 * R, Plano)) +
  geom_boxplot(width = .55, fill = "#D7EDE6", colour = "#14594A", outlier.size = .6, outlier.alpha = .4) +
  geom_vline(xintercept = 100 * of$gabarito$total, linewidth = .8, colour = "#C2410C") +
  geom_vline(xintercept = 100 * of$gabarito$pareado, linewidth = .6, linetype = "dashed", colour = "#555555") +
  scale_x_continuous(labels = scales::label_number(decimal.mark = ",")) +
  labs(x = "Estimativa da taxa de abstenção (%)", y = NULL) +
  theme_minimal(base_size = 15) + theme(panel.grid.major.y = element_blank(), panel.grid.minor = element_blank())
ggsave("slides/fig-boxplot.png", p, width = 8, height = 4.2, dpi = 200, bg = "white")
