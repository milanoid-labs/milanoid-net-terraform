terraform {

  required_version = "~> 1.12"

  backend "s3" {
    bucket       = "milanoid-labs-terraform-tofu-state"
    key          = "milanoid-net-terraform/terraform.tfstate"
    use_lockfile = true
    region       = "eu-central-1"
    # profile      = "milanoid" # uncomment this if running locally, or rather run 'export AWS_PROFILE=milanoid'
    encrypt = true # to make it explicit, S3 default encryption is enabled in AWS
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
}


variable "cloudflare_api_token" {
  type = string
}


provider "cloudflare" {
  api_token = var.cloudflare_api_token
}



data "cloudflare_account_dns_settings" "example_account_dns_settings" {
  account_id = "291411295d77f61bd1a1b00993b3a9b8" # not sensitive, same as username
}

output "test" {
  value = data.cloudflare_account_dns_settings.example_account_dns_settings
}


