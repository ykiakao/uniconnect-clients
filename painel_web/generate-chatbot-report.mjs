import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import vm from "node:vm";

const root = resolve(import.meta.dirname, "..");
const appPath = resolve(import.meta.dirname, "app.js");
const outputPath = resolve(
  root,
  "docs",
  "relatorio-funcionalidades-botoes-chatbot.html",
);
const pdfOutputPath = resolve(
  root,
  "docs",
  "relatorio-funcionalidades-botoes-chatbot.pdf",
);

const appSource = readFileSync(appPath, "utf8");
const flow = extractChatbotFlow(appSource);
const parentMap = buildParentMap(flow);

const chatbotControls = [
  {
    name: "Abrir/fechar ajuda",
    selector: "#chatbot-toggle",
    behavior:
      "Alterna o painel do chatbot, atualiza aria-expanded e devolve foco ao botao ao fechar.",
  },
  {
    name: "Fechar",
    selector: ".chatbot-close",
    behavior: "Fecha o painel de ajuda e retorna foco ao botao flutuante.",
  },
  {
    name: "Voltar",
    selector: ".chatbot-back",
    behavior:
      "Retorna ao no pai calculado por chatbotParentMap; fica desabilitado no inicio.",
  },
  {
    name: "Inicio",
    selector: ".chatbot-reset",
    behavior: "Reinicia o fluxo no no start; fica desabilitado no inicio.",
  },
  {
    name: "Opcao de fluxo",
    selector: ".chatbot-option[data-chatbot-target]",
    behavior:
      "Le o destino em data-chatbot-target e navega para o no correspondente; se o destino nao existir, volta ao start.",
  },
  {
    name: "Escape",
    selector: "document.onkeydown",
    behavior: "Fecha o chatbot quando o painel esta aberto.",
  },
];

const stats = {
  nodes: Object.keys(flow).length,
  optionButtons: Object.values(flow).reduce(
    (total, node) => total + (node.options?.length ?? 0),
    0,
  ),
  nodesWithSteps: Object.values(flow).filter((node) => node.steps?.length).length,
  steps: Object.values(flow).reduce(
    (total, node) => total + (node.steps?.length ?? 0),
    0,
  ),
};

const html = renderReport({
  flow,
  parentMap,
  stats,
  chatbotControls,
});

mkdirSync(dirname(outputPath), { recursive: true });
writeFileSync(outputPath, html);
writeFileSync(
  pdfOutputPath,
  createPdfReport({
    flow,
    parentMap,
    stats,
    chatbotControls,
  }),
  "binary",
);
console.log(outputPath);
console.log(pdfOutputPath);

function extractChatbotFlow(source) {
  const marker = "const chatbotFlow =";
  const markerIndex = source.indexOf(marker);
  if (markerIndex === -1) {
    throw new Error("chatbotFlow nao encontrado em app.js.");
  }

  const objectStart = source.indexOf("{", markerIndex);
  const objectEndMarker = "\n\nconst chatbotParentMap";
  const objectEnd = source.indexOf(objectEndMarker, objectStart);
  if (objectStart === -1 || objectEnd === -1) {
    throw new Error("Nao foi possivel delimitar o objeto chatbotFlow.");
  }

  const literal = source.slice(objectStart, objectEnd).trim().replace(/;$/, "");
  return vm.runInNewContext(`(${literal})`, Object.create(null), {
    timeout: 1000,
  });
}

function buildParentMap(flowMap) {
  return Object.entries(flowMap).reduce((parents, [nodeId, node]) => {
    node.options?.forEach((option) => {
      if (!parents[option.target]) parents[option.target] = nodeId;
    });
    return parents;
  }, {});
}

