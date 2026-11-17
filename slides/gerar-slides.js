// Gera slides/apresentacao.pptx a partir de slides/numeros.json e slides/fig-boxplot.png
// (ambos produzidos por slides/extrair-numeros.R, que só lê resultados/).
// Uso: NODE_PATH=<node_modules com pptxgenjs> PPTX_SKILL=<dir da skill pptx> node slides/gerar-slides.js
const path = require("path");
const pptxgen = require("pptxgenjs");
const J = require("./numeros.json");

const SKILL = process.env.PPTX_SKILL;  // diretório da skill (apply_theme.js)
const { applyTheme } = require(path.join(SKILL, "scripts/apply_theme.js"));

// ---------- formatação pt-BR ----------
const num = (x, d = 0) => x.toLocaleString("pt-BR", { minimumFractionDigits: d, maximumFractionDigits: d });
const pct = (x, d = 2) => num(100 * x, d);

const THEME = {
  name: "ME430 Abstencao",
  headFontFace: "Cambria", bodyFontFace: "Calibri",
  colors: { dk1: "1F2A28", lt1: "FFFFFF", dk2: "14594A", lt2: "EAF3EF",
            accent1: "14594A", accent2: "C2410C", accent3: "6BA292", accent4: "D9A520",
            accent5: "6B7B77", accent6: "A7C9BC", hlink: "14594A", folHlink: "6BA292" },
};
const HEX = THEME.colors;

const pres = new pptxgen();
pres.layout = "LAYOUT_16x9";   // 10 x 5.625
pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };
pres.title = "Qual plano amostral estima melhor a abstenção?";
const C = pres.SchemeColor;

// ---------- layouts ----------
pres.defineSlideMaster({
  title: "CAPA", background: { color: HEX.dk2 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.6, y: 1.0, w: 8.8, h: 1.8,
        fontSize: 36, bold: true, color: C.background1, valign: "bottom", align: "left" }, text: "" } },
    { placeholder: { options: { name: "body", type: "body", x: 0.6, y: 3.0, w: 8.8, h: 2.0,
        fontSize: 16, color: C.background2, valign: "top" }, text: "" } },
  ],
});
pres.defineSlideMaster({
  title: "SECAO", background: { color: HEX.dk2 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.6, y: 1.9, w: 8.8, h: 1.0,
        fontSize: 40, bold: true, color: C.background1, valign: "middle", align: "left" }, text: "" } },
    { placeholder: { options: { name: "body", type: "body", x: 0.6, y: 2.9, w: 8.8, h: 0.8,
        fontSize: 20, color: C.background2, valign: "top" }, text: "" } },
  ],
});
pres.defineSlideMaster({
  title: "CONTEUDO", background: { color: HEX.lt1 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.5, y: 0.3, w: 9.0, h: 0.75,
        fontSize: 28, bold: true, color: C.text2, valign: "middle", align: "left" }, text: "" } },
  ],
  slideNumber: { x: 9.0, y: 5.2, w: 0.5, h: 0.3, fontSize: 10, color: HEX.accent5, align: "right" },
});

const ORADORES = ["João Vitor Matoso", "Bruno Shimooka", "Matheus Pierri", "João Vitor Saes"];

