# 7. Experiência dos times de desenvolvimento

Uma plataforma com doze times e quatro pessoas de sustentação só funciona se o caminho comum não
passar por chamado. A medida de sucesso é direta: **um time coloca uma aplicação nova em
desenvolvimento no mesmo dia, sem falar com ninguém da plataforma.**

O desenho que entrega isso é o caminho pavimentado. Existe um jeito recomendado, que é fácil,
rápido e já vem com observabilidade, segurança e implantação resolvidas. Sair dele é permitido e
custa mais, porque o time passa a responder pelo que escolheu trocar.

---

## Colocando uma aplicação nova em produção

### Dia 1, pela manhã: o pedido

O time abre um merge request no repositório `catalogo-apps` com um arquivo de quarenta linhas. Esse
arquivo é a única coisa que o time preenche para existir na plataforma. O exemplo comentado está em
[`exemplos/catalogo/exemplo-aplicacao.yaml`](../exemplos/catalogo/exemplo-aplicacao.yaml).

```yaml
nome: nfe-emissor
time: fiscal
tier: 1
linguagem: dotnet
rotas:
  - host: nfe.sefaz.gov.br
    publica: true
dependencias:
  bancos:
    - tipo: oracle
      nome: DBFISCAL
  servicos:
    - sefaz-autorizador
slo:
  disponibilidade: 99.9
  latencia_p95_ms: 800
plantao:
  grupo_ad: SEFAZ-FISCAL-PLANTAO
```

A revisão é da plataforma e olha três coisas: se o nível declarado é compatível com o impacto real,
se as dependências existem e se o compromisso de nível de serviço é alcançável com o desenho
proposto. Costuma levar menos de uma hora.

### Dia 1, à tarde: o que acontece sozinho

Com o merge, um pipeline executa e cria tudo o que a aplicação precisa:

| Criado | Onde |
|---|---|
| Repositório a partir do template da linguagem | GitLab |
| Namespaces nos três ambientes, com cota, limites, negação de rede e permissão | Quatro clusters |
| Projeto com política de retenção e varredura | Harbor |
| Caminho de segredos e política de acesso | Vault |
| Diretório de manifestos com os três overlays | `manifestos-apps` |
| Objeto de aplicação gerado pelo gerador | Argo CD |
| Painel com as quatro métricas de ouro | Grafana |
| Alertas de orçamento de erro conforme o nível declarado | Prometheus |
| Grupo de roteamento de plantão | Alertmanager |
| Rota em homologação | Roteador do OpenShift |

O repositório gerado já vem com Dockerfile multi-estágio sobre imagem base aprovada, pipeline de
doze linhas que inclui o template central, chart de valores preenchido, sonda de saúde implementada
e instrumentação OpenTelemetry configurada. O primeiro `git push` percorre a esteira inteira e
chega em desenvolvimento.

### Semanas seguintes: a subida até produção

A promoção para homologação é automática quando os testes passam. A promoção para produção é um
merge request de uma linha, com duas aprovações.

Antes da primeira entrega em produção, há uma lista de prontidão que a plataforma confere junto com
o time. Ela não é burocracia de carimbo: cada item corresponde a uma causa conhecida de incidente.

- Sondas de vitalidade e prontidão implementadas e distintas.
- Requisições e limites de recurso medidos em teste de carga, não chutados.
- Encerramento gracioso tratado.
- Repetição com espera progressiva e disjuntor nas chamadas externas.
- Migração de banco em duas etapas, com a etapa de expandir separada da de contrair.
- Nível de serviço acordado com a área de negócio, não escolhido pelo time sozinho.
- Runbook escrito para cada alerta que gera chamada telefônica.
- Escala de plantão preenchida.
- Teste de retorno de versão executado em homologação pelo menos uma vez.

O último item é o mais ignorado e o mais útil. Time que nunca reverteu em homologação vai descobrir
durante o primeiro incidente que a migração de banco não permitia reverter.

---

## Quem responde pelo quê

A fronteira é esta: **a plataforma responde pelo que é comum a todas as aplicações; o time responde
pelo que é específico da sua.**

