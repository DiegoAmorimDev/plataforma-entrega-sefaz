#!/usr/bin/env bash
# Gera um HTML único, pronto para imprimir em PDF pelo navegador.
#
#   bash build-pdf.sh
#   abra dist/proposta.html no Chrome e use Ctrl+P > Salvar como PDF
#   (marque "Gráficos de plano de fundo" para os diagramas saírem com cor)

set -euo pipefail
cd "$(dirname "$0")"
mkdir -p dist

pandoc \
  README.md \
  docs/01-visao-geral.md \
  docs/02-topologia.md \
  docs/03-cicd.md \
  docs/04-observabilidade.md \
  docs/05-resiliencia.md \
  docs/06-iac.md \
  docs/07-experiencia-dev.md \
  docs/08-plano-evolucao.md \
  docs/09-gitops-argocd.md \
  docs/10-dados.md \
  docs/adr/README.md \
  docs/adr/ADR-001-openshift-producao-rancher-dev.md \
  docs/adr/ADR-002-dois-clusters-independentes.md \
  docs/adr/ADR-003-gitops-em-vez-de-deploy-por-pipeline.md \
  docs/adr/ADR-004-bancos-fora-do-kubernetes.md \
  docs/adr/ADR-005-sem-service-mesh-na-fase-inicial.md \
  docs/adr/ADR-006-harbor-como-registry.md \
  docs/adr/ADR-007-promocao-por-digest.md \
  docs/adr/ADR-008-conjur-como-cofre.md \
  docs/adr/ADR-009-argocd-central-com-contingencia.md \
  docs/adr/ADR-010-promocao-por-merge-request.md \
  docs/adr/ADR-011-ambiente-por-diretorio.md \
  docs/adr/ADR-012-sonarqube-community.md \
  docs/adr/ADR-013-cache-valkey-por-aplicacao.md \
  docs/adr/ADR-014-leitura-e-particionamento-sem-sharding.md \
  --from=gfm \
  --to=html5 \
  --standalone \
  --toc --toc-depth=2 \
  --metadata title="Plataforma de Entrega e Execução — Secretaria da Fazenda" \
  --template=template.html \
  --output=dist/proposta.html

# Mermaid lê o textContent de <pre class="mermaid">. O pandoc envolve em <code>,
# que atrapalha o parser em alguns diagramas; removemos a camada interna.
node -e '
const fs = require("fs");
const p = "dist/proposta.html";
let h = fs.readFileSync(p, "utf8");
h = h.replace(
  /<pre class="mermaid"><code>([\s\S]*?)<\/code><\/pre>/g,
  (_, body) => `<pre class="mermaid">${body
      .replace(/&quot;/g, "\"")
      .replace(/&#39;/g, "'"'"'")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&amp;/g, "&")}</pre>`
);
// As figuras do draw.io e a capa entram embutidas, para o HTML não depender de caminho
// relativo: o README aponta para docs/diagramas/ e os documentos, para diagramas/.
let figuras = 0;
h = h.replace(/<img src="((?:docs\/)?(?:diagramas|assets)\/[^"]+\.svg)"/g, (_, src) => {
  const caminho = [src, "docs/" + src].find((c) => fs.existsSync(c));
  if (!caminho) throw new Error("figura não encontrada: " + src);
  figuras++;
  const dados = fs.readFileSync(caminho).toString("base64");
  return `<img class="figura" src="data:image/svg+xml;base64,${dados}"`;
});
fs.writeFileSync(p, h);
console.log("diagramas preparados:", (h.match(/class="mermaid"/g) || []).length);
console.log("figuras embutidas:", figuras);
'

echo "pronto: dist/proposta.html"