// Os nomes só aparecem na capa; o orador de cada slide vai nas notas.
function conteudo(titulo, orador, secao) {
  const s = pres.addSlide({ masterName: "CONTEUDO", sectionTitle: secao });
  s.addText(titulo, { placeholder: "title" });
  const addNotes = s.addNotes.bind(s);
  s.addNotes = (txt) => addNotes(`[${orador}] ${txt}`);
  return s;
}
// Sem slides de transição: só a seção do arquivo (organização no PowerPoint).
function secao(titulo, sub, secaoNome) {
  pres.addSection({ title: secaoNome });
}
// cartão: retângulo arredondado com fundo claro, título e texto
function cartao(s, x, y, w, h, titulo, texto, nome, opts = {}) {
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w, h, rectRadius: 0.08,
    fill: { color: C.background2 }, line: { color: C.background2 }, objectName: nome });
  s.addText(titulo, { x: x + 0.2, y: y + 0.15, w: w - 0.4, h: 0.45, fontSize: 18, bold: true,
    color: C.text2, margin: 0, isTextBox: true, valign: "top", fontFace: THEME.headFontFace });
  s.addText(texto, { x: x + 0.2, y: y + 0.65, w: w - 0.4, h: h - 0.8, fontSize: opts.size || 14,
    color: C.text1, margin: 0, isTextBox: true, valign: "top" });
}
// número em destaque
function destaque(s, x, y, w, valor, rotulo, cor) {
  s.addText(valor, { x, y, w, h: 0.75, fontSize: 36, bold: true, color: cor || C.text2, margin: 0,
    isTextBox: true, fontFace: THEME.headFontFace });
  s.addText(rotulo, { x, y: y + 0.75, w, h: 0.6, fontSize: 13, color: C.accent5, margin: 0, isTextBox: true, valign: "top" });
}
// círculo numerado (motivo visual)
function bolinha(s, x, y, txt, cor) {
  s.addShape(pres.shapes.OVAL, { x, y, w: 0.5, h: 0.5, fill: { color: cor || C.accent1 }, line: { color: cor || C.accent1 } });
  s.addText(txt, { x, y, w: 0.5, h: 0.5, fontSize: 16, bold: true, color: C.background1, align: "center",
    valign: "middle", margin: 0, isTextBox: true });
}

// ---------- números ----------
const ofc = J.oficial.filter(r => r.gabarito_usado === "total");
const R0 = J.gabarito.total;
const get = (pl, n, c = 10) => J.grade.find(r => r.plano === pl && r.n_ref === n && r.razao_c1_c2 === c);
const P = ["1 AAS", "2 Estrat. proporcional", "2 Estrat. Neyman", "3 Dois estágios", "4 Razão com auxiliar 2018"];
const NOME = { "1 AAS": "AAS", "2 Estrat. proporcional": "Estrat. proporcional", "2 Estrat. Neyman": "Estrat. Neyman",
               "3 Dois estágios": "Dois estágios", "4 Razão com auxiliar 2018": "Razão (aux. 2018)" };
const ef3 = [5, 10, 20].map(c => [200, 400, 800].map(n => get("3 Dois estágios", n, c).eficiencia_custo));
const ef3c = ef3[1];
const orc = [200, 400, 800].map(n => get("1 AAS", n).orcamento);

// estilo comum dos gráficos
const eixo = () => ({ catAxisLabelColor: HEX.accent5, valAxisLabelColor: HEX.accent5, catAxisLabelFontSize: 12,
  valAxisLabelFontSize: 12, catAxisLabelFontFace: "+mn-lt", valAxisLabelFontFace: "+mn-lt",
  valGridLine: { color: "E3E8E6", size: 0.75 }, catGridLine: { style: "none" },
  valAxisTitleFontFace: "+mn-lt", catAxisTitleFontFace: "+mn-lt", valAxisTitleColor: HEX.accent5,
  catAxisTitleColor: HEX.accent5, valAxisTitleFontSize: 12, catAxisTitleFontSize: 12,
  legendFontFace: "+mn-lt", legendFontSize: 12, legendColor: HEX.dk1, dataLabelFontFace: "+mn-lt" });

