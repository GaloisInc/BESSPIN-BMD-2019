<#

.SYNOPSIS
    This script is designed to secure a Windows 10 client and configure it in kiosk mode to be used as a voting platform
.DESCRIPTION
  This script will confifure a laptop or desktop to be used as a voting device.  It will check if the correct Windows Features
  are installed and if not installed, install them.  It will then configure Keyboard filters to limit what key combinations are
  avaiable.  Then it will setup the Kiosk user account, the Election Official account, and a seperate admin account.

.PARAMETER <Parameter_Name>
    None

.INPUTS
    None

.OUTPUTS
    None

.NOTES
    Version:        1.1
    Author:         Pete Baxter
    Creation Date:  6/19/2019
    Purpose/Change: Additional keyboard strokes added to the restricted list to prevent Chrome shortcuts from working

    Version:        1.0
    Author:         Pete Baxter
    Creation Date:  4/4/2019
    Purpose/Change: Initial script development

.EXAMPLE
  .\Enable-Kiosk.ps1
#>

#region #---------------------------------------------------------[Initializations]--------------------------------------------------------

#Script Version
$sScriptVersion = "1.1"

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

#Dot Source required Function Libraries
Import-Module .\Logging_Functions.psm1 -AsCustomObject -Force -DisableNameChecking
Import-Module .\Keyboard-Filter-Functions.psm1 -AsCustomObject -Force -DisableNameChecking

#Log File Info
$sLogPath = ".\logs"
$sLogName = "$($MyInvocation.MyCommand.Name)-Log-{0}.log" -f [DateTime]::Now.ToString("yyyy-mm-dd_hh-mm-ss")
$sLogFile = $sLogPath + "\" + $sLogName

# Check that the log path exists and if not create it.
$boolLogPathExist = Test-Path $sLogPath

if(!$boolLogPathExist){
    New-Item -ItemType Directory -Force -Path $sLogPath
}

#endregion

#region #----------------------------------------------------------[Declarations]----------------------------------------------------------P

# Progress bar setup
$script:steps = ([System.Management.Automation.PsParser]::Tokenize((Get-Content ".\$($MyInvocation.MyCommand.Name)"), [ref]$null) | Where-Object { $_.Type -eq 'Command' -and $_.Content -eq 'Write-ProgressHelper' }).Count
$stepCounter = 0

# User and Password variables
$KioskUser = "VoterKiosk"
$KioskUserPassword = "kiosk123"
$AdminUser = "AdminUser"
$AdminUserPassword = "Msft1235"
$ElectionOfficialUser = "ElectionOfficial"
$ElectionOfficialUserPassword = "P)o9i8u7mn"

# Shell Path variables
$kioskChromePath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe --kiosk --kiosk-printing http://localhost:7777/index.html"
$electionChromePath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe --kiosk --kiosk-printing http://localhost:7777/index.html"
$adminuserPath = "explorer.exe"

# Define actions to take when the shell program exits.
$restart_shell = 0
$restart_device = 1
$shutdown_device = 2

# Feature Name variables

# Device Lockdown is the parent feature and must be enabled before the others
$featDeviceLockdown = "Client-DeviceLockdown"

# Shell Launcher and Keyboard Filter
$featEmbedShellLauncher = "Client-EmbeddedShellLauncher"
$featKeyboardFilter = "Client-KeyboardFilter"

# Variable to track if restart is needed when enabling windows features
$script:boolRestartRequired = $false

#endregion

#region #-----------------------------------------------------------[Functions]------------------------------------------------------------

function Write-ProgressHelper
{

    [CmdletBinding()]

    Param
    (
        [parameter(Mandatory = $true)][int]$StepNumber,
        [parameter(Mandatory = $true)][string]$Message
    )

    Begin {
    
    }
    Process {
            Write-Progress -Activity 'Enable-Kiosk' -Status $Message -PercentComplete (($StepNumber / $steps) * 100)
        Start-Sleep -Seconds 2
    }

    End {

    }
}

