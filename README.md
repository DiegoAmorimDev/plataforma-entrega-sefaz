<div align="center">

<img src="docs/assets/capa.svg" alt="Plataforma de Entrega e Execução — Secretaria da Fazenda. 60 aplicações, 12 times, 5 clusters, 2 datacenters, 12 decisões, 12 figuras" width="100%">

<p>
<a href="#a-proposta-em-uma-página"><b>Proposta</b></a> ·
<a href="#por-onde-começar"><b>Por onde começar</b></a> ·
<a href="#documentos"><b>Documentos</b></a> ·
<a href="#decisões-de-arquitetura"><b>Decisões</b></a> ·
<a href="#artefatos"><b>Artefatos</b></a> ·
<a href="#premissas"><b>Premissas</b></a>
</p>

</div>

Proposta de arquitetura e plano de implantação para modernizar a plataforma da Secretaria da
Fazenda: 60 aplicações em produção, 12 times de desenvolvimento, infraestrutura on-premises
virtualizada.

O documento responde aos oito tópicos do desafio. O diretório [`exemplos/`](exemplos/) traz os
artefatos que sustentam o desenho — pipeline, manifestos GitOps, chart, política de admissão,
regras de alerta, borda e infraestrutura — em arquivos que podem ser lidos e criticados linha a
linha.

**Figura 1.1 — Panorama da plataforma.**

![Panorama da plataforma: o cluster de plataforma e os clusters de execução em DC1, a produção e as réplicas em DC2, a borda, a zona de banco e a vigilância externa](docs/diagramas/panorama.drawio.svg)

A topologia física, com a quantidade de nós de cada cluster, está na Figura 2.1, em
[docs/02](docs/02-topologia.md).

---

## Por onde começar

