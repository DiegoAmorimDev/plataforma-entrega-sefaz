# ADR-010 — A promoção é um merge request aberto pela esteira

**Situação:** aceita.

## Contexto

Promover é alterar o digest no overlay do ambiente seguinte (ADR-007). Falta decidir quem altera.
Há três candidatos: a própria esteira, que abre o merge request; o Argo CD Image Updater, que
observa o registry e escreve no Git; e o Kargo, ferramenta feita para orquestrar promoção entre
estágios.

## Decisão

A esteira altera. Um job no runner restrito escreve o digest direto no overlay de desenvolvimento.
Para homologação e produção, o mesmo job abre um merge request no repositório de manifestos, com a
evidência da etapa anterior na descrição: teste de fumaça, tempo de permanência e relatório da
análise.

Em homologação, o merge request é aprovado sozinho quando o pipeline dele passa. Em produção,
exige duas aprovações de pessoas do time dono. A plataforma só aprova quando o merge request altera
algo além do digest, como versão do chart, ajuste de overlay ou recurso novo; um job do pipeline de
`manifestos-apps` faz essa distinção e bloqueia o merge sem a aprovação dela. Com sessenta
aplicações e dezenas de promoções por dia, a plataforma no caminho de toda promoção seria a fila
que o desenho quer evitar.

## Alternativas descartadas

**Argo CD Image Updater.** Ele observa o registry e promove a imagem mais nova que casar com um
padrão de tag. Descartado porque a regra é "a mais nova", não "a que passou na etapa anterior".
Expressar "só depois de 24 horas estável em homologação, com teste de fumaça aprovado" exige
lógica que ele não tem. Ele serve bem para desenvolvimento e mal para a cadeia inteira.

**Kargo.** Foi feito exatamente para isto: estágios, verificação entre eles e promoção com
evidência. É a evolução natural deste desenho. Descartado nos primeiros doze meses porque
acrescenta mais um controlador a operar, com modelo próprio de conceitos, num momento em que os
doze times ainda estão aprendendo GitOps. Os mesmos merge requests, abertos por um script, ensinam
o modelo sem esconder o mecanismo.

## Consequência aceita

- **A lógica de promoção mora em script**, na imagem `promotor` do template central. Script de
  promoção cresce, e cresce mal. Ele é testado e versionado como qualquer outra peça do template.
- **O token de escrita no repositório de manifestos existe.** Ele vem do Conjur, pela identidade do
  job, só para jobs de branch protegido, e é rotacionado pelo PAM.
- **A evidência fica na descrição do merge request**, e não num objeto estruturado. Quem audita lê
  texto, não consulta uma API.

## O que mudaria a decisão

- **Se o script de promoção passar de algumas centenas de linhas**, ou se surgir um quarto
  ambiente, o Kargo entra no lugar dele.
- **Se a auditoria pedir a evidência de promoção em formato consultável**, o Kargo também resolve,
  porque registra cada promoção como objeto.
