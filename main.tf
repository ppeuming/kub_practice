# ================================================================
# ================================================================
# ================================================================

# Terraform 초기구성
terraform {
  backend "s3" {
    bucket         = "myterraform-bucket-state-choi-t"
    key            = "aws_eks/terraform.tfstate"
    region         = "ap-northeast-2"
    profile        = "admin_user"
    dynamodb_table = "myTerraform-bucket-lock-choi-t"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "ap-northeast-2"
  profile = "admin_user"
}

# ================================================================
# ================================================================
# ================================================================

# AWS EKS VPC 
module "aws_eks_vpc" {
  source          = "./modules/eks_vpc"
  cidr            = "192.168.0.0/16"
  azs             = ["ap-northeast-2a", "ap-northeast-2c"]
  public_subnets  = ["192.168.1.0/24", "192.168.2.0/24"]
  private_subnets = ["192.168.10.0/24", "192.168.20.0/24"]
}

# ================================================================
# ================================================================
# ================================================================

# AWS EKS Cluster
module "aws_eks_cluster" {
  source          = "./modules/eks_cluster"
  cluster_name    = "my-eks"
  cluster_version = "1.24"
  account_id      = data.aws_iam_user.EKS_Admin_ID.user_id
  vpc_id          = data.terraform_remote_state.remote_data.outputs.vpc_id
  public_subnets  = data.terraform_remote_state.remote_data.outputs.public_subnets
  private_subnets = data.terraform_remote_state.remote_data.outputs.private_subnets
}

# ================================================================
# ================================================================
# ================================================================






