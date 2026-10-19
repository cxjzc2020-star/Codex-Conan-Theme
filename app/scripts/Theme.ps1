[CmdletBinding()]
param(
    [ValidateSet('Start','Restore','Doctor','Plain')][string]$Action = 'Doctor',
    [string]$ResultPath,
    [string]$StateRoot
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Core.ps1')
if ($StateRoot) {
    if (-not [IO.Path]::IsPathRooted($StateRoot)) { throw 'StateRoot must be absolute.' }
    $script:ConanStateRoot = [IO.Path]::GetFullPath($StateRoot)
}
. (Join-Path $script:ConanRoot 'vendor\codex-dynamic-skin\scripts\common-windows.ps1')
# The unmodified upstream helpers use PowerShell's normal empty-output semantics.
Set-StrictMode -Off
. (Join-Path $PSScriptRoot 'Wait-Cdp.ps1')
. (Join-Path $PSScriptRoot 'WindowGate.ps1')
. (Join-Path $PSScriptRoot 'Resume.ps1')
. (Join-Path $PSScriptRoot 'Network.ps1')
$env:DREAMSKIN_COMPAT_PROFILE = '0'
$injector = Join-Path $script:ConanRoot 'vendor\codex-dynamic-skin\scripts\injector.mjs'
$stateFile = Join-Path $script:ConanStateRoot 'session.json'
$pauseFile = Join-Path $script:ConanStateRoot 'paused'
$mutex = $null
$ownsMutex = $false
$launchedAppPid = 0
$windowGate = $null

function Invoke-ConanInjector {
    param([string[]]$Arguments)
    $result = Invoke-DreamSkinNative -FilePath $node -ArgumentList (@($injector) + $Arguments)
    if ($result.ExitCode -ne 0) {
        $details = $result.Output -join "`n"
        $exception = New-Object InvalidOperationException('壁纸引擎尚未通过界面校验，请切换至 Codex 页面后重试。')
        if ($details -match 'No verified Codex renderer|No page matched the expected Codex shell markers') {
            $exception.Data['ConanWaitingForRenderer'] = $true
        }
        [void][IO.Directory]::CreateDirectory($script:ConanStateRoot)
        [IO.File]::WriteAllText((Join-Path $script:ConanStateRoot 'verification-error.log'), $details)
        throw $exception
    }
    return ($result.Output -join "`n")
}

try {
    $settings = Read-ConanSettings
    $codex = Get-DreamSkinCodexInstall
    if ($Action -eq 'Doctor') {
        $node = Get-ConanNode
        $running = @(Get-DreamSkinCodexProcesses -Codex $codex).Count -gt 0
        $identity = Get-ConanManagedCdpIdentity -Port $settings.port -Codex $codex -Profile (Join-Path $script:ConanStateRoot 'profile')
        [pscustomobject]@{
            appVersion=$codex.Version; nodeReady=$true; running=$running
            cdpReady=($null -ne $identity); port=$settings.port
            introConfigured=[bool]$settings.introPath; wallpaperConfigured=[bool]$settings.wallpaperPath
            nextStep= $(if ($running -and -not $identity) { '保存工作并完全退出 Codex 后，通过本项目启动。首次使用独立配置可能需要重新登录。' } else { '在启动器中选择素材，然后启动。' })
        } | ConvertTo-Json
        exit 0
    }
    $mutex = New-Object Threading.Mutex($false, 'Local\CodexConanLauncher.Theme')
    try { $ownsMutex = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $ownsMutex = $true }
    if (-not $ownsMutex) { throw '另一个主题操作正在进行，请稍后重试。' }

    if ($Action -eq 'Plain') {
        if($settings.useSystemProxy){$null = Enable-ConanLaunchProxy}
        $null = Start-DreamSkinCodex -Codex $codex
        if ($ResultPath) { Write-ConanStatus $ResultPath 'success' '已普通打开 Codex。选择壁纸后可启用主题。' }
        exit 0
    }
    if ($Action -eq 'Restore') {
        $node = Get-ConanNode
        [IO.Directory]::CreateDirectory($script:ConanStateRoot) | Out-Null
        [IO.File]::WriteAllText($pauseFile, 'paused')
        if (-not (Test-Path -LiteralPath $stateFile)) {
            if ($ResultPath) { Write-ConanStatus $ResultPath 'success' '没有受管的主题会话。' }
            exit 0
        }
        $session = Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $restoreMessage = '原主题会话已结束；当前窗口没有被修改。'
        $verifiedSession = Get-DreamSkinVerifiedCdpIdentityForAnyRegistered -Port $session.port
        $identity = if ($verifiedSession) { $verifiedSession.Identity } else { $null }
        if ($identity -and $identity.BrowserId -ceq $session.browserId) {
            # Leave the watcher paused so reload registrations are removed by its own loop.
            # Keeping it alive until Codex exits avoids terminating it halfway through cleanup.
            Start-Sleep -Milliseconds 2600
            $null = Invoke-ConanInjector -Arguments @('--remove','--port',"$($session.port)",'--browser-id',$identity.BrowserId,'--timeout-ms','5000')
            # The contrast monitor observes the same pause marker and removes its
            # styles and reload registrations while its CDP sessions are alive.
            $restoreMessage = '已暂停壁纸并恢复界面。完全退出 Codex 后，调试端口也会关闭。'
        } elseif (-not $identity -and @(Get-DreamSkinCodexProcesses -Codex $codex).Count -gt 0) {
            throw '无法验证原主题会话，暂停请求已保存。请完全退出主题 Codex 窗口，以确保壁纸和调试连接关闭。'
        }
        if ($ResultPath) { Write-ConanStatus $ResultPath 'success' $restoreMessage }
        exit 0
    }

    if(Test-Path -LiteralPath (Join-Path $script:ConanStateRoot 'disabled')){
        $null=Start-DreamSkinCodex -Codex $codex
        if($ResultPath){Write-ConanStatus $ResultPath 'success' '主题已停用，已普通打开 Codex。运行“启用主题”可以重新启用。'}
        exit 0
    }
    $profile = Join-Path $script:ConanStateRoot 'profile'
    $network = if($settings.useSystemProxy){Enable-ConanLaunchProxy}else{[pscustomobject]@{mode='disabled';changed=$false}}
    $identity = Get-ConanManagedCdpIdentity -Port $settings.port -Codex $codex -Profile $profile
    if (-not $identity -and @(Get-DreamSkinCodexProcesses -Codex $codex).Count -gt 0) {
        $null = Start-DreamSkinCodex -Codex $codex
        if ($ResultPath) { Write-ConanStatus $ResultPath 'success' '已切回正在运行的 Codex。主题启动会在应用完全退出后的下一次启动生效。' }
        exit 0
    }
    $node = Get-ConanNode
    $coldStart = $false
    if($identity){
        if($ResultPath){Write-ConanStatus $ResultPath 'working' '正在恢复原主题窗口，后台任务继续运行…'}
        $identity=Resume-ConanManagedSession -Port $settings.port -Codex $codex -Profile $profile -BrowserId $identity.BrowserId
    }
    if ($ResultPath) { Write-ConanStatus $ResultPath 'working' '正在校验本地壁纸…' }
    $theme = $null
    if ($settings.wallpaperPath) {
    $prepared = Invoke-DreamSkinNative -FilePath $node -ArgumentList @(
        (Join-Path $script:ConanRoot 'src\prepare-theme.mjs'),$settings.wallpaperPath,$script:ConanStateRoot
    )
    if ($prepared.ExitCode -ne 0) { throw "素材校验失败：$($prepared.Output -join ' ')" }
    $theme = ($prepared.Output -join "`n") | ConvertFrom-Json
    }
    if (-not $identity) {
        $coldStart = $true
        Write-ConanJson (Join-Path $script:ConanStateRoot 'network-launch.json') @{
            mode=$network.mode; changed=$network.changed; appliedAt=[DateTime]::UtcNow.ToString('o')
        }
        if (-not (Test-DreamSkinPortAvailable -Port $settings.port)) { throw '主题端口被其他程序占用，请先检查端口。' }
        $profile = Join-Path $script:ConanStateRoot 'profile'
        [void][IO.Directory]::CreateDirectory($profile)
        if ($ResultPath) { Write-ConanStatus $ResultPath 'working' '正在启动主题会话。首次使用可能需要重新登录，并切换到 Codex 模式。' }
        # Launch only when no instance exists. No fallback that kills application processes.
        $launchArguments = @(
            '--remote-debugging-address=127.0.0.1',"--remote-debugging-port=$($settings.port)","--user-data-dir=$profile"
        )
        if($settings.introEnabled -and $settings.introPath){
            $gateDirectory=Join-Path $script:ConanStateRoot ('startup\'+[guid]::NewGuid().ToString('N'))
            $windowGate=Start-ConanWindowGate -Codex $codex -Arguments $launchArguments -Directory $gateDirectory
            $launchedAppPid=$windowGate.ProcessId
        }else{
            $launchedAppPid = Start-DreamSkinCodexDirect -Codex $codex -Arguments $launchArguments
        }
        $identity = Wait-ConanVerifiedCdp -Port $settings.port -Codex $codex
        if (-not $identity) { throw '当前 Codex 未开放可验证的调试接口。应用保持运行；主题接入未成功。' }
    }

    if ($coldStart -and $settings.introEnabled -and $settings.introPath) {
        if ($ResultPath) { Write-ConanStatus $ResultPath 'working' '正在连接原生启动页…' }
        $startupSettings = Join-Path $script:ConanStateRoot 'startup-settings.json'
        Write-ConanJson $startupSettings $settings
        $startup = Invoke-DreamSkinNative -FilePath $node -ArgumentList @(
            (Join-Path $script:ConanRoot 'src\startup.mjs'),"$($settings.port)",$identity.BrowserId,
            (Join-Path $codex.PackageRoot 'app\resources\app.asar'),$startupSettings
        )
        [IO.File]::WriteAllText((Join-Path $script:ConanStateRoot 'startup-result.log'),($startup.Output -join "`n"))
        if ($startup.ExitCode -ne 0) { throw '原生启动页未能接入。请查看 startup-result.log；当前应用没有被强制结束。' }
        Complete-ConanWindowGate $windowGate
    }
    if ($theme) {
        $contrastScript = Join-Path $script:ConanRoot 'src\control-contrast.mjs'
        $contrastOwnerPath = Join-Path $script:ConanStateRoot 'contrast-monitor.json'
        $contrastRunning = $false
        if (Test-Path -LiteralPath $contrastOwnerPath) {
            $owner = Get-Content -LiteralPath $contrastOwnerPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $existingContrast = Get-CimInstance Win32_Process -Filter "ProcessId = $([int]$owner.processId)" -ErrorAction SilentlyContinue
            $contrastRunning = $owner.browserId -ceq $identity.BrowserId -and $existingContrast -and
                (Test-DreamSkinPathEqual -Left $existingContrast.ExecutablePath -Right $node) -and
                (Test-DreamSkinCommandLineToken -CommandLine $existingContrast.CommandLine -Token $contrastScript) -and
                (Test-DreamSkinCommandLineToken -CommandLine $existingContrast.CommandLine -Token 'watch') -and
                (Test-DreamSkinCommandLineToken -CommandLine $existingContrast.CommandLine -Token $identity.BrowserId) -and
                ((Get-DreamSkinProcessStartedAt -ProcessId $owner.processId) -ceq $owner.startedAt)
        }
        if (-not $contrastRunning) {
            $contrastLog = [guid]::NewGuid().ToString('N')
            $contrastProcess = Start-Process -FilePath $node -ArgumentList (ConvertTo-DreamSkinArgumentLine -Arguments @(
                $contrastScript,'watch',"$($settings.port)",$identity.BrowserId,
                (Join-Path $script:ConanStateRoot 'contrast-watch-state.json'),$pauseFile
            )) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $script:ConanStateRoot "contrast-$contrastLog.log") -RedirectStandardError (Join-Path $script:ConanStateRoot "contrast-error-$contrastLog.log")
            Write-ConanJson $contrastOwnerPath @{browserId=$identity.BrowserId;processId=$contrastProcess.Id;startedAt=(Get-DreamSkinProcessStartedAt -ProcessId $contrastProcess.Id)}
        }
    }
    if (-not $theme) {
        if ($ResultPath) { Write-ConanStatus $ResultPath 'success' 'Codex 已启动，当前未启用壁纸。' }
        exit 0
    }
    $watcherAlreadyRunning = $false
    if (Test-Path -LiteralPath $stateFile) {
        $previous = Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($previous.browserId -ceq $identity.BrowserId) {
            # A live watcher is bound to one theme directory. Require an ordinary app exit
            # rather than killing the watcher and leaving reload scripts registered.
            $oldProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $([int]$previous.injectorPid)" -ErrorAction SilentlyContinue
            if ($oldProcess) {
                $expectedTheme = Join-Path $previous.themeDirectory 'theme.json'
                $sameTheme = (Test-Path -LiteralPath $expectedTheme) -and
                    (Test-DreamSkinPathEqual -Left $previous.themeDirectory -Right $theme.themeDirectory)
                $ourWatcher = (Test-DreamSkinPathEqual -Left $oldProcess.ExecutablePath -Right $node) -and
                    (Test-DreamSkinCommandLineToken -CommandLine $oldProcess.CommandLine -Token $injector) -and
                    (Test-DreamSkinCommandLineToken -CommandLine $oldProcess.CommandLine -Token '--watch') -and
                    (Test-DreamSkinCommandLineToken -CommandLine $oldProcess.CommandLine -Token $previous.themeDirectory) -and
                    (Test-DreamSkinCommandLineToken -CommandLine $oldProcess.CommandLine -Token $identity.BrowserId)
                if ($previous.PSObject.Properties.Name -contains 'injectorStartedAt') {
                    $ourWatcher = $ourWatcher -and ((Get-DreamSkinProcessStartedAt -ProcessId $previous.injectorPid) -ceq $previous.injectorStartedAt)
                }
                if (-not $sameTheme -or -not $ourWatcher) { throw '更换壁纸前请完全退出 Codex，再从启动器打开。' }
                $watcherAlreadyRunning = $true
                $theme.themeDirectory = $previous.themeDirectory
            }
        }
    }
    if (-not $watcherAlreadyRunning) {
      # Save a recoverable session before allowing the watcher to change the renderer.
      [IO.File]::WriteAllText($pauseFile, 'paused')
      $logSuffix = [guid]::NewGuid().ToString('N')
      $watcher = Start-Process -FilePath $node -ArgumentList (ConvertTo-DreamSkinArgumentLine -Arguments @(
        $injector,'--watch','--port',"$($settings.port)",'--browser-id',$identity.BrowserId,
        '--theme-dir',$theme.themeDirectory,'--pause-file',$pauseFile
    )) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $script:ConanStateRoot "engine-$logSuffix.log") `
       -RedirectStandardError (Join-Path $script:ConanStateRoot "engine-error-$logSuffix.log")
    $session = [ordered]@{
        port=$settings.port; browserId=$identity.BrowserId; injectorPid=$watcher.Id
        themeDirectory=$theme.themeDirectory; injectorPath=$injector; nodePath=$node
        injectorStartedAt=(Get-DreamSkinProcessStartedAt -ProcessId $watcher.Id)
    }
      Write-ConanJson $stateFile $session
    }
    if(Test-Path -LiteralPath (Join-Path $script:ConanStateRoot 'disabled')){
        if($ResultPath){Write-ConanStatus $ResultPath 'success' '主题已在启动期间停用，后台任务保持运行。'}
        exit 0
    }
    if (Test-Path -LiteralPath $pauseFile) { [IO.File]::Delete($pauseFile) }
    if ($ResultPath) { Write-ConanStatus $ResultPath 'working' '引擎已启动，正在等待 Codex 界面。若出现登录页，请先完成登录。' }
    $null = Invoke-ConanInjector -Arguments @('--verify','--port',"$($settings.port)",'--browser-id',$identity.BrowserId,
        '--theme-dir',$theme.themeDirectory,'--timeout-ms','8000')
    if ($ResultPath) { Write-ConanStatus $ResultPath 'success' '壁纸已应用并通过引擎界面校验。' }
} catch {
    if ($Action -eq 'Start' -and $_.Exception.Data['ConanWaitingForRenderer'] -and $ResultPath) {
        Write-ConanStatus $ResultPath 'waiting' '主题会话已启动，正在等待登录或 Codex 页面。完成后再点击启动以校验壁纸。'
        exit 0
    }
    if ($ResultPath) { Write-ConanStatus $ResultPath 'error' $_.Exception.Message }
    else { Write-Error $_.Exception.Message }
    exit 1
} finally {
    Complete-ConanWindowGate $windowGate
    if ($ownsMutex -and $mutex) { $mutex.ReleaseMutex() }
    if ($mutex) { $mutex.Dispose() }
}