# Check if shell launcher license is enabled
function Check-ShellLauncherLicenseEnabled
{
    [CmdletBinding()]

    Param
    (
    
    )
  
    Begin
    {
        Log-Write -LogPath $sLogFile -LineValue "$($MyInvocation.MyCommand.Name) - Starting Execution."
    }

    Process
    {
        Try
        {
            [string]$source = @"

                using System;
                using System.Runtime.InteropServices;

                static class CheckShellLauncherLicense
                {
                    const int S_OK = 0;

                    public static bool IsShellLauncherLicenseEnabled()
                    {
                        int enabled = 0;

                        if (NativeMethods.SLGetWindowsInformationDWORD("EmbeddedFeature-ShellLauncher-Enabled", out enabled) != S_OK) {
                            enabled = 0;
                        }

                        return (enabled != 0);
                    }

                    static class NativeMethods
                    {
                        [DllImport("Slc.dll")]
                        internal static extern int SLGetWindowsInformationDWORD([MarshalAs(UnmanagedType.LPWStr)]string valueName, out int value);
                    }

                }
"@

        $type = Add-Type -TypeDefinition $source -PassThru

        return $type[0]::IsShellLauncherLicenseEnabled()
        }

        Catch
        {
            Log-Error -LogPath $sLogFile -ErrorDesc "Line Number: $MyInvocation.ScriptLineNumber `n" + $_.Exception -ExitGracefully $True
            Break
        }
    }

    End
    {
        If($?)
        {
            Log-Write -LogPath $sLogFile -LineValue "$($MyInvocation.MyCommand.Name) - Completed Successfully."
        }
    }
}

# Check if the needed Windows features are enabled and if not enable them
function Check-WindowsFeature
{
    [CmdletBinding()]

    Param
    (
        [parameter(Mandatory = $true)][String]$FeatureName
    )
  
    Begin
    {
        Log-Write -LogPath $sLogFile -LineValue "$($MyInvocation.MyCommand.Name) - $FeatureName - Starting Execution."
    }

    Process
    {
        Try
        {
            $boolState = (Get-WindowsOptionalFeature -Online -FeatureName $FeatureName).State
            Log-Write -LogPath $sLogFile -LineValue "$($MyInvocation.MyCommand.Name) - $FeatureName - State property set to $boolState."

            if($boolState -eq "Disabled")
            {
                $results = Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -NoRestart -WarningAction SilentlyContinue

                Log-Write -LogPath $sLogFile -LineValue "$($MyInvocation.MyCommand.Name) - $FeatureName : Restart Needed : $($results.RestartNeeded)"

                if($results.RestartNeeded -eq $true)
                {
                   $script:boolRestartRequired = $true                   
                }
            }
            else {
                Log-Write -LogPath $sLogFile -LineValue "$FeatureName - Feature has already been installed."                    
            }
        }

        Catch
        {
            Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
            Break
        }
    }

    End
    {
        If($?)
        {
            Log-Write -LogPath $sLogFile -LineValue "$($MyInvocation.MyCommand.Name) - $FeatureName - Completed Successfully."
        }
    }
}

