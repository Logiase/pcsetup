param (
    [switch] $InstallOpenSSHServer = $false,
    [switch] $InstallWSL = $false
)

function Update-Scoop {
    Write-Host "Update Scoop"
    scoop update
}

function Enable-ScoopBucket {
    param ( [string] $Bucket )

    Write-Host "Enable Scoop Bucket $Bucket"
    scoop bucket add $Bucket
}

function Install-ScoopApps {
    param ( [string[]] $Apps )

    Write-Host "Install Scoop Apps $Apps"
    scoop install $Apps
}

function Update-WinGet {
    Write-Host "Update WinGet"
    winget source update
}

function Install-WinGetApps {
    param ( [string[]] $Apps )

    Write-Host "Install WinGet Apps $Apps"
    $Packages = @()
    foreach ($App in $Apps) {
        $Packages += @{PackageIdentifier = $App }
    }
    $Source = winget source export winget | ConvertFrom-Json
    $Argument = $Source.Arg
    $Source.PSObject.Properties.Remove('Data')
    $Source.PSObject.Properties.Remove('Arg')
    $Source | Add-Member -MemberType NoteProperty -Name Argument -Value $Argument
    $JsonStr = @{"`$schema" = "https://aka.ms/winget-packages.schema.2.0.json"; Sources = @(@{Packages = $Packages ; SourceDetails = $Source }) } | ConvertTo-Json -Depth 5
    $JsonStr > $env:TEMP\wingetapps.json

    winget import $env:TEMP\wingetapps.json
    Remove-Item -Path $env:TEMP\wingetapps.json -Force
}

function Install-OpenSSH {
    param ( [bool] $InstallServer = $false)

    Write-Host "Installing OpenSSH Client"
    if ($InstallServer) {
        Write-Host "Installing OpenSSH Server"
    }

    @"
function InstallClient {
    `$OpenSSHClient = Get-WindowsCapability -Online -Name OpenSSH.Client*
    if (`$OpenSSHClient.State -ne 'Installed') {
        Add-WindowsCapability -Online -Name `$OpenSSHClient.Name
    }
}

function InstallServer {
    `$OpenSSHServer = Get-WindowsCapability -Online -Name OpenSSH.Server*
    if (`$OpenSSHServer.State -ne 'Installed') {
        Add-WindowsCapability -Online -Name `$OpenSSHServer.Name
    }

    `$SSHDService = Get-Service -Name sshd -ErrorAction Break
    if (`$SSHDService.Status -ne 'Running') {
        Start-Service sshd
    }
    Set-Service -Name sshd -StartupType Automatic

    if (!(Get-FirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentContinue | Select-Object Name, Enabled)) {
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
    }
}

InstallClient
if ($InstallServer) { InstallServer }

"@ > $env:TEMP/install_openssh.ps1
    Start-Process -FilePath 'powershell' -ArgumentList $env:TEMP/install_openssh_client.ps1 -Verb RunAs -Wait -WindowStyle Hidden
    Remove-Item -Path $env:TEMP/install_openssh.ps1 -Force
}

function Install-Scoop {
    Invoke-RestMethod get.scoop.sh | Invoke-Expression
}

function Install-WSL {
    Start-Process -FilePath powershell -ArgumentList 'wsl', '--install', '--no-distribution' -Verb RunAs -Wait -WindowStyle Hidden
    Scoop-InstallApps -Apps archwsl
}

Write-Host 'Starting PC setup script'

if ((Get-ExecutionPolicy -Scope CurrentUser) -ne 'RemoteSigned') {
    Write-Host 'Set PowerShell Execution Policy to RemoteSigned'
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
}

Install-OpenSSH -InstallServer $InstallOpenSSHServer
if (!(Get-Command -Name 'scoop' -ErrorAction SilentlyContinue)) {
    Write-Host 'Installing Scoop'
    Install-Scoop
}
else {
    Write-Host "Scoop already installed"
}

Install-ScoopApps -Apps git
Enable-ScoopBucket -Bucket "extras"
Update-Scoop
Install-ScoopApps -Apps refreshenv
refreshenv

Write-Host 'Confiurating git'
if (!$(git config --global credential.helper) -eq "manager-core") {
    git config --global credential.help manager-core
}
if (!($env:GIT_SSH)) {
    Write-Information "Setting GIT_SSH User Environment Variable."
    [System.Environment]::SetEnvironmentVariable('GIT_SSH', (Resolve-Path (scoop which ssh)), 'USER')
}

Write-Host 'Use aria2 for scoop'
Install-ScoopApps -Apps aria2
if (!$(scoop config aria2-enabled) -eq $true) {
    scoop config aria2-enabled true
}
if (!$(scoop config aria2-warning-enabled) -eq $false) {
    scoop config aria2-warning-enabled false
}

$ScoopApps = @(
    'curl',
    'python',
    'neovim',
    'sudo',
    'busybox'
)
Install-ScoopApps -Apps $ScoopApps

Update-WinGet
$WinGetApps = @(
    'Microsoft.DotNet.DesktopRuntime.3_1',
    'Microsoft.DotNet.DesktopRuntime.5',
    'Microsoft.DotNet.DesktopRuntime.6',
    'Microsoft.DotNet.DesktopRuntime.7',
    'Microsoft.WindowsTerminal',
    'Microsoft.PowerToys',
    'Microsoft.PowerShell',
    'Microsoft.Teams',

    'Google.Chrome',

    'SomePythonThings.WingetUIStore',
    
    'Fndroid.ClashForWindows',
    'ZeroTier.ZeroTierOne'
)
Install-WinGetApps -Apps $WinGetApps

Write-Host 'Installing VSCode'
winget install Microsoft.VisualStudioCode --override '/SILENT /mergetasks="!runcode,addcontextmenufiles,addcontextmenufolders"'

if ($InstallWSL -and (Get-Command -Name 'wsl')) {
    Write-Information "Installing WSL..."
    
    Install-WSL
}
