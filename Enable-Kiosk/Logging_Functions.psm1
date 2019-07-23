<# 
==================================================================

Microsoft provides programming examples for illustration only, 
without warranty either expressed or implied, including, but not 
limited to, the implied warranties of merchantability and/or 
fitness for a particular purpose. 

This sample assumes that you are familiar with the programming 
language being demonstrated and the tools used to create and debug 
procedures. Microsoft support professionals can help explain the 
functionality of a particular procedure, but they will not modify 
these examples to provide added functionality or construct 
procedures to meet your specific needs. If you have limited 
programming experience, you may want to contact a Microsoft 
Certified Partner or the Microsoft fee-based consulting line at 
(800) 936-5200. 

For more information about Microsoft Certified Partners, please 
visit the following Microsoft Web site:
https://partner.microsoft.com/global/30000104 

Author: Pete Baxter (pete.baxter@microsoft.com)

===================================================================
#>
Function Log-Start{
  <#
  .SYNOPSIS
    Creates log file

  .DESCRIPTION
    Creates log file with path and name that is passed. Checks if log file exists, and if it does deletes it and creates a new one.
    Once created, writes initial logging data

  .PARAMETER LogPath
    Mandatory. Path of where log is to be created. Example: C:\Windows\Temp

  .PARAMETER LogName
    Mandatory. Name of log file to be created. Example: Test_Script.log
      
  .PARAMETER ScriptVersion
    Mandatory. Version of the running script which will be written in the log. Example: 1.5

  .INPUTS
    Parameters above

  .OUTPUTS
    Log file created

  .NOTES
    Version:        1.0
    Author:         Pete Baxter
    Creation Date:  08/14/14
    Purpose/Change: Initial function development    

  .EXAMPLE
    Log-Start -LogPath "C:\Windows\Temp" -LogName "Test_Script.log" -ScriptVersion "1.5"
  #>
    
  [CmdletBinding()]
  
  Param ([Parameter(Mandatory=$true)][string]$LogPath, [Parameter(Mandatory=$true)][string]$LogName, [Parameter(Mandatory=$true)][string]$ScriptVersion)
  
  Process{
    $sFullPath = $LogPath + "\" + $LogName
    		
    #Check if file exists and delete if it does
    If((Test-Path -Path $sFullPath)){
      Remove-Item -Path $sFullPath -Force
    }
    
    #Create file and start logging
    New-Item -Path $LogPath -Name $LogName -ItemType File
    
    Add-Content -Path $sFullPath -Value "***************************************************************************************************"
    Add-Content -Path $sFullPath -Value "Started processing at [$([DateTime]::Now)]."
    Add-Content -Path $sFullPath -Value "***************************************************************************************************"
    Add-Content -Path $sFullPath -Value ""
    Add-Content -Path $sFullPath -Value "Running script version [$ScriptVersion]."
    Add-Content -Path $sFullPath -Value ""
    Add-Content -Path $sFullPath -Value "***************************************************************************************************"
    Add-Content -Path $sFullPath -Value ""
  
    #Write to screen for debug mode
    Write-Debug "***************************************************************************************************"
    Write-Debug "Started processing at [$([DateTime]::Now)]."
    Write-Debug "***************************************************************************************************"
    Write-Debug ""
    Write-Debug "Running script version [$ScriptVersion]."
    Write-Debug ""
    Write-Debug "***************************************************************************************************"
    Write-Debug ""
  }
}

Function Log-Write{
  <#
  .SYNOPSIS
    Writes to a log file

  .DESCRIPTION
    Appends a new line to the end of the specified log file
  
  .PARAMETER LogPath
    Mandatory. Full path of the log file you want to write to. Example: C:\Windows\Temp\Test_Script.log
  
  .PARAMETER LineValue
    Mandatory. The string that you want to write to the log
      
  .INPUTS
    Parameters above

  .OUTPUTS
    None

  .NOTES
    Version:        1.0
    Author:         Pete Baxter
    Creation Date:  08/14/14
    Purpose/Change: Initial function development    
	
  .EXAMPLE
    Log-Write -LogPath "C:\Windows\Temp\Test_Script.log" -LineValue "This is a new line which I am appending to the end of the log file."
  #>
  
  [CmdletBinding()]
  
  Param ([Parameter(Mandatory=$true)][string]$LogPath, [Parameter(Mandatory=$true)][string]$LineValue)
  
  Process{
    Add-Content -Path $LogPath -Value "[$([DateTime]::Now)] :: $LineValue"
  
    #Write to screen for debug mode
    Write-Debug "[$([DateTime]::Now)] :: $LineValue"
  }
}

