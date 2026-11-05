# =============================================================================
# preparar-dados.R — download, limpeza, pareamento 2018 ↔ 2022 e consistência
# Roda uma vez, a partir da raiz do projeto:  Rscript R/preparar-dados.R
# Gera:  dados/secoes-sp-2022.csv  (uma linha por seção; gabarito + auxiliar 2018)
#        dados/dicionario.csv      (nome, descrição, unidade, origem)
# Fontes: TSE, "Detalhe da votação por seção" (2022 e 2018); IBGE, API de
#         localidades (município → região geográfica intermediária).
# Dados públicos e agregados por seção: não há dados pessoais.
# =============================================================================
source("R/config.R")
suppressMessages(library(data.table))
options(timeout = 3600)  # zips do TSE têm ~240 MB cada

URL_TSE  <- "https://cdn.tse.jus.br/estatistica/sead/odsele/detalhe_votacao_secao/detalhe_votacao_secao_%d.zip"
URL_IBGE <- "https://servicodados.ibge.gov.br/api/v1/localidades/estados/35/municipios"
CARGO    <- "Governador"  # um cargo só: o arquivo repete cada seção por cargo

# Colunas lidas do TSE (nomes conferidos no layout dos dois anos)
COLS_TSE <- c("SG_UF", "NR_TURNO", "CD_MUNICIPIO", "NM_MUNICIPIO", "NR_ZONA", "NR_SECAO",
              "DS_CARGO", "QT_APTOS", "QT_COMPARECIMENTO", "QT_ABSTENCOES",
              "QT_VOTOS_BRANCOS", "QT_VOTOS_NULOS")

# --- Funções auxiliares -------------------------------------------------------

# Baixa (se preciso) o zip do TSE e extrai só o CSV de SP. Devolve o caminho do CSV.
obter_csv_tse <- function(ano) {
  zip <- file.path(DIR_BRUTOS, sprintf("detalhe_votacao_secao_%d.zip", ano))
  dir <- file.path(DIR_BRUTOS, sprintf("tse-%d", ano))
  csv <- file.path(dir, sprintf("detalhe_votacao_secao_%d_SP.csv", ano))
  if (!file.exists(csv)) {
    if (!file.exists(zip)) download.file(sprintf(URL_TSE, ano), zip, mode = "wb")
    dir.create(dir, showWarnings = FALSE)
    unzip(zip, files = basename(csv), exdir = dir)
  }
  csv
}

# Nome de município sem acento, maiúsculo, sem pontuação (para casar TSE × IBGE)
normalizar_nome <- function(x) {
  x <- toupper(iconv(enc2utf8(x), from = "UTF-8", to = "ASCII//TRANSLIT"))
  x <- gsub("[^A-Z ]", " ", x)
  gsub("\\s+", " ", trimws(x))
}

# Lê um ano, aplica os filtros e registra quantas linhas/seções restam em cada um
ler_ano <- function(ano) {
  d <- fread(obter_csv_tse(ano), sep = ";", encoding = "Latin-1", select = COLS_TSE)
  d[, NM_MUNICIPIO := enc2utf8(NM_MUNICIPIO)]
  chave <- c("CD_MUNICIPIO", "NR_ZONA", "NR_SECAO")
  n_sec <- function(x) uniqueN(x, by = chave)
  passos <- list(bruto = d)
  passos$uf_sp  <- passos$bruto[SG_UF == "SP"]
  passos$turno1 <- passos$uf_sp[NR_TURNO == 1]
  passos$cargo  <- passos$turno1[DS_CARGO == CARGO]
  filtros <- data.table(ano = ano, passo = names(passos),
                        linhas = sapply(passos, nrow), secoes = sapply(passos, n_sec))
  # Aptos, comparecimento e abstenções não podem depender do cargo
  var_cargo <- passos$turno1[, .(k = uniqueN(.SD)), by = chave,
                             .SDcols = c("QT_APTOS", "QT_COMPARECIMENTO", "QT_ABSTENCOES")]
  list(dados = passos$cargo, filtros = filtros,
       secoes_variam_por_cargo = var_cargo[k > 1, .N])
}