// =====================================================================
// 1. CAPA
pres.addSection({ title: "Abertura" });
let s = pres.addSlide({ masterName: "CAPA", sectionTitle: "Abertura" });
s.addText("Qual plano amostral estima melhor a abstenção com orçamento limitado?", { placeholder: "title" });
s.addText([
  { text: "Seções eleitorais de São Paulo · 1º turno de 2022", options: { breakLine: true } },
  { text: "ME430 – Técnicas de Amostragem · IMECC/Unicamp", options: { breakLine: true } },
  { text: " ", options: { breakLine: true } },
  { text: ORADORES.join("  ·  "), options: { fontSize: 14 } },
], { placeholder: "body" });
s.addNotes(`${ORADORES[0]} abre. Apresentar o grupo e a pergunta em uma frase: se cada seção eleitoral custasse dinheiro para ser coletada, que plano amostral daria a melhor estimativa da abstenção gastando o mesmo?`);

// 2. A PERGUNTA
s = conteudo("A pergunta", ORADORES[0], "Abertura");
s.addText([
  { text: "Se obter os dados de cada seção eleitoral tivesse um custo, ", options: {} },
  { text: "qual plano amostral estimaria melhor a taxa de abstenção", options: { bold: true, color: C.text2 } },
  { text: " gastando o mesmo orçamento?", options: {} },
], { x: 0.5, y: 1.3, w: 5.2, h: 1.4, fontSize: 20, color: C.text1, margin: 0, isTextBox: true, valign: "top" });
s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.5, y: 2.95, w: 5.2, h: 1.0, rectRadius: 0.08,
  fill: { color: C.background2 }, line: { color: C.background2 }, objectName: "formula" });
s.addText("R = Σ abstenções / Σ eleitores aptos", { x: 0.7, y: 2.95, w: 4.8, h: 1.0, fontSize: 20,
  color: C.text2, bold: true, margin: 0, isTextBox: true, valign: "middle", fontFace: THEME.headFontFace });
s.addText("Dados públicos do TSE, agregados por seção: sem dados pessoais. Trabalho metodológico: nenhum candidato ou partido é analisado.",
  { x: 0.5, y: 4.15, w: 5.2, h: 0.8, fontSize: 13, color: C.accent5, margin: 0, isTextBox: true, valign: "top" });
destaque(s, 6.4, 1.3, 3.1, pct(R0, 2) + "%", "abstenção real em SP (o \"gabarito\")", C.accent2);
destaque(s, 6.4, 2.75, 3.1, "101.073", "seções eleitorais na população");
s.addNotes("O parâmetro é uma razão: total de abstenções dividido pelo total de aptos. Como temos todas as seções, sabemos o valor verdadeiro (21,63%) e podemos medir o erro de cada plano. É um cenário controlado: fingimos que cada seção custa para ser coletada.");

// 3. DADOS
s = conteudo("Os dados", ORADORES[0], "Abertura");
[["101.073", "seções (população)"], ["645", "municípios"], ["34,6 mi", "eleitores aptos"], ["11", "regiões do IBGE"]]
  .forEach((v, i) => destaque(s, 0.5 + i * 2.3, 1.25, 2.1, v[0], v[1]));
cartao(s, 0.5, 2.85, 4.3, 2.15, "Origem",
  "TSE, \"Detalhe da votação por seção\" (2022 e 2018).\nFiltros: SP, 1º turno e um único cargo, para ter uma linha por seção.", "c-origem");
cartao(s, 5.2, 2.85, 4.3, 2.15, "Conferência",
  "Aptos = comparecimento + abstenções em todas as seções; nenhuma duplicata.\nTotais iguais aos de outra tabela do TSE.", "c-conf");
s.addNotes("População: todas as seções de SP no 1º turno de 2022. O arquivo repete cada seção por cargo, por isso filtramos um cargo só. Checamos a consistência e conferimos os totais com a tabela do TSE por município e zona: bateram exatamente. Também pareamos com 2018 para usar como variável auxiliar.");

// 4. CUSTO
s = conteudo("Comparar planos com o mesmo custo", ORADORES[0], "Abertura");
s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.5, y: 1.25, w: 9.0, h: 1.0, rectRadius: 0.08,
  fill: { color: C.text2 }, line: { color: C.text2 }, objectName: "custo" });
