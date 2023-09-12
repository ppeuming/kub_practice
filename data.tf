data "terraform_remote_state" "remote_data" {
  backend = "s3"
  config = {
    bucket  = "myterraform-bucket-state-choi-t"
    key     = "aws_eks/terraform.tfstate"
    profile = "admin_user"
    region  = "ap-northeast-2"
  }
}

data "aws_iam_user" "EKS_Admin_ID" {
  user_name = "admin"
}