# --- 1. TSE 2022 e 2018 ------------------------------------------------------
cat("Lendo TSE 2022 e 2018...\n")
a22 <- ler_ano(2022)
a18 <- ler_ano(2018)
cat("\nFiltros aplicados (linhas e seções restantes em cada passo):\n")
print(rbind(a22$filtros, a18$filtros))
cat("Seções em que aptos/comparecimento/abstenções variam entre cargos (T1): 2022 =",
    a22$secoes_variam_por_cargo, "| 2018 =", a18$secoes_variam_por_cargo, "\n")

d22 <- a22$dados
d18 <- a18$dados[, .(CD_MUNICIPIO, NR_ZONA, NR_SECAO,
                     aptos_2018 = QT_APTOS, abstencoes_2018 = QT_ABSTENCOES)]

# --- 2. IBGE: região geográfica intermediária ---------------------------------
arq_ibge <- file.path(DIR_BRUTOS, "ibge", "municipios-sp.json")
if (!file.exists(arq_ibge)) {
  dir.create(dirname(arq_ibge), showWarnings = FALSE)
  download.file(URL_IBGE, arq_ibge, mode = "wb")
}
js <- jsonlite::fromJSON(arq_ibge, simplifyVector = FALSE)
ibge <- rbindlist(lapply(js, function(m) {
  ri <- m[["regiao-imediata"]][["regiao-intermediaria"]]
  data.table(cod_ibge = m$id, nome_ibge = m$nome, cod_regiao_int = ri$id, nm_regiao_int = ri$nome)
}))
ibge[, nome_norm := normalizar_nome(nome_ibge)]
stopifnot(!anyDuplicated(ibge$nome_norm))

# Única divergência de grafia encontrada (registro 2026-11-05): Luís (TSE) × Luiz (IBGE)
EXCECOES_NOME <- c("SAO LUIS DO PARAITINGA" = "SAO LUIZ DO PARAITINGA")

mun <- unique(d22[, .(CD_MUNICIPIO, NM_MUNICIPIO)])
mun[, nome_norm := normalizar_nome(NM_MUNICIPIO)]
mun[nome_norm %in% names(EXCECOES_NOME), nome_norm := EXCECOES_NOME[nome_norm]]
mun <- merge(mun, ibge, by = "nome_norm", all.x = TRUE)
if (mun[is.na(cod_ibge), .N] > 0) {
  print(mun[is.na(cod_ibge)])
  stop("Há municípios do TSE sem casamento com o IBGE (ver acima).")
}
cat("\nMunicípios: TSE =", nrow(mun), "| casados com IBGE =", mun[!is.na(cod_ibge), .N],
    "| regiões intermediárias =", uniqueN(mun$cod_regiao_int), "\n")

# --- 3. Base final: uma linha por seção de 2022 -------------------------------
secoes <- d22[, .(cd_municipio_tse = CD_MUNICIPIO, nm_municipio = NM_MUNICIPIO,
                  nr_zona = NR_ZONA, nr_secao = NR_SECAO,
                  aptos = QT_APTOS, comparecimento = QT_COMPARECIMENTO,
                  abstencoes = QT_ABSTENCOES, brancos = QT_VOTOS_BRANCOS,
                  nulos = QT_VOTOS_NULOS)]
secoes <- merge(secoes, mun[, .(cd_municipio_tse = CD_MUNICIPIO, cod_ibge, cod_regiao_int, nm_regiao_int)],
                by = "cd_municipio_tse", all.x = TRUE)
secoes[, capital := cod_ibge == 3550308L]  # município de São Paulo (código IBGE)

# Pareamento com 2018 por município + zona + seção (seções sem par: NA no auxiliar)
secoes <- merge(secoes, d18, by.x = c("cd_municipio_tse", "nr_zona", "nr_secao"),
                by.y = c("CD_MUNICIPIO", "NR_ZONA", "NR_SECAO"), all.x = TRUE)
secoes[, pareada := !is.na(aptos_2018)]
secoes[, id_secao := sprintf("%d-%d-%d", cd_municipio_tse, nr_zona, nr_secao)]