s.addText("Custo = 10 × (nº de municípios) + 1 × (nº de seções)", { x: 0.7, y: 1.25, w: 8.6, h: 1.0,
  fontSize: 22, bold: true, color: C.background1, align: "center", valign: "middle", margin: 0, isTextBox: true,
  fontFace: THEME.headFontFace });
cartao(s, 0.5, 2.55, 2.8, 2.45, "Por quê?", "Incluir um município novo na amostra é caro; uma seção a mais de um município que já está na amostra é barata.", "c-pq");
cartao(s, 3.6, 2.55, 2.8, 2.45, "Orçamentos", `O custo de uma AAS de 200, 400 e 800 seções.\nReferência: 400 seções (${num(orc[1], 0)} unidades).`, "c-orc");
cartao(s, 6.7, 2.55, 2.8, 2.45, "Sensibilidade", "Também testamos o município valendo 5 e 20 seções.", "c-sens");
s.addNotes("Comparar com o mesmo número de seções seria injusto: planos que concentram a amostra em poucos municípios gastam menos. Então todos os planos gastam o mesmo orçamento esperado. Cada município diferente na amostra custa 10, cada seção custa 1 (é uma hipótese do cenário: não visitamos nenhum município, os dados vêm do TSE). Os orçamentos são o custo de uma AAS de 200, 400 e 800 seções.");

// =====================================================================
// 5. SEÇÃO PLANOS
secao("Os quatro planos", ORADORES[1], "Planos");

// 6. QUATRO PLANOS
s = conteudo("Quatro planos, mesmo orçamento", ORADORES[1], "Planos");
[
  ["1", "AAS", "Sorteia seções ao acaso no estado inteiro."],
  ["2", "Estratificada", "Sorteia seções dentro de cada uma das 11 regiões (proporcional ou Neyman)."],
  ["3", "Dois estágios", "Sorteia municípios e, dentro deles, algumas seções."],
  ["4", "Razão com 2018", "AAS que usa a abstenção de 2018 da mesma seção como auxiliar."],
].forEach((p, i) => {
  const x = 0.5 + (i % 2) * 4.6, y = 1.3 + Math.floor(i / 2) * 1.9;
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w: 4.4, h: 1.7, rectRadius: 0.08, fill: { color: C.background2 },
    line: { color: C.background2 }, objectName: "plano" + p[0] });
  bolinha(s, x + 0.2, y + 0.2, p[0]);
  s.addText(p[1], { x: x + 0.85, y: y + 0.2, w: 3.35, h: 0.5, fontSize: 18, bold: true, color: C.text2, margin: 0,
    isTextBox: true, valign: "middle", fontFace: THEME.headFontFace });
  s.addText(p[2], { x: x + 0.85, y: y + 0.75, w: 3.35, h: 0.85, fontSize: 14, color: C.text1, margin: 0, isTextBox: true, valign: "top" });
});
s.addNotes("Os quatro planos. Em todos a unidade é a seção eleitoral e o estimador é uma razão: abstenções estimadas sobre aptos estimados, com pesos iguais ao inverso da probabilidade de seleção. A variância vem da linearização de Taylor. Conferimos nossas fórmulas contra o pacote survey do R: deram iguais.");

// 7. ESTRATIFICADA
s = conteudo("Estratificada: as regiões quase não diferem", ORADORES[1], "Planos");
destaque(s, 0.5, 1.3, 4.0, "3,8%", "da variação da abstenção por seção é explicada pela região (dados de 2018)");
destaque(s, 0.5, 2.8, 4.0, "≈ 4%", "de ganho esperado sobre a AAS: pequeno");
cartao(s, 5.0, 1.3, 4.5, 3.6, "Proporcional × Neyman",
  "Proporcional: cada região recebe seções conforme o seu tamanho.\n\nNeyman: dá mais seções às regiões mais variáveis (medido em 2018, nunca em 2022).\n\nComo as regiões variam pouco, as duas ficam parecidas.", "c-estrat");
