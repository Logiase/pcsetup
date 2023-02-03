param (
    [switch]$InstallOpenSSHServer = $false,
    [switch]$InstallWSL = $false
)

$InformationPreference = "Continue"

function Enable-ScoopBucket {
    param (
        [string] $Bucket
    )

    Write-Information "Enabling scoop bucket $Bucket"
    scoop bucket add $Bucket
}

function Install-ScoopApps {
    param (
        [string[]] $Apps
    )

    Write-Information "Updating scoop..."
    scoop update

    Write-Information "Installing Apps $Apps..."
    scoop install $Apps
}

function Install-WingetApp {
    param (
        [string]$PackageID
    )

    Write-Information -Message "Installing Apps $PackageID"
    winget install --silent --id "$PackageID" --accept-source-agreements --accept-package-agreements
}

Write-Information "Starting PC setup script..."
Write-Information "Setting PowerShell Execution Policy to RemoteSigned..."
if ((Get-ExecutionPolicy -Scope CurrentUser) -notcontains "RemoteSigned") {
    Start-Process -FilePath "PowerShell" -ArgumentList "Set-ExecutionPolicy", "RemoteSigned", "-Scope", "CurrentUser" -Verb RunAs -Wait
    Write-Output "Need to restart/re-run to refresh Execution Policy"
    Start-Sleep -Seconds 10
    Break
}
else {
    Write-Information "Execution Policy alread set to RemoteSigned, skipping."
}

Write-Information "Installing OpenSSH..."
if ((Get-WindowsCapability -Online -Name 'OpenSSH.Client*').State -ne "Installed") {
    Write-Information "Installing OpenSSH.Client..."
    $Name = (Get-WindowsCapability -Online -Name 'OpenSSH.Client*').Name
    Add-WindowsCapability -Online -Name $Name
}
else {
    Write-Information "OpenSSH.Client Already Installed, skipping."
}
if ($InstallOpenSSHServer) {
    if ((Get-WindowsCapability -Online -Name 'OpenSSH.Server*').State -ne "Installed") {
        Write-Information "Installing OpenSSH.Server..."
        $Name = (Get-WindowsCapability -Online -Name 'OpenSSH.Server*').Name
        Add-WindowsCapability -Online -Name $Name

        Write-Information "Starting OpenSSH.Server..."
        if (!(Get-Service -Name 'sshd' -ErrorAction)) {
            Write-Information "Service sshd not found!!!"
        }
        else {
            if ((Get-Service -Name 'sshd').Status -ne "Running") {
                Write-Information "Starting Service sshd..."
                Start-Service sshd
            }
            else {
                Write-Information "Service sshd already started."
            }

            Set-Service -Name sshd -StartupType Automatic

            Write-Information "Checking sshd firewall rule..."
            if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) {
                Write-Information "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..."
                New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
            }
            else {
                Write-Information "Firewall rule 'OpenSSH-Server-In-TCP' has been created and exists."
            }
        }
    }
    else {
        Write-Information "OpenSSH.Server Already Installed, skipping."
    }
}

if (!(Get-Command -Name 'scoop' -ErrorAction SilentlyContinue)) {
    Write-Information 'Installing scoop...'
    irm get.scoop.sh | iex
}

Write-Information 'Installing refreshenv and git first...'
Install-ScoopApps -Apps refreshenv, git
Start-Sleep -Seconds 5
refreshenv
Start-Sleep -Seconds 5

Write-Information "Configuring git..."
if (!$(git config --global credential.helper) -eq "manager-core") {
    git config --global credential.help manager-core
}
if (!($env:GIT_SSH)) {
    Write-Information "Setting GIT_SSH User Environment Variable."
    [System.Environment]::SetEnvironmentVariable('GIT_SSH', (Resolve-Path (scoop which ssh)), 'USER')
}

Write-Information "Using aria2 for scoop..."
Install-ScoopApps -Apps aria2
if (!$(scoop config aria2-enabled) -eq $true) {
    scoop config aria2-enabled true
}
if (!$(scoop config aria2-warning-enabled) -eq $false) {
    scoop config aria2-warning-enabled false
}

Enable-ScoopBucket -Bucket "extras"

winget install Microsoft.VisualStudioCode --override '/SILENT /mergetasks="!runcode,addcontextmenufiles,addcontextmenufolders"'

if ($InstallWSL) {
    Write-Information "Installing WSL..."
    wsl --install --no-distribution

}
