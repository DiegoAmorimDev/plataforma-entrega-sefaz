# ADR-012 — SonarQube Community, com o portão de cobertura do merge request fora dele

**Situação:** aceita.

## Contexto

O quality gate do código novo precisa reprovar a alteração antes do merge, enquanto o autor ainda
está com o contexto na cabeça. Na edição Community do SonarQube, isso não acontece: ela analisa
apenas o branch principal. A análise de merge request, com o comentário no próprio merge request,
começa na edição Developer, que é paga por linhas de código.

## Decisão

O SonarQube é a edição Community. O portão do merge request é montado com duas peças:

- **No merge request**, a cobertura das linhas alteradas é calculada pelo `diff-cover` a partir do
  relatório do JaCoCo, e reprova abaixo de 80 por cento. A análise estática de segurança, a
  varredura de dependência e a busca de segredo também rodam aqui e também reprovam.
- **Em `main`, depois do merge**, o SonarQube analisa o branch e o quality gate do código novo
  reprova o pipeline antes do build da imagem. Como a imagem só nasce de `main`, uma reprovação ali
  impede que a versão chegue a qualquer ambiente, e a correção vem no commit seguinte.

## Alternativas descartadas

**Edição Developer.** É a que o autor opera hoje, em ambiente financeiro regulado. Ela analisa o
merge request, comenta nas linhas e reúne num só lugar o que aqui fica dividido em duas peças. É
melhor, e a proposta não esconde isso. Foi descartada como ponto de partida porque é a única
licença do desenho cujo valor depende do tamanho do código, e o tamanho das 60 aplicações só é
conhecido depois do inventário da fase 0.

**Extensão comunitária que habilita branch na Community.** Ela existe e funciona. Foi descartada
porque precisa casar com a versão exata do SonarQube: cada atualização do SonarQube espera uma
versão nova da extensão, e uma correção de segurança do SonarQube passa a depender de um projeto de
terceiros.

## Consequência aceita

- **O desenvolvedor vê os problemas de manutenção só depois do merge.** Os de segurança e a
  cobertura ele vê antes, que são os que bloqueiam. Os de manutenção são informativos de qualquer
  forma.
- **Duas medições de cobertura.** O `diff-cover` e o SonarQube podem divergir em uma ou duas linhas,
  por diferença de critério. O portão do merge request vale para entrar; o do SonarQube vale para
  construir.
- **`main` pode ficar vermelho.** Um merge que passa no `diff-cover` e reprova no quality gate
  bloqueia o build até a correção. O time aprende rápido, porque o próximo merge dele também fica
  parado.

## O que mudaria a decisão

- **Com o inventário da fase 0 em mãos**, se a licença Developer couber no orçamento, ela entra e o
  `diff-cover` sai. O critério é o custo anual da licença comparado com o tempo perdido em `main`
  vermelho, medido nos três primeiros meses.
