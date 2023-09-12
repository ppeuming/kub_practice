locals {
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  region          = "ap-northeast-2"
  vpc_id          = var.vpc_id
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  tag = {
    Environment = "test"
    Terraform   = "true"
  }
}

variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
}

variable "cluster_version" {
  description = "EKS Cluster Version"
  type        = string
}

variable "account_id" {
  description = "IAM User Account ID"
  type        = string
}

variable "vpc_id" {
  description = "EKS VPC_ID"
  type        = string
}

variable "public_subnets" {
  description = "EKS VPC Public Subnets"
  type        = list(any)
}

variable "private_subnets" {
  description = "EKS VPC Public Subnets"
  type        = list(any)
}

