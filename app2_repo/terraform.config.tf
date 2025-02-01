terraform {
  cloud {

    organization = "<org>"

    workspaces {
      name = "<workspace_name>"
    }
  }
}

provider "aws" {
  region = var.region
}
