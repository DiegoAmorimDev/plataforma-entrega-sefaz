# Plataforma de Entrega e Execução — Secretaria da Fazenda

Proposta de arquitetura e plano de implantação para modernizar a plataforma da Secretaria da
Fazenda: 60 aplicações em produção, 12 times de desenvolvimento, infraestrutura on-premises
virtualizada.

O documento responde aos oito tópicos do desafio. O diretório `exemplos/` traz os artefatos que
sustentam o desenho — pipeline, manifestos GitOps, módulo de infraestrutura, regras de alerta e
política de admissão — em arquivos que podem ser lidos e criticados linha a linha.

---

## A proposta em uma página

**Cinco clusters, dois datacenters.** Produção roda em OpenShift, em dois clusters independentes
(um por datacenter). Homologação roda em OpenShift com a mesma configuração de produção e um terço
da capacidade. Desenvolvimento roda em RKE2 sob Rancher, que custa menos e tolera instabilidade.
A esteira e a observabilidade ficam num cluster de plataforma separado, para que uma falha de
pipeline não alcance produção.

**O pipeline constrói, o GitOps implanta.** O GitLab CI compila, testa, analisa, constrói a imagem,
assina e publica no registry. Ele nunca recebe credencial de cluster de produção. A implantação
acontece quando o Argo CD observa uma alteração no repositório de manifestos e converge o cluster
para o estado declarado.

**A promoção move um identificador, não um artefato.** A imagem é referenciada pelo digest
`sha256:...` desde o primeiro build. Promover de homologação para produção altera uma linha de
manifesto. Nenhum estágio reconstrói a imagem, então o que foi testado é bit a bit o que executa.

**O alerta que acorda alguém nasce de orçamento de erro.** O time de plataforma mede nível de
serviço por aplicação e dispara chamada telefônica apenas quando a taxa de consumo do orçamento
indica esgotamento em horas. O resto vira chamado ou fica no painel.

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

As decisões que admitem alternativa defensável estão registradas em
[docs/adr/](docs/adr/), uma por arquivo, com o contexto, a alternativa descartada e o
critério que mudaria a escolha.

## Artefatos

| Diretório | O que tem |
|---|---|
| [`exemplos/ci/`](exemplos/ci/) | Pipeline da aplicação e os templates centrais que ela inclui |
| [`exemplos/gitops/`](exemplos/gitops/) | ApplicationSet do Argo CD, base Kustomize e os três overlays de ambiente |
| [`exemplos/helm/`](exemplos/helm/) | Chart base que padroniza sonda, limite de recurso e orçamento de interrupção |
| [`exemplos/terraform/`](exemplos/terraform/) | Módulo que cria nó de trabalho no vSphere |
| [`exemplos/ansible/`](exemplos/ansible/) | Role de linha de base do sistema operacional |
| [`exemplos/borda/`](exemplos/borda/) | Configuração do HAProxy com failover entre datacenters e corte por aplicação |
| [`exemplos/observabilidade/`](exemplos/observabilidade/) | Regra de alerta por orçamento de erro, roteamento do Alertmanager e coletor OpenTelemetry |
| [`exemplos/politicas/`](exemplos/politicas/) | Política de admissão que recusa imagem não assinada ou fora do registry interno |
| [`exemplos/catalogo/`](exemplos/catalogo/) | O arquivo que um time preenche para colocar uma aplicação nova na plataforma |

## Premissas

O enunciado não fixa alguns números que mudam o desenho. As premissas abaixo valem para todo o
documento, e cada uma aponta o que mudaria se fosse falsa.

| Premissa | Se for falsa |
|---|---|
| Existem dois datacenters próprios com enlace dedicado e latência abaixo de 5 ms | Sem o segundo sítio, a continuidade cai para restauração de backup, com objetivo de retomada em dia e não em hora |
| A virtualização é VMware vSphere, com vCenter | O módulo de infraestrutura troca de provedor; o restante do desenho não muda |
| Já existe diretório corporativo para autenticação | A identidade passa a ser gerida na própria plataforma, o que cria mais um ponto de falha |
| Há subscrição Red Hat OpenShift válida para produção | O cluster de produção passa a ser RKE2 sob Rancher, e a diferença entre ambientes aumenta |
| As 60 aplicações rodam hoje em servidor de aplicação sobre máquina virtual | A ordem das ondas de migração muda, o desenho não |
