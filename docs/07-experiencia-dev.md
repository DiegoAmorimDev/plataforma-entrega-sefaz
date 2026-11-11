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

O time abre um merge request no repositório `catalogo-apps` com uma ficha de cerca de cinquenta
linhas de configuração, fora os comentários. A ficha é a única coisa que o time preenche para
existir na plataforma. O exemplo comentado está em [`exemplos/catalogo/exemplo-aplicacao.yaml`](../exemplos/catalogo/exemplo-aplicacao.yaml);
o trecho abaixo mostra as partes que mais pesam.

```yaml
metadata:
  nome: nfe-emissor
  time: fiscal
classificacao:
  tier: 1
  dados_sensiveis: true
tecnologia:
  linguagem: java
  versao_runtime: "21"
rotas:
  - host: nfe.sefaz.exemplo.gov.br
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
operacao:
  plantao:
    grupo_ad: SEFAZ-FISCAL-PLANTAO
```

A revisão é da plataforma e olha três coisas: se o nível declarado é compatível com o impacto real,
se as dependências existem e se o compromisso de nível de serviço é alcançável com o desenho
proposto. Costuma levar menos de uma hora. É a única aprovação da plataforma no caminho comum, e
acontece uma vez por aplicação, e não uma vez por entrega.

### Dia 1, à tarde: o que acontece sozinho

Com o merge, um pipeline executa e cria tudo o que a aplicação precisa:

| Criado | Onde |
|---|---|
| Repositório a partir do template da linguagem | GitLab |
| Namespaces nos três ambientes, com cota, limites, negação de rede e permissão. O pipeline do catálogo faz commit dos objetos em `plataforma-addons/namespaces/`; o Argo CD os lê sob o projeto `plataforma`, que tem permissão de escopo de cluster. O pipeline continua sem credencial de cluster | Quatro clusters |
| Projeto com política de retenção e varredura | Harbor |
| Caminho de segredos, identidade da ServiceAccount e política de acesso | Conjur |
| Diretório de manifestos com os três overlays | `manifestos-apps` |
| Objeto de aplicação gerado pelo gerador | Argo CD |
| Painel com as métricas de ouro | Grafana |
| Alertas de orçamento de erro conforme o nível declarado | Prometheus |
| Grupo de roteamento de plantão | Alertmanager |
| Rota em homologação | Roteador do OpenShift |

> *Decisão: o pipeline do catálogo não aplica nada em produção, só faz commit. A alternativa
> descartada é dar a ele credencial de cluster para criar o namespace direto, que quebra a regra de
> que o GitLab nunca a recebe. O custo é a aplicação nova esperar a sincronização do Argo CD, de
> poucos minutos, antes de existir em `prd-dc1` e `prd-dc2`.*

O repositório gerado já vem pronto para o primeiro `git push`. No template Java, isso significa:

- projeto Spring Boot 3 com Java 21 e Maven, com uma rota HTTP de exemplo e o teste dela;
- Spring Boot Actuator expondo as sondas de saúde e o encerramento gracioso ligado;
- Dockerfile multiestágio sobre a imagem base aprovada, que já traz o agente Java do
  OpenTelemetry: métrica, log e trace saem sem uma linha de instrumentação no código;
- teste de integração que roda contra PostgreSQL real, pelo Testcontainers na máquina do
  desenvolvedor e como serviço do job na esteira, e o arquivo do Liquibase para a primeira
  migração;
- o `.gitlab-ci.yml` de cerca de trinta e cinco linhas que inclui o template central.

Ao lado, em `manifestos-apps`, nasce o diretório da aplicação, com o `values.yaml` do chart base
preenchido a partir do catálogo e os overlays dos três ambientes. O manifesto mora lá, e não no
repositório de código, porque o Argo CD só lê manifesto ([`docs/09`](09-gitops-argocd.md)).

O primeiro `git push` percorre a esteira inteira e chega em desenvolvimento.

---

## Configuração, variável de ambiente e segredo

A pergunta que todo time faz na primeira semana é onde colocar a URL do banco, a senha e o nível
de log. A resposta da plataforma cabe numa regra: **a imagem é a mesma em todos os ambientes, e
tudo o que muda entre eles chega como variável de ambiente.** A regra decorre da promoção por
digest: se a configuração de produção estivesse dentro da imagem, a imagem de produção seria
outra imagem.

| O quê | Exemplo | Onde mora | Quem escreve | Como chega à aplicação | Quando muda |
|---|---|---|---|---|---|
| Padrão da aplicação | Tamanho do pool, tempo limite | `application.yaml`, dentro da imagem | Time | Lido pelo Spring na partida | Nova versão |
| Configuração do ambiente | URL do autorizador, nível de log | `configMapGenerator` no overlay do ambiente | Time, por merge request | `ConfigMap`, como variável de ambiente | O nome do `ConfigMap` muda com o conteúdo, e os pods são recriados |
| Segredo | Senha do banco, certificado | Conjur | PAM, na rotação; ninguém digita | `ExternalSecret` gera o `Secret`, lido como variável de ambiente | O Reloader recria os pods de forma gradual |
| Identidade do pod | Nome, namespace, ambiente | Chart base | Plataforma | Variável preenchida pelo Kubernetes | Nunca muda dentro do pod |

O time declara o segredo pelo caminho, nunca pelo valor. No `values.yaml` da aplicação:

```yaml
segredos:
  - caminho: banco
    chaves:
      SPRING_DATASOURCE_USERNAME: usuario
      SPRING_DATASOURCE_PASSWORD: senha
```

O chart transforma isso num `ExternalSecret` que aponta para
`fiscal/nfe-emissor/<ambiente>/banco` no Conjur. O mesmo `values.yaml` serve aos três ambientes, e
o ambiente decide qual segredo é lido. O desenvolvedor de desenvolvimento nunca vê a senha de
produção, e não precisa dela.

