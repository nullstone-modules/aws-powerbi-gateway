variable "ami" {
  type        = string
  default     = ""
  description = <<EOF
By default, this module will choose the latest official Windows Server 2022 (English, Full) image.
Specify `ami` to select an alternative AMI.

The gateway requires Windows Server 2019+ with .NET 4.8.
Make sure the selected AMI has Amazon SSM Agent installed to enable remote access.
EOF
}

variable "instance_type" {
  type        = string
  default     = "t3.xlarge"
  description = <<EOF
Instance Type that dictates CPU, Memory, network bandwidth, and file storage type and bandwidth.
Microsoft recommends 8 GB memory and 8 cores for a production gateway.
See https://aws.amazon.com/ec2/instance-types/ for EC2 instance types.
EOF
}

variable "root_volume_size" {
  type        = number
  default     = 100
  description = "Size (GiB) of the root volume. Gateway spooling uses local disk; keep headroom above the ~30 GiB Windows base."
}

variable "gateway_name" {
  type        = string
  default     = ""
  description = "Name of the gateway cluster registered with the Power BI service. Defaults to the Nullstone block name."
}

variable "tenant_id" {
  type        = string
  default     = ""
  description = "Microsoft Entra tenant ID used for unattended gateway registration. Leave blank to register manually over RDP."
}

variable "application_id" {
  type        = string
  default     = ""
  description = "Microsoft Entra application (service principal) ID used for unattended gateway registration."
}

variable "client_secret" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Client secret for the Microsoft Entra application used for unattended gateway registration."
}

variable "recovery_key" {
  type        = string
  default     = ""
  sensitive   = true
  description = <<EOF
Recovery key for the gateway cluster.
Required for unattended registration; needed again to restore the gateway or add cluster members.
EOF
}

variable "gateway_region" {
  type        = string
  default     = ""
  description = "Power BI region key for the gateway (e.g. `westus2`). Leave blank to use the tenant's default region."
}

variable "force_https_mode" {
  type        = bool
  default     = false
  description = <<EOF
When true, only HTTPS (443) egress is opened and the gateway relies on HTTPS mode to reach Azure Relay.
When false, direct TCP ports 5671-5672 and 9350-9354 are also opened for better throughput.
EOF
}

locals {
  gateway_name = coalesce(var.gateway_name, local.block_name)

  auto_register = alltrue([
    var.tenant_id != "",
    var.application_id != "",
    var.client_secret != "",
    var.recovery_key != "",
  ])
}
