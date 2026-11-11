# ADR-002 — Dois clusters de produção independentes, um por sítio

**Situação:** aceita.

## Contexto

Com dois datacenters, há duas formas de usar os dois em produção. Um cluster esticado, com nós nos
dois sítios e um plano de controle só. Ou dois clusters independentes, cada um completo no seu
sítio, com o tráfego distribuído por fora.

O cluster esticado é mais simples de operar: uma atualização, um conjunto de objetos, uma aplicação
no Argo CD. O pod se move sozinho entre sítios quando um nó cai.

## Decisão

Produção são dois clusters independentes, `prd-dc1` e `prd-dc2`. Cada um tem três nós de controle
no próprio sítio. A distribuição de tráfego entre eles é do HAProxy, com verificação ativa de
saúde.

## Alternativa descartada

**Cluster esticado entre DC1 e DC2.** Descartada por causa do etcd. O etcd precisa de maioria
para escrever, e dois sítios não dividem três membros por igual: um sítio fica com dois, o outro
com um. Na perda do sítio que tem dois membros, o sobrevivente fica sem quórum e não aceita
nenhuma mudança, no exato momento em que a contingência precisa dele. Na partição com os dois
sítios vivos, o lado minoritário congela, e decidir qual lado fica com a maioria é uma escolha
arbitrária feita antes de saber qual sítio vai falhar. E uma oscilação de rede de trinta
segundos, que num desenho independente passa despercebida, provoca trocas de líder que
instabilizam o plano de controle do cluster inteiro.

O desenho esticado só é defensável com três sítios, em que o terceiro hospeda o nó de desempate.
A Secretaria tem dois.

## Consequência aceita

O custo da escolha é operacional, e é real:

- Duas atualizações de cluster por ciclo, em vez de uma.
- O mesmo objeto precisa existir nos dois clusters, o que o `ApplicationSet` resolve com um
  cruzamento de diretórios com clusters do `ApplicationSet`, mas que o time precisa entender ao depurar.
- A falha de um sítio não move pods sozinha. Para aplicação de nível 1, a réplica já está em
  execução no outro sítio. Para nível 2, há uma ação humana de escalar.
- Aplicação com estado precisa decidir em qual sítio o volume vive, e isso não é transparente.

## O que mudaria a decisão

- Um terceiro sítio, ainda que pequeno e apenas para desempate, com enlace abaixo de 2 ms entre os
  três. Nesse caso o cluster esticado passa a ser a melhor escolha.
- Armazenamento com replicação síncrona entre sítios já homologado, que removeria a parte difícil
  da aplicação com estado.
