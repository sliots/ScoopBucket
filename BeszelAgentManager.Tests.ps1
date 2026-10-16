BeforeAll {
    if (!$env:SCOOP_HOME) { $env:SCOOP_HOME = Resolve-Path (scoop prefix scoop) }
    . "$env:SCOOP_HOME\lib\core.ps1"
    . "$env:SCOOP_HOME\lib\manifest.ps1"
    . "$env:SCOOP_HOME\lib\install.ps1"
    . "$env:SCOOP_HOME\lib\shortcuts.ps1"

    $manifest = Get-Content "$PSScriptRoot\bucket\BeszelAgentManager.json" -Raw | ConvertFrom-Json
    $originalProgramFiles = $env:ProgramW6432
    $env:ProgramW6432 = Join-Path $TestDrive 'Program Files'
    $applicationRoot = Join-Path $env:ProgramW6432 'BeszelAgentManager'
    $application = Join-Path $applicationRoot 'app\BeszelAgentManager.exe'
    $uninstallerPath = Join-Path $applicationRoot 'unins000.exe'
}

AfterAll {
    $env:ProgramW6432 = $originalProgramFiles
}

Describe 'BeszelAgentManager installation lifecycle' {
    BeforeEach {
        $dir = Join-Path $TestDrive 'Scoop Apps\BeszelAgentManager\4.21.2'
        $cmd = 'install'
        $global = $false
        New-Item -Path $dir, (Split-Path $application) -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath $application -Value 'test application' -Encoding UTF8
        Set-Content -LiteralPath $uninstallerPath -Value 'test uninstaller' -Encoding UTF8

        Mock Invoke-ExternalCommand { $true }
        Mock startmenu_shortcut {}
        Mock shortcut_folder { Join-Path $TestDrive 'Start Menu\Scoop Apps' }
    }

    It 'uses the official installer directory and records an installation log' {
        $installerName = 'BeszelAgentManagerSetup.exe'
        $installerPath = Join-Path $dir $installerName
        Set-Content -LiteralPath $installerPath -Value 'test installer' -Encoding UTF8

        Invoke-Installer -Path $dir -Name $installerName -Manifest $manifest -ProcessorArchitecture '64bit' -AppName 'BeszelAgentManager'

        Should -Invoke Invoke-ExternalCommand -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq $installerPath -and
            !($ArgumentList -match '^/DIR=') -and
            $ArgumentList -contains "/LOG=$dir\install.log" -and
            $ArgumentList -contains '/NORESTART'
        }
    }

    It 'creates the <Scope> shortcut pointing directly into Program Files' -ForEach @(
        @{ Scope = 'user'; IsGlobal = $false }
        @{ Scope = 'global'; IsGlobal = $true }
    ) {
        $global = $IsGlobal

        Invoke-HookScript -HookType 'post_install' -Manifest $manifest -ProcessorArchitecture '64bit'

        Should -Invoke startmenu_shortcut -Times 1 -Exactly -ParameterFilter {
            $target.FullName -eq $application -and $shortcutName -eq 'BeszelAgentManager' -and $global -eq $IsGlobal
        }
    }

    It 'fails installation when the official application is missing' {
        Remove-Item -LiteralPath $application

        { Invoke-HookScript -HookType 'post_install' -Manifest $manifest -ProcessorArchitecture '64bit' } |
            Should -Throw '*was not installed*install.log*'
        Should -Invoke startmenu_shortcut -Times 0
    }

    It 'runs the official uninstaller with elevation and a log path containing spaces' {
        $cmd = 'uninstall'

        Invoke-Installer -Path $dir -Manifest $manifest -ProcessorArchitecture '64bit' -AppName 'BeszelAgentManager' -Uninstall

        Should -Invoke Invoke-ExternalCommand -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq $uninstallerPath -and $RunAs -and
            $ArgumentList -contains "/LOG=$dir\uninstall.log" -and
            $ArgumentList -contains '/VERYSILENT' -and
            $ArgumentList -contains '/NORESTART'
        }
    }

    It 'keeps the official installation in place during Scoop updates' {
        $cmd = 'update'

        Invoke-Installer -Path $dir -Manifest $manifest -ProcessorArchitecture '64bit' -AppName 'BeszelAgentManager' -Uninstall

        Should -Invoke Invoke-ExternalCommand -Times 0
        $application | Should -Exist
        $uninstallerPath | Should -Exist
    }

    It 'allows Scoop cleanup after the application was removed outside Scoop' {
        $cmd = 'uninstall'
        Remove-Item -LiteralPath $uninstallerPath

        Invoke-Installer -Path $dir -Manifest $manifest -ProcessorArchitecture '64bit' -AppName 'BeszelAgentManager' -Uninstall

        Should -Invoke Invoke-ExternalCommand -Times 0
    }

    It 'stops uninstall cleanup when elevation is cancelled or the native uninstaller fails' {
        $cmd = 'uninstall'
        Mock Invoke-ExternalCommand { $false }

        { Invoke-Installer -Path $dir -Manifest $manifest -ProcessorArchitecture '64bit' -AppName 'BeszelAgentManager' -Uninstall } |
            Should -Throw '*uninstallation failed*uninstall.log*'
    }

    It 'removes only the manager shortcut after uninstall' {
        $shortcutRoot = shortcut_folder $global
        New-Item -Path $shortcutRoot -ItemType Directory -Force | Out-Null
        $managerShortcut = Join-Path $shortcutRoot 'BeszelAgentManager.lnk'
        $otherShortcut = Join-Path $shortcutRoot 'Other application.lnk'
        Set-Content -LiteralPath $managerShortcut -Value 'manager shortcut' -Encoding UTF8
        Set-Content -LiteralPath $otherShortcut -Value 'other shortcut' -Encoding UTF8

        Invoke-HookScript -HookType 'post_uninstall' -Manifest $manifest -ProcessorArchitecture '64bit'

        $managerShortcut | Should -Not -Exist
        $otherShortcut | Should -Exist
        Should -Invoke shortcut_folder -ParameterFilter { $global -eq $false }
    }
}
