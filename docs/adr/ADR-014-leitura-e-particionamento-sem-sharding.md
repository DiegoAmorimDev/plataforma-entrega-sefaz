# ADR-014 — Réplica de relatório e particionamento por período, sem sharding

**Situação:** aceita, com revisão por aplicação quando um dos critérios abaixo for atingido.

## Contexto

O desenho de banco do `docs/05` responde à falha: replicação síncrona dentro do sítio, assíncrona
entre sítios, troca de papel automática no sítio e humana entre sítios. Ele não responde à carga.
Faltam três respostas: se alguma réplica atende leitura, como tratar a tabela que cresce sem parar,
e se a escrita precisa ser dividida entre vários bancos principais.

## Decisão

- **A réplica síncrona não atende leitura.** Ela existe para a troca de papel do nível 1.
- **Réplica de relatório dedicada**, assíncrona, em DC1, marcada no Patroni com `nofailover` e
  `nosync`, só no banco que tiver relatório pesado. Atraso aceito de até 15 minutos.
- **Roteamento explícito.** A aplicação declara duas fontes de dados e o módulo de relatório usa a
  segunda por configuração. Nada é roteado automaticamente pela marcação de somente leitura.
- **Oracle:** relatório pesado roda na principal em janela noturna, ou o banco recebe Active Data
  Guard. Decisão por banco, com o inventário da fase 0.
- **Particionamento declarativo por período** na tabela que cresce sem parar, no PostgreSQL. No
  Oracle, onde a opção de particionamento já estiver licenciada.
- **Sem sharding.** A divisão da escrita entre máquinas já acontece por domínio: cada aplicação tem
  o próprio banco.

## Alternativas descartadas

**Ler da réplica síncrona.** Consulta longa na réplica conflita com a aplicação do registro de
transação. Ou a consulta é cancelada, ou a réplica para de aplicar o registro e fica minutos atrás,
e a promoção dentro do sítio passa a esperar o relatório mais lento do dia. Ligar o
`hot_standby_feedback` evita o cancelamento empurrando o custo para a principal, que segura linhas
antigas e incha.

**Roteamento automático das transações somente leitura para a réplica.** Manda para a réplica a
leitura que vem logo depois de uma escrita, e o contribuinte não vê o que acabou de gravar.

**Sharding, com o Citus ou na própria aplicação.** Resolve a escrita que não cabe num servidor.
Custaria a consulta que cruza contribuintes, a transação entre faixas diferentes, a restauração
consistente entre bancos e, principalmente, a troca de papel entre sítios: a decisão humana de até
10 minutos passaria a promover vários principais e garantir que todos pararam no mesmo ponto.

## Consequência aceita

- **Uma máquina virtual a mais** por banco com relatório pesado.
- **Relatório até 15 minutos atrasado**, declarado na tela.
- **O time separa o módulo de relatório** e configura a segunda fonte de dados.
- **O limite de escrita de cada aplicação é o de um servidor**, com escala vertical e
  particionamento. A premissa está no README.
- **Relatório que cruza aplicações fica fora da plataforma**, num armazém de dados que não é escopo
  desta proposta.

## O que mudaria a decisão

- **Principal acima de 70 por cento de CPU ou de escrita em disco no pico do mês**, depois de escala
  vertical, particionamento e ajuste de consulta: sharding com o Citus, só no banco daquela
  aplicação.
- **Tempo de restauração do banco acima do tempo máximo de retomada da classe dele**: o banco é
  dividido, por sharding ou por arquivamento das partições antigas.
- **Muitos bancos Oracle com relatório pesado**: o Active Data Guard em todos pode sair mais barato
  do que a janela noturna em cada um. A conta é feita na fase 0.
