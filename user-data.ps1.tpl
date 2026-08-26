<powershell>
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path "C:\ProgramData\nullstone" | Out-Null
Start-Transcript -Path "C:\ProgramData\nullstone\bootstrap.log" -Append
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Import-Module AWSPowerShell

# Materialize app env vars; secrets are loaded from AWS Secrets Manager, never embedded in user data
%{ for name, value in env_vars ~}
[Environment]::SetEnvironmentVariable('${name}', '${replace(value, "'", "''")}', 'Machine')
%{ endfor ~}
%{ for name, secret_id in secret_ids ~}
[Environment]::SetEnvironmentVariable('${name}', (Get-SECSecretValue -SecretId '${secret_id}').SecretString, 'Machine')
%{ endfor ~}

# Trust the RDS certificate authorities so TLS connections to RDS verify
$bundle = "C:\ProgramData\nullstone\rds-global-bundle.pem"
Invoke-WebRequest -Uri "https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem" -OutFile $bundle
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
$store.Open("ReadWrite")
foreach ($match in [regex]::Matches((Get-Content $bundle -Raw), "(?s)-----BEGIN CERTIFICATE-----(.*?)-----END CERTIFICATE-----")) {
  $bytes = [Convert]::FromBase64String(($match.Groups[1].Value -replace "\s", ""))
  $store.Add((New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(,$bytes)))
}
$store.Close()

# The DataGateway PowerShell module requires PowerShell 7
$ps7 = "C:\ProgramData\nullstone\PowerShell-7.msi"
Invoke-WebRequest -Uri "https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.msi" -OutFile $ps7
Start-Process msiexec.exe -ArgumentList "/i", $ps7, "/quiet", "/norestart" -Wait

$gatewayScript = "C:\ProgramData\nullstone\install-gateway.ps1"
@'
$ErrorActionPreference = "Stop"
%{ if auto_register ~}
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name DataGateway -Force
# Install-DataGateway refuses to run without a service-principal login
$clientSecret = ConvertTo-SecureString $env:NS_CLIENT_SECRET -AsPlainText -Force
$recoveryKey  = ConvertTo-SecureString $env:NS_RECOVERY_KEY -AsPlainText -Force
Connect-DataGatewayServiceAccount -ApplicationId "${application_id}" -ClientSecret $clientSecret -Tenant "${tenant_id}"
Install-DataGateway -AcceptConditions
Add-DataGatewayCluster -Name "${gateway_name}" -RecoveryKey $recoveryKey%{ if gateway_region != "" } -RegionKey "${gateway_region}"%{ endif }
%{ else ~}
# Without a service principal, the DataGateway module cannot install unattended;
# stage the interactive installer for manual install/registration over RDP.
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?LinkId=2116849" -OutFile "C:\ProgramData\nullstone\GatewayInstall.exe"
%{ endif ~}
'@ | Set-Content -Path $gatewayScript -Encoding UTF8

%{ if auto_register ~}
$env:NS_CLIENT_SECRET = (Get-SECSecretValue -SecretId "${client_secret_id}").SecretString
$env:NS_RECOVERY_KEY = (Get-SECSecretValue -SecretId "${recovery_key_id}").SecretString
%{ endif ~}

# Transcripts miss native child output and a non-zero exit doesn't throw; capture and check explicitly
& "C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -ExecutionPolicy Bypass -File $gatewayScript *> "C:\ProgramData\nullstone\install-gateway.log"
$gatewayExitCode = $LASTEXITCODE
$env:NS_CLIENT_SECRET = ""
$env:NS_RECOVERY_KEY = ""
if ($gatewayExitCode -ne 0) {
  throw "install-gateway.ps1 failed with exit code $gatewayExitCode; see C:\ProgramData\nullstone\install-gateway.log"
}

Stop-Transcript
</powershell>