s.addNotes("Usamos as 11 regiões intermediárias do IBGE como estratos. A expectativa era que a abstenção variasse mais entre regiões, mas em 2018 a região explicava só 3,8% da variação. Então já esperávamos ganho pequeno. A Neyman usa o desvio-padrão de 2018 de cada região.");

// 8. DOIS ESTÁGIOS
s = conteudo("Dois estágios: municípios, depois seções", ORADORES[1], "Planos");
[
  ["1", "São Paulo entra uma única vez", "Tem 27% dos eleitores: no sorteio proporcional ao tamanho, sairia várias vezes (em média 2,7 vezes em 10 sorteios). Por isso entra uma vez só, com certeza, e sorteamos 268 seções dentro dela.", 0.95],
  ["2", "Sorteio dos outros municípios", "Os outros 644 são sorteados com chance proporcional ao nº de eleitores (com reposição).", 0.6],
  ["3", "Sorteio de seções", "Em cada município sorteado, 4 seções ao acaso.", 0.4],
].reduce((y, p) => {
  bolinha(s, 0.5, y + 0.05, p[0]);
  s.addText(p[1], { x: 1.2, y, w: 4.5, h: 0.4, fontSize: 17, bold: true, color: C.text2, margin: 0, isTextBox: true, fontFace: THEME.headFontFace });
  s.addText(p[2], { x: 1.2, y: y + 0.42, w: 4.5, h: p[3], fontSize: 13, color: C.text1, margin: 0, isTextBox: true, valign: "top" });
  return y + 0.42 + p[3] + 0.25;
}, 1.25);
const o3 = ofc.find(r => r.plano === "3 Dois estágios"), oA = ofc.find(r => r.plano === "1 AAS");
cartao(s, 6.0, 1.3, 3.5, 3.6, "O ganho",
  `Com o mesmo dinheiro, compra muito mais seções: ${num(o3.secoes)} contra ${num(oA.secoes)} da AAS na amostra oficial.\n\nDesenho escolhido: 160 sorteios de municípios × 4 seções + 268 seções na capital.`, "c-ganho");
s.addNotes("Como o custo depende de quantos municípios entram na amostra, sortear municípios e várias seções dentro de cada um barateia a seção. No primeiro estágio, a capital não entra no sorteio: com 27% dos eleitores, num sorteio proporcional ao tamanho e com reposição ela sairia repetidas vezes (em média 2,7 vezes a cada 10 sorteios). Por isso ela entra uma única vez, com probabilidade 1, e dentro dela sorteamos 268 seções. Fora dela usamos sorteio com reposição e o estimador de Hansen-Hurwitz, uma aproximação que declaramos no relatório. O número de municípios e de seções por município foi escolhido pela menor margem de erro calculada com 2018.");

// 9. RAZÃO 2018
s = conteudo("Razão com auxiliar: a abstenção de 2018", ORADORES[1], "Planos");
destaque(s, 0.5, 1.3, 4.0, "94,5%", "das seções de 2022 têm par em 2018 (mesmo município, zona e seção)");
destaque(s, 0.5, 2.8, 4.0, "5.580", "seções sem par ficam de fora do plano 4 (erro de cobertura)", C.accent2);
cartao(s, 5.0, 1.3, 4.5, 3.6, "Ideia",
  "Seções com muita abstenção em 2018 tendem a ter muita em 2022.\n\nO plano usa o total conhecido de 2018 para corrigir a estimativa.\n\nProblema: as seções sem par têm abstenção menor (18,97% contra 21,77%).", "c-razao");
s.addNotes("O plano 4 só pode sortear seções que existem nos dois anos. As seções novas ou renumeradas ficam de fora, e elas têm abstenção menor. Isso é um erro não amostral de cobertura: o plano mira um alvo um pouco diferente do verdadeiro.");

