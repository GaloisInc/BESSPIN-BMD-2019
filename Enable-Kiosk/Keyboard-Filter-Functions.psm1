#
# Copyright (C) Microsoft. All rights reserved.
#

<#
.Synopsis
    This script shows how to use the built in WMI providers to enable and add 
    keyboard filter rules through Windows PowerShell on the local computer.
.Parameter ComputerName
    Optional parameter to specify a remote machine that this script should
    manage.  If not specified, the script will execute all WMI operations
    locally.
#>
param (
    [String] $ComputerName
)

$CommonParams = @{"namespace"="root\standardcimv2\embedded"}
$CommonParams += $PSBoundParameters

function Enable-Predefined-Key($Id) {
    <#
    .Synopsis
        Toggle on a Predefined Key keyboard filter Rule
    .Description
        Use Get-WMIObject to enumerate all WEKF_PredefinedKey instances,
        filter against key value "Id", and set that instance's "Enabled"
        property to 1/true.
    .Example
        Enable-Predefined-Key "Ctrl+Alt+Del"
        Enable CAD filtering
#>

    $predefined = Get-WMIObject -class WEKF_PredefinedKey @CommonParams |
        where {
            $_.Id -eq "$Id"
        };

    if ($predefined) {
        $predefined.Enabled = 1;
        $predefined.Put() | Out-Null;
        Log-Write -LogPath $sLogFile -LineValue "Enabled $Id"
        #Write-Host Enabled $Id
    } else {
        Log-Error -LogPath $sLogFile -ErrorDesc "Line Number: $MyInvocation.ScriptLineNumber `n" + $_.Exception -ExitGracefully $True
        #Write-Error "$Id is not a valid predefined key"
    }
}


function Enable-Custom-Key($Id) {
    <#
    .Synopsis
        Toggle on a Custom Key keyboard filter Rule
    .Description
        Use Get-WMIObject to enumerate all WEKF_CustomKey instances,
        filter against key value "Id", and set that instance's "Enabled"
        property to 1/true.

        In the case that the Custom instance does not exist, add a new
        instance of WEKF_CustomKey using Set-WMIInstance.
    .Example
        Enable-Custom-Key "Ctrl+V"
        Enable filtering of the Ctrl + V sequence.
#>

    $custom = Get-WMIObject -class WEKF_CustomKey @CommonParams |
        where {
            $_.Id -eq "$Id"
        };

    if ($custom) {
# Rule exists.  Just enable it.
        $custom.Enabled = 1;
        $custom.Put() | Out-Null;
        "Enabled Custom Filter $Id.";

    } else {
        Set-WMIInstance `
            -class WEKF_CustomKey `
            -argument @{Id="$Id"} `
            @CommonParams | Out-Null
        Log-Write -LogPath $sLogFile -LineValue "Added Custom Filter $Id"
        #"Added Custom Filter $Id.";
    }
}

function Enable-Scancode($Modifiers, [int]$Code) {
    <#
    .Synopsis
        Toggle on a Scancode keyboard filter Rule
    .Description
        Use Get-WMIObject to enumerate all WEKF_Scancode instances,
        filter against key values of "Modifiers" and "Scancode", and set
        that instance's "Enabled" property to 1/true.

        In the case that the Scancode instance does not exist, add a new
        instance of WEKF_Scancode using Set-WMIInstance.
    .Example
        Enable-Scancode "Ctrl" 37
        Enable filtering of the Ctrl + keyboard scancode 37 (base-10)
        sequence.
#>

    $scancode =
        Get-WMIObject -class WEKF_Scancode @CommonParams |
            where {
                ($_.Modifiers -eq $Modifiers) -and ($_.Scancode -eq $Code)
            }

    if($scancode) {
        $scancode.Enabled = 1
        $scancode.Put() | Out-Null
        "Enabled Custom Scancode {0}+{1:X4}" -f $Modifiers, $Code
    } else {
        Set-WMIInstance `
            -class WEKF_Scancode `
            -argument @{Modifiers="$Modifiers"; Scancode=$Code} `
            @CommonParams | Out-Null
 
        Log-Write -LogPath $sLogFile -LineValue "Added Custom Scancode {0}+{1:X4}" -f $Modifiers, $Code
        #"Added Custom Scancode {0}+{1:X4}" -f $Modifiers, $Code
    }
}

<# Examples