# Check that the needed accounts have been created on the machine and if not create them
function Check-UserAccounts {

    [CmdletBinding()]

    Param
    (
        [parameter(Mandatory = $true)][String]$AccountName,
        [parameter(Mandatory = $false)][String]$Password,
        [parameter(Mandatory = $false)][Boolean]$PasswordRequired        
    )
  
    Begin
    {
        Log-Write -LogPath $sLogFile -LineValue "$($MyInvocation.MyCommand.Name) - $AccountName - Starting Execution."
    }

    Process
    {
        Try
        {
            # Check if user already exists
            $doesExist = Get-LocalUser -Name $AccountName

            # Create the user if they do not exist
            if(!$doesExist)
            {
                if(!$PasswordRequired) {
                    New-LocalUser -Name $AccountName -NoPassword
                    Set-LocalUser -Name $AccountName -UserMayChangePassword $false -PasswordNeverExpires $true
                }
                else {
                    $pwd = ConvertTo-SecureString $Password -AsPlainText -Force
                    New-LocalUser -Name $AccountName -Password $pwd -PasswordNeverExpires
                }
            }
            
            # Add the AdminUser to the Local Administrators Group
            if($AccountName -eq "AdminUser")
            {
                Add-LocalGroupMember -Group "Administrators" -Member $AccountName
            }
            else
            {
                Add-LocalGroupMember -Group "Users" -Member $AccountName
                Add-LocalGroupMember -Group "Remote Desktop Users" -Member $AccountName
            }     

        }

        Catch
        {
            Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
            Break
        }
    }

    End
    {
        Log-Write -LogPath $sLogFile -LineValue "$($MyInvocation.MyCommand.Name) - $AccountName - Completed Successfully."
    }

} 

# Get the User Account SID to be used to set the proper Shell Launcher
function Get-UsernameSID {

    [CmdletBinding()]

    Param
    (
        [parameter(Mandatory = $true)][String]$AccountName        
    )
  
    Begin
    {
        Log-Write -LogPath $sLogFile -LineValue "$($MyInvocation.MyCommand.Name) - $AccountName - Starting Execution."
    }

    Process
    {
        Try
        {
            # Get the SID for the user once we know they exist
            $SID = (Get-LocalUser -Name $AccountName).SID.Value
            return $SID 
        }

        Catch
        {
            Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
            Break
        }
    }

    End
    {
        If($?)
        {
            Log-Write -LogPath $sLogFile -LineValue "$($MyInvocation.MyCommand.Name) - $AccountName - Completed Successfully."
        }
    }

} 

#endregion

#region #-----------------------------------------------------------[Execution]------------------------------------------------------------

Write-ProgressHelper -Message 'Begin Execution..' -StepNumber ($stepCounter++)

# Create Log File
Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion

#region #-------------------------------------------[Begin Main Script Execution]------------------------------------------------------------

Write-ProgressHelper -Message 'Checking Shell Launcher License..' -StepNumber ($stepCounter++)

[bool]$result = $false

$result = Check-ShellLauncherLicenseEnabled

Log-Write -LogPath $sLogFile -LineValue "Shell Launcher license enabled is set to $result"

if (-not($result))
{
    Log-Write -LogPath $sLogFile -LineValue "This device doesn't have required license to use Shell Launcher"
    exit
}

Write-ProgressHelper -Message 'Checking for Google Chrome..' -StepNumber ($stepCounter++)

# Check if Chrome is installed on the machine
Log-Write -LogPath $sLogFile -LineValue "Checking of the Chrome install path was found."
$boolChromePathExist = Test-Path "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"

if(!$boolChromePathExist){

    Log-Write -LogPath $sLogFile -LineValue "Chrome install path not found...Installing"
    Write-ProgressHelper -Message 'Google Chrome was not found...Installing..' -StepNumber ($stepCounter++)
    
    $Path = ".\"
    $Installer = "ChromeStandaloneSetup64.exe"
    
    Log-Write -LogPath $sLogFile -LineValue "Checking if Chrome installer file path was found"
    $boolChromeInstallerExist = Test-Path $Path\$Installer

    if (!$boolChromeInstallerExist){
        Log-Write -LogPath $sLogFile -LineValue "The Google Chrome Installer file is not avaialble.  Please add it to the local directory before continuing."
        Exit
    }
    #Invoke-WebRequest "http://dl.google.com/chrome/install/375.126/chrome_installer.exe" -OutFile $Path\$Installer
    Log-Write -LogPath $sLogFile -LineValue "Chrome installer file was found...Starting install Process"
    Start-Process -FilePath $Path\$Installer -Args "/silent /install" -Verb RunAs -Wait
}

