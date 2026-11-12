# ADR-013 — Cache-aside com Valkey em instância por aplicação, dentro do cluster

**Situação:** aceita, com o Valkey entrando no chart base na fase 2.

## Contexto

As aplicações de atendimento ao contribuinte leem muito mais do que escrevem, e boa parte da leitura
recai sobre dado que muda pouco: tabela de alíquota, NCM, CFOP, configuração, consulta repetida. Sem
cache, toda essa leitura chega ao banco principal, que é o recurso mais caro e mais difícil de
escalar do desenho (ADR-004).

Ao mesmo tempo, o dado é fiscal. Parte dele tem sigilo, e parte das leituras decide ato com efeito
jurídico, como a emissão de certidão. Um valor desatualizado nessas leituras é um erro
administrativo, não uma lentidão.

## Decisão

- **Padrão cache-aside.** A aplicação lê do cache; na ausência, lê do banco e grava no cache com
  prazo de validade. Na escrita, grava no banco e apaga a chave. O banco é a única fonte da verdade.
- **Duas camadas.** Cache local na JVM, com Caffeine, para a tabela de referência pequena. Valkey
  para o que é grande demais para cada réplica ou caro demais para calcular trinta vezes.
- **Uma instância de Valkey por aplicação, no namespace dela, em cada cluster.** Sem disco, sem
  Sentinel, com teto de memória, senha pelo Conjur e NetworkPolicy que só aceita os pods da
  própria aplicação. O tráfego é cifrado pelo IPsec da rede do cluster, sem TLS próprio. Criada pelo chart base quando o catálogo pede.
- **Regra do que nunca vai para cache:** decisão com efeito jurídico, numeração e controle de
  duplicidade, e qualquer estado que não possa ser perdido.
- **O banco é dimensionado para a carga sem cache.** O cache é otimização, não capacidade.

## Alternativas descartadas

**Escrita através do cache e escrita adiada.** Põem o cache no caminho da escrita. Na escrita
adiada, o dado fiscal confirmado ao contribuinte vive em memória antes de chegar ao banco, e um
reinício do pod o perde.

**Redis.** É a referência do mercado, e o Valkey nasceu dele. Desde 2024 a licença do Redis deixou
de ser BSD, e um órgão público teria de avaliar a licença a cada atualização. O Valkey é mantido
pela Linux Foundation, com licença BSD, e fala o mesmo protocolo: o Spring Data Redis conecta sem
mudança.

**Red Hat Data Grid.** É o cache suportado pela Red Hat no OpenShift, com operador e suporte do
fornecedor. Descartado como ponto de partida por ser subscrição à parte e usar cliente próprio. O
OpenShift não traz cache de aplicação embutido; o Data Grid é o produto que cumpre esse papel.

**Agrupamento de cache compartilhado pelas 60 aplicações.** Ocupa menos memória e é uma coisa só
para operar. Mistura dado de contribuinte de aplicações diferentes na mesma memória e cria vizinho
barulhento: a aplicação que enche o cache despeja as chaves das outras.

**Replicar o cache ou a invalidação entre sítios.** Exige um canal que atravessa o enlace. Na
partição de rede o canal some sem aviso, e o cache do outro sítio passa a servir valor antigo sem
prazo nenhum.

## Consequência aceita

- **Dezenas de instâncias pequenas para operar**, uma por aplicação que pedir, em cada cluster de
  produção.
- **O prazo de validade é o atraso máximo entre sítios.** Uma escrita em DC1 não apaga a chave em
  DC2. Dado que não tolera esse atraso não vai para cache.
- **Cache frio na troca de sítio.** A primeira onda de leitura em DC2 vai inteira ao banco promovido.
  A regra de dimensionamento sem cache existe por isso.
- **Sessão HTTP no Valkey é exceção declarada**, para a aplicação legada em transição, com o custo de
  novo login quando o Valkey reinicia ou o tráfego troca de sítio.
- **Risco de dependência escondida.** Mitigado pelo teste de carga trimestral com o cache desligado e
  pela medição da primeira hora em DC2 no exercício semestral.

## O que mudaria a decisão

- **A Secretaria já ter subscrição do Red Hat Data Grid**, ou passar a ter pelo pacote do OpenShift:
  o Data Grid substitui o Valkey, com o mesmo padrão e as mesmas regras.
- **Mais de 20 aplicações pedindo cache**, com a soma das instâncias passando de 10 por cento da
  memória dos clusters de produção: um agrupamento compartilhado por classe de dado, com ACL por
  aplicação, passa a compensar.
