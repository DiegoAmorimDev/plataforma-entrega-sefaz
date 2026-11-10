# Plataforma de Entrega e Execução — Secretaria da Fazenda

Proposta de arquitetura e plano de implantação para modernizar a plataforma da Secretaria da
Fazenda: 60 aplicações em produção, 12 times de desenvolvimento, infraestrutura on-premises
virtualizada.

O documento responde aos oito tópicos do desafio. O diretório `exemplos/` traz os artefatos que
sustentam o desenho — pipeline, manifestos GitOps, módulo de infraestrutura, regras de alerta e
política de admissão — em arquivos que podem ser lidos e criticados linha a linha.

**Figura 1.1 — Panorama da plataforma.**

![Panorama da plataforma: o cluster de plataforma e os clusters de execução em DC1, a produção e as réplicas em DC2, a borda, a zona de banco e a vigilância externa](docs/diagramas/panorama.drawio.svg)

A topologia física, com a quantidade de nós de cada cluster, está na Figura 2.1, em
[docs/02](docs/02-topologia.md).

---

## A proposta em uma página

**Cinco clusters, dois datacenters.** Produção roda em OpenShift, em dois clusters independentes
(um por datacenter). Homologação roda em OpenShift com a mesma configuração de produção e um terço
da capacidade. Desenvolvimento roda em RKE2 sob Rancher, que custa menos e tolera instabilidade.
A esteira e a observabilidade ficam num cluster de plataforma separado, para que uma falha de
pipeline não alcance produção.

**O pipeline publica, o GitOps implanta.** O GitLab CI compila, testa, analisa, constrói a imagem,
assina e publica no registry. Ele nunca recebe credencial de cluster de produção. A implantação
acontece quando o Argo CD observa uma alteração no repositório de manifestos e converge o cluster
para o estado declarado.

**A promoção move um identificador, não um artefato.** A imagem é referenciada pelo digest
`sha256:...` desde o primeiro build. Promover de homologação para produção altera uma linha de
manifesto. Nenhum estágio reconstrói a imagem, então o que foi testado é bit a bit o que executa.

**O alerta que acorda alguém nasce de orçamento de erro.** O time de plataforma mede nível de
serviço por aplicação e dispara chamada telefônica apenas quando a taxa de consumo do orçamento
indica que ele acaba em poucos dias. O resto vira chamado ou fica no painel.

**A migração acontece por onda, com o tráfego decidindo.** O HAProxy fica na frente do legado e da
plataforma nova ao mesmo tempo. Cada aplicação migrada passa a receber tráfego por regra de rota,
e volta para o legado invertendo essa regra. Nenhuma onda depende da anterior ter terminado.

---

## Índice

| Tópico do desafio | Documento |
|---|---|
| 1. Visão geral da arquitetura | [docs/01-visao-geral.md](docs/01-visao-geral.md) |
| 2. Topologia de clusters e ambientes | [docs/02-topologia.md](docs/02-topologia.md) |
| 3. Fluxo de entrega (CI/CD) | [docs/03-cicd.md](docs/03-cicd.md) |
| 4. Observabilidade e operação | [docs/04-observabilidade.md](docs/04-observabilidade.md) |
| 5. Resiliência e continuidade | [docs/05-resiliencia.md](docs/05-resiliencia.md) |
| 6. Infraestrutura como código | [docs/06-iac.md](docs/06-iac.md) |
| 7. Experiência dos times de desenvolvimento | [docs/07-experiencia-dev.md](docs/07-experiencia-dev.md) |
| 8. Plano de evolução | [docs/08-plano-evolucao.md](docs/08-plano-evolucao.md) |
| Aprofundamento do tópico 3: GitOps com Argo CD | [docs/09-gitops-argocd.md](docs/09-gitops-argocd.md) |

As decisões que admitem alternativa defensável estão registradas em
[docs/adr/](docs/adr/), uma por arquivo, com o contexto, a alternativa descartada e o
critério que mudaria a escolha. São doze.

## Como ler os diagramas

As doze figuras seguem uma convenção só. A cor diz a qual plano a peça pertence; o traço e a forma
dizem o estado dela. Cada figura tem número e título acima, numerada pelo documento onde está.

| Cor | Plano | Exemplos |
|---|---|---|
| Azul | Entrega | GitLab, executores, Harbor, Argo CD |
| Verde | Execução | Clusters e aplicações |
| Âmbar | Dados e segredos | Oracle, PostgreSQL, Conjur, MinIO |
| Magenta | Observação | Prometheus, Grafana, Thanos, Loki, Tempo |
| Laranja | Tráfego | DNS público, firewall, HAProxy |
| Cinza | Fora dos planos da plataforma | Pessoas, legado, serviços externos |

| Sinal | Significado |
|---|---|
| Linha cheia | Fluxo principal |
| Linha tracejada | Replicação, contingência ou caminho assíncrono |
| Borda tracejada | Componente em espera ou desligado |
| Trapézio | Passo que exige decisão humana |

Os fluxos estão em Mermaid, dentro do próprio texto, para que cada mudança apareça no diff do
merge request. O panorama e a topologia estão em draw.io, em [docs/diagramas/](docs/diagramas/): o
arquivo `.drawio.svg` é a imagem e a fonte editável ao mesmo tempo, e abre direto no draw.io.

## Onde o desenho se apoia em operação real

Parte das escolhas vem de operação em produção, em ambiente financeiro regulado que o autor opera
hoje. Onde a escolha aqui é diferente da de lá, o motivo está registrado.

