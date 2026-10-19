[CmdletBinding()]
param(
    [ValidateSet('Install','Restore','Inspect')][string]$Action='Inspect',
    [string]$DesktopDirectory=[Environment]::GetFolderPath('Desktop'),
    [string]$ProgramsDirectory=[Environment]::GetFolderPath('Programs'),
    [string]$StateRoot
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Core.ps1')
if ($StateRoot) { $script:ConanStateRoot=[IO.Path]::GetFullPath($StateRoot) }
$entry=Join-Path $script:ConanRoot 'ConanLauncher.exe'
$backupRoot=Join-Path $script:ConanStateRoot 'entrypoints'
$manifestPath=Join-Path $backupRoot 'manifest.json'
$shell=New-Object -ComObject WScript.Shell
$explorer=New-Object -ComObject Shell.Application
function Get-LinkTarget([string]$Path) {
    $link=$shell.CreateShortcut($Path)
    if ($link.TargetPath) { return $link.TargetPath }
    $folder=$explorer.NameSpace([IO.Path]::GetDirectoryName($Path))
    $item=$folder.ParseName([IO.Path]::GetFileName($Path))
    return [string]$item.ExtendedProperty('System.Link.TargetParsingPath')
}
function Get-LinkHash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Test-OurLink([string]$Path) {
    $candidate=$shell.CreateShortcut($Path)
    return $candidate.TargetPath -ieq $entry -and $candidate.Arguments -ceq '--start'
}
function Test-OfficialLink([string]$Path) {
    $target=Get-LinkTarget $Path
    return $target -ieq $appId -or $target -ieq $codex.Executable
}
function Move-Link([string]$Source,[string]$Destination) {
    if ([IO.File]::Exists($Destination)) { [IO.File]::Replace($Source,$Destination,[System.Management.Automation.Language.NullString]::Value) }
    else { [IO.File]::Move($Source,$Destination) }
}
$manifest=if (Test-Path -LiteralPath $manifestPath) { Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { [pscustomobject]@{version=1;links=@()} }
if ($Action -eq 'Inspect') { $manifest | ConvertTo-Json -Depth 8; exit 0 }
if ($Action -eq 'Restore') {
    foreach ($record in $manifest.links) {
        if ($record.restored) { continue }
        if (Test-Path -LiteralPath $record.path) {
            $current=Get-LinkHash $record.path
            if ($record.originalExists -and $current -ceq $record.originalHash) { $record.restored=$true; continue }
            if ($current -cne $record.installedHash) { throw "快捷方式已被另外修改，保留现状：$($record.path)" }
        } elseif (-not $record.originalExists) { $record.restored=$true; continue }
        if ($record.originalExists) {
            if ((Get-LinkHash $record.backupPath) -cne $record.originalHash) { throw '快捷方式备份校验失败。' }
            $temp=$record.path+'.'+[guid]::NewGuid().ToString('N')+'.lnk'
            [IO.File]::Copy($record.backupPath,$temp)
            Move-Link $temp $record.path
        } else { [IO.File]::Delete($record.path) }
        $record.restored=$true
        Write-ConanJson $manifestPath $manifest
    }
    Write-ConanJson $manifestPath $manifest
    Write-Output '已恢复本项目接管的快捷方式。'
    exit 0
}
if (-not (Test-Path -LiteralPath $entry)) { throw '请先编译 ConanLauncher.exe。' }
. (Join-Path $script:ConanRoot 'vendor\codex-dynamic-skin\scripts\common-windows.ps1')
Set-StrictMode -Off
$codex=Get-DreamSkinCodexInstall
$appId=$codex.AppUserModelId
if (-not $appId) { $appId='OpenAI.Codex_2p2nqsd0c76g0!App' }
[void][IO.Directory]::CreateDirectory($backupRoot)
$icon=Join-Path $script:ConanRoot 'assets\codex.ico'
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($icon))
$packageIcon=Join-Path $codex.PackageRoot 'app\resources\icon-chatgpt.ico'
if (Test-Path -LiteralPath $packageIcon) { [IO.File]::WriteAllBytes($icon,[IO.File]::ReadAllBytes($packageIcon)) }
if (-not (Test-Path -LiteralPath $icon)) { throw '未找到可保存的官方图标。' }
[void][IO.Directory]::CreateDirectory($DesktopDirectory)
[void][IO.Directory]::CreateDirectory($ProgramsDirectory)
$desktopLinks=@(Get-ChildItem -LiteralPath $DesktopDirectory -Filter '*.lnk' -File | Where-Object { (Test-OfficialLink $_.FullName) -or (Test-OurLink $_.FullName) })
$targets=@($desktopLinks | ForEach-Object {$_.FullName})
$targets+=@($manifest.links | Where-Object {-not $_.restored -and [IO.Path]::GetDirectoryName($_.path) -ieq $DesktopDirectory} | ForEach-Object {$_.path})
if ($targets.Count -eq 0) { $targets=@(Join-Path $DesktopDirectory 'Codex.lnk') }
# Include already managed links so repeated installation is idempotent.
$targets+=@($manifest.links | Where-Object {-not $_.restored} | ForEach-Object {$_.path})
$targets+=Join-Path $ProgramsDirectory 'Codex.lnk'
$targets=@($targets | Select-Object -Unique)
foreach ($target in $targets) {
    $record=@($manifest.links | Where-Object {$_.path -ieq $target -and -not $_.restored}) | Select-Object -First 1
    if ($record) {
        if (Test-Path -LiteralPath $target) {
            if ((Get-LinkHash $target) -cne $record.installedHash) { throw "快捷方式发生变化，未覆盖：$target" }
            if ((Test-OurLink $target) -and ($shell.CreateShortcut($target)).IconLocation -ieq ($icon+',0')) { continue }
        }
    }
    $exists=Test-Path -LiteralPath $target
    if ($exists -and -not $record -and -not(Test-OfficialLink $target) -and -not (Test-OurLink $target)) { throw "同名快捷方式属于其他程序，未覆盖：$target" }
    if($exists -and -not $record -and (Test-OurLink $target)){throw '发现没有备份记录的受管快捷方式。请先恢复官方快捷方式，再启用主题。'}
    $backup=Join-Path $backupRoot ([guid]::NewGuid().ToString('N')+'.lnk')
    $originalHash=''
    if ($exists -and -not $record) { [IO.File]::Copy($target,$backup); $originalHash=Get-LinkHash $backup }
    $temp=Join-Path ([IO.Path]::GetDirectoryName($target)) ([guid]::NewGuid().ToString('N')+'.lnk')
    try {
        $link=$shell.CreateShortcut($temp)
        $link.TargetPath=$entry; $link.Arguments='--start'; $link.WorkingDirectory=$script:ConanRoot
        $link.Description='Codex · 柯南开场与壁纸'
        $link.IconLocation=$icon+',0'
        $link.Save()
        if ((Get-LinkTarget $temp) -ine $entry) { throw '快捷方式目标校验失败。' }
        if ($record) { $record.installedHash=Get-LinkHash $temp }
        else {
            $record=[pscustomobject]@{path=$target;originalExists=[bool]$exists;backupPath=$backup;originalHash=$originalHash;installedHash=(Get-LinkHash $temp);restored=$false}
            $manifest.links=@($manifest.links)+@($record)
        }
        # Journal before replacing the entry so its original bytes are recoverable.
        Write-ConanJson $manifestPath $manifest
        Move-Link $temp $target
        if ((Get-LinkHash $target) -cne $record.installedHash) { throw '安装后的快捷方式校验失败。' }
    } finally { if(Test-Path -LiteralPath $temp){[IO.File]::Delete($temp)} }
}
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class ConanShellIcons { [DllImport("shell32.dll")] public static extern void SHChangeNotify(uint e,uint f,IntPtr a,IntPtr b); }'
[ConanShellIcons]::SHChangeNotify(0x08000000,0,[IntPtr]::Zero,[IntPtr]::Zero)
$manifest | ConvertTo-Json -Depth 8
