# ADR-003 — Implantação por Argo CD, não por comando no pipeline

**Situação:** aceita.

## Contexto

O GitLab CI já consegue implantar. Um job com `kubectl apply` ou `helm upgrade`, usando um
`kubeconfig` guardado como variável protegida, resolve a entrega e é o caminho mais curto a partir
do que já existe.

A alternativa é um agente dentro do cluster que lê um repositório e converge o estado, sem o
pipeline ter acesso ao servidor de API.

## Decisão

A implantação é do Argo CD. O pipeline constrói, assina, publica e abre um commit no repositório
de manifestos. Nenhum runner tem `kubeconfig` de cluster de execução, e a rede bloqueia a rota dos
runners até a porta do servidor de API de produção.

## Alternativa descartada

**Implantação pelo pipeline.** Descartada por quatro razões, em ordem de peso.

Primeira, a credencial. Um `kubeconfig` de produção numa variável de CI é uma credencial de alto
privilégio acessível a qualquer pessoa que consiga alterar o arquivo de pipeline, incluindo por
merge request num branch. Em plataforma com doze times, essa superfície é grande demais.

Segunda, o desvio. O pipeline aplica no momento da entrega e nunca mais olha. Alteração manual
feita durante um incidente permanece até a próxima entrega, e ninguém sabe que o cluster difere do
repositório. O Argo CD compara continuamente e corrige.

Terceira, o retorno de versão. Com pipeline, reverter é reexecutar uma execução antiga, o que
depende de o artefato ainda existir e de o pipeline daquela época ainda funcionar. Com GitOps, é
um `git revert`.

Quarta, a resposta à pergunta "o que está rodando em produção agora". Com pipeline, é preciso
consultar o cluster. Com GitOps, é o conteúdo de um diretório no Git, com histórico de quem mudou
e quando.

## Consequência aceita

- Mais uma ferramenta para operar, com atualização, backup e plano próprio de recuperação.
- O time vê dois lugares: o pipeline da aplicação e o estado da aplicação no Argo CD. Até o hábito
  se formar, isso gera a pergunta "meu pipeline passou, por que não subiu".
- O commit automático do pipeline no repositório de manifestos exige um token com escopo restrito.
  Ele vem do Conjur pela identidade do job e é rotacionado pelo PAM (ADR-008).
- A correção automática de desvio impede ajuste manual emergencial. Durante incidente, a saída é o
  `git revert`; com o GitLab indisponível, o plantão da plataforma desliga a sincronização daquela
  aplicação, volta à sincronização anterior e abre o `git revert` depois (`docs/09`).

## O que mudaria a decisão

- Se a correção automática de desvio se mostrar um obstáculo real em incidentes, a resposta é
  ajustar a janela de sincronização, e não voltar para o pipeline.
- Se o Argo CD se tornar um ponto de falha frequente, a substituição seria por outro agente
  GitOps, como o Flux, mantendo o modelo.
