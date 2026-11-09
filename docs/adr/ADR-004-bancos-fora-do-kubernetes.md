# ADR-004 — Oracle e PostgreSQL permanecem em máquina virtual

**Situação:** aceita, com revisão prevista no mês 12.

## Contexto

Os bancos de dados da Secretaria rodam hoje em máquina virtual, com rotina de backup, monitoração
e equipe de administração estabelecidas. Existe a opção de movê-los para dentro do Kubernetes, com
operadores como o CloudNativePG para PostgreSQL.

## Decisão

Oracle e PostgreSQL permanecem fora do Kubernetes, em máquina virtual provisionada por Terraform e
configurada por Ansible. A alta disponibilidade é do Data Guard e do Patroni, não do Kubernetes.

## Alternativa descartada

**Operador de banco dentro do cluster.** Entregaria provisionamento sob demanda, a mesma forma de
declarar banco e aplicação, e recuperação automática de instância.

Descartada por três motivos.

O Oracle não tem caminho razoável. Não existe operador maduro com suporte do fornecedor para o
modelo de licenciamento em uso, e licença Oracle sobre núcleo de nó de Kubernetes é um problema
contratual, não técnico. Como parte relevante das 60 aplicações usa Oracle, metade do parque
continuaria fora de qualquer forma.

O ganho é pequeno no cenário real. Operador de banco brilha com muitos bancos pequenos, criados e
destruídos com frequência. Aqui há dezenas de bancos estáveis e de vida longa, onde o provisionamento
sob demanda quase não é exercido.

O custo de aprendizado chega no pior momento. Operar banco no Kubernetes exige dominar classe de
armazenamento, comportamento de volume persistente sob falha de nó, desalojamento e o próprio
operador. Aprender isso durante a migração de plataforma concentra dois riscos no mesmo trimestre.

## Consequência aceita

- Duas formas de provisionar infraestrutura convivem: Terraform mais Ansible para banco,
  Kubernetes para aplicação.
- Banco para ambiente de desenvolvimento não é instantâneo, e isso atrita. A compensação é
  autorizar PostgreSQL em contêiner dentro do namespace de desenvolvimento, sem compromisso de
  disponibilidade e sem backup, apenas para teste.
- O tempo de retomada da maioria das aplicações passa a ser determinado pelo banco, não pela
  plataforma. A seção de resiliência deixa isso explícito.

## O que mudaria a decisão

- Demanda real por muitos bancos PostgreSQL pequenos e de vida curta, tipicamente a partir de
  trinta instâncias com rotatividade alta.
- Equipe de plataforma com experiência consolidada em armazenamento no Kubernetes, demonstrada por
  restauração testada em ambiente de laboratório.
- Nesse caso, a migração começaria apenas pelo PostgreSQL de aplicações de nível 3 e 4. O Oracle
  permanece fora enquanto o modelo de licenciamento não mudar.
