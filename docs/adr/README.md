# Decisões de arquitetura

Cada arquivo registra uma decisão que admite alternativa defensável. O formato é curto de
propósito: contexto, decisão, alternativa descartada, consequência aceita e o critério que faria a
decisão mudar.

O último campo é o mais útil. Decisão sem critério de revisão vira dogma, e seis meses depois
ninguém sabe se a razão original ainda vale.

| ADR | Decisão | Alternativa principal |
|---|---|---|
| [001](ADR-001-openshift-producao-rancher-dev.md) | OpenShift em produção, RKE2 sob Rancher em desenvolvimento | Padronizar em uma distribuição só |
| [002](ADR-002-dois-clusters-independentes.md) | Dois clusters de produção independentes, um por sítio | Um cluster esticado entre os dois sítios |
| [003](ADR-003-gitops-em-vez-de-deploy-por-pipeline.md) | Implantação por Argo CD, não por `kubectl` no pipeline | Pipeline com credencial de cluster |
| [004](ADR-004-bancos-fora-do-kubernetes.md) | Oracle e PostgreSQL permanecem em máquina virtual | Operadores de banco dentro do cluster |
| [005](ADR-005-sem-service-mesh-na-fase-inicial.md) | Sem malha de serviço nos doze primeiros meses | Istio ou Linkerd desde a fundação |
| [006](ADR-006-harbor-como-registry.md) | Harbor como registry de contêiner | Quay, ou o registry interno do GitLab |
| [007](ADR-007-promocao-por-digest.md) | Promoção entre ambientes move o digest da imagem | Reconstruir a imagem por ambiente |
| [008](ADR-008-conjur-como-cofre.md) | Conjur como cofre, rotação pelo PAM, consumo pelo External Secrets | Vault ou OpenBao; aplicação chamando a API do cofre |
| [009](ADR-009-argocd-central-com-contingencia.md) | Um Argo CD central, com contingência desligada em DC2 | Uma instância por cluster |
| [010](ADR-010-promocao-por-merge-request.md) | Promoção por merge request aberto pela esteira | Argo CD Image Updater ou Kargo |
| [011](ADR-011-ambiente-por-diretorio.md) | Ambiente é diretório no mesmo branch | Um branch por ambiente |
| [012](ADR-012-sonarqube-community.md) | SonarQube Community, com cobertura do merge request pelo `diff-cover` | Edição Developer |