function renderReport({
  flow,
  parentMap,
  stats,
  chatbotControls,
}) {
  const generatedAt = new Intl.DateTimeFormat("pt-BR", {
    dateStyle: "long",
    timeStyle: "short",
  }).format(new Date());

  const nodeRows = Object.entries(flow)
    .map(([nodeId, node]) => {
      const options = node.options?.map((option) => option.label).join(", ") || "-";
      const steps = node.steps?.length ?? 0;
      const parent = parentMap[nodeId] ?? "-";
      return `
        <tr>
          <td><code>${escapeHtml(nodeId)}</code></td>
          <td>${escapeHtml(parent)}</td>
          <td>${escapeHtml(node.eyebrow)}</td>
          <td>${escapeHtml(node.title)}</td>
          <td>${escapeHtml(node.message)}</td>
          <td>${steps}</td>
          <td>${escapeHtml(options)}</td>
        </tr>
      `;
    })
    .join("");

  const optionRows = Object.entries(flow)
    .flatMap(([nodeId, node]) =>
      (node.options ?? []).map(
        (option) => `
          <tr>
            <td><code>${escapeHtml(nodeId)}</code></td>
            <td>${escapeHtml(node.title)}</td>
            <td>${escapeHtml(option.label)}</td>
            <td><code>${escapeHtml(option.target)}</code></td>
            <td>${escapeHtml(flow[option.target]?.title ?? "Destino nao encontrado")}</td>
          </tr>
        `,
      ),
    )
    .join("");

  const details = Object.entries(flow)
    .map(([nodeId, node]) => {
      const steps =
        node.steps
          ?.map((step) => `<li>${escapeHtml(step)}</li>`)
          .join("") || "<li>Este no apresenta apenas opcoes de navegacao.</li>";
      const options =
        node.options
          ?.map(
            (option) =>
              `<li><strong>${escapeHtml(option.label)}</strong> -> <code>${escapeHtml(
                option.target,
              )}</code></li>`,
          )
          .join("") || "<li>Sem opcoes neste no.</li>";

      return `
        <section class="node-detail">
          <h3>${escapeHtml(node.title)} <code>${escapeHtml(nodeId)}</code></h3>
          <p><strong>Categoria:</strong> ${escapeHtml(node.eyebrow)}</p>
          <p>${escapeHtml(node.message)}</p>
          <div class="split">
            <div>
              <h4>Passos do fluxo</h4>
              <ol>${steps}</ol>
            </div>
            <div>
              <h4>Botoes/opcoes exibidos</h4>
              <ul>${options}</ul>
            </div>
          </div>
        </section>
      `;
    })
    .join("");

  return `<!doctype html>
<html lang="pt-BR">
  <head>
    <meta charset="utf-8" />
    <title>Relatorio do Chatbot UniConnect</title>
    <style>
      @page { size: A4; margin: 14mm; }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        color: #212529;
        font-family: Arial, Helvetica, sans-serif;
        font-size: 12px;
        line-height: 1.45;
      }
      h1, h2, h3, h4 { margin: 0 0 8px; color: #0b2f66; line-height: 1.2; }
      h1 { font-size: 26px; }
      h2 { margin-top: 24px; font-size: 18px; border-bottom: 1px solid #cfd8e3; padding-bottom: 6px; }
      h3 { font-size: 15px; }
      h4 { font-size: 12px; text-transform: uppercase; letter-spacing: .4px; }
      p { margin: 0 0 8px; }
      code { color: #0b2f66; font-family: "SFMono-Regular", Consolas, monospace; font-size: 11px; }
      table { width: 100%; border-collapse: collapse; margin-top: 10px; page-break-inside: auto; }
      th, td { border: 1px solid #cfd8e3; padding: 6px; text-align: left; vertical-align: top; }
      th { background: #edf4ff; color: #0b2f66; font-size: 11px; text-transform: uppercase; }
      ul, ol { margin: 0 0 0 18px; padding: 0; }
      li { margin-bottom: 4px; }
      .cover {
        padding: 18px;
        border: 1px solid #b8c7dc;
        border-radius: 8px;
        background: #f6f9fd;
      }
      .summary-grid {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 8px;
        margin-top: 14px;
      }
      .metric {
        padding: 10px;
        border: 1px solid #cfd8e3;
        border-radius: 6px;
        background: #ffffff;
      }
      .metric strong { display: block; color: #0b2f66; font-size: 20px; }
      .note {
        margin-top: 10px;
        padding: 10px;
        border-left: 4px solid #0b72e7;
        background: #eef6ff;
      }
      .node-detail {
        page-break-inside: avoid;
        margin-top: 14px;
        padding: 12px;
        border: 1px solid #d7dee8;
        border-radius: 6px;
      }
      .split {
        display: grid;
        grid-template-columns: 1.2fr .8fr;
        gap: 18px;
        margin-top: 10px;
      }
      .page-break { page-break-before: always; }
    </style>
  </head>
  <body>
    <section class="cover">
      <h1>Relatorio de funcionalidades e botoes do chatbot UniConnect</h1>
      <p><strong>Escopo:</strong> somente o chatbot de fluxos UniConnect.</p>
      <p><strong>Gerado em:</strong> ${escapeHtml(generatedAt)}</p>
      <div class="summary-grid">
        <div class="metric"><strong>${stats.nodes}</strong><span>nos de fluxo</span></div>
        <div class="metric"><strong>${stats.optionButtons}</strong><span>botoes de opcao</span></div>
        <div class="metric"><strong>${stats.nodesWithSteps}</strong><span>nos com passo a passo</span></div>
        <div class="metric"><strong>${stats.steps}</strong><span>passos documentados</span></div>
      </div>
    </section>

    <h2>Funcionalidades do chatbot</h2>
    <ul>
      <li>Assistente flutuante disponivel tanto na tela de login quanto no painel autenticado.</li>
      <li>Navegacao por arvore de decisoes baseada em <code>chatbotFlow</code>.</li>
      <li>Mensagem contextual, categoria, titulo, botoes de opcao e passo a passo por no.</li>
      <li>Historico simples por mapa de pais para o botao Voltar.</li>
      <li>Reset para o inicio do fluxo.</li>
      <li>Fechamento por botao e por tecla Escape.</li>
      <li>Foco gerenciado apos abertura, fechamento e troca de no.</li>
      <li>Protecao contra HTML injetado por <code>escapeHtml</code>.</li>
      <li>Sem persistencia remota: o estado atual vive em memoria em <code>state.chatbotNodeId</code> e <code>state.chatbotOpen</code>.</li>
    </ul>

    <h2>Botoes e controles proprios do chatbot</h2>
    ${renderSimpleTable(chatbotControls, ["name", "selector", "behavior"], ["Controle", "Seletor", "Comportamento"])}

    <h2>Mapa de nos do fluxo</h2>
    <table>
      <thead>
        <tr>
          <th>No</th>
          <th>Pai</th>
          <th>Categoria</th>
          <th>Titulo</th>
          <th>Mensagem</th>
          <th>Passos</th>
          <th>Opcoes</th>
        </tr>
      </thead>
      <tbody>${nodeRows}</tbody>
    </table>

    <h2 class="page-break">Botoes de opcao do chatbot</h2>
    <table>
      <thead>
        <tr>
          <th>No origem</th>
          <th>Tela origem</th>
          <th>Texto do botao</th>
          <th>Destino</th>
          <th>Tela destino</th>
        </tr>
      </thead>
      <tbody>${optionRows}</tbody>
    </table>

    <h2 class="page-break">Detalhamento por no</h2>
    ${details}

    <h2>Observacoes tecnicas</h2>
    <ul>
      <li>O chatbot usa uma arvore de decisoes local baseada no objeto <code>chatbotFlow</code>.</li>
      <li>Cada opcao de fluxo aponta para um destino por <code>data-chatbot-target</code>.</li>
      <li>Quando um destino invalido e solicitado, o chatbot retorna ao no inicial.</li>
      <li>O conteudo apresentado no chatbot e escapado por <code>escapeHtml</code>.</li>
    </ul>
  </body>
</html>`;
}

