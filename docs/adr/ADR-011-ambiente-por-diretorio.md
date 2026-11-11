# ADR-011 — Ambiente é diretório, não branch

**Situação:** aceita.

## Contexto

O repositório de manifestos precisa representar três ambientes, e produção em dois sítios. Há dois
jeitos comuns de fazer isso no Git: um branch por ambiente, em que promover é fazer merge de `hml`
em `prd`; ou um branch só, `main`, com um diretório por ambiente, em que promover é alterar um
arquivo.

## Decisão

Um branch só. Cada aplicação tem `base/` e um diretório por ambiente em `overlays/`: `dev`, `hml`,
`prd`, `prd-dc1` e `prd-dc2`. Os dois últimos herdam de `prd` e carregam só o que difere por sítio.

O Argo CD sempre lê `main`. O que muda entre ambientes é o caminho.

## Alternativa descartada

**Branch por ambiente.** Parece natural porque espelha o fluxo de promoção. Na prática, os branches
divergem. Uma correção feita direto em `prd` durante um incidente não volta para `hml`, e o merge
seguinte de `hml` em `prd` traz junto alterações que ninguém pretendia promover. A pergunta "qual a
diferença entre homologação e produção" vira um `git diff` entre branches, que mistura a diferença
intencional com o acúmulo acidental.

Com diretório, a diferença entre ambientes é o conteúdo de dois arquivos lado a lado, e ela é
sempre intencional.

## Consequência aceita

- **Todos os times escrevem no mesmo `main`.** O arquivo `CODEOWNERS` garante que cada time só
  aprove o próprio diretório. Em `overlays/prd*`, um job do pipeline exige também a plataforma
  quando a mudança vai além do digest (ADR-010).
- **O histórico de `main` é ruidoso**, com dezenas de commits de promoção por dia. A mensagem
  padronizada pelo promotor, com aplicação, ambiente e digest, torna o histórico filtrável.
- **Uma alteração na `base` afeta todos os ambientes ao mesmo tempo.** Alteração estrutural começa
  como ajuste no overlay de `dev`, sobe como ajuste no de `hml` e só então entra na `base`.

## O que mudaria a decisão

- **Se o repositório único degradar a renderização do Argo CD** ou gerar conflito frequente entre
  promotores concorrentes no push para `main`, ele se divide em um repositório por time. Nunca em
  um branch por ambiente.
- **Se um ambiente passar a ter aprovadores fora do GitLab**, como uma área de controle externo,
  aquele ambiente ganha repositório próprio, com permissão própria.
