$VerbosePreference = "Continue"

function Install-ScoopApp {
    param (
        [string]$Package
    )

    Write-Verbose -Message "Preparing to install $Package"
    if (!(scoop info $Package).Installed) {
        Write-Verbose -Message "Installing $Package"
        scoop install $Package
    }
    else {
        Write-Verbose -Message "Package $Package already installed! Skipping..."
    }
}

function Enable-ScoopBucket {
    param (
        [string]$Bucket
    )

    if (!($(scoop bucket list).Name -eq "$Bucket")) {
        Write-Verbose -Message "Adding Bucket $Bucket to scoop..."
        scoop bucket add $Bucket
    }
    else {
        Write-Verbose -Message "Bucket $Bucket already added! Skipping..."
    }
}

function Install-WingetApp {
    param (
        [string]$PackageID
    )

    Write-Verbose -Message "Preparing to install $Package"
    Write-Verbose -Message "Installing $PackageID"
    winget install --silent --id "$PackageID" --accept-source-agreements --accept-package-agreements
}

if ((Get-ExecutionPolicy -Scope CurrentUser) -notcontains "RemoteSigned") {
    Write-Verbose -Message "Setting Execution Policy for Current User..."
    Start-Process -FilePath "PowerShell" -ArgumentList "Set-ExecutionPolicy", "RemoteSigned", "-Scope", "CurrentUser" -Verb RunAs -Wait
    Write-Output "Restart/Re-Run script!!!"
    Start-Sleep -Seconds 10
    Break
}

# Install Scoop
if (!(Get-Command -Name "scoop" -CommandType Application -ErrorAction SilentlyContinue)) {
    Write-Verbose -Message "Installing Scoop..."
    irm get.scoop.sh | iex
}

# Install Winget

# Install OpenSSH.Client on Windows 10+
@'
if ((Get-WindowsCapability -Online -Name OpenSSH.Client*).State -ne "Installed) {
    Add-WindowsCapability -Online -Name OpenSSH.Client*
}
'@ > "${Env:Temp}\openssh.ps1"
Start-Process -FilePath "PowerShell" -ArgumentList "${Env:Temp}\openssh.ps1" -Verb RunAs -Wait -WindowStyle Hidden
Remove-Item -Path "${Env:Temp}\openssh.ps1" -Force

# refreshenv
Install-ScoopApp -Package refreshenv

# Configure git
Install-ScoopApp -Package git
Start-Sleep -Seconds 5
refreshenv
Start-Sleep -Seconds 5
if (!$(git config --global credential.helper) -eq "manager-core") {
    git config --global credential.helper manager-core
}
if (!($Env:GIT_SSH)) {
    Write-Verbose -Message "Setting GIT_SSH User Environment Variable"
    [System.Environment]::SetEnvironmentVariable('GIT_SSH', (Resolve-Path (scoop which ssh)), 'USER')
}
if ((Get-Service -Name ssh-agent).Status -ne "Running") {
    Start-Process -FilePath "PowerShell" -ArgumentList "Set-Service", "ssh-agent", "-StartupType", "Manual" -Verb RunAs -Wait -WindowStyle Hidden 
}

# Configure Aria2 Download Manager
Install-ScoopApp -Package aria2
if (!$(scoop config aria2-enabled) -eq $true) {
    scoop config aria2-enabled true
}
if (!$(scoop config aria2-warning-enabled) -eq $false) {
    scoop config aria2-warning-enabled false
}

Enable-ScoopBucket -Bucket "extras"
Enable-ScoopBucket -Bucket "nerd-fonts"

# UNIX Tools
Write-Verbose -Message "Removing curl Alias..."
if (Get-Alias -Name curl -ErrorAction SilentlyContinue) {
    Remove-Item Alias::curl
}
if (!($Env:TERM)) {
    Write-Verbose -Message "Setting TERM User Environment Variable"
    [System.Environment]::SetEnvironmentVariable("TERM", "xterm-256color", "USER")
}

$ScoopApps = @(
    # "curl"
    "busybox",
    "cacert",
    "sudo",
    
    "python",
    "go",
    # "nodejs-lts"
    
    # "ffmpeg",
    # "obs-studio"
    # "wingetui",
    "neovim"
)
foreach ($item in $ScoopApps) {
    Install-ScoopApp -Package "$item"
}

$WingetApps = @(
    "Microsoft.DotNet.DesktopRuntime.3_1",
    "Microsoft.DotNet.DesktopRuntime.5",
    "Microsoft.DotNet.DesktopRuntime.6",
    "Microsoft.DotNet.DesktopRuntime.7",
    "Microsoft.WindowsTerminal",
    "Microsoft.Edge",
    "Microsoft.Teams",
    "Microsoft.PowerToys",
    "Microsoft.PowerShell",
    
    # "Google.Chrome",
    
    "SomePythonThings.WingetUIStore",
    
    "ZeroTier.ZeroTierOne",
    "Fndroid.ClashForWindows"
)
foreach ($item in $WingetApps) {
    Install-WingetApp -PackageID "$item"
}

winget install Microsoft.VisualStudioCode --override '/SILENT /mergetasks="!runcode,addcontextmenufiles,addcontextmenufolders"'

$wslInstalled = Get-Command "wsl" -CommandType Application -ErrorAction Ignore
if (!$wslInstalled) {
    Write-Verbose -Message "Installing Windows SubSystems for Linux..."
    Start-Process -FilePath "PowerShell" -ArgumentList "wsl", "--install", "--no-distribution" -Verb RunAs -Wait -WindowStyle Hidden
}
Install-ScoopApp -Package archwsl

# install my powershell configurations
