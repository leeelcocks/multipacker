#init packer with the required plugins - AMI management is optional
packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.1"
      source  = "github.com/hashicorp/amazon"
    }
    amazon-ami-management = {
      version = ">= 1.0.0"
      source  = "github.com/wata727/amazon-ami-management"
    }
  }
}

#declare all your vars - same as terraform

variable "aws_access_key" {
  type    = string
  default = "${env("AWS_ACCESS_KEY_ID")}"
}

variable "aws_secret_key" {
  type    = string
  default = "${env("AWS_SECRET_ACCESS_KEY")}"
}

variable "aws_region" {
  type    = string
  default = "${env("AWS_DEFAULT_REGION")}"
}

variable "vpc" {
  type    = string
  default = "vpc-8bb4aaed"
}

variable "subnet" {
  type    = string
  default = "subnet-ffc155a5"
}

#do a datapull from AWS below we are finding the latest base image from amazon, a good way to find the
#correct name of the ami to search for is by running a one off aws cli command i.e
#aws ec2 describe-images --image-ids ami-0d1bf5b68307103c2

data "amazon-ami" "linux" {
  filters = {
    name                = "amzn2-ami-hvm-2.*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["amazon"]
  region      = "${var.aws_region}"
}

#declr a local var, only used in this source block.

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

#configure your source AMI

source "amazon-ebs" "linux" {
  ami_name          = "lee-ami-${local.timestamp}"
  ami_users         = [273539952517]
  communicator      = "ssh"
  instance_type     = "t2.micro"
  region            = "${var.aws_region}"
  source_ami        = "${data.amazon-ami.linux.id}"
  ssh_username      = "ec2-user"
  subnet_id         = var.subnet
  vpc_id            = var.vpc
  tags = {
      Name = "Lee"
  }
}

#now configure another source AZURE in this case.

source "azure-arm" "ubuntu" {
  client_id                         = "XXXX"
  client_secret                     = "XXXX"
  managed_image_resource_group_name = "packer_images"
  managed_image_name                = "packer-ubuntu-azure-{{timestamp}}"
  subscription_id                   = "XXXX"
  tenant_id                         = "XXXX"

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "UbuntuServer"
  image_sku       = "16.04-LTS"

  azure_tags = {
    Created-by = "Packer"
    OS_Version = "Ubuntu 16.04"
    Release    = "Latest"
  }

  location = "East US"
  vm_size  = "Standard_A2"
}

#now i can use the same build block, as i want EXACTLY The same stuff on both the azure and AWS AMI's

build {
  sources = ["source.amazon-ebs.linux", "source.azure-arm.ubuntu",]

  provisioner "shell" {
    inline = ["sudo amazon-linux-extras install ansible2"]
}

  provisioner "ansible-local" {
    playbook_file   = "./ansible/playbook.yaml"
  }
}

#But wait - what if youm want aws cli on aws and azure cli on the other  - no problem
#you can do this.

   provisioner "shell" {
    only = ["source.amazon-ebs.linux"]
    inline = ["sudo yum install awscli"]
  }

  provisioner "shell" {
    only = ["source.azure-arm.ubuntu"]
    inline = ["sudo apt-get install azure-cli"]
  }