// =====================================================================
// 10. SEÇÃO RESULTADOS
secao("Resultados", ORADORES[2], "Resultados");

// 11. COMO AVALIAMOS
s = conteudo("Como avaliamos", ORADORES[2], "Resultados");
cartao(s, 0.5, 1.3, 4.3, 2.0, "Amostra oficial", "Um sorteio de cada plano, com semente fixa, no orçamento de referência.", "c-oficial");
cartao(s, 5.2, 1.3, 4.3, 2.0, "Monte Carlo", `${num(J.B)} sorteios de cada plano, em 3 orçamentos e 3 cenários de custo.`, "c-mc");
s.addText([
  { text: "Viés: ", options: { bold: true, color: C.text2 } }, { text: "na média, o plano acerta o valor real?", options: { breakLine: true } },
  { text: "REQM: ", options: { bold: true, color: C.text2 } }, { text: "erro típico de uma estimativa (quanto menor, melhor)", options: { breakLine: true } },
  { text: "Cobertura: ", options: { bold: true, color: C.text2 } }, { text: "o IC de 95% contém o valor real em ~95% das vezes?", options: {} },
], { x: 0.5, y: 3.55, w: 9.0, h: 1.4, fontSize: 15, color: C.text1, margin: 0, isTextBox: true, valign: "top", paraSpaceAfter: 6 });
s.addNotes("Uma amostra só pode dar sorte ou azar. Por isso, além da amostra oficial, repetimos o sorteio mil vezes para cada plano e medimos viés, raiz do erro quadrático médio e cobertura do intervalo de confiança.");

// 12. AMOSTRA OFICIAL (tabela)
s = conteudo("Amostra oficial: todos os ICs acertam", ORADORES[2], "Resultados");
const cab = ["Plano", "Seções", "Municípios", "Estimativa", "IC 95%"].map(t => ({ text: t,
  options: { bold: true, color: C.background1, fill: { color: C.text2 } } }));
const linhas = P.map(pl => {
  const r = ofc.find(x => x.plano === pl), dest = pl === "3 Dois estágios";
  const o = dest ? { bold: true, fill: { color: C.background2 } } : {};
  return [NOME[pl], num(r.secoes), num(r.municipios), pct(r.R, 2) + "%", `${pct(r.ic_inf)}% a ${pct(r.ic_sup)}%`]
    .map(t => ({ text: t, options: { ...o } }));
});
s.addTable([cab, ...linhas], { x: 0.5, y: 1.25, w: 9.0, colW: [2.6, 1.2, 1.4, 1.5, 2.3], fontSize: 14,
  color: C.text1, border: { type: "solid", pt: 0.5, color: "D5DFDB" }, align: "left", valign: "middle", rowH: 0.42 });
s.addText([
  { text: `Valor real: ${pct(R0, 2)}%. `, options: { bold: true, color: C.accent2 } },
  { text: "Todos os intervalos contêm o valor real. O dois estágios teve o menor erro-padrão estimado.", options: {} },
], { x: 0.5, y: 4.0, w: 9.0, h: 0.9, fontSize: 15, color: C.text1, margin: 0, isTextBox: true, valign: "top" });
s.addNotes("Na amostra oficial, todos os planos chegaram perto: erros entre 0,1 e 0,4 ponto percentual, e todos os intervalos cobrem o valor real. No plano 3, as 908 seções contam os sorteios repetidos. Com uma amostra só não dá para dizer qual é melhor: a diferença é quase só sorte. Por isso o Monte Carlo.");

// 13. BOXPLOT
s = conteudo("1.000 sorteios: onde caem as estimativas", ORADORES[2], "Resultados");
s.addImage({ path: path.join(__dirname, "fig-boxplot.png"), x: 0.5, y: 1.15, w: 6.3, h: 6.3 * 4.2 / 8,
  altText: "Boxplots das estimativas de cada plano em 1.000 sorteios, com a linha do valor real" });
