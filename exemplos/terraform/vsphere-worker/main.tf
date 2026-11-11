# Módulo que cria nós de trabalho do RKE2 (dev-dc1) no vSphere.
#
# Entrada: função do nó e quantidade. Saída: máquinas criadas, espalhadas por
# host físico, já no inventário do Ansible, que aplica a linha de base.
#
# Nó de OpenShift não nasce aqui: a instalação IPI cria os nós, e o próprio
# cluster os substitui pelo MachineSet (docs/06, camada 2). O mesmo padrão
# deste módulo serve às outras máquinas fora do OpenShift: bancos, Conjur e
# HAProxy.

terraform {
  required_version = ">= 1.6"
  required_providers {
    vsphere = { source = "hashicorp/vsphere", version = "~> 2.8" }
  }
}

# Este módulo não configura provedor nem backend: quem o chama configura.
# No módulo raiz de infra-vsphere, a credencial do vCenter vem do Conjur no
# momento da execução, nunca de variável de CI de longa duração nem de arquivo,
# e o estado fica no backend do GitLab, com trava.
#
# A credencial NÃO é lida por data "conjur_secret": o valor iria para o estado
# do Terraform, em texto claro, e o estado é lido por quem tem acesso ao projeto
# de infraestrutura. O job lê o segredo e o entrega por variável de ambiente,
# que o provedor vsphere aceita sem argumento no bloco:
#
#   # No job de CI, com a identidade do job (ADR-008):
#   export VSPHERE_USER="$(conjur-segredo plataforma/vcenter/dc1/usuario)"
#   export VSPHERE_PASSWORD="$(conjur-segredo plataforma/vcenter/dc1/senha)"
#
#   terraform {
#     backend "http" {}                # estado no GitLab; duas pessoas não aplicam juntas
#   }
#
#   provider "vsphere" {
#     vsphere_server = "vcenter-dc1.sefaz.interno"
#     # usuário e senha vêm de VSPHERE_USER e VSPHERE_PASSWORD
#   }
#
# Custo aceito: o job de infraestrutura depende do utilitário conjur-segredo,
# que já é premissa de toda a esteira. Alternativa descartada: o provedor do
# Conjur no próprio plano, mais direto, mas que grava a senha no estado.
#
#   module "workers_dev_dc1" {
#     source     = "./modulos/vsphere-worker"
#     cluster    = "dev-dc1"
#     funcao     = "worker"
#     quantidade = 4
#     ...
#   }

locals {
  nome_base = "${var.cluster}-${var.funcao}"

  # Espalha as máquinas pelos hosts em rodízio. Combinado com a regra de
  # anti-afinidade abaixo, tende a manter no máximo um nó do mesmo cluster por
  # host físico. Só vale enquanto a quantidade não passa do número de hosts: a
  # verificação no recurso (precondition) barra o plano quando passa. A regra de
  # anti-afinidade é preferencial, então o vSphere HA ainda pode juntar dois nós
  # num host depois de uma falha; o rodízio não é garantia.
  distribuicao = {
    for i in range(var.quantidade) :
    format("%s-%02d", local.nome_base, i + 1) => {
      host = var.hosts_esxi[i % length(var.hosts_esxi)]
      rack = var.racks[i % length(var.racks)]
      ip   = cidrhost(var.cidr_rede, var.primeiro_ip + i)
    }
  }
}

resource "vsphere_virtual_machine" "no" {
  for_each = local.distribuicao

  name             = each.key
  resource_pool_id = data.vsphere_compute_cluster.alvo.resource_pool_id
  datastore_id     = data.vsphere_datastore.alvo.id
  host_system_id   = data.vsphere_host.hosts[each.value.host].id

  num_cpus = var.vcpus
  memory   = var.memoria_mb

  # Reserva de memória total nos nós de produção. Sem reserva, o balanceamento
  # do vSphere pode reduzir memória sob pressão, e o kubelet não entende isso:
  # ele continua agendando pod para uma memória que o hipervisor já tirou.
  memory_reservation = var.ambiente == "prd" ? var.memoria_mb : 0

  guest_id         = data.vsphere_virtual_machine.template.guest_id
  scsi_type        = data.vsphere_virtual_machine.template.scsi_type
  firmware         = "efi"
  efi_secure_boot_enabled = true

  network_interface {
    network_id   = data.vsphere_network.rede.id
    adapter_type = "vmxnet3"
  }

  disk {
    label            = "sistema"
    size             = var.disco_sistema_gb
    thin_provisioned = false     # provisionamento fino em nó de produção esconde
  }                              # o momento em que o datastore enche de verdade

  disk {
    label            = "container-runtime"
    unit_number      = 1
    size             = var.disco_containers_gb
    thin_provisioned = false
  }

  clone {
    # Template gerado por Packer a partir da imagem oficial do RHEL. Nunca uma
    # máquina de referência que alguém configurou à mão em 2019.
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = each.key
        domain    = "sefaz.interno"
      }
      network_interface {
        ipv4_address = each.value.ip
        ipv4_netmask = var.mascara
      }
      ipv4_gateway    = var.gateway
      dns_server_list = var.dns
    }
  }

  tags = [
    vsphere_tag.ambiente.id,
    vsphere_tag.cluster.id,
  ]

  # Anotações que o Rancher escreve na máquina durante o registro do nó não
  # devem reaparecer como desvio no plano diário.
  lifecycle {
    ignore_changes = [annotation, clone[0].template_uuid]

    # Mais nós que hosts põe dois nós no mesmo host, e perder esse host derruba
    # os dois. O plano falha em vez de aceitar em silêncio.
    precondition {
      condition     = var.quantidade <= length(var.hosts_esxi)
      error_message = "quantidade maior que o número de hosts ESXi: dois nós do mesmo cluster dividiriam um host físico."
    }
  }
}

# Impede que o balanceamento do vSphere junte os nós no mesmo host físico, o que
# anularia a dispersão topológica configurada no Kubernetes.
#
# Regra preferencial, não obrigatória. Obrigatória, ela impediria o vSphere HA
# de reiniciar o nó em outro host quando sobram menos hosts que nós, e a
# máquina ficaria desligada justamente durante a falha.
resource "vsphere_compute_cluster_vm_anti_affinity_rule" "espalhar" {
  name                = "${local.nome_base}-anti-afinidade"
  compute_cluster_id  = data.vsphere_compute_cluster.alvo.id
  virtual_machine_ids = [for vm in vsphere_virtual_machine.no : vm.id]
  enabled             = true
  mandatory           = false
}

# Saída consumida pelo inventário dinâmico do Ansible, que aplica a linha de base.
output "inventario" {
  value = {
    for nome, vm in vsphere_virtual_machine.no : nome => {
      ip   = vm.default_ip_address
      rack = local.distribuicao[nome].rack
      # Vira o rótulo topology.kubernetes.io/zone no nó do Kubernetes. Para o
      # rótulo continuar verdadeiro depois de um vMotion, uma regra VM-Host
      # preferencial mantém cada máquina no grupo de hosts do próprio rack.
      zona = "${var.sitio}-${local.distribuicao[nome].rack}"
    }
  }
}
