# ADR-005 — Sem malha de serviço nos doze primeiros meses

**Situação:** aceita, com reavaliação na quarta fase.

## Contexto

Uma malha de serviço como Istio ou Linkerd entrega criptografia mútua automática entre serviços,
política de tráfego fina, implantação canário sem alterar aplicação, repetição e disjuntor fora do
código, e métrica de tráfego entre serviços sem instrumentação.

O OpenShift inclui o Service Mesh baseado em Istio na subscrição, o que remove o argumento de
custo de licença.

## Decisão

A plataforma não adota malha de serviço nos doze primeiros meses. As necessidades que ela cobriria
são atendidas por outros meios:

| Necessidade | Solução adotada |
|---|---|
| Criptografia em trânsito | TLS na borda, pelo HAProxy e pelo roteador; rede interna segmentada |
| Implantação canário | Argo Rollouts, a partir da terceira fase |
| Repetição e disjuntor | Biblioteca na aplicação, com configuração padronizada pelo chart base |
| Métrica entre serviços | Instrumentação OpenTelemetry, já exigida pelo padrão de telemetria |
| Política de tráfego | NetworkPolicy com negação por padrão |

## Alternativa descartada

**Adotar a malha desde a fundação.** O argumento a favor é que instalar depois, com sessenta
aplicações rodando, é mais difícil do que instalar antes.

Descartada por três custos que chegam antes do benefício.

O custo de recurso é concreto. Um proxy por pod consome de 50 a 100 MB de memória e um núcleo
fracionário. Com algumas centenas de pods, isso equivale a nós inteiros, num ambiente on-premises
onde capacidade nova leva meses para chegar.

O custo cognitivo é maior ainda. A malha cria uma classe nova de incidente, em que o sintoma está
na aplicação e a causa está no proxy. Depurar isso exige conhecer o plano de controle da malha. Um
time de plataforma em formação, aprendendo Kubernetes, GitOps e observabilidade ao mesmo tempo,
não tem folga para essa quarta frente.

O benefício principal ainda não é exigido. Criptografia mútua entre serviços só vira obrigação
formal quando houver exigência de auditoria nesse sentido. Até lá, a rede segmentada com negação
por padrão atende o que é pedido.

## Consequência aceita

- A criptografia entre serviços dentro do cluster fica em aberto, protegida apenas pela
  segmentação de rede. É uma lacuna declarada, não um esquecimento.
- Repetição e disjuntor dependem da aplicação implementar. Aplicação que não implementa fica
  exposta à oscilação de dependência, e a lista de prontidão cobra isso.
- Adotar a malha depois exigirá habilitar por namespace, de forma gradual, com migração mais
  trabalhosa do que seria agora.

## O que mudaria a decisão

- Exigência formal de criptografia em trânsito entre serviços, vinda de auditoria ou norma.
- Mais de cem serviços conversando entre si, quando o mapa de dependências deixa de caber na
  cabeça de alguém.
- Equipe de plataforma com pelo menos duas pessoas confortáveis em operar o plano de controle da
  malha, demonstrado em laboratório antes de produção.