| Tempo | Caminho |
|---|---|
| **5 minutos** | Esta página: a Figura 1.1 e as cinco teses logo abaixo |
| **20 minutos** | [docs/01](docs/01-visao-geral.md), [docs/03](docs/03-cicd.md) e [docs/05](docs/05-resiliencia.md): o desenho, o caminho do commit até produção e o que acontece quando um datacenter cai |
| **Leitura técnica** | [docs/09](docs/09-gitops-argocd.md) com [`exemplos/gitops/`](exemplos/gitops/), e [docs/04](docs/04-observabilidade.md) com [`exemplos/observabilidade/`](exemplos/observabilidade/) |
| **Decisões** | As [doze ADRs](#decisões-de-arquitetura), cada uma com a alternativa descartada e o critério que a faria mudar |
| **Limites declarados** | Os pontos de falha que permanecem, em [docs/05](docs/05-resiliencia.md), e a expectativa real de migração, em [docs/08](docs/08-plano-evolucao.md) |

## A proposta em uma página

**1 · Cinco clusters, dois datacenters.** Produção roda em OpenShift, em dois clusters
independentes (um por datacenter). Homologação roda em OpenShift com a mesma configuração de
produção e um terço da capacidade. Desenvolvimento roda em RKE2 sob Rancher, que custa menos e
tolera instabilidade. A esteira e a observabilidade ficam num cluster de plataforma separado, para
que uma falha de pipeline não alcance produção.
<br><sub>Onde ver: [docs/02](docs/02-topologia.md) · [ADR-001](docs/adr/ADR-001-openshift-producao-rancher-dev.md) · [ADR-002](docs/adr/ADR-002-dois-clusters-independentes.md) · [Figura 2.1](docs/diagramas/topologia.drawio.svg)</sub>

**2 · O pipeline publica, o GitOps implanta.** O GitLab CI compila, testa, analisa, constrói a
imagem, assina e publica no registry. Ele nunca recebe credencial de cluster de produção. A
implantação acontece quando o Argo CD observa uma alteração no repositório de manifestos e converge
o cluster para o estado declarado.
<br><sub>Onde ver: [docs/03](docs/03-cicd.md) · [ADR-003](docs/adr/ADR-003-gitops-em-vez-de-deploy-por-pipeline.md) · [`exemplos/ci/`](exemplos/ci/) · [`exemplos/gitops/`](exemplos/gitops/)</sub>

**3 · A promoção move um identificador, não um artefato.** A imagem é referenciada pelo digest
`sha256:...` desde o primeiro build. Promover de homologação para produção altera uma linha de
manifesto. Nenhum estágio reconstrói a imagem, então o que foi testado é bit a bit o que executa.
<br><sub>Onde ver: [ADR-007](docs/adr/ADR-007-promocao-por-digest.md) · [ADR-010](docs/adr/ADR-010-promocao-por-merge-request.md) · [`promocao.yml`](exemplos/ci/templates/promocao.yml) · [`exigir-imagem-assinada.yaml`](exemplos/politicas/exigir-imagem-assinada.yaml)</sub>

**4 · O alerta que acorda alguém nasce de orçamento de erro.** O time de plataforma mede nível de
serviço por aplicação e dispara chamada telefônica apenas quando a taxa de consumo do orçamento
indica que ele acaba em poucos dias. O resto vira chamado ou fica no painel.
<br><sub>Onde ver: [docs/04](docs/04-observabilidade.md) · [`prometheus-rules.yaml`](exemplos/observabilidade/prometheus-rules.yaml) · [`alertmanager.yaml`](exemplos/observabilidade/alertmanager.yaml)</sub>

**5 · A migração acontece por onda, com o tráfego decidindo.** O HAProxy fica na frente do legado
e da plataforma nova ao mesmo tempo. Cada aplicação migrada passa a receber tráfego por regra de
rota, e volta para o legado invertendo essa regra. Nenhuma onda depende da anterior ter terminado.
<br><sub>Onde ver: [docs/08](docs/08-plano-evolucao.md) · [`haproxy.cfg`](exemplos/borda/haproxy.cfg)</sub>

## Ferramentas por plano

Cada selo tem a cor do plano a que a ferramenta pertence, a mesma das figuras.

| Plano | Ferramentas |
|---|---|
| **Entrega** | ![GitLab CI](https://img.shields.io/badge/GitLab%20CI-0072B2?style=flat-square&logo=gitlab&logoColor=white) ![Harbor](https://img.shields.io/badge/Harbor-0072B2?style=flat-square&logo=harbor&logoColor=white) ![Argo CD](https://img.shields.io/badge/Argo%20CD-0072B2?style=flat-square&logo=argo&logoColor=white) ![SonarQube](https://img.shields.io/badge/SonarQube-0072B2?style=flat-square&logo=sonarqube&logoColor=white) ![Trivy](https://img.shields.io/badge/Trivy-0072B2?style=flat-square&logo=trivy&logoColor=white) ![Cosign](https://img.shields.io/badge/Cosign-0072B2?style=flat-square) ![Kyverno](https://img.shields.io/badge/Kyverno-0072B2?style=flat-square) ![Keycloak](https://img.shields.io/badge/Keycloak-0072B2?style=flat-square&logo=keycloak&logoColor=white) ![Terraform](https://img.shields.io/badge/Terraform-0072B2?style=flat-square&logo=terraform&logoColor=white) ![Ansible](https://img.shields.io/badge/Ansible-0072B2?style=flat-square&logo=ansible&logoColor=white) |
| **Execução** | ![OpenShift](https://img.shields.io/badge/OpenShift-009E73?style=flat-square&logo=redhatopenshift&logoColor=white) ![RKE2 sob Rancher](https://img.shields.io/badge/RKE2%20sob%20Rancher-009E73?style=flat-square&logo=rancher&logoColor=white) ![Helm](https://img.shields.io/badge/Helm-009E73?style=flat-square&logo=helm&logoColor=white) ![Kustomize](https://img.shields.io/badge/Kustomize-009E73?style=flat-square&logo=kubernetes&logoColor=white) ![Argo Rollouts](https://img.shields.io/badge/Argo%20Rollouts-009E73?style=flat-square&logo=argo&logoColor=white) ![Spring Boot](https://img.shields.io/badge/Spring%20Boot-009E73?style=flat-square&logo=springboot&logoColor=white) ![vSphere](https://img.shields.io/badge/VMware%20vSphere-009E73?style=flat-square&logo=vmware&logoColor=white) |
| **Dados e segredos** | ![Oracle](https://img.shields.io/badge/Oracle-B87D00?style=flat-square&logo=oracle&logoColor=white) ![PostgreSQL](https://img.shields.io/badge/PostgreSQL-B87D00?style=flat-square&logo=postgresql&logoColor=white) ![Patroni](https://img.shields.io/badge/Patroni-B87D00?style=flat-square) ![Conjur](https://img.shields.io/badge/CyberArk%20Conjur-B87D00?style=flat-square) ![External Secrets](https://img.shields.io/badge/External%20Secrets-B87D00?style=flat-square) ![MinIO](https://img.shields.io/badge/MinIO-B87D00?style=flat-square&logo=minio&logoColor=white) ![Velero](https://img.shields.io/badge/Velero-B87D00?style=flat-square) |
| **Observação** | ![Prometheus](https://img.shields.io/badge/Prometheus-B05A8C?style=flat-square&logo=prometheus&logoColor=white) ![Thanos](https://img.shields.io/badge/Thanos-B05A8C?style=flat-square&logo=thanos&logoColor=white) ![Grafana](https://img.shields.io/badge/Grafana-B05A8C?style=flat-square&logo=grafana&logoColor=white) ![Loki](https://img.shields.io/badge/Loki-B05A8C?style=flat-square) ![Tempo](https://img.shields.io/badge/Tempo-B05A8C?style=flat-square) ![OpenTelemetry](https://img.shields.io/badge/OpenTelemetry-B05A8C?style=flat-square&logo=opentelemetry&logoColor=white) |
| **Tráfego** | ![HAProxy](https://img.shields.io/badge/HAProxy-D55E00?style=flat-square) ![Apache](https://img.shields.io/badge/Apache-D55E00?style=flat-square&logo=apache&logoColor=white) ![DNS](https://img.shields.io/badge/DNS%20com%20TTL%20de%2060%20s-D55E00?style=flat-square) |

## Documentos

| # | Tópico do desafio | O que responde |
|---|---|---|
| 1 | [Visão geral da arquitetura](docs/01-visao-geral.md) | Os cinco planos, o caminho de um pedido, sigilo fiscal e o que foi acrescentado além do enunciado |
| 2 | [Topologia de clusters e ambientes](docs/02-topologia.md) | Cinco clusters em dois datacenters, separação de ambientes, organização das 60 aplicações |
| 3 | [Fluxo de entrega (CI/CD)](docs/03-cicd.md) | Do commit até produção, o que bloqueia e o que só informa, promoção por digest e retorno de versão |
| 4 | [Observabilidade e operação](docs/04-observabilidade.md) | O caminho dos sinais, as regras para o alerta ser levado a sério, o que o plantão vê |
| 5 | [Resiliência e continuidade](docs/05-resiliencia.md) | Classes de aplicação, falha de nó, de banco e de datacenter, e os pontos de falha que permanecem |
| 6 | [Infraestrutura como código](docs/06-iac.md) | Quatro camadas e a ferramenta de cada uma, revisão pelo plano no merge request |
| 7 | [Experiência dos times](docs/07-experiencia-dev.md) | Aplicação nova em produção dia a dia, fronteira de responsabilidade, saída do caminho pavimentado |
| 8 | [Plano de evolução](docs/08-plano-evolucao.md) | Cinco fases em doze meses, riscos com mitigação, custo e como medir sucesso |
| + | [GitOps com Argo CD](docs/09-gitops-argocd.md) | Aprofundamento do tópico 3: repositórios, ondas, permissões, acesso de emergência, dois sítios |

## Decisões de arquitetura

Cada decisão que admite alternativa defensável tem um registro em [docs/adr/](docs/adr/), com o
contexto, a alternativa descartada, a consequência aceita e o critério que faria a decisão mudar.

| ADR | Decisão | Alternativa descartada |
|---|---|---|
| [001](docs/adr/ADR-001-openshift-producao-rancher-dev.md) | OpenShift em produção, RKE2 sob Rancher em desenvolvimento | Padronizar em uma distribuição só |
| [002](docs/adr/ADR-002-dois-clusters-independentes.md) | Dois clusters de produção independentes, um por sítio | Um cluster esticado entre os dois sítios |
| [003](docs/adr/ADR-003-gitops-em-vez-de-deploy-por-pipeline.md) | Implantação por Argo CD, não por `kubectl` no pipeline | Pipeline com credencial de cluster |
| [004](docs/adr/ADR-004-bancos-fora-do-kubernetes.md) | Oracle e PostgreSQL permanecem em máquina virtual | Operadores de banco dentro do cluster |
| [005](docs/adr/ADR-005-sem-service-mesh-na-fase-inicial.md) | Sem malha de serviço nos doze primeiros meses | Istio ou Linkerd desde a fundação |
| [006](docs/adr/ADR-006-harbor-como-registry.md) | Harbor como registry de contêiner | Quay, ou o registry interno do GitLab |
| [007](docs/adr/ADR-007-promocao-por-digest.md) | Promoção entre ambientes move o digest da imagem | Reconstruir a imagem por ambiente |
| [008](docs/adr/ADR-008-conjur-como-cofre.md) | Conjur como cofre, rotação pelo PAM, consumo pelo External Secrets | Vault ou OpenBao; aplicação chamando a API do cofre |
| [009](docs/adr/ADR-009-argocd-central-com-contingencia.md) | Um Argo CD central, com contingência desligada em DC2 | Uma instância por cluster |
| [010](docs/adr/ADR-010-promocao-por-merge-request.md) | Promoção por merge request aberto pela esteira | Argo CD Image Updater ou Kargo |
| [011](docs/adr/ADR-011-ambiente-por-diretorio.md) | Ambiente é diretório no mesmo branch | Um branch por ambiente |
| [012](docs/adr/ADR-012-sonarqube-community.md) | SonarQube Community, com cobertura do merge request pelo `diff-cover` | Edição Developer |

## Como ler os diagramas

As doze figuras seguem uma convenção só. A cor diz a qual plano a peça pertence; o traço e a forma
dizem o estado dela. Cada figura tem número e título acima, numerada pelo documento onde está.

| Cor | Plano | Exemplos |
|---|---|---|
| ![Azul](https://img.shields.io/badge/Azul-0072B2?style=flat-square) | Entrega | GitLab, executores, Harbor, Argo CD |
| ![Verde](https://img.shields.io/badge/Verde-009E73?style=flat-square) | Execução | Clusters e aplicações |
| ![Âmbar](https://img.shields.io/badge/%C3%82mbar-B87D00?style=flat-square) | Dados e segredos | Oracle, PostgreSQL, Conjur, MinIO |
| ![Magenta](https://img.shields.io/badge/Magenta-B05A8C?style=flat-square) | Observação | Prometheus, Grafana, Thanos, Loki, Tempo |
| ![Laranja](https://img.shields.io/badge/Laranja-D55E00?style=flat-square) | Tráfego | DNS público, firewall, HAProxy |
| ![Cinza](https://img.shields.io/badge/Cinza-6B7280?style=flat-square) | Fora dos planos da plataforma | Pessoas, legado, serviços externos |

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
| [`exemplos/helm/`](exemplos/helm/) | Chart base: Route ou Ingress, sondas, limites, escala automática, orçamento de interrupção, referência a segredo, migração de banco e teste de fumaça como ganchos |
| [`exemplos/segredos/`](exemplos/segredos/) | Política do Conjur e a conexão do External Secrets com ele, por identidade de ServiceAccount |
| [`exemplos/terraform/`](exemplos/terraform/) | Módulo que cria nós do RKE2 no vSphere; o mesmo padrão serve às máquinas fora do OpenShift |
| [`exemplos/ansible/`](exemplos/ansible/) | Role de linha de base do sistema operacional |
| [`exemplos/borda/`](exemplos/borda/) | Configuração do HAProxy com troca entre datacenters e corte por aplicação |
| [`exemplos/observabilidade/`](exemplos/observabilidade/) | Regras de alerta por orçamento de erro e de queda total, roteamento do Alertmanager e coletor OpenTelemetry |
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
| O vSphere existente comporta cerca de 50 máquinas virtuais novas: cerca de 680 vCPU e 2,7 TB de memória somando os cinco clusters (15 nós de controle de 8 vCPU e 32 GB, 35 nós de trabalho de 16 vCPU e 64 GB) | A compra de hospedeiros entra na fase 0, e a fase 1 desloca pelo prazo de compra pública, de três a seis meses |
| A Secretaria tem SIEM e uma ferramenta de escala de plantão com acionamento por telefone | A auditoria continua guardada com bloqueio de escrita, mas sem correlação; a chamada telefônica passa a depender de serviço contratado, viável porque o alerta não carrega dado fiscal |

## Estrutura do repositório

```
.
├── README.md            esta página
├── docs/
│   ├── 01 … 08          os oito tópicos do desafio
│   ├── 09               aprofundamento de GitOps com Argo CD
│   ├── adr/             as doze decisões de arquitetura
│   ├── diagramas/       panorama e topologia em .drawio.svg
│   └── assets/          capa desta página
├── exemplos/            artefatos que sustentam o desenho, em dez áreas
├── build-pdf.sh         consolida tudo num HTML único para imprimir em PDF
└── template.html        tipografia e regras de impressão do consolidado
```

O documento consolidado sai com `bash build-pdf.sh`, que precisa de pandoc e node. O resultado,
`dist/proposta.html`, é impresso em PDF pelo navegador.