| Assunto | Plataforma | Time de desenvolvimento |
|---|---|---|
| Clusters, nós, atualização, rede, armazenamento | Responsável | — |
| Registry, cofre, esteira, templates de pipeline | Responsável | Consome |
| Imagem base e sua atualização de segurança | Responsável | Reconstrói quando avisado |
| Política de admissão e linha de base de segurança | Responsável | Cumpre |
| Pilha de observabilidade em funcionamento | Responsável | — |
| Código, teste, qualidade do que escreve | — | Responsável |
| Dockerfile da aplicação, sobre base aprovada | — | Responsável |
| Valores do chart, recursos, réplicas | — | Responsável |
| Nível de serviço, alertas e runbook da aplicação | Acorda e revisa | Define e mantém |
| Atender o alerta da própria aplicação | Escala quando é infraestrutura | Responsável |
| Vulnerabilidade em dependência da aplicação | Informa e acompanha prazo | Corrige |
| Vulnerabilidade na imagem base | Corrige | Reconstrói |
| Esquema e desempenho de consulta ao banco | — | Responsável |
| Disponibilidade e backup do banco | Responsável | — |
| Capacidade de hardware | Responsável | Informa previsão de crescimento |
| Decisão de reverter a própria entrega | — | Responsável |
| Decisão de ativar o plano de continuidade | Responsável | — |

A linha mais polêmica é a do atendimento ao alerta. **Quem constrói, opera.** O time que escreveu o
código atende o alerta da aplicação, dentro de um horário estendido definido pelo nível. Isso não é
transferência de carga: é o que fecha o ciclo de retorno. Um time que acorda com o próprio
vazamento de memória conserta o vazamento; um time que nunca é acordado aprende que a plataforma
absorve o problema.

A plataforma sustenta isso com três compromissos. Primeiro, o alerta chega com runbook e com dado,
não como "algo está errado". Segundo, o que for de infraestrutura é escalado para a plataforma sem
o time precisar provar nada. Terceiro, o volume de alertas por plantão é medido, e alerta ruidoso é
problema da plataforma para resolver.

---

## O que acontece quando o time quer sair do caminho pavimentado

Um time vai querer Node.js quando só há template de .NET e Java. Outro vai querer um banco que não
está no catálogo. Isso é legítimo e a resposta não é "não".

A regra tem três degraus:

**Degrau 1, dentro do caminho:** linguagem com template, dependências do catálogo, chart base. A
plataforma sustenta tudo.

**Degrau 2, variação negociada:** o time precisa de algo que não existe e a plataforma avalia. Se o
pedido se repetir em mais de dois times, vira caminho pavimentado e a plataforma constrói o
template. Se for de um time só, ele constrói com apoio e mantém.

**Degrau 3, fora do caminho:** o time quer operar algo que a plataforma não sustenta. É permitido,
desde que fique claro no catálogo e que o time assuma o plantão daquele componente. Nenhum
compromisso de nível de serviço da plataforma cobre o que ela não opera.

O que não é negociável, em nenhum degrau: imagem assinada e vinda do registry interno, ausência de
segredo no repositório, execução sem usuário privilegiado, limites de recurso declarados, nível de
serviço declarado e telemetria emitida no padrão. Esses são a condição para rodar em produção, e a
política de admissão os aplica sem depender de alguém lembrar.

---

## Como a plataforma evita virar fila de chamados

Quatro mecanismos, nessa ordem de importância.

**O autoatendimento vem na primeira fase, não na última.** Construir a plataforma por um ano
atendendo tudo por chamado e só depois automatizar não funciona, porque a equipe fica presa na
operação e nunca chega na automação.

**Toda pergunta respondida duas vezes vira documentação ou automação.** A terceira ocorrência do
mesmo chamado é defeito da plataforma, e entra no backlog como tal.

**Há horário fixo de atendimento aberto.** Duas horas por semana em que qualquer pessoa entra, sem
chamado, para tirar dúvida ou pedir ajuda. Concentrar a interrupção em uma janela protege o resto
da semana.

**Cada pessoa da plataforma passa um dia por mês dentro de um time de desenvolvimento**, usando a
plataforma como usuário. É o que evita o desenho que parece ótimo para quem o construiu e é
intragável para quem o usa.

> *Decisão: o portal interno de desenvolvedor, do tipo Backstage, fica para a quarta fase. Antes de
> construir a interface sobre a plataforma, a plataforma precisa estar estável e o catálogo
> precisa estar completo; portal sobre processo instável mostra informação errada com confiança.*