setcolorder(secoes, c("id_secao", "cd_municipio_tse", "cod_ibge", "nm_municipio", "nr_zona", "nr_secao",
                      "cod_regiao_int", "nm_regiao_int", "capital",
                      "aptos", "comparecimento", "abstencoes", "brancos", "nulos",
                      "pareada", "aptos_2018", "abstencoes_2018"))
setorder(secoes, cd_municipio_tse, nr_zona, nr_secao)

# --- 4. Consistência ------------------------------------------------------------
cols_obrig <- setdiff(names(secoes), c("aptos_2018", "abstencoes_2018"))
checagens <- data.table(
  checagem = c("aptos = comparecimento + abstenções (violações)",
               "brancos + nulos <= comparecimento (violações)",
               "seções duplicadas",
               "ausentes nas colunas obrigatórias",
               "seções com 0 aptos",
               "pareadas sem auxiliar 2018 (deve ser 0)",
               "seções aptos 2018 = 0 entre as pareadas",
               "seções cuja chave varia de cargo (2022)"),
  valor = c(secoes[, sum(aptos != comparecimento + abstencoes)],
            secoes[, sum(brancos + nulos > comparecimento)],
            sum(duplicated(secoes$id_secao)),
            sum(is.na(secoes[, ..cols_obrig])),
            secoes[, sum(aptos == 0)],
            secoes[pareada == TRUE, sum(is.na(abstencoes_2018))],
            secoes[pareada == TRUE, sum(aptos_2018 == 0)],
            a22$secoes_variam_por_cargo))
cat("\nChecagens de consistência:\n"); print(checagens)
if (any(checagens$valor[1:4] > 0)) stop("Falha de consistência (ver tabela acima).")

# Resumo: tamanho da população, pareamento e gabarito
resumo <- secoes[, .(N_secoes = .N, N_municipios = uniqueN(cd_municipio_tse),
                     aptos = sum(aptos), abstencoes = sum(abstencoes),
                     R_2022 = sum(abstencoes) / sum(aptos),
                     pct_pareadas = 100 * mean(pareada),
                     pct_aptos_pareados = 100 * sum(aptos[pareada]) / sum(aptos))]
cat("\nResumo da população (gabarito):\n"); print(resumo)
cat("\nPor região intermediária:\n")
print(secoes[, .(N_h = .N, aptos = sum(aptos), R_h = round(sum(abstencoes) / sum(aptos), 4),
                 pct_pareadas = round(100 * mean(pareada), 1)), by = nm_regiao_int][order(-N_h)])

# --- 4b. Conferência externa: tabela "Detalhe da votação por município e zona" ---
# Outra tabela do TSE (agregada por zona). Compara aptos, comparecimento,
# abstenções e nº de seções, no total e zona a zona (Governador, 1º turno).
URL_MUNZONA <- "https://cdn.tse.jus.br/estatistica/sead/odsele/detalhe_votacao_munzona/detalhe_votacao_munzona_2022.zip"
zip_mz <- file.path(DIR_BRUTOS, "detalhe_votacao_munzona_2022.zip")
csv_mz <- file.path(DIR_BRUTOS, "tse-munzona-2022", "detalhe_votacao_munzona_2022_SP.csv")
if (!file.exists(csv_mz)) {
  if (!file.exists(zip_mz)) download.file(URL_MUNZONA, zip_mz, mode = "wb")
  unzip(zip_mz, files = basename(csv_mz), exdir = dirname(csv_mz))
}
mz <- fread(csv_mz, sep = ";", encoding = "Latin-1")[NR_TURNO == 1 & DS_CARGO == CARGO]
cat("\nVoto em trânsito na tabela munzona:\n"); print(mz[, .N, by = ST_VOTO_EM_TRANSITO])
cat("Seções na tabela munzona: principais =", mz[, sum(QT_SECOES_PRINCIPAIS)],
    "| agregadas =", mz[, sum(QT_SECOES_AGREGADAS)],
    "| não instaladas =", mz[, sum(QT_SECOES_NAO_INSTALADAS)],
    "| total =", mz[, sum(QT_TOTAL_SECOES)], "\n")

