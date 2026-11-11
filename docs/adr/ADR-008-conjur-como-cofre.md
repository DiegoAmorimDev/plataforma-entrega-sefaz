# ADR-008 — CyberArk Conjur como cofre de segredos, consumido pelo External Secrets

**Situação:** aceita.

## Contexto

A plataforma guarda quatro famílias de segredo: credencial de banco das aplicações, credencial de
integração com outros órgãos, credencial da própria esteira (chave de assinatura de imagem, token
de escrita no repositório de manifestos) e credencial de infraestrutura (vCenter, contas de
serviço dos clusters).

Três exigências pesam mais que as outras. A primeira é que nenhuma carga de trabalho precise de um
segredo estático para buscar os outros segredos. A segunda é que a senha de banco troque
periodicamente sem derrubar a aplicação. A terceira é que a conta privilegiada de banco e de
servidor seja governada no mesmo lugar onde a auditoria já procura por ela.

## Decisão

O cofre é o **CyberArk Conjur**, na edição comercial (Secrets Manager Self-Hosted), integrado ao
CyberArk PAM.

- **A rotação é do PAM.** O CPM, componente do PAM que troca senhas, rotaciona a credencial de
  banco conforme a política de cada conta. O Vault Synchronizer leva o valor novo para o Conjur.
  A aplicação nunca participa da rotação.
- **Conta dupla para credencial de aplicação.** Cada aplicação tem duas contas de banco que se
  alternam. Enquanto uma está em uso, a outra é rotacionada. Quando o ponteiro troca, a conta
  anterior continua válida até o ciclo seguinte. Isso elimina a janela em que o pod ainda tem a
  senha velha e o banco já aceita só a nova.
- **O Conjur roda em máquina virtual, fora dos clusters.** Líder e réplica de espera em DC1,
  réplica de espera e réplica de leitura em DC2. O cofre é necessário para reconstruir um cluster;
  se morasse dentro dele, a reconstrução dependeria do que está sendo reconstruído.
- **A aplicação não conhece o cofre.** O External Secrets, dentro de cada cluster, autentica no
  Conjur pelo token da ServiceAccount do namespace, usando o autenticador JWT. Ele materializa o
  segredo como `Secret` do Kubernetes, e a aplicação lê variável de ambiente. Quando o valor muda,
  o Reloader reinicia os pods de forma gradual.
- **A esteira também autentica por identidade.** O job do GitLab CI recebe um token de curta
  duração (`id_tokens`) e o troca no Conjur pelo segredo que a política dele permite ler. Não
  existe variável de CI com segredo de longa duração.

## Alternativas descartadas

**HashiCorp Vault ou OpenBao.** É a alternativa tecnicamente mais forte. A credencial dinâmica de
banco, em que o cofre cria um usuário com validade de horas para cada pod, é superior à rotação
periódica. Foi descartada por dois motivos. Com o PAM já em uso, adotar o Vault divide a
governança de conta privilegiada em dois sistemas, e a auditoria passa a perguntar qual dos dois é
a fonte verdadeira. Além disso, desde 2023 o Vault é distribuído sob licença BSL; o caminho aberto
é o OpenBao, uma bifurcação mais nova, com menos histórico de operação em órgão público.

**Aplicação chamando a API do Conjur.** É o modelo que o autor opera hoje, em ambiente financeiro
regulado: a rotação vem do CPM, como aqui, e a aplicação busca o segredo pelo SDK. Funciona e tem
uma vantagem real: a aplicação pode buscar o valor novo sem reiniciar. Foi descartado nesta
plataforma por três motivos, todos ligados à escala de 60 aplicações e 12 times.

1. Cada aplicação carrega um SDK e uma identidade própria no Conjur. Doze times implementam a
   mesma integração doze vezes, e um defeito nela vira doze defeitos.
2. Com chamada direta, o Conjur indisponível impede o pod de subir. Com o External Secrets, o
   `Secret` já está no cluster: pod reagendado durante uma queda do Conjur sobe normalmente.
3. Trocar de cofre no futuro passaria a exigir alteração no código das 60 aplicações. Com o
   External Secrets, exige trocar o provedor de um objeto por cluster.

**Segredo cifrado no Git, com Sealed Secrets ou SOPS.** Descartado porque a rotação vira um commit
por aplicação, a chave de decifração vira o segredo mais valioso da plataforma, e o Git não
registra quem leu o segredo, só quem o alterou.

## Consequência aceita

- **Custo de licença.** O Conjur comercial e o PAM são pagos. A edição aberta do Conjur não tem a
  rotação pelo CPM nem a réplica de espera.
- **O segredo passa a existir no etcd** de cada cluster, como `Secret`. A criptografia do etcd em
  repouso é obrigatória, e a permissão de leitura de `Secret` não é concedida a nenhum grupo humano
  em homologação e produção.
- **Rotação implica reinício gradual.** O pod lê a variável de ambiente uma vez, na partida.
  A conta dupla torna esse reinício seguro, mas ele acontece a cada rotação.
- **O Cosign não usa o Conjur como serviço de chave.** O job de assinatura busca a chave privada
  pelo token de identidade, assina em memória e descarta. A chave sai do cofre por segundos, dentro
  do runner restrito, e só para jobs de branch protegido do projeto autorizado.

## O que mudaria a decisão

- **Se a Secretaria não tiver o PAM da CyberArk**, a decisão se inverte para o OpenBao, com
  credencial dinâmica de banco. O consumo pelo External Secrets não muda, porque ele também tem
  provedor para o OpenBao.
- **Se uma aplicação precisar de credencial que troca a cada poucos minutos**, ela passa a chamar
  o cofre diretamente, como exceção registrada no catálogo.