# Some example uses of the functions defined above.
Enable-Predefined-Key "Ctrl+Alt+Del"
Enable-Predefined-Key "Ctrl+Esc"
Enable-Custom-Key "Ctrl+V"
Enable-Custom-Key "Numpad0"
Enable-Custom-Key "Shift+Numpad1"
Enable-Custom-Key "%"
Enable-Scancode "Ctrl" 37

#>

#
# Copyright (C) Microsoft. All rights reserved.
#

<#
.Synopsis
    This script shows how to enumerate WEKF_Settings to find global settings
    that can be set on the keyboard filter.  In this specific script, the
    global setting to be set is "DisableKeyboardFilterForAdministrators".
.Parameter ComputerName
    Optional parameter to specify a remote computer that this script should
    manage.  If not specified, the script will execute all WMI operations
    locally.
#>

$CommonParams = @{"namespace"="root\standardcimv2\embedded"};

if ($PSBoundParameters.ContainsKey("ComputerName")) {
    $CommonParams += @{"ComputerName" = $ComputerName};
}

<#
    .Synopsis
        Get a WMIObject by name from WEKF_Settings
    .Parameter Name
        The name of the setting, which is the key for the WEKF_Settings class.
#>
function Get-Setting([String] $Name) {

    $Entry = Get-WMIObject -class WEKF_Settings @CommonParams |
        where {
            $_.Name -eq $Name
        }

    return $Entry
}

<#
    .Synopsis
        Set the DisableKeyboardFilterForAdministrators setting to true or
        false.
    .Description
        Set DisableKeyboardFilterForAdministrators to true or false based
        on $Value
    .Parameter Value
        A Boolean value
#>
function Set-DisableKeyboardFilterForAdministrators([Bool] $Value) {


    $Setting = Get-Setting("DisableKeyboardFilterForAdministrators")

    if ($Setting) {
        if ($Value) {
            $Setting.Value = "true" 
        } else {
            $Setting.Value = "false"
        }
        $Setting.Put() | Out-Null;
    } 
    else {
        Log-Write -LogPath $sLogFile -LineValue "Unable to find DisableKeyboardFilterForAdministrators setting"
        #Write-Error "Unable to find DisableKeyboardFilterForAdministrators setting";
    }
}

#Set-DisableKeyboardFilterForAdministrators $true

function Remove-Custom-Key($Id) {
    <#
    .Synopsis
        Remove an instance of WEKF_CustomKey
    .Description
        Enumerate all instances of WEKF_CustomKey.  When an instance has an
        Id that matches $Id, delete it.
    .Example
        Remove-Custom-Key "Ctrl+V"

        This removes the instance of WEKF_CustomKey with a key Id of "Ctrl+V"
#>

    $customInstance = Get-WMIObject -class WEKF_CustomKey @CommonParams |
        where {$_.Id -eq $Id}

    if ($customInstance) {
        $customInstance.Delete();
        "Removed Custom Filter $Id.";
    } else {
        "Custom Filter $Id does not exist.";
    }
}

function Remove-Scancode($Modifiers, [int]$Code) {
    <#
    .Synopsis
        Remove and instance of WEKF_Scancode
    .Description
        Enumerate all instances of WEKF_Scancode.  When an instance has a
        matching modifiers and code, delete it.
    .Example
        Remove-Scancode "Ctrl" 37

        This removes the instance of WEKF_Scancode with Modifiers="Ctrl" and
        Scancode=37.
#>

    $scancodeInstance = Get-WMIObject -class WEKF_Scancode @CommonParams |
        where {($_.Modifiers -eq $Modifiers) -and ($_.Scancode -eq $Code)}

    if ($scancodeInstance) {
        $scancodeInstance.Delete();
        "Removed Scancode $Modifiers+$Code.";
    } else {
        "Scancode $Modifiers+$Code does not exist.";
    }
}

# Some example uses of the functions defined above.
<#
Remove-Custom-Key "Ctrl+V"
Remove-Custom-Key "Numpad0"
Remove-Custom-Key "Shift+Numpad1"
Remove-Custom-Key "%"
Remove-Scancode "Ctrl" 37
#>

function Disable-Predefined-Keys {

$CommonParams = @{"namespace"="root\standardcimv2\embedded"}
$CommonParams += $PSBoundParameters

Get-WMIObject -class WEKF_PredefinedKey @CommonParams |
    foreach {
        if ($_.Enabled) {
            $_.Enabled = 0;
            $_.Put() | Out-Null;
            Write-Host Disabled $_.Id
        }
    }
}