Write-ProgressHelper -Message 'Checking and Enabling Windows Features..' -StepNumber ($stepCounter++)

# We must check if the proper Windows features are enabled

# Device Lockdown must be enabled first
Check-WindowsFeature $featDeviceLockdown

# Now the other features can be enabled
Check-WindowsFeature $featEmbedShellLauncher
Check-WindowsFeature $featKeyboardFilter

# After the Windows Features are enabled a Restart may be needed.
# We detect if a Restart is needed and reboot the machine
if($script:boolRestartRequired -eq $true)
{
    Log-Write -LogPath $sLogFile -LineValue "Restart required for Windows Feature install to complete"
    # Finish log and close out file
    Log-Finish -LogPath $sLogFile -NoExit $true

    Write-Host -ForegroundColor Yellow 'The computer will reboot in 15 seconds to complete Windows Feature installation.  Please re-run the script when the reboot is complete.'
    Start-Sleep -Seconds 15
    # Force Restart of the Computer to complete Feature enablement
    Restart-Computer -Force
}

# Set Keyboard Filter settings
Try {
    
    Log-Write -LogPath $sLogFile -LineValue "Keyboard Filter - Setting Keyboard Filter to be Disabled for Administrators"
    Set-DisableKeyboardFilterForAdministrators $true

    Log-Write -LogPath $sLogFile -LineValue "Keyboard Filter - Setting Keyboard Filter for Ctrl+Alt+Del"
    Enable-Predefined-Key "Ctrl+Alt+Del"
    Log-Write -LogPath $sLogFile -LineValue "Keyboard Filter - Setting Keyboard Filter for Win+L"
    Enable-Predefined-Key "Win+L"
    Log-Write -LogPath $sLogFile -LineValue "Keyboard Filter - Setting Keyboard Filter for Ctrl+n"
    Enable-Custom-Key "Ctrl+n"
    Log-Write -LogPath $sLogFile -LineValue "Keyboard Filter - Setting Keyboard Filter for Ctrl+Shift+n"
    Enable-Custom-Key "Ctrl+Shift+n"
    Log-Write -LogPath $sLogFile -LineValue "Keyboard Filter - Setting Keyboard Filter for Ctrl+t"
    Enable-Custom-Key "Ctrl+t"
    Log-Write -LogPath $sLogFile -LineValue "Keyboard Filter - Setting Keyboard Filter for Strl+Shift+t"
    Enable-Custom-Key "Ctrl+Shift+t"
    Log-Write -LogPath $sLogFile -LineValue "Keyboard Filter - Setting Keyboard Filter for Alt+Home"
    Enable-Custom-Key "Alt+Home"
    Log-Write -LogPath $sLogFile -LineValue "Keyboard Filter - Setting Keyboard Filter Scancode for Ctrl 11"
    Enable-Scancode "Ctrl" 11
}
Catch {

    Log-Error -LogPath $sLogFile -ErrorDesc "Line Number: $MyInvocation.ScriptLineNumber `n" + $_.Exception -ExitGracefully $True
    Break 

}

Write-ProgressHelper -Message 'Setting up Shell Launcher..' -StepNumber ($stepCounter++)

$COMPUTER = "localhost"
$NAMESPACE = "root\standardcimv2\embedded"

# Create a handle to the class instance so we can call the static methods.
try 
{
    Log-Write -LogPath $sLogFile -LineValue "Creating Shell Launcher object"
    $ShellLauncherClass = [wmiclass]"\\$COMPUTER\${NAMESPACE}:WESL_UserSetting"
} 
catch
{
    Log-Error -LogPath $sLogFile -ErrorDesc "Line Number: $MyInvocation.ScriptLineNumber `n" + $_.Exception -ExitGracefully $True
    Break 
}

