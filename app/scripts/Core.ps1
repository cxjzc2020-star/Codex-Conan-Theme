Set-StrictMode -Version 3.0
$script:ConanRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:ConanStateRoot = Join-Path $env:LOCALAPPDATA 'CodexConanLauncher'

function Get-ConanDefaultSettings {
    return [pscustomobject]@{
        schemaVersion = 1
        introPath = ''
        wallpaperPath = ''
        introEnabled = $true
        muted = $true
        maxSeconds = 6
        port = 9347
        useBundledIntro = $true
        useBundledWallpaper = $true
        useSystemProxy = $false
    }
}

function Assert-ConanSettings {
    param([object]$Settings)
    $expected = @('schemaVersion','introPath','wallpaperPath','introEnabled','muted','maxSeconds','port')
    foreach ($key in $expected) {
        if ($Settings.PSObject.Properties.Name -notcontains $key) { throw "设置缺少字段：$key" }
    }
    if ($Settings.schemaVersion -ne 1) { throw '不支持的设置版本。' }
    if ($Settings.introEnabled -isnot [bool] -or $Settings.muted -isnot [bool]) { throw '动画开关必须是布尔值。' }
    if ($Settings.maxSeconds -isnot [int] -or $Settings.maxSeconds -lt 1 -or $Settings.maxSeconds -gt 30) { throw '开场时长须为 1–30 秒的整数。' }
    if ($Settings.port -isnot [int] -or $Settings.port -lt 1024 -or $Settings.port -gt 65535) { throw '端口须为 1024–65535。' }
    foreach ($key in @('useBundledIntro','useBundledWallpaper','useSystemProxy')) {
        if ($Settings.PSObject.Properties.Name -contains $key -and $Settings.$key -isnot [bool]) { throw '内置素材开关必须是布尔值。' }
    }
    foreach ($key in @('introPath','wallpaperPath')) {
        $value = $Settings.$key
        if ($value -isnot [string]) { throw '素材路径必须是文本。' }
        if ($value -and (-not [IO.Path]::IsPathRooted($value) -or $value.StartsWith('\\') -or $value -match '^[a-z]+://')) {
            throw '请选择本机磁盘上的素材文件。'
        }
    }
}

function Write-ConanJson {
    param([string]$Path, [object]$Value)
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path))
    $tempPath = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    $encoding = New-Object Text.UTF8Encoding($false)
    try {
        [IO.File]::WriteAllText($tempPath, ($Value | ConvertTo-Json -Depth 10), $encoding)
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($tempPath, $Path, [System.Management.Automation.Language.NullString]::Value) }
        else { [IO.File]::Move($tempPath, $Path) }
    } finally {
        if ([IO.File]::Exists($tempPath)) { [IO.File]::Delete($tempPath) }
    }
}

function Read-ConanSettings {
    $settingsPath = Join-Path $script:ConanStateRoot 'settings.json'
    $settings = if (Test-Path -LiteralPath $settingsPath) {
        Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } else { Get-ConanDefaultSettings }
    Assert-ConanSettings $settings
    # Migrate the original schema without losing explicitly selected custom media.
    if ($settings.PSObject.Properties.Name -notcontains 'useBundledIntro') {
        $settings | Add-Member -NotePropertyName useBundledIntro -NotePropertyValue (-not $settings.introPath)
    }
    if ($settings.PSObject.Properties.Name -notcontains 'useBundledWallpaper') {
        $settings | Add-Member -NotePropertyName useBundledWallpaper -NotePropertyValue (-not $settings.wallpaperPath)
    }
    # Existing installations already used the verified local proxy workaround.
    # Fresh installations use Get-ConanDefaultSettings and default to off.
    if ($settings.PSObject.Properties.Name -notcontains 'useSystemProxy') {
        $settings | Add-Member -NotePropertyName useSystemProxy -NotePropertyValue $true
    }
    Resolve-ConanBundledMedia $settings
    return $settings
}

function Resolve-ConanBundledMedia {
    param([object]$Settings)
    if ($Settings.useBundledIntro) {
        $Settings.introPath = ''
        foreach ($filename in @('startup.mp4','startup.gif')) {
            $candidate = Join-Path $script:ConanRoot "media\$filename"
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { $Settings.introPath = $candidate; break }
        }
    }
    if ($Settings.useBundledWallpaper) {
        $Settings.wallpaperPath = ''
        foreach ($filename in @('wallpaper.mp4','wallpaper.webm','wallpaper.jpg','wallpaper.png','wallpaper.webp')) {
            $candidate = Join-Path $script:ConanRoot "media\$filename"
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { $Settings.wallpaperPath = $candidate; break }
        }
    }
}

function Test-ConanBundledMediaPath {
    param([string]$Path, [ValidateSet('Intro','Wallpaper')][string]$Kind)
    $defaults = Get-ConanDefaultSettings
    Resolve-ConanBundledMedia $defaults
    $expected = if ($Kind -eq 'Intro') { $defaults.introPath } else { $defaults.wallpaperPath }
    return [bool]($Path -and $expected -and [IO.Path]::GetFullPath($Path) -ieq [IO.Path]::GetFullPath($expected))
}

function Get-ConanOperationResult {
    param([string]$Path, [bool]$HasExited, [int]$ExitCode = 0)
    $result = $null
    if ($Path -and (Test-Path -LiteralPath $Path -PathType Leaf)) {
        try {
            $result = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($result.state -notin @('working','waiting','success','error') -or $result.message -isnot [string]) { $result = $null }
        } catch { $result = $null }
    }
    if ($HasExited -and (-not $result -or $result.state -eq 'working' -or ($ExitCode -ne 0 -and $result.state -eq 'success'))) {
        return [pscustomobject]@{state='error'; message='操作未正常完成。请重试，或查看本机引擎日志。'}
    }
    if ($result) { return $result }
    return [pscustomobject]@{state='working'; message='正在处理…'}
}

function Save-ConanSettings {
    param([object]$Settings)
    Assert-ConanSettings $Settings
    Write-ConanJson -Path (Join-Path $script:ConanStateRoot 'settings.json') -Value $Settings
}

function Get-ConanNode {
    $candidates = @((Join-Path $script:ConanRoot 'runtime\node.exe'))
    $command = Get-Command node.exe -ErrorAction SilentlyContinue
    if ($command) { $candidates += $command.Source }
    $candidates += Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Get-DreamSkinValidatedNodeRuntime -Path $candidate -MinimumMajor 22).Path
        }
    }
    throw '未找到 Node.js 22+。请安装 Node.js，或将可信的 node.exe 放到项目 runtime 目录。'
}

function Write-ConanStatus {
    param([string]$Path, [string]$State, [string]$Message)
    Write-ConanJson -Path $Path -Value ([ordered]@{state=$State;message=$Message})
}
