# aws-powerbi-gateway

Creates a Windows EC2 instance running the [Microsoft on-premises data gateway](https://learn.microsoft.com/en-us/data-integration/gateway/) so Power BI can query databases in a private AWS network.

## What it creates

- Windows Server 2022 EC2 instance (`t3.xlarge` default) in a private subnet, no public IP, no ingress.
- Egress-only security group: 443, plus 5671-5672/9350-9354 for Azure Relay direct TCP (disable with `force_https_mode`).
- Boot script imports the RDS CA bundle into the trusted root store, materializes app env vars/secrets as machine environment variables, and installs the gateway. Bootstrap log: `C:\ProgramData\nullstone\bootstrap.log`.

Database access is granted by attaching a capability (e.g. `aws-postgres-access`) — it opens the database's security group to this app and injects connection env vars.

The network must provide NAT egress; the gateway requires an always-on outbound internet connection.

## Registration

Unattended: set `tenant_id`, `application_id`, `client_secret`, and `recovery_key` — the gateway registers itself at first boot using a Microsoft Entra service principal. Secrets are stored in AWS Secrets Manager and loaded by the init script, never embedded in user data. If any of the four is blank, registration is skipped.

Manual: RDP in via SSM port forwarding using the `admin_username`/`admin_password` outputs, run the staged installer at `C:\ProgramData\nullstone\GatewayInstall.exe`, and register interactively.

Keep the recovery key — it is required to restore the gateway or add cluster members.

## Remote access

The instance has no public IP and no ingress rules; access is through AWS Session Manager (no VPN or security group changes needed).
Module outputs are shown under the app's **Outputs** in the Nullstone UI.

Requires the AWS CLI with the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html).
Choose one: a shell session, or an RDP tunnel — connect any RDP client to `localhost:13389` using the `admin_username`/`admin_password` outputs (`admin_password` requires `--sensitive`, or view it in the Nullstone UI).

bash:

```bash
INSTANCE_ID=$(nullstone outputs --stack=<stack> --block=<app> --env=<env> --field=instance_id)

# Option 1: shell session
aws ssm start-session --target $INSTANCE_ID

# Option 2: RDP tunnel (then connect an RDP client to localhost:13389)
aws ssm start-session --target $INSTANCE_ID --document-name AWS-StartPortForwardingSession --parameters "portNumber=3389,localPortNumber=13389"
```

PowerShell:

```powershell
$instanceId = nullstone outputs --stack=<stack> --block=<app> --env=<env> --field=instance_id

# Option 1: shell session
aws ssm start-session --target $instanceId

# Option 2: RDP tunnel (then connect an RDP client to localhost:13389)
aws ssm start-session --target $instanceId --document-name AWS-StartPortForwardingSession --parameters "portNumber=3389,localPortNumber=13389"
```

RDP works from any OS:

- **Windows**: [Remote Desktop Connection](https://support.microsoft.com/en-us/windows/how-to-use-remote-desktop-5fe128d5-8fb1-7a23-3b8a-41e636865e8c) (`mstsc`, built in)
- **macOS**: [Windows App](https://apps.apple.com/us/app/windows-app/id1295203466) (formerly Microsoft Remote Desktop)
- **Linux**: [Remmina](https://remmina.org/) or [FreeRDP](https://www.freerdp.com/) (`xfreerdp /v:localhost:13389 /u:Administrator`)

A freshly launched instance takes ~10 minutes to boot Windows and register with SSM; `start-session` fails with `TargetNotConnected` until then. Retry after a few minutes.
If the instance still doesn't appear in Session Manager well after launch, the subnet has no NAT egress — the SSM agent can't reach AWS.

## Limitations

- The gateway does not self-update; Microsoft ships monthly releases. Update by rerunning the installer on the instance.
- Single instance; no gateway cluster HA.