Function Log-Error{
  <#
  .SYNOPSIS
    Writes an error to a log file

  .DESCRIPTION
    Writes the passed error to a new line at the end of the specified log file
  
  .PARAMETER LogPath
    Mandatory. Full path of the log file you want to write to. Example: C:\Windows\Temp\Test_Script.log
  
  .PARAMETER ErrorDesc
    Mandatory. The description of the error you want to pass (use $_.Exception)
  
  .PARAMETER ExitGracefully
    Mandatory. Boolean. If set to True, runs Log-Finish and then exits script

  .INPUTS
    Parameters above

  .OUTPUTS
    None

  .NOTES
    Version:        1.0
    Author:         Pete Baxter
    Creation Date:  08/14/14
    Purpose/Change: Initial function development
    
  .EXAMPLE
    Log-Error -LogPath "C:\Windows\Temp\Test_Script.log" -ErrorDesc $_.Exception -ExitGracefully $True
  #>
  
  [CmdletBinding()]
  
  Param ([Parameter(Mandatory=$true)][string]$LogPath, [Parameter(Mandatory=$true)][string]$ErrorDesc, [Parameter(Mandatory=$true)][boolean]$ExitGracefully)
  
  Process{
    Add-Content -Path $LogPath -Value "Error: An error has occurred [$ErrorDesc]."
  
    #Write to screen for debug mode
    Write-Debug "Error: An error has occurred [$ErrorDesc]."
    
    #If $ExitGracefully = True then run Log-Finish and exit script
    If ($ExitGracefully -eq $True){
      Log-Finish -LogPath $LogPath
      Break
    }
  }
}

Function Log-Finish{
  <#
  .SYNOPSIS
    Write closing logging data & exit

  .DESCRIPTION
    Writes finishing logging data to specified log and then exits the calling script
  
  .PARAMETER LogPath
    Mandatory. Full path of the log file you want to write finishing data to. Example: C:\Windows\Temp\Test_Script.log

  .PARAMETER NoExit
    Optional. If this is set to True, then the function will not exit the calling script, so that further execution can occur
  
  .INPUTS
    Parameters above

  .OUTPUTS
    None

  .NOTES
    Version:        1.0
    Author:         Pete Baxter
    Creation Date:  08/14/14
    Purpose/Change: Initial function development
    
  .EXAMPLE
    Log-Finish -LogPath "C:\Windows\Temp\Test_Script.log"

  .EXAMPLE
    Log-Finish -LogPath "C:\Windows\Temp\Test_Script.log" -NoExit $True
  #>
  
  [CmdletBinding()]
  
  Param ([Parameter(Mandatory=$true)][string]$LogPath, [Parameter(Mandatory=$false)][string]$NoExit)
  
  Process{
    Add-Content -Path $LogPath -Value ""
    Add-Content -Path $LogPath -Value "***************************************************************************************************"
    Add-Content -Path $LogPath -Value "Finished processing at [$([DateTime]::Now)]."
    Add-Content -Path $LogPath -Value "***************************************************************************************************"
  
    #Write to screen for debug mode
    Write-Debug ""
    Write-Debug "***************************************************************************************************"
    Write-Debug "Finished processing at [$([DateTime]::Now)]."
    Write-Debug "***************************************************************************************************"
  
    #Exit calling script if NoExit has not been specified or is set to False
    If(!($NoExit) -or ($NoExit -eq $False)){
      Exit
    }    
  }
}