data "aws_ami" "this" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "platform"
    values = ["windows"]
  }
}

locals {
  ami = var.ami == "" ? data.aws_ami.this.id : var.ami
}
