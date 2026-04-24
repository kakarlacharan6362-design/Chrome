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
    [String]$appName = 'ChromeBeta'
    [String]$appVersion = '147.0.7727.3'
    [String]$appArch = ''
    [String]$appLang = 'EN'
    [String]$appRevision = ''
    [String]$appScriptVersion = '1.0.0'
    [String]$appScriptDate = '13/03/2026'
    [String]$appScriptAuthor = 'Charan k'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [String]$installName = ''
    [String]$installTitle = ''

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

        $items = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object {($_.DisplayName -like "Google Chrome Beta")}

        $DisplayVersion = $items.DisplayVersion
        $GUID = $items.PSChildName


        Write-Log -Message "`"$DisplayVersion`" Value"
        Write-Log -Message "`"$GUID`" Value"

        $ChromeBetaver = "147.0.7727.3"

        if ([Version]$DisplayVersion -lt [Version]$ChromeBetaver) { 

            if ((gwmi win32_operatingsystem | select osarchitecture).osarchitecture -eq "64-bit")
            {

                Write-Log -Message " 64bit Installation"

                TASKKILL /F /IM "chrome.exe"

                Execute-MSI -Action 'Install' -Path "$dirFiles\googlechromebetastandaloneenterprise64.msi" -Transform "$dirFiles\Google_ChromeBeta_147.0.7727.3_x64_EN.Mst" -Parameters '/qn /norestart' -LogName 'Google_ChromeBeta_147.0.7727.3_x64_EN'

                If (Test-Path -path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{8237E44A-0054-442C-B6B6-EA0509993955}")
                {                                                                               

                Remove-Item -path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{8237E44A-0054-442C-B6B6-EA0509993955}" -Force -Recurse
                }
            }

            else 
            {

                Write-Log -Message " 32bit Installation"

                TASKKILL /F /IM "chrome.exe"

                Execute-MSI -Action 'Install' -Path "$dirFiles\googlechromebetastandaloneenterprise.msi" -Transform "$dirFiles\Google_ChromeBeta_147.0.7727.3_x86_EN.Mst" -Parameters '/qn /norestart' -LogName 'Google_ChromeBeta_147.0.7727.3_x86_EN'

                If (Test-Path -path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Active Setup\Installed Components\{8237E44A-0054-442C-B6B6-EA0509993955}"){
                                                                                                                                                                                              
                Remove-Item -path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Active Setup\Installed Components\{8237E44A-0054-442C-B6B6-EA0509993955}" -Force -Recurse
                }
            }

        }



        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'

        ## <Perform Post-Installation tasks here>

        $items = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object {($_.DisplayName -like "Google Chrome Beta")}

        $DisplayVersion = $items.DisplayVersion

        if ([Version]$DisplayVersion -ge [Version]$ChromeBetaver) 
        {

            Write-Log -Message " Installation Sucessful "
                
            New-Item -Path "HKLM:\Software" -Name "" -erroraction silentlycontinue
            New-Item -Path "HKLM:\Software\" -Name "GoogleChromeBeta" -erroraction silentlycontinue
            Set-ItemProperty -Path "HKLM:\Software\\GoogleChromeBeta" -Name "Version"  -Type String -Value "147.0.7727.3" -erroraction silentlycontinue

            Write-Log -Message " Detection registry added successfully "
                
        }

        else 
        {

            Write-Log -Message " Installation failed"
                
            Exit 69001
                
        }

        #Audit-Key -Action "Create"

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

        if ((test-path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{7A604C90-3628-3B89-AB24-FE3DAF0C0BB8}") -or (test-path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{B0EC609F-EFB8-3E5E-A25D-9916641A2B52}")) {

            if ((gwmi win32_operatingsystem | select osarchitecture).osarchitecture -eq "64-bit")  {

                Write-Log -Message " 64bit Uninstallation"

                Execute-MSI -Action 'Uninstall' -Path '{7A604C90-3628-3B89-AB24-FE3DAF0C0BB8}' -Parameters '/qn ' -LogName 'Google_ChromeBeta_147.0.7727.3_x64_EN'
            }


            else {

                Write-Log -Message " 32bit Uninstallation"

                Execute-MSI -Action 'Uninstall' -Path '{B0EC609F-EFB8-3E5E-A25D-9916641A2B52}' -Parameters '/qn ' -LogName 'Google_ChromeBeta_147.0.7727.3_x64_EN'
            }


        }


        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'

        ## <Perform Post-Uninstallation tasks here>


        if (-NOT ((test-path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{7A604C90-3628-3B89-AB24-FE3DAF0C0BB8}") -or (test-path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{B0EC609F-EFB8-3E5E-A25D-9916641A2B52}"))) {

            Write-Log -Message " Uninstallation Sucessfull "
                
            Remove-Item -Path "HKLM:\Software\\GoogleChromeBeta" -force

            Write-Log -Message " Detection registry removed successfully "

        }
                
        else {

            Write-Log -Message " Uninstallation failed"
                
            Exit 69001
                
        }

        #Audit-Key -Action "Delete"


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
