# ADR-007 — A promoção entre ambientes move o digest da imagem

**Situação:** aceita.

## Contexto

Há três formas comuns de levar uma versão de desenvolvimento até produção.

Reconstruir a imagem em cada ambiente, a partir do mesmo commit. Reaproveitar a imagem e trocar a
tag, publicando a mesma imagem como `app:hml` e depois `app:prd`. Ou referenciar a imagem pelo
digest, o hash do conteúdo, e promover alterando apenas esse identificador.

## Decisão

A imagem é construída uma única vez, quando o commit entra em `main`. Todo manifesto referencia a
imagem por `@sha256:...`. Promover é substituir uma linha no overlay do ambiente de destino.

## Alternativas descartadas

**Reconstruir por ambiente.** Descartada porque o mesmo Dockerfile não produz a mesma imagem em
dias diferentes. A imagem base recebeu correção, o repositório de pacotes atualizou uma
biblioteca, uma dependência transitiva mudou de versão dentro da mesma faixa. O resultado é que a
imagem testada em homologação não é a que executa em produção, e nada no processo registra a
diferença. O defeito que aparece só em produção, nesse modelo, é impossível de reproduzir.

**Promover trocando a tag.** Melhor que reconstruir, mas ainda frágil. Tag é um ponteiro mutável:
`app:prd` pode ser reapontada por qualquer pessoa com acesso de escrita no registry, inclusive por
engano. O manifesto fica idêntico antes e depois, o que torna a alteração invisível no Git. Além
disso, o nó que já tem `app:prd` guardada pode não perceber a mudança, conforme a política de
obtenção da imagem.

## Consequência aceita

- O manifesto fica menos legível. `app@sha256:9f2c7b...` não diz qual versão é. A compensação é um
  comentário obrigatório na linha, com a versão e a data, escrito pelo próprio pipeline.
- Encontrar a versão em execução exige consultar o Harbor ou o comentário, e não apenas olhar a
  tag.
- A limpeza do registry precisa respeitar digest ainda referenciado. A política de retenção
  preserva as últimas dez versões por ambiente e tudo com rótulo de produção.
- Correção urgente não pode pular etapas pegando atalho pela tag. Correção urgente percorre o
  mesmo caminho, com a janela de aprovação reduzida, nunca com build direto para produção.

## O que reforça a decisão

A política de admissão do Kyverno verifica a assinatura Cosign da imagem antes de criar o pod.
Imagem construída fora da esteira não executa, mesmo que alguém consiga publicá-la no registry. As
duas regras juntas, digest no manifesto e assinatura verificada na admissão, respondem com
evidência à pergunta de auditoria: o artefato em produção é exatamente o que passou pelos
controles.

## O que mudaria a decisão

- **Se a correção da imagem base demorar a chegar às aplicações.** Com digest fixo, uma correção de
  segurança na base só chega a produção quando cada aplicação reconstrói e promove. Se o tempo
  entre a correção da base e as 60 aplicações reconstruídas passar de duas semanas, a plataforma
  passa a disparar reconstrução automática em `main`, que gera um digest novo e percorre a esteira
  inteira. Nunca reconstrução por ambiente.
- **Se o build passar a ser reprodutível e atestado por proveniência**, reconstruir deixa de ser
  risco para a garantia de que o testado é o que executa. A referência por digest continua, porque
  ainda é o que torna a mudança visível no Git.