> *Decisão: nenhum perfil do Spring por ambiente dentro da imagem. A alternativa comum,
> `application-prd.yaml` empacotado no JAR, coloca a configuração de produção dentro do artefato:
> mudar o nível de log em produção exige build novo e quebra a garantia de que o testado é o que
> executa. O Spring já lê variável de ambiente no lugar de qualquer propriedade:
> `SPRING_DATASOURCE_URL` substitui `spring.datasource.url` sem uma linha de código. O custo é o
> time perder o hábito do perfil por ambiente, que é o hábito mais comum em projeto Spring.*

**A rotação não exige nada do time.** O PAM troca a senha no banco e no Conjur, o External Secrets
busca o valor novo no intervalo configurado, e o Reloader recria os pods um a um. Cada aplicação
tem duas contas de banco que se alternam, então o pod que ainda não foi recriado continua
conectando com a conta anterior, que segue válida até o ciclo seguinte.

**Em desenvolvimento local, nada vem do Conjur.** O repositório traz um `compose.yaml` com o banco
em contêiner e um `.env.exemplo` com valores falsos. O `.env` real está no `.gitignore`, e o
Gitleaks reprova o merge request se alguém o enviar por engano.

### Semanas seguintes: a subida até produção

A promoção para homologação é automática quando os testes passam. A promoção para produção é um
merge request de uma linha, aprovado por duas pessoas do próprio time. A plataforma só entra quando
o merge request muda algo além do digest (ADR-010).

Antes da primeira entrega em produção, há uma lista de prontidão que a plataforma confere junto com
o time. Ela não é burocracia de carimbo: cada item corresponde a uma causa conhecida de incidente.

- Sondas de vitalidade e prontidão implementadas e distintas.
- Requisições e limites de recurso medidos em teste de carga, não chutados.
- Encerramento gracioso tratado.
- Repetição com espera progressiva e disjuntor nas chamadas externas.
- Migração de banco em duas etapas, com a etapa de expandir separada da de contrair.
- Nível de serviço acordado com a área de negócio, não escolhido pelo time sozinho.
- Roteiro de resposta escrito para cada alerta que gera chamada telefônica.
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
| Nível de serviço, alertas e roteiro de resposta da aplicação | Acorda e revisa | Define e mantém |
| Atender o alerta da própria aplicação | Escala quando é infraestrutura | Responsável |
| Vulnerabilidade em dependência da aplicação | Informa e acompanha prazo | Corrige |
| Vulnerabilidade na imagem base | Corrige | Reconstrói |
| Esquema e desempenho de consulta ao banco | — | Responsável |
| Disponibilidade e backup do banco | — (é da equipe de banco, que já existe) | — |
| Capacidade de hardware | Responsável | Informa previsão de crescimento |
| Decisão de reverter a própria entrega | — | Responsável |
| Decisão de ativar o plano de continuidade | Responsável | — |

A linha mais polêmica é a do atendimento ao alerta. **Quem constrói, opera.** O time que escreveu o
código atende o alerta da aplicação, no horário definido pelo nível. É o que fecha o ciclo de
retorno. Um time que acorda com o próprio
vazamento de memória conserta o vazamento; um time que nunca é acordado aprende que a plataforma
absorve o problema.

A plataforma sustenta isso com três compromissos. Primeiro, o alerta chega com roteiro de resposta e com dado,
não como "algo está errado". Segundo, o que for de infraestrutura é escalado para a plataforma sem
o time precisar provar nada. Terceiro, o volume de alertas por plantão é medido, e alerta ruidoso é
problema da plataforma para resolver.

---

## O que acontece quando o time quer sair do caminho pavimentado

Um time vai querer Node.js quando só há template de Java e .NET. Outro vai querer um banco que não
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
serviço declarado e telemetria emitida no padrão. Cada um tem quem o aplique sem depender de alguém
lembrar. A política de admissão recusa imagem de fora, imagem sem assinatura, contêiner
privilegiado e pod sem limite. O Gitleaks reprova segredo no repositório. O processo de catálogo
não cria namespace para aplicação sem nível de serviço declarado. A telemetria vem da imagem base
e do chart, e a lista de prontidão confere antes da primeira entrega em produção.

---

## Como a plataforma evita virar fila de chamados

Quatro mecanismos, nessa ordem de importância.

**O autoatendimento vem na primeira fase, não na última.** Construir a plataforma por um ano
atendendo tudo por chamado e só depois automatizar não funciona, porque a equipe fica presa na
operação e nunca chega na automação.

**Toda pergunta respondida duas vezes vira documentação ou automação.** A terceira ocorrência do
mesmo chamado é defeito da plataforma, e entra na fila de trabalho como tal.

**Há horário fixo de atendimento aberto.** Duas horas por semana em que qualquer pessoa entra, sem
chamado, para tirar dúvida ou pedir ajuda. Concentrar a interrupção em uma janela protege o resto
da semana.

**Cada pessoa da plataforma passa um dia por mês dentro de um time de desenvolvimento**, usando a
plataforma como usuário. É o que evita o desenho que parece ótimo para quem o construiu e é
intragável para quem o usa.

> *Decisão: o portal interno de desenvolvedor, do tipo Backstage, fica para a quarta fase. Antes de
> construir a interface sobre a plataforma, a plataforma precisa estar estável e o catálogo
> precisa estar completo; portal sobre processo instável mostra informação errada com confiança. A
> alternativa, portal desde a fase 1, foi descartada por isso. O custo é o time navegar entre
> GitLab, Argo CD e Grafana até lá.*
