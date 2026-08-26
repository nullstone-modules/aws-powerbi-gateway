resource "aws_iam_instance_profile" "this" {
  name = local.resource_name
  role = aws_iam_role.this.name
}

// Key pair used solely to decrypt the Windows Administrator password
// for manual gateway registration over RDP (via SSM port forwarding).
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = local.resource_name
  public_key = tls_private_key.this.public_key_openssh
  tags       = local.tags
}

resource "aws_instance" "this" {
  ami                         = local.ami
  instance_type               = var.instance_type
  subnet_id                   = local.private_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.this.id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.this.name
  key_name                    = aws_key_pair.this.key_name
  get_password_data           = true
  disable_api_termination     = false
  monitoring                  = false
  user_data                   = local.user_data
  tags                        = merge(local.tags, { Name = local.resource_name })

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
  }
}
