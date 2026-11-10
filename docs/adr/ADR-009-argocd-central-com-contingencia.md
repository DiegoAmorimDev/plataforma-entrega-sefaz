# ADR-009 — Um Argo CD central, com instância de contingência desligada em DC2

**Situação:** aceita.

## Contexto

São quatro clusters de execução e um de plataforma. O Argo CD pode ficar em três lugares: uma
instância central que alcança todos os clusters, uma instância dentro de cada cluster, ou um
modelo híbrido em que o controle é central e a aplicação do estado é local.

A escolha decide duas coisas: quantas instâncias a equipe de quatro pessoas opera, e o que
acontece com a implantação quando DC1 cai.

## Decisão

Uma instância central, em modo de alta disponibilidade, no cluster `plat-dc1`. Ela gerencia os
quatro clusters de execução por conexão de saída até o servidor de API de cada um.

Uma segunda instância fica **instalada e desligada** no `prd-dc2`, com réplicas em zero. Ela lê a
mesma configuração do Git e só conhece o próprio cluster. Na perda de DC1, ativá-la é escalar os
componentes, o que leva minutos. Reconstruir do zero levaria cerca de trinta.

A rota de rede até o servidor de API dos clusters de produção é concedida por endereço de saída
dedicado ao namespace do Argo CD, recurso nativo do OpenShift. Os runners do GitLab, no mesmo
cluster, saem por outro endereço, que o firewall bloqueia.

## Alternativas descartadas

**Uma instância por cluster.** Isola melhor a falha: cada cluster se implanta sozinho. Foi
descartada pelo custo de operação. São cinco instâncias para atualizar, cinco configurações de
permissão para manter coerentes e nenhuma visão única de "o que está implantado onde". Com quatro
pessoas na plataforma, a divergência entre as cinco é questão de meses.

**Controle central com agente em cada cluster.** O projeto `argocd-agent` combina a visão única
com a aplicação local do estado, que é exatamente o que este desenho precisa. Foi descartado por
maturidade: ainda é jovem para sustentar a produção de uma Secretaria da Fazenda nos primeiros
doze meses.

## Consequência aceita

- **O Argo CD central é ponto único para implantar, não para executar.** Se ele cair, nenhuma
  aplicação para. A plataforma só deixa de receber entrega nova e de corrigir desvio.
- **A instância de contingência envelhece.** Instalada e desligada, ela pode ficar para trás nas
  atualizações sem ninguém perceber. Ela é atualizada no mesmo merge request da central, e o
  exercício semestral de continuidade a ativa de verdade.
- **A instância central concentra credencial de todos os clusters.** Ela roda em nós dedicados do
  `plat-dc1`, e as credenciais de cluster vêm do Conjur pelo External Secrets, nunca do Git.

## O que mudaria a decisão

- **Se o `argocd-agent` chegar a uma versão estável com suporte comercial**, ele substitui a
  instância de contingência, porque resolve o mesmo problema sem a cópia desligada.
- **Se a auditoria exigir segregação completa do plano de controle de produção**, os clusters de
  produção passam a ter instância própria, e a central fica com desenvolvimento e homologação.
