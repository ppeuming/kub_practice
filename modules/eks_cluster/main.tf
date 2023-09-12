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
  vpc_id                          = local.vpc_id
  subnet_ids                      = local.private_subnets

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
      userarn  = "arn:aws:iam::${var.account_id}:user/admin"
      username = "admin"
      groups   = ["system:masters"]
    },
  ]

  aws_auth_accounts = [
    "${var.account_id}"
  ]
}

# ================================================================
# ================================================================
# ================================================================

# Private_Subnet Tag
resource "aws_ec2_tag" "private_subnet_tag" {
  for_each    = toset(local.private_subnets)
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_ec2_tag" "private_subnet_cluster_tag" {
  for_each    = toset(local.private_subnets)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.cluster_name}"
  value       = "owned"
}

resource "aws_ec2_tag" "private_subnet_karpenter_tag" {
  for_each    = toset(local.private_subnets)
  resource_id = each.value
  key         = "karpenter.sh/discovery/${local.cluster_name}"
  value       = local.cluster_name
}

# Public_Subnet Tag
resource "aws_ec2_tag" "public_subnet_tag" {
  for_each    = toset(local.public_subnets)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

# ================================================================
# ================================================================
# ================================================================
