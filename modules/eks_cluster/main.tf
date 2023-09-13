# ================================================================
# ================================================================
# ================================================================

# VPC
module "vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  version              = "5.1.1"
  name                 = "eks_vpc"
  azs                  = local.azs
  cidr                 = local.cidr
  public_subnets       = local.public_subnets
  private_subnets      = local.private_subnets
  enable_dns_hostnames = "true"
  enable_dns_support   = "true"
  tags = {
    "TerraformManaged" = "true"
  }
}

# ================================================================
# ================================================================
# ================================================================

# Security-Group (NAT-Instance)
module "NAT_SG" {
  source          = "terraform-aws-modules/security-group/aws"
  version         = "5.1.0"
  name            = "NAT_SG"
  description     = "All Traffic"
  vpc_id          = module.vpc.vpc_id
  use_name_prefix = "false"

  ingress_with_cidr_blocks = [
    {
      from_port   = local.any_port
      to_port     = local.any_port
      protocol    = local.any_protocol
      cidr_blocks = local.private_subnets[0]
    },
    {
      from_port   = local.any_port
      to_port     = local.any_port
      protocol    = local.any_protocol
      cidr_blocks = local.private_subnets[1]
    }
  ]
  egress_with_cidr_blocks = [
    {
      from_port   = local.any_port
      to_port     = local.any_port
      protocol    = local.any_protocol
      cidr_blocks = local.all_network
    }
  ]
}

# NAT Instance ENI EIP
resource "aws_eip" "NAT_Instance_eip" {
  network_interface = aws_network_interface.NAT_ENI.id
  tags = {
    Name = "NAT_EIP"
  }
}

# NAT Instance ENI(Elastic Network Interface)
resource "aws_network_interface" "NAT_ENI" {
  subnet_id         = module.vpc.public_subnets[0]
  private_ips       = ["192.168.1.50"]
  security_groups   = [module.NAT_SG.security_group_id]
  source_dest_check = false

  tags = {
    Name = "NAT_Instance_ENI"
  }
}

# NAT Instance 
resource "aws_instance" "NAT_Instance" {
  ami           = "ami-00295862c013bede0"
  instance_type = "t2.micro"
  key_name      = data.aws_key_pair.EC2-Key.key_name
  depends_on    = [aws_network_interface.NAT_ENI]

  network_interface {
    network_interface_id = aws_network_interface.NAT_ENI.id
    device_index         = 0
  }

  tags = {
    Name = "NAT_Instance"
  }
}

# Private Subnet Routing Table ( dest: NAT Instance ENI )
data "aws_route_table" "private_1" {
  subnet_id  = module.vpc.private_subnets[0]
  depends_on = [module.vpc]
}

data "aws_route_table" "private_2" {
  subnet_id  = module.vpc.private_subnets[1]
  depends_on = [module.vpc]
}

resource "aws_route" "private_subnet_1" {
  route_table_id         = data.aws_route_table.private_1.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_network_interface.NAT_ENI.id
  depends_on             = [module.vpc, aws_instance.NAT_Instance]
}

resource "aws_route" "private_subnet_2" {
  route_table_id         = data.aws_route_table.private_2.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_network_interface.NAT_ENI.id
  depends_on             = [module.vpc, aws_instance.NAT_Instance]
}

# ================================================================
# ================================================================
# ================================================================

# Terraform EKS Module DOCS : https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.31.0"

  # EKS Cluster Setting
  cluster_name                    = local.cluster_name
  cluster_version                 = local.cluster_version
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets

  # IRSA(IAM Role for Service Account) Enable / OIDC(OpenID Connect) 구성
  # EKS Cluster 내부의 Object에 IAM Role을 부여 ( Pod 혹은 Namespace 영역별 권한 부여를 다르게 설정 )
  # https://aws.amazon.com/ko/blogs/containers/diving-into-iam-roles-for-service-accounts/
  enable_irsa = true

  # Karpenter ( Cluster Auto-Scaling ) Security Group Policy 
  node_security_group_additional_rules = {
    ingress_nodes_karpenter_port = {
      description                   = "Cluster API to Node group for Karpenter webhook"
      protocol                      = "tcp"
      from_port                     = 8443
      to_port                       = 8443
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  # Karpenter ( Cluster Auto-Scaling ) Security Group TAG
  node_security_group_tags = {
    "karpenter.sh/discovery" = local.cluster_name
  }

  eks_managed_node_groups = {
    initial = {
      instance_types         = ["t3.large"]
      create_security_group  = false
      create_launch_template = false # do not remove
      launch_template_name   = ""    # do not remove

      min_size     = 2
      max_size     = 3
      desired_size = 2

      # Karpenter에서 사용 할 IAM Role 권한 추가
      iam_role_additional_policies = [
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      ]
    }
  }

  # EKS configmap Resource의 "aws-auth" Object에서 IAM User 혹은 Role을 등록하여 관리하는 작업을 허용 ( RBAC 작업 )
  manage_aws_auth_configmap = true

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::${local.cluster_admin}:user/admin"
      username = "admin"
      groups   = ["system:masters"]
    },
  ]

  aws_auth_accounts = [
    "${local.cluster_admin}"
  ]
  depends_on = [module.vpc]
}

# ================================================================
# ================================================================
# ================================================================

# Private_Subnet Tag
resource "aws_ec2_tag" "private_subnet_tag" {
  for_each    = toset(module.vpc.private_subnets)
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
  depends_on  = [module.vpc]
}

resource "aws_ec2_tag" "private_subnet_cluster_tag" {
  for_each    = toset(module.vpc.private_subnets)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.cluster_name}"
  value       = "owned"
  depends_on  = [module.vpc]
}

resource "aws_ec2_tag" "private_subnet_karpenter_tag" {
  for_each    = toset(module.vpc.private_subnets)
  resource_id = each.value
  key         = "karpenter.sh/discovery/${local.cluster_name}"
  value       = local.cluster_name
  depends_on  = [module.vpc]
}

# Public_Subnet Tag
resource "aws_ec2_tag" "public_subnet_tag" {
  for_each    = toset(module.vpc.public_subnets)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
  depends_on  = [module.vpc]
}

# ================================================================
# ================================================================
# ================================================================