conf_total <- data.table(
  medida  = c("aptos", "comparecimento", "abstencoes", "secoes"),
  base    = c(secoes[, sum(aptos)], secoes[, sum(comparecimento)], secoes[, sum(abstencoes)], nrow(secoes)),
  munzona = c(mz[, sum(QT_APTOS)], mz[, sum(QT_COMPARECIMENTO)], mz[, sum(QT_ABSTENCOES)], mz[, sum(QT_TOTAL_SECOES)]))
conf_total[, diferenca := base - munzona]
cat("\nConferência externa (total SP):\n"); print(conf_total)

por_zona <- merge(
  secoes[, .(aptos = sum(aptos), abst = sum(abstencoes), n = .N), by = .(cd_municipio_tse, nr_zona)],
  mz[, .(aptos_mz = sum(QT_APTOS), abst_mz = sum(QT_ABSTENCOES), n_mz = sum(QT_TOTAL_SECOES)),
     by = .(cd_municipio_tse = CD_MUNICIPIO, nr_zona = NR_ZONA)],
  by = c("cd_municipio_tse", "nr_zona"), all = TRUE)
cat("Município-zona: na base =", por_zona[!is.na(aptos), .N], "| na munzona =", por_zona[!is.na(aptos_mz), .N],
    "| com aptos diferentes =", por_zona[is.na(aptos) | is.na(aptos_mz) | aptos != aptos_mz, .N],
    "| com abstenções diferentes =", por_zona[is.na(abst) | is.na(abst_mz) | abst != abst_mz, .N], "\n")
if (por_zona[is.na(aptos) | is.na(aptos_mz) | aptos != aptos_mz, .N] > 0)
  print(head(por_zona[is.na(aptos) | is.na(aptos_mz) | aptos != aptos_mz][order(-abs(aptos - aptos_mz))], 10))

# --- 5. Gravação ---------------------------------------------------------------
dir.create(DIR_DADOS, showWarnings = FALSE)
fwrite(secoes, ARQ_SECOES)

dicionario <- data.table(
  nome = names(secoes),
  descricao = c("Identificador da seção (município TSE-zona-seção)",
                "Código do município no TSE",
                "Código do município no IBGE (7 dígitos)",
                "Nome do município (TSE)",
                "Número da zona eleitoral",
                "Número da seção eleitoral",
                "Código da região geográfica intermediária (IBGE)",
                "Nome da região geográfica intermediária (IBGE); estrato do plano 2",
                "Seção no município de São Paulo (UPA autorrepresentativa no plano 3)",
                "Eleitores aptos em 2022 (x)",
                "Comparecimento em 2022",
                "Abstenções em 2022 (y)",
                "Votos brancos para Governador, 2022 (parâmetro secundário)",
                "Votos nulos para Governador, 2022 (parâmetro secundário)",
                "Seção encontrada em 2018 pela chave município + zona + seção",
                "Eleitores aptos em 2018 na mesma seção (NA se sem par)",
                "Abstenções em 2018 na mesma seção (z; NA se sem par)"),
  unidade = c("texto", "código", "código", "texto", "número", "número", "código", "texto",
              "lógico", "eleitores", "eleitores", "eleitores", "votos", "votos",
              "lógico", "eleitores", "eleitores"),
  origem = c("derivada", "TSE 2022", "IBGE (API de localidades)", "TSE 2022", "TSE 2022", "TSE 2022",
             "IBGE (API de localidades)", "IBGE (API de localidades)", "derivada",
             "TSE 2022", "TSE 2022", "TSE 2022", "TSE 2022", "TSE 2022",
             "derivada (pareamento)", "TSE 2018", "TSE 2018"))
fwrite(dicionario, ARQ_DICIONARIO)

cat(sprintf("\nGravados: %s (%d linhas, %.1f MB) e %s (%d variáveis)\n",
            ARQ_SECOES, nrow(secoes), file.size(ARQ_SECOES) / 2^20, ARQ_DICIONARIO, nrow(dicionario)))