function renderSimpleTable(rows, keys, headers) {
  return `
    <table>
      <thead>
        <tr>${headers.map((header) => `<th>${escapeHtml(header)}</th>`).join("")}</tr>
      </thead>
      <tbody>
        ${rows
          .map(
            (row) =>
              `<tr>${keys
                .map((key) => `<td>${escapeHtml(row[key])}</td>`)
                .join("")}</tr>`,
          )
          .join("")}
      </tbody>
    </table>
  `;
}

function createPdfReport({
  flow,
  parentMap,
  stats,
  chatbotControls,
}) {
  const pageWidth = 595.28;
  const pageHeight = 841.89;
  const margin = 42;
  const pages = [];
  let commands = [];
  let y = pageHeight - margin;

  function newPage() {
    if (commands.length) pages.push(commands.join("\n"));
    commands = [];
    y = pageHeight - margin;
  }

  function text(value, size = 10, indent = 0, gapBefore = 0) {
    y -= gapBefore;
    const lines = wrapPdfText(value, size, pageWidth - margin * 2 - indent);
    lines.forEach((line) => {
      const lineHeight = size * 1.35;
      if (y - lineHeight < margin) newPage();
      commands.push(
        `BT /F1 ${size} Tf ${margin + indent} ${y.toFixed(2)} Td (${escapePdfText(
          line,
        )}) Tj ET`,
      );
      y -= lineHeight;
    });
  }

  function heading(value, level = 1) {
    const size = level === 1 ? 18 : level === 2 ? 14 : 12;
    const gap = level === 1 ? 0 : 16;
    text(value, size, 0, gap);
    y -= 4;
  }

  function bullet(value, indent = 12) {
    text(`- ${value}`, 9.5, indent);
  }

  heading("Relatorio de funcionalidades e botoes do chatbot UniConnect", 1);
  text(
    "Escopo: somente o chatbot de fluxos UniConnect.",
  );
  text(
    `Resumo: ${stats.nodes} nos de fluxo; ${stats.optionButtons} botoes de opcao; ${stats.nodesWithSteps} nos com passo a passo; ${stats.steps} passos documentados.`,
    10,
    0,
    8,
  );

  heading("Funcionalidades do chatbot", 2);
  [
    "Assistente flutuante disponivel na tela de login e no painel autenticado.",
    "Navegacao por arvore de decisoes baseada em chatbotFlow.",
    "Mensagem contextual, categoria, titulo, botoes de opcao e passo a passo por no.",
    "Historico simples por mapa de pais para o botao Voltar.",
    "Reset para o inicio do fluxo.",
    "Fechamento por botao e por tecla Escape.",
    "Foco gerenciado apos abertura, fechamento e troca de no.",
    "Protecao contra HTML injetado por escapeHtml.",
    "Sem persistencia remota: o estado vive em state.chatbotNodeId e state.chatbotOpen.",
  ].forEach((item) => bullet(item));

  heading("Botoes e controles proprios do chatbot", 2);
  chatbotControls.forEach((control) => {
    bullet(`${control.name} (${control.selector}): ${control.behavior}`);
  });

  heading("Mapa de nos do fluxo", 2);
  Object.entries(flow).forEach(([nodeId, node]) => {
    const options = node.options?.map((option) => option.label).join(", ") || "-";
    text(
      `${nodeId} | pai: ${parentMap[nodeId] ?? "-"} | ${node.eyebrow} | ${node.title}`,
      10,
      0,
      6,
    );
    text(`Mensagem: ${node.message}`, 9.2, 10);
    text(`Passos: ${node.steps?.length ?? 0}. Opcoes: ${options}`, 9.2, 10);
  });

  newPage();
  heading("Botoes de opcao do chatbot", 2);
  Object.entries(flow).forEach(([nodeId, node]) => {
    (node.options ?? []).forEach((option) => {
      bullet(
        `${nodeId} / ${node.title}: "${option.label}" -> ${option.target} (${flow[option.target]?.title ?? "Destino nao encontrado"})`,
      );
    });
  });

  newPage();
  heading("Detalhamento por no", 2);
  Object.entries(flow).forEach(([nodeId, node]) => {
    heading(`${node.title} (${nodeId})`, 3);
    text(`Categoria: ${node.eyebrow}`, 9.5);
    text(`Mensagem: ${node.message}`, 9.5);
    text("Passos do fluxo:", 9.5, 0, 4);
    if (node.steps?.length) {
      node.steps.forEach((step, index) => bullet(`${index + 1}. ${step}`, 18));
    } else {
      bullet("Este no apresenta apenas opcoes de navegacao.", 18);
    }
    text("Botoes/opcoes exibidos:", 9.5, 0, 4);
    if (node.options?.length) {
      node.options.forEach((option) =>
        bullet(`${option.label} -> ${option.target}`, 18),
      );
    } else {
      bullet("Sem opcoes neste no.", 18);
    }
  });

  heading("Observacoes tecnicas", 2);
  [
    "O chatbot usa uma arvore de decisoes local baseada no objeto chatbotFlow.",
    "Cada opcao de fluxo aponta para um destino por data-chatbot-target.",
    "Quando um destino invalido e solicitado, o chatbot retorna ao no inicial.",
    "O conteudo apresentado no chatbot e escapado por escapeHtml.",
  ].forEach((item) => bullet(item));

  newPage();

  return buildPdf(pages, pageWidth, pageHeight);
}

