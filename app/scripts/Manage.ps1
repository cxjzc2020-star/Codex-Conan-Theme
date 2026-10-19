[CmdletBinding()]
param(
    [ValidateSet('Enable','Restore','Status')][string]$Action='Status',
    [switch]$UseSystemProxy,
    [switch]$NoLaunch,
    [string]$DesktopDirectory=[Environment]::GetFolderPath('Desktop'),
    [string]$ProgramsDirectory=[Environment]::GetFolderPath('Programs'),
    [string]$StateRoot
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Core.ps1')
if ($StateRoot) { $script:ConanStateRoot=[IO.Path]::GetFullPath($StateRoot) }
$activationPath=Join-Path $script:ConanStateRoot 'activation.json'
$disabledPath=Join-Path $script:ConanStateRoot 'disabled'
$activation=if(Test-Path -LiteralPath $activationPath){Get-Content -LiteralPath $activationPath -Raw -Encoding UTF8 | ConvertFrom-Json}else{$null}
if($Action -eq 'Status'){
    [pscustomobject]@{enabled=(-not(Test-Path -LiteralPath $disabledPath) -and $null -ne $activation -and $activation.enabled);installed=($null -ne $activation);root=$script:ConanRoot} | ConvertTo-Json
    exit 0
}
$mutex=New-Object Threading.Mutex($false,'Local\CodexConanLauncher.Manage')
$owns=$false
try{
    try{$owns=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$owns=$true}
    if(-not $owns){throw '另一个启用或恢复操作正在运行，请稍后重试。'}
    # The user explicitly ran this package's entry point. Remove download marks
    # from its PowerShell helpers only; never change the machine execution policy.
    Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File | Unblock-File
    Get-ChildItem -LiteralPath (Join-Path $script:ConanRoot 'vendor') -Filter '*.ps1' -File -Recurse | Unblock-File
    if($Action -eq 'Enable'){
        # Validate before changing shortcuts or an existing theme installation.
        . (Join-Path $script:ConanRoot 'vendor\codex-dynamic-skin\scripts\common-windows.ps1')
        Set-StrictMode -Off
        $null=Get-DreamSkinCodexInstall
        $null=Get-ConanNode
        if(-not(Test-Path -LiteralPath (Join-Path $script:ConanRoot 'ConanLauncher.exe'))){
            & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $PSScriptRoot 'Build-Launcher.ps1')
            if($LASTEXITCODE -ne 0){throw '启动程序编译失败，请查看上方提示。'}
        }
        foreach($relative in @('ConanLauncher.exe','media\startup.mp4','media\wallpaper.png')){
            if(-not(Test-Path -LiteralPath (Join-Path $script:ConanRoot $relative) -PathType Leaf)){throw "发布包缺少文件，请完整解压：$relative"}
        }
        $settingsPath=Join-Path $script:ConanStateRoot 'settings.json'
        $settings=Read-ConanSettings
        if($UseSystemProxy){$settings.useSystemProxy=$true;Save-ConanSettings $settings}
        elseif(-not(Test-Path -LiteralPath $settingsPath)){Save-ConanSettings $settings}
        & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $PSScriptRoot 'Entrypoints.ps1') -Action Install -DesktopDirectory $DesktopDirectory -ProgramsDirectory $ProgramsDirectory -StateRoot $script:ConanStateRoot | Out-Null
        if($LASTEXITCODE -ne 0){throw '快捷方式安装失败，原始备份已保留。可运行“恢复默认”撤销已完成的变更。'}
        Write-ConanJson $activationPath @{schemaVersion=1;enabled=$true;installRoot=$script:ConanRoot;updatedAt=[DateTime]::UtcNow.ToString('o')}
        if(Test-Path -LiteralPath $disabledPath){[IO.File]::Delete($disabledPath)}
        if(Test-Path -LiteralPath (Join-Path $script:ConanStateRoot 'paused')){[IO.File]::Delete((Join-Path $script:ConanStateRoot 'paused'))}
        Write-Output '主题已启用并保存。以后从桌面或开始菜单的 Codex 图标打开即可。'
        Write-Output '若 Codex 已在运行，请等任务完成后通过“文件 → 退出”完全退出，再打开以应用开场。后台任务没有被结束。'
        if(-not $NoLaunch){
            $null=Start-Process -FilePath (Join-Path $script:ConanRoot 'ConanLauncher.exe') -ArgumentList '--start' -WindowStyle Hidden -PassThru
        }
    }else{
        # Disable first so an old taskbar pin cannot re-enable the theme.
        [void][IO.Directory]::CreateDirectory($script:ConanStateRoot)
        [IO.File]::WriteAllText($disabledPath,'disabled')
        [IO.File]::WriteAllText((Join-Path $script:ConanStateRoot 'paused'),'paused')
        $cleanupFailed=$false
        if(Test-Path -LiteralPath (Join-Path $script:ConanStateRoot 'session.json')){
            & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $PSScriptRoot 'Theme.ps1') -Action Restore -StateRoot $script:ConanStateRoot
            $cleanupFailed=$LASTEXITCODE -ne 0
        }
        & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $PSScriptRoot 'Entrypoints.ps1') -Action Restore -DesktopDirectory $DesktopDirectory -ProgramsDirectory $ProgramsDirectory -StateRoot $script:ConanStateRoot | Out-Null
        if($LASTEXITCODE -ne 0){throw '快捷方式被其他程序修改，已保留现状和备份。主题已经停用，请查看上方提示。'}
        Write-ConanJson $activationPath @{schemaVersion=1;enabled=$false;installRoot=$script:ConanRoot;updatedAt=[DateTime]::UtcNow.ToString('o')}
        Write-Output '主题已停用，原快捷方式已恢复。登录、聊天和个人设置均保留。'
        Write-Output '请等任务完成后通过“文件 → 退出”完全退出，再正常打开 Codex，完成恢复。'
        if($cleanupFailed){throw '活动界面的主题清理尚未通过验证。后续启动已停用主题，请完全退出 Codex 完成清理。'}
    }
}catch{
    Write-Error $_
    exit 1
}finally{
    if($owns){$mutex.ReleaseMutex()}
    $mutex.Dispose()
}
