output "vpc_id" {
  value       = module.aws_eks_vpc.vpc_id
  description = "VPC Module ID"
}

output "public_subnets" {
  value       = module.aws_eks_vpc.public_subnets
  description = "Stage Public Subnet Out List"
}

output "private_subnets" {
  value       = module.aws_eks_vpc.private_subnets
  description = "Stage Private Subnet Out List"
}