| Peça | O que o autor opera | O que muda nesta proposta, e por quê |
|---|---|---|
| OpenShift | Clusters de produção | Nada. É a razão de o controle de contexto de segurança pesar na escolha (ADR-001) |
| GitLab CI | Esteira com quality gate do SonarQube obrigatório | O template central fixado por tag, para doze times em vez de um |
| SonarQube | Edição Developer, com análise de merge request | Edição Community, com a cobertura do merge request calculada fora dele, até o inventário mostrar o custo da licença (ADR-012) |
| Argo CD | Implantação por GitOps em ambiente on-premises | Nada no modelo; o desenho de repositório, permissão e contingência está em `docs/09` |
| Conjur | Rotação pelo CPM do PAM, aplicação chamando a API do Conjur | A rotação continua no PAM; o consumo passa ao External Secrets, para que 60 aplicações não carreguem SDK de cofre (ADR-008) |
| Grafana e OpenTelemetry | Painéis e instrumentação de aplicação | Nada |

Terraform para vSphere e HAProxy em produção o autor não operou. Essas partes foram estudadas e
desenhadas, e o texto as trata com o mesmo cuidado, sem fingir experiência.

## Artefatos

| Diretório | O que tem |
|---|---|
| [`exemplos/ci/`](exemplos/ci/) | Pipeline da aplicação Java e os templates centrais que ela inclui, com a estratégia de testes |
| [`exemplos/gitops/`](exemplos/gitops/) | ApplicationSet e AppProject, valores da aplicação, overlays por ambiente e por sítio, canário, configuração do Argo CD e o pipeline do repositório de manifestos |
| [`exemplos/helm/`](exemplos/helm/) | Chart base: Route ou Ingress, sondas, limites, orçamento de interrupção, referência a segredo, migração de banco e teste de fumaça como ganchos |
| [`exemplos/segredos/`](exemplos/segredos/) | Política do Conjur e a conexão do External Secrets com ele, por identidade de ServiceAccount |
| [`exemplos/terraform/`](exemplos/terraform/) | Módulo que cria nó de trabalho no vSphere |
| [`exemplos/ansible/`](exemplos/ansible/) | Role de linha de base do sistema operacional |
| [`exemplos/borda/`](exemplos/borda/) | Configuração do HAProxy com troca entre datacenters e corte por aplicação |
| [`exemplos/observabilidade/`](exemplos/observabilidade/) | Regra de alerta por orçamento de erro, roteamento do Alertmanager e coletor OpenTelemetry |
| [`exemplos/politicas/`](exemplos/politicas/) | Política de admissão que recusa imagem não assinada ou fora do registry interno |
| [`exemplos/catalogo/`](exemplos/catalogo/) | O arquivo que um time preenche para colocar uma aplicação nova na plataforma |

Os artefatos são parciais de propósito. Cada um mostra a decisão que sustenta o texto, com a
sintaxe real da ferramenta, e omite o que não acrescenta à discussão: variáveis de módulo,
scripts auxiliares referenciados como `/scripts/...` e o utilitário `conjur-segredo`, que a
plataforma forneceria.

## Premissas

O enunciado não fixa alguns números que mudam o desenho. As premissas abaixo valem para todo o
documento, e cada uma aponta o que mudaria se fosse falsa.

| Premissa | Se for falsa |
|---|---|
| Existem dois datacenters próprios com enlace dedicado, por duas operadoras distintas, e latência abaixo de 5 ms | Sem o segundo sítio, a continuidade cai para restauração de backup, com objetivo de retomada em dia e não em hora. Com uma operadora só, a partição de rede entre sítios sobe para o primeiro lugar da tabela de riscos |
| A virtualização é VMware vSphere, com vCenter | O módulo de infraestrutura troca de provedor; o restante do desenho não muda |
| Já existe diretório corporativo para autenticação | A identidade passa a ser gerida na própria plataforma, o que cria mais um ponto de falha |
| Há subscrição Red Hat OpenShift válida para produção | O cluster de produção passa a ser RKE2 sob Rancher, e a diferença entre ambientes aumenta |
| As 60 aplicações rodam hoje em servidor de aplicação sobre máquina virtual | A ordem das ondas de migração muda, o desenho não |
| A maior parte das aplicações é escrita em Java | O exemplo e o primeiro template de linguagem passam a ser os da linguagem predominante no inventário. O chart base já prevê .NET, e o template de pipeline .NET entra na fase 1; o desenho não muda |
| A Secretaria já usa o CyberArk PAM para governar contas privilegiadas, e há orçamento para o Conjur comercial | O cofre passa a ser o OpenBao, com credencial dinâmica de banco no lugar da rotação; o consumo pelo External Secrets continua igual (ADR-008) |
| A equipe de plataforma começa com quatro pessoas e chega a seis na fase 2 | Com menos gente, a fase 3 (segundo sítio e contingência do Argo CD) escorrega seis meses, e o plantão contínuo da plataforma não fecha a escala |
| Os times de desenvolvimento podem assumir o plantão da própria aplicação | Se forem fábrica de software contratada, o plantão da aplicação vira cláusula de contrato ou passa à central de operações da Secretaria, com roteiro de resposta obrigatório |
| As áreas de negócio aceitam a janela de mudança de produção em dias úteis, das 7h às 19h | A janela vira configuração por projeto no Argo CD; o desenho não muda, só o horário |
| A Secretaria tem SIEM e uma ferramenta de escala de plantão com acionamento por telefone | A auditoria continua guardada com bloqueio de escrita, mas sem correlação; a chamada telefônica passa a depender de serviço contratado, viável porque o alerta não carrega dado fiscal |