cartao(s, 7.1, 1.25, 2.4, 3.7, "Leitura",
  "Linha laranja: valor real.\n\nDois estágios: caixa mais estreita.\n\nRazão 2018: centrada na linha tracejada (só seções pareadas).", "c-leitura", { size: 13 });
s.addNotes("Orçamento de referência. Os planos 1 a 3 se centram no valor real, sem viés. O de dois estágios é o mais concentrado. O plano 4 se centra um pouco à direita: é o efeito das seções sem par em 2018.");

// =====================================================================
// 14. SEÇÃO CONCLUSÕES
secao("Comparação e conclusões", ORADORES[3], "Conclusões");

// 15. REQM POR ORÇAMENTO
s = conteudo("Dois estágios erra menos em todo orçamento", ORADORES[3], "Conclusões");
const cats = ["200 seções", "400 seções", "800 seções"];
const dadosReqm = P.map(pl => ({ name: NOME[pl], labels: cats, values: [200, 400, 800].map(n => +(100 * get(pl, n).reqm).toFixed(3)) }));
s.addChart(pres.charts.LINE, dadosReqm, { x: 0.5, y: 1.15, w: 6.2, h: 3.9, ...eixo(),
  chartColors: [HEX.accent5, HEX.accent6, HEX.accent4, HEX.accent1, HEX.accent2], lineSize: 2.5, lineDataSymbolSize: 8,
  showLegend: true, legendPos: "b", showValAxisTitle: true, valAxisTitle: "REQM (p.p.)", valAxisMinVal: 0, valAxisMajorUnit: 0.1,
  valAxisLabelFormatCode: "0.0", showCatAxisTitle: true, catAxisTitle: "Orçamento (custo de uma AAS de…)" });
destaque(s, 7.0, 1.3, 2.5, num(Math.min(...ef3c), 2) + " a " + num(Math.max(...ef3c), 2), "vezes: EQM da AAS dividido pelo do dois estágios (mesmo custo)");
destaque(s, 7.0, 3.0, 2.5, "≈ AAS", "estratificadas: diferença dentro do erro do Monte Carlo", C.accent5);
s.addNotes(`Erro típico (raiz do EQM) em pontos percentuais, cenário central de custo. O dois estágios é o mais baixo nos três orçamentos: o EQM da AAS é ${num(Math.min(...ef3c), 2)} a ${num(Math.max(...ef3c), 2)} vezes o dele. As duas estratificadas ficam em cima da AAS. O plano 4 é o pior quando comparado com o valor real, por causa do viés de cobertura.`);

// 16. SENSIBILIDADE AO CUSTO
s = conteudo("Quanto mais caro o município, maior a vantagem", ORADORES[3], "Conclusões");
s.addChart(pres.charts.BAR, [200, 400, 800].map((n, j) => ({ name: `Orçamento ${n}`,
  labels: ["Município = 5 seções", "= 10 seções", "= 20 seções"], values: [0, 1, 2].map(i => +ef3[i][j].toFixed(2)) })),
  { x: 0.5, y: 1.15, w: 6.2, h: 3.9, barDir: "col", ...eixo(),
  chartColors: [HEX.accent6, HEX.accent3, HEX.accent1], showLegend: true, legendPos: "b", valAxisMinVal: 0,
  showValue: true, dataLabelPosition: "outEnd", dataLabelFormatCode: "0.00", dataLabelFontSize: 11, dataLabelColor: HEX.dk1,
  showValAxisTitle: true, valAxisTitle: "Eficiência do dois estágios (× AAS)", valAxisLabelFormatCode: "0.0" });
cartao(s, 7.0, 1.25, 2.5, 3.7, "Leitura",
  "Acima de 1: melhor que a AAS.\n\nCom município barato (5), a vantagem quase some.\n\nCom município caro (20), chega a cerca de 2×.", "c-sens2", { size: 13 });
