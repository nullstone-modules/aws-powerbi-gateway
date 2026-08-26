resource "aws_security_group" "this" {
  name   = local.resource_name
  vpc_id = local.vpc_id
  tags   = merge(local.tags, { Name = local.resource_name })
}

// HTTPS egress is required for:
//   - the Power BI service and Azure Relay (HTTPS mode)
//   - Amazon SSM (remote access)
//   - downloading the gateway installer and RDS certificate bundle
resource "aws_security_group_rule" "this-https-to-world" {
  security_group_id = aws_security_group.this.id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = ["0.0.0.0/0"]
}

// Direct TCP to Azure Relay performs better than HTTPS mode.
// See https://learn.microsoft.com/en-us/data-integration/gateway/service-gateway-communication
resource "aws_security_group_rule" "this-amqp-to-world" {
  count = var.force_https_mode ? 0 : 1

  security_group_id = aws_security_group.this.id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 5671
  to_port           = 5672
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "this-relay-to-world" {
  count = var.force_https_mode ? 0 : 1

  security_group_id = aws_security_group.this.id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 9350
  to_port           = 9354
  cidr_blocks       = ["0.0.0.0/0"]
}
