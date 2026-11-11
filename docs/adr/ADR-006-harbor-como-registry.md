# ADR-006 — Harbor como registry de contêiner

**Situação:** aceita, condicionada ao modelo de subscrição.

## Contexto

A plataforma precisa de registry interno. Sem ele, a entrega depende de internet no momento da
implantação, a rastreabilidade do artefato se perde e não há onde aplicar política de retenção.

Três candidatos: Harbor, Red Hat Quay e o registry embutido no GitLab.

## Decisão

Harbor, instalado no cluster de plataforma, com replicação contínua para uma instância em DC2.

## Alternativas descartadas

**Registry do GitLab.** É o caminho mais curto, já existe junto com o repositório e não exige
instalação. Descartado porque amarra o registry ao GitLab: indisponibilidade do GitLab passa a
impedir que o cluster puxe imagem, o que transforma uma parada de ferramenta de desenvolvimento em
parada de produção. A varredura de vulnerabilidade e a replicação entre sítios também são mais
limitadas.

**Red Hat Quay.** Tecnicamente equivalente ao Harbor para este caso, com georeplicação madura e
suporte comercial. Descartado por custo: exige subscrição própria ou o pacote OpenShift Platform
Plus. **Se a Secretaria já tiver o Platform Plus contratado, a decisão se inverte e passa a ser
Quay**, pelo suporte do mesmo fornecedor da plataforma de contêiner.

## O que pesou a favor do Harbor

- Varredura com Trivy embutida, com gatilho automático na publicação e reavaliação periódica das
  imagens já armazenadas, que é o que pega vulnerabilidade divulgada depois do build.
- Verificação de assinatura Cosign no próprio registry, além da verificação no momento da admissão.
- Replicação entre instâncias configurável por projeto, que é o que mantém DC2 funcional quando
  DC1 cai.
- Cópia local das imagens de registries públicos, que remove a dependência de internet e o limite de
  requisições do Docker Hub.
- Políticas de retenção por projeto. Sem elas, o armazenamento de um registry com sessenta
  aplicações cresce sem controle.
- Projeto graduado na CNCF, sem aprisionamento a fornecedor.

## Consequência aceita

- Mais um componente com estado para operar, com backup próprio e plano de recuperação.
- A varredura na publicação adiciona de trinta segundos a dois minutos ao pipeline, conforme o
  tamanho da imagem.
- A replicação entre sítios consome enlace. Com imagens base compartilhadas, o volume incremental
  é pequeno, mas precisa ser monitorado.
- A política de retenção pode apagar uma imagem ainda referenciada por um manifesto antigo. A
  regra protege as últimas dez versões de cada ambiente e tudo o que estiver com rótulo de
  produção.

## O que mudaria a decisão

- Contratação do OpenShift Platform Plus, que inverteria para Quay.
- Exigência de suporte comercial para o registry, que o Harbor da comunidade não oferece.