s.addNotes("Eficiência a custo igual do plano de dois estágios: EQM da AAS dividido pelo dele. Quando incluir um município é barato, a vantagem é pequena, perto do erro do Monte Carlo. Quanto mais caro, mais compensa concentrar a amostra em menos municípios.");

// 17. ESCOLHA DE m
s = conteudo("Plano 3: mais municípios, menos seções", ORADORES[3], "Conclusões");
s.addChart(pres.charts.LINE, [{ name: "REQM", labels: J.curva.map(r => String(r.m)), values: J.curva.map(r => +(100 * r.reqm).toFixed(3)) }],
  { x: 0.5, y: 1.15, w: 6.2, h: 3.9, ...eixo(), chartColors: [HEX.accent1], lineSize: 2.5, lineDataSymbolSize: 6, showLegend: false,
    valAxisMinVal: 0, valAxisLabelFormatCode: "0.0", showValAxisTitle: true, valAxisTitle: "REQM (p.p.)",
    showCatAxisTitle: true, catAxisTitle: "m = nº de municípios sorteados (mesmo custo)" });
const cm = J.curva, c3 = cm[0], cU = cm[cm.length - 1];
cartao(s, 7.0, 1.25, 2.5, 3.7, "Leitura",
  `m = ${c3.m} (k = ${c3.k}): REQM ${pct(c3.reqm)} p.p., IC cobre só ${pct(c3.cobertura, 0)}%.\n\nm = ${cU.m} (k = ${cU.k}): REQM ${pct(cU.reqm)} p.p. É o desenho escolhido.`, "c-m", { size: 13 });
s.addNotes(`Mesmo orçamento, trocando número de municípios (m) por seções por município (k). Poucos municípios com muitas seções é ruim: seções do mesmo município se parecem (correlação intraclasse de ${num(J.icc, 2)}). O erro cai quando espalhamos por mais municípios, e o par escolhido a priori com 2018 foi o melhor.`);

// 18. CONCLUSÕES
s = conteudo("Conclusões", ORADORES[3], "Conclusões");
[
  ["Dois estágios é o melhor", "Compra mais seções com o mesmo dinheiro; vence em todos os cenários testados."],
  ["Estratificar por região não ajudou", "A abstenção varia pouco entre as regiões."],
  ["O auxiliar de 2018 não ajudou", "Não reduz a variância, e as seções sem par criam viés."],
  ["Planejar com 2018 funcionou", "As margens previstas foram conservadoras e a ordem dos planos se manteve."],
].forEach((c, i) => {
  const y = 1.25 + i * 0.95;
  bolinha(s, 0.5, y + 0.1, String(i + 1), i === 0 ? C.accent2 : C.accent1);
  s.addText(c[0], { x: 1.2, y, w: 8.3, h: 0.4, fontSize: 18, bold: true, color: C.text2, margin: 0, isTextBox: true, fontFace: THEME.headFontFace });
  s.addText(c[1], { x: 1.2, y: y + 0.4, w: 8.3, h: 0.4, fontSize: 14, color: C.text1, margin: 0, isTextBox: true });
});
s.addNotes("Fechamento: com orçamento limitado e custo de deslocamento, a amostragem em dois estágios, com muitos municípios e poucas seções em cada, foi a melhor. A estratificação por região e o auxiliar de 2018 não trouxeram ganho. As escolhas feitas só com dados de 2018 se confirmaram em 2022.");

// 19. OBRIGADO
s = pres.addSlide({ masterName: "SECAO", sectionTitle: "Conclusões" });
s.addText("Obrigado!", { placeholder: "title" });
s.addText("Perguntas?", { placeholder: "body" });
s.addNotes("Abrir para perguntas.");

(async () => {
  const out = path.join(__dirname, "apresentacao.pptx");
  await pres.writeFile({ fileName: out });
  await applyTheme(out, THEME);
  console.log("ok:", out);
})();
