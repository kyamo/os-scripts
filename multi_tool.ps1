# PowerShell script for automated installation of an OpenSSH Server and the option to set vim as the default editor.

#Requires -RunAsAdministrator

###### Functions ######

# Menu display
function Show-Menu
{
    param (
        [string]$Title = 'Menu'
    )
    Clear-Host
    write-Host "================ $Title ================"

    Write-Host "1: Install OpenSSH Server"
    Write-Host "2: Install vim"
    Write-Host "3: Set PowerShell as SSH Shell"
    Write-Host "Q: Quit"
}


# (1) Install and enable OpenSSH Server
function install-openssh-server
{
    # Check if the OpenSSH Server is already running
    if ([bool](Get-Service | ? name -eq sshd | ? status -eq Running))
    {
        write-host "The OpenSSH Server is already running."
        return
    }

    # Check if OpenSSH Server is already installed
    if ([bool](Get-WindowsCapability -Online | ? Name -like 'OpenSSH.Server*' | ? State -like 'Installed'))
    {
        write-host "OpenSSH Server is already installed."
        return
    }

    # Install OpenSSH Server
    write-host "Installing OpenSSH Server."
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    Start-Service sshd
    Set-Service -Name sshd -StartupType 'Automatic'

    # Check firewall rules
    if (-Not ([bool](Get-NetFirewallRule -Name *ssh*)))
    {
        New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
    }

}


# (2) Installation of vim
function install-vim
{
    # Check if ExecutionPolicy is set correctly
    if (-not ((Get-ExecutionPolicy) -eq 'Unrestricted'))
    {
        write-host "Setting ExecutionPolicy to Unrestricted."
        Set-ExecutionPolicy Unrestricted
    }

    # Check if vim is already installed
    if ((Test-path -LiteralPath "$env:Programdata\chocolatey"))
    {
        write-Host "vim is already installed"
        return
    }

    Invoke-WebRequest https://chocolatey.org/install.ps1 -UseBasicParsing | Invoke-Expression;
    choco install vim
    choco update vim

    $command = (Get-itemProperty -LiteralPath "HKLM:\SOFTWARE\Classes\`*\shell\Vim\Command").'(default)';

    if ($command -match "`"([^`"]+)`".*")
    {
        $expression = "Set-Alias -Name 'vim' -Value '$($Matches[1])';"

        if (-Not (Test-Path "$PROFILE"))
        {
            "$expression`r`n" | Out-File -FilePath "$PROFILE" -Encoding UTF8;
        }
        elseif (Get-Content "$PROFILE" | Where-Object { $_ -eq "$expression" })
        {
            Add-Content '$PROFILE' "`r`n$expression`r`n";
        }
    }
}


# (3) Set PowerShell as default shell
function set-pwsh-as-default
{
    # Check if OpenSSH is already installed (required)
    if (-Not ([bool](Get-WindowsCapability -Online | ? Name -like 'OpenSSH.Server*' | ? State -like 'Installed')))
    {
        write-host "First install the OpenSSH Server!"
        return
    }

    $regpath = "HKLM:\SOFTWARE\OpenSSH"
    $pwshpath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

    # Check if the change has already been made
    if ([bool]((Get-ItemProperty -Path "$regpath").DefaultShell -like "*powershell.exe"))
    {
        write-host "PowerShell is already the default shell. No action required."
        return
    }

    # Edit the registry
    New-ItemProperty -Path "$regpath" -Name DefaultShell -Value "$pwshpath" -PropertyType String -Force
    write-host "PowerShell successfully set as the default shell via SSH."

}


#############################################################


# Menu invocation
do
{
    Show-Menu
    $selection = Read-Host "Choose a menu option"
    switch ($selection)
    {
        '1' {
                install-openssh-server
            }
        '2' {
                install-vim
            }
        '3' {
                set-pwsh-as-default
            }
        'q' {
                return
            }
    }
    pause
}
until ($selection -eq 'q')
