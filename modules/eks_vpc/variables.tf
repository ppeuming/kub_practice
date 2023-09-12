locals {
  any_port            = 0
  any_protocol        = "-1"
  tcp_protocol        = "tcp"
  icmp_protocol       = "icmp"
  all_network         = "0.0.0.0/0"
}

variable "cidr" {
  description = "VPC CIDR BLOCK"
  type        = string
}

variable "azs" {
  description = "azs"
  type        = list
}

variable "public_subnets" {
  description = "VPC Public Subnets"
  type        = list
}

variable "private_subnets" {
  description = "VPC Private Subnets"
  type        = list
}