# Enable Shell Launcher
Try
{
    $ShellLauncherClass.SetEnabled($TRUE)
    $IsShellLauncherEnabled = $ShellLauncherClass.IsEnabled()
    Log-Write -LogPath $sLogFile -LineValue "IsShellLauncherEnabled is set to $($IsShellLauncherEnabled.Enabled)"
}
Catch
{
    Log-Error -LogPath $sLogFile -ErrorDesc "Line Number: $MyInvocation.ScriptLineNumber `n" + $_.Exception -ExitGracefully $True
    Log-Write -LogPath $sLogFile -LineValue "Make sure Shell Launcher feature is enabled"
    Break 
}

Write-ProgressHelper -Message 'Checking and Enabling Local Accounts..' -StepNumber ($stepCounter++)

# Check if local users exist and if not then create them
Check-UserAccounts -AccountName $KioskUser -PasswordRequired $false
Check-UserAccounts -AccountName $AdminUser -Password $AdminUserPassword -PasswordRequired $true
Check-UserAccounts -AccountName $ElectionOfficialUser -Password $ElectionOfficialUserPassword -PasswordRequired $true

# Get the SID for each user so that we can set the proper shell
$KioskUser_SID = Get-UsernameSID $KioskUser
$AdminUser_SID = Get-UsernameSID $AdminUser
$ElectionOfficial_SID = Get-UsernameSID $ElectionOfficialUser

Write-ProgressHelper -Message 'Setting Shell Launcher for Local Accounts..' -StepNumber ($stepCounter++)

Log-Write -LogPath $sLogFile -LineValue "Setting Default Shell to explorer.exe"
$ShellLauncherClass.SetDefaultShell("explorer.exe", $restart_device)


# Set Chrome as the shell for "KioskUser" and "ElectionOfficial", and restart 
# the machine if it is closed. The URL for "ElectionOfficial" will be changed in the future.
try {
     # Kiosk User
    Log-Write -LogPath $sLogFile -LineValue "Setting custom shell for $KioskUser - Path: $kioskChromePath"
    $ShellLauncherClass.SetCustomShell($KioskUser_SID, $kioskChromePath, $null, $null, $restart_device)

    # Election Official User
    Log-Write -LogPath $sLogFile -LineValue "Setting custom shell for $ElectionOfficialUser - Path: $electionChromePath"
    $ShellLauncherClass.SetCustomShell($ElectionOfficial_SID, $electionChromePath, ($null), ($null), $restart_device)
    
    # Admin User
    Log-Write -LogPath $sLogFile -LineValue "Setting custom shell for $AdminUser - Path: $adminuserPath"
    $ShellLauncherClass.SetCustomShell($AdminUser_SID, $adminuserPath, ($null), ($null), $restart_shell)
}
catch {
    Log-Error -LogPath $sLogFile -ErrorDesc "Line Number: $MyInvocation.ScriptLineNumber `n" + $_.Exception -ExitGracefully $True
    Log-Write -LogPath $sLogFile -LineValue "Setting the Shell Launcher failed."
    Break 
}

# Disable all network adapters without prompting the user to confirm
Get-NetAdapter | Disable-NetAdapter -Confirm:$false

#Set explorer.exe as normal shell for the Admin user
#$ShellLauncherClass.SetCustomShell($AdminUser_SID, "explorer.exe", ($null), ($null), $restart_shell)


# View all the custom shells defined.

#"`nCurrent settings for custom shells:"
#Get-WmiObject -namespace $NAMESPACE -computer $COMPUTER -class WESL_UserSetting | Select Sid, Shell, DefaultAction 

#Write-Host $steps

#endregion #-------------------------------------------[End Main Script Execution]------------------------------------------------------------

Write-ProgressHelper -Message 'Complete Logging..' -StepNumber ($stepCounter++)

# Finish log and close out file
Log-Finish -LogPath $sLogFile

#endregion