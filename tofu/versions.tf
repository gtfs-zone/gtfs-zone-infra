# State lives in the private B2 bucket gtfs-zone-tfstate through the S3 backend.
# Credentials come from the environment (see tofu.sh): AWS_* for the backend,
# CLOUDFLARE_API_TOKEN for cloudflare.
terraform {
  required_version = ">= 1.8"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.28"
    }
  }

  backend "s3" {
    bucket = "gtfs-zone-tfstate"
    key    = "edge.tfstate"
    region = "us-east-005"
    endpoints = {
      s3 = "https://s3.us-east-005.backblazeb2.com"
    }
    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}

provider "cloudflare" {}
