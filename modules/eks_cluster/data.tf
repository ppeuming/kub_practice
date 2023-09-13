# AWS KEY-Pair Data Source
data "aws_key_pair" "EC2-Key" {
  key_name = "EC2-key"
}

# AWS EKS Cluster ID Data Source
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

# AWS EKS Cluster Auth Data Source
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

