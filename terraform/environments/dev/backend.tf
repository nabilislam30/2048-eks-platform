terraform {
  backend "s3" {
    bucket       = "2048-eks-platform-terraform-state-2026"
    key          = "dev/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}