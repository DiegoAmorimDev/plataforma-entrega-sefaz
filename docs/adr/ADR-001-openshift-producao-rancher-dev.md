# ADR-001 — OpenShift em produção, RKE2 sob Rancher em desenvolvimento

**Situação:** aceita.

## Contexto

O parque já tem Red Hat OpenShift e Rancher. A pergunta é se a modernização deve padronizar numa
distribuição só ou manter as duas com papéis distintos.

OpenShift traz suporte comercial, controle de contexto de segurança no momento da admissão, ciclo
de atualização testado pelo fornecedor e integração com o ecossistema Red Hat que a Secretaria já
usa no sistema operacional. Cobra por isso subscrição por núcleo e um ciclo de atualização mais
rígido. Rancher com RKE2 custa menos, é mais flexível e serve como console multi-cluster.

## Decisão

Produção e homologação rodam em OpenShift. Desenvolvimento roda em RKE2 gerenciado pelo Rancher.
O Rancher importa os cinco clusters e serve de inventário único.

## Alternativa descartada

**Padronizar tudo em OpenShift.** Daria ambiente idêntico em todas as etapas, que é o ideal
técnico. Foi descartada pelo custo de subscrição num ambiente que existe para ser destruído e
recriado, e onde a instabilidade é aceitável. O dinheiro economizado em desenvolvimento compra nó
de produção.

**Padronizar tudo em RKE2.** Removeria a subscrição inteira. Foi descartada porque produção com
dado fiscal auditado por órgão de controle externo pesa suporte contratado e rastreabilidade de
correção de segurança acima do custo de licença. A pergunta "quem responde quando o plano de
controle falhar às três da manhã" precisa ter resposta com contrato.

## Consequência aceita

Existe diferença entre desenvolvimento e produção, e ela pode esconder defeito. As três
contenções:

1. O chart base emite `Route` ou `Ingress` conforme o ambiente, e o time não escreve nenhum dos
   dois.
2. As políticas de admissão do Kyverno são as mesmas nos quatro clusters de execução. Origem e
   assinatura da imagem são obrigatórias em homologação e produção; em desenvolvimento ficam em
   auditoria, e o relatório mostra ao time, antes de promover, o que seria recusado adiante.
3. Um teste de conformidade instala a mesma aplicação de referência nos quatro clusters de execução
   a cada
   atualização e compara comportamento.

Homologação ser OpenShift é o que mantém a garantia: qualquer coisa que dependa de distribuição
aparece antes de produção.

## O que mudaria a decisão

- Se a subscrição do OpenShift deixar de ser renovada, produção migra para RKE2 e a homologação
  acompanha.
- Se o custo de operar duas distribuições se mostrar maior que a economia de licença, medido em
  horas da equipe no primeiro semestre, desenvolvimento migra para OpenShift.
