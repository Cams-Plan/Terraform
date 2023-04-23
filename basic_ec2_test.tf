terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region     = "us-east-1"
  access_key = <"your access key ID">
  secret_key = <"your secret key">
}

resource "aws_instance" "firt-tf-server" {
  ami           = "ami-02396cdd13e9a1257"
  instance_type = "t2.micro"
  tags = {
    # "significance" = "test"
  }
}


### this is only a basic test. typical deployments utilised a secure config
