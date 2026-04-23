<#
.SYNOPSIS

PSApppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION

- The script is provided as a template to perform an install or uninstall of an application(s).
- The script either performs an "Install" deployment type or an "Uninstall" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.PARAMETER DeploymentType

The type of deployment to perform. Default is: Install.

.PARAMETER DeployMode

Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.

.PARAMETER AllowRebootPassThru

Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode

Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging

Disables logging to file for the script. Default is: $false.

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"

.EXAMPLE

Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
- 69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
- 70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1

.LINK

https://psappdeploytoolkit.com
#>


[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [String]$DeploymentType = 'Install',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [String]$DeployMode = 'Interactive',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false
)

Try {
    ## Set the script execution policy for this process
    Try {
        Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop'
    }
    Catch {
    }

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [String]$appVendor = 'Google'
    [String]$appName = 'Chrome'
    [String]$appVersion = '147.0.7727.56'
    [String]$AppRequestID = 'LUM0190'
    [String]$appArch = 'x64'
    [String]$appLang = 'EN'
    [String]$appRevision = 'R01'
    [String]$appScriptVersion = ''
    [String]$appScriptDate = '18-02-2026'
    [String]$appScriptAuthor = 'Charan k'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [String]$installName = 'LUM0190_Google_Chrome_147.0.7727.56-R01_EN'
    [String]$installTitle = 'LUM0190_Google_Chrome_147.0.7727.56-R01_EN'

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [Int32]$mainExitCode = 0

    ## Variables: Script
    [String]$deployAppScriptFriendlyName = 'Deploy Application'
    [Version]$deployAppScriptVersion = [Version]'3.9.2'
    [String]$deployAppScriptDate = '02/02/2023'
    [Hashtable]$deployAppScriptParameters = $PsBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') {
        $InvocationInfo = $HostInvocation
    }
    Else {
        $InvocationInfo = $MyInvocation
    }
    [String]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [String]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) {
            Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]."
        }
        If ($DisableLogging) {
            . $moduleAppDeployToolkitMain -DisableLogging
        }
        Else {
            . $moduleAppDeployToolkitMain
        }
    }
    Catch {
        If ($mainExitCode -eq 0) {
            [Int32]$mainExitCode = 60008
        }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') {
            $script:ExitCode = $mainExitCode; Exit
        }
        Else {
            Exit $mainExitCode
        }
    }

    #endregion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Installation'

        ## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
        #Show-InstallationWelcome -CloseApps 'iexplore' -AllowDefer -DeferTimes 3 -CheckDiskSpace -PersistPrompt

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Installation tasks here>


        $registryPaths = @(
                "HKLM:\SYSTEM\LUMILEDS\Packages\Google Chrome 128.0.6613.120",
                "HKLM:\SYSTEM\LUMILEDS\Packages\Google Chrome 130.0.6723.92",
                "HKLM:\SYSTEM\LUMILEDS\Packages\Google Chrome 132.0.6834.84",
                "HKLM:\SYSTEM\LUMILEDS\Packages\Google Chrome 135.0.7049.96",
                "HKLM:\SYSTEM\LUMILEDS\Packages\Google Chrome 137.0.7151.69",
                "HKLM:\SYSTEM\LUMILEDS\Packages\Google Chrome 139.0.7258.139",
                "HKLM:\SYSTEM\LUMILEDS\Packages\Google Chrome 140.0.7339.186",
                "HKLM:\SYSTEM\LUMILEDS\Packages\Google Chrome 142.0.7444.163",
                "HKLM:\SYSTEM\LUMILEDS\Packages\Google Chrome 144.0.7559.110",
                "HKLM:\SYSTEM\LUMILEDS\Packages\Google Chrome 145.0.7632.76"
            )
 
            foreach ($registryPath in $registryPaths) {
                if (Test-Path $registryPath) {
                    Remove-Item -Path $registryPath -Recurse -Force
                    Write-Log -Message "Registry key removed: $registryPath"
                } else {
                    Write-Log -Message "Registry key not found: $registryPath"
                }
            }
 


        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'

        ## Handle Zero-Config MSI Installations
        <#If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) {
                $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ }
            }
        }#>

        ## <Perform Installation tasks here>

        
        # Function to obtain the version of Google Chrome from chrome.exe path
        function Get-ChromeVersionFromPath {
            # Define possible Chrome installation paths for both 32-bit and 64-bit systems
            $chromePaths = @(
                "$envProgramFiles\Google\Chrome\Application\chrome.exe",
                "$envProgramFilesX86\Google\Chrome\Application\chrome.exe" # Include 32-bit path if needed
            )

            # Iterate through paths to find the chrome.exe
            foreach ($chromePath in $chromePaths) {
                if (Test-Path $chromePath) {
                    # Get the file version of chrome.exe
                    $version = (Get-Item $chromePath).VersionInfo.ProductVersion
                    return $version
                }
            }

            # Return empty if Chrome is not installed
            return ""
        }

        # Function to compare two versions
        function Compare-Versions {
            param (
                [string]$installedVersion,
                [string]$requiredVersion
            )

            # Convert string versions to System.Version type
            $installed = [version]$installedVersion
            $required = [version]$requiredVersion

            if ($installed -lt $required) {
                return -1  # Installed version is lower than the required version
            } elseif ($installed -eq $required) {
                return 0   # Installed version matches the required version
            } else {
                return 1   # Installed version is higher than the required version
            }
        }

        # ChromeVersion:
        $requiredVersion = "147.0.7727.56" # Define the required version
        $chromeVersion = Get-ChromeVersionFromPath

        # Check if Google Chrome is installed
        if ($chromeVersion) {
            Write-Log -Message "Installed Google Chrome version: $chromeVersion"
    
            # Compare the installed version with the required version
            $comparisonResult = Compare-Versions -installedVersion $chromeVersion -requiredVersion $requiredVersion

             if ($comparisonResult -eq -1) {
                        Write-Log -Message "Installed version ($chromeVersion) is lower than the required version ($requiredVersion)."

                # Proceed to remove older versions of Google Chrome
                Write-Log -Message "*************************************************************"
                Write-Log -Message "Removal of Google Chrome MSI Version started......."
                Write-Log -Message "*************************************************************"

                $RegUninstallPaths = @(
                    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
                    'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
                )
                $UninstallSearchFilter = { ($_.GetValue('DisplayName') -like '*Google Chrome*') } 
        
                foreach ($Path in $RegUninstallPaths) {
                If (test-path -Path $Path){
                Get-ChildItem $Path | Where $UninstallSearchFilter | 
                Foreach {Execute-MSI -Action 'Uninstall' -Path "$($_.PSChildName)" -Parameters '/qn' -LogName "Google_Chrome_PreviousVersion"}
                write-log -message "Google Chrome Previous version got uninstalled"	
	
                }
                }
                

                # Kill Chrome if it's running
                Write-Log -Message "Checking if Chrome is running in the machine..."
                $chromeProcesses = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
                if ($chromeProcesses) {
                    Write-Log -Message "Chrome.exe is running in the machine..."
                    Stop-Process -Name "chrome" -Force
                    Write-Log -Message "Terminated chrome.exe..."
                }
                Write-Log -Message "Now Chrome is not running in the machine..."


                # Kill GoogleUpdate.exe if it's running
                Write-Log -Message "Checking if GoogleUpdate.exe is running in the machine..."
                $googleUpdateProcesses = Get-Process -Name "GoogleUpdate" -ErrorAction SilentlyContinue
                if ($googleUpdateProcesses) {
                    Write-Log -Message "GoogleUpdate.exe is running in the machine..."
                    Stop-Process -Name "GoogleUpdate" -Force
                    Write-Log -Message "Terminated GoogleUpdate.exe..."
                }
                Write-Log -Message "Now GoogleUpdate.exe is not running in the machine..."

                # Execute installation
                Execute-MSI -Action 'Install' -Path "$dirFiles\googlechromestandaloneenterprise64.msi" -Transform "$dirFiles\Google_Chrome_147.0.7727.56-R01_EN.Mst" -Parameters '/qn' -LogName "LUM0190_Google_Chrome_147.0.7727.56-R01_EN"
                    

            }
                    
                else
                     
                {
                Write-Log -Message "The latest version of Google Chrome is already installed."
                        
            }


        } 
                
                
        else
                
            {
            # Chrome is not installed
            Write-Log -Message "Google Chrome is not installed. Starting installation..."
            Execute-MSI -Action 'Install' -Path "$dirFiles\googlechromestandaloneenterprise64.msi" -Transform "$dirFiles\Google_Chrome_147.0.7727.56-R01_EN.Mst" -Parameters '/qn' -LogName "LUM0190_Google_Chrome_147.0.7727.56-R01_EN"
            }
            

        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'

        ## <Perform Post-Installation tasks here>

        Audit-Key -Action "Create"

        ## Display a message at the end of the install
        #If (-not $useDefaultMsi) {
            #Show-InstallationPrompt -Message 'You can customize text to appear at the end of an install or remove it completely for unattended installations.' -ButtonRightText 'OK' -Icon Information -NoWait
        #}
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        #Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Uninstallation tasks here>

       # Kill Chrome if it's running
        Write-Log -Message "Checking if Chrome is running in the machine..."
        $chromeProcesses = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
        if ($chromeProcesses) {
            Write-Log -Message "Chrome.exe is running in the machine..."
            Stop-Process -Name "chrome" -Force
            Write-Log -Message "Terminated chrome.exe..."
        }
        Write-Log -Message "Now Chrome is not running in the machine..."




        # Kill GoogleUpdate.exe if it's running
        Write-Log -Message "Checking if GoogleUpdate.exe is running in the machine..."
        $googleUpdateProcesses = Get-Process -Name "GoogleUpdate" -ErrorAction SilentlyContinue
        if ($googleUpdateProcesses) {
            Write-Log -Message "GoogleUpdate.exe is running in the machine..."
            Stop-Process -Name "GoogleUpdate" -Force
            Write-Log -Message "Terminated GoogleUpdate.exe..."
        }
   
        Write-Log -Message "Now GoogleUpdate.exe is not running in the machine..."

        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'

        ## Handle Zero-Config MSI Uninstallations
        <#If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }#>

        ## <Perform Uninstallation tasks here>

            
        # Proceed to remove Google Chrome
        Write-Log -Message "*************************************************************"
        Write-Log -Message "Removal of Google Chrome started......."
        Write-Log -Message "*************************************************************"

        $RegUninstallPath = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
        )
        $UninstallSearchFilter = { ($_.GetValue('DisplayName') -like '*Google Chrome*') } 
        
        foreach ($Path in $RegUninstallPath) {
            if (Test-Path -Path $Path) {
                Get-ChildItem $Path | Where-Object $UninstallSearchFilter | 
                ForEach-Object {
                Execute-MSI -Action 'Uninstall' -Path "$($_.PSChildName)" -Parameters '/qn' -LogName "LUM0190_Google_Chrome_147.0.7727.56-R01_EN"                     

                }
            }
        }

        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'

        ## <Perform Post-Uninstallation tasks here>

        $FolderName1 = "$envProgramFiles\Google\Chrome"
        if (Test-Path $FolderName1) {
        Remove-Folder -Path "$envProgramFiles\Google\Chrome"
        }

        $FolderName2 = "$envProgramFilesX86\Google\Update"
        if (Test-Path $FolderName2) {
        Remove-Folder -Path "$envProgramFilesX86\Google\Update*"
        }
      
        Audit-Key -Action "Delete"


    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [String]$installPhase = 'Pre-Repair'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Repair tasks here>

        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [String]$installPhase = 'Repair'

        ## Handle Zero-Config MSI Repairs
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }
        ## <Perform Repair tasks here>

        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [String]$installPhase = 'Post-Repair'

        ## <Perform Post-Repair tasks here>


    }
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [Int32]$mainExitCode = 60001
    [String]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