function wrapPdfText(value, size, maxWidth) {
  const maxChars = Math.max(28, Math.floor(maxWidth / (size * 0.52)));
  const words = normalizePdfText(value).split(/\s+/);
  const lines = [];
  let current = "";

  words.forEach((word) => {
    const next = current ? `${current} ${word}` : word;
    if (next.length <= maxChars) {
      current = next;
      return;
    }

    if (current) lines.push(current);
    current = word;

    while (current.length > maxChars) {
      lines.push(current.slice(0, maxChars));
      current = current.slice(maxChars);
    }
  });

  if (current) lines.push(current);
  return lines.length ? lines : [""];
}

function normalizePdfText(value) {
  return String(value ?? "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[–—]/g, "-")
    .replace(/[“”]/g, '"')
    .replace(/[‘’]/g, "'")
    .replace(/[^ -~]/g, "");
}

function escapePdfText(value) {
  return normalizePdfText(value)
    .replaceAll("\\", "\\\\")
    .replaceAll("(", "\\(")
    .replaceAll(")", "\\)");
}

function buildPdf(pageStreams, pageWidth, pageHeight) {
  const objects = [];
  const addObject = (body) => {
    objects.push(body);
    return objects.length;
  };

  const catalogId = addObject("<< /Type /Catalog /Pages 2 0 R >>");
  const pagesId = addObject("");
  const fontId = addObject("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>");
  const pageIds = [];

  pageStreams.forEach((stream) => {
    const contentId = addObject(
      `<< /Length ${Buffer.byteLength(stream, "binary")} >>\nstream\n${stream}\nendstream`,
    );
    const pageId = addObject(
      `<< /Type /Page /Parent ${pagesId} 0 R /MediaBox [0 0 ${pageWidth} ${pageHeight}] /Resources << /Font << /F1 ${fontId} 0 R >> >> /Contents ${contentId} 0 R >>`,
    );
    pageIds.push(pageId);
  });

  objects[pagesId - 1] =
    `<< /Type /Pages /Kids [${pageIds.map((id) => `${id} 0 R`).join(" ")}] /Count ${pageIds.length} >>`;

  let pdf = "%PDF-1.4\n";
  const offsets = [0];
  objects.forEach((body, index) => {
    offsets.push(Buffer.byteLength(pdf, "binary"));
    pdf += `${index + 1} 0 obj\n${body}\nendobj\n`;
  });
  const xrefOffset = Buffer.byteLength(pdf, "binary");
  pdf += `xref\n0 ${objects.length + 1}\n`;
  pdf += "0000000000 65535 f \n";
  offsets.slice(1).forEach((offset) => {
    pdf += `${String(offset).padStart(10, "0")} 00000 n \n`;
  });
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root ${catalogId} 0 R >>\nstartxref\n${xrefOffset}\n%%EOF\n`;
  return pdf;
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}
