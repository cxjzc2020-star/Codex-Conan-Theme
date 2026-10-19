function Start-ConanWindowGate {
    param([object]$Codex,[string[]]$Arguments,[string]$Directory,[int]$TimeoutMs=15000)
    Assert-DreamSkinCodexDirectLaunchTarget -Codex $Codex
    $helper=Join-Path $script:ConanRoot 'ConanLauncher.exe'
    if(-not(Test-Path -LiteralPath $helper)){throw 'Window gate helper is missing. Build the launcher again.'}
    [void][IO.Directory]::CreateDirectory($Directory)
    $state=Join-Path $Directory 'window-gate-state.json'
    $release=Join-Path $Directory 'window-gate-release'
    $config=Join-Path $Directory 'window-gate.json'
    Write-ConanJson $config @{executable=$Codex.Executable;arguments=(ConvertTo-DreamSkinArgumentLine -Arguments $Arguments);state=$state;release=$release;timeoutMs=$TimeoutMs}
    $helperProcess=Start-Process -FilePath $helper -ArgumentList (ConvertTo-DreamSkinArgumentLine -Arguments @('--window-gate',$config)) -WindowStyle Hidden -PassThru
    $deadline=(Get-Date).AddSeconds(4)
    do {
        if(Test-Path -LiteralPath $state){
            try{$status=Get-Content -LiteralPath $state -Raw -Encoding UTF8 | ConvertFrom-Json}catch{$status=$null}
            if($status.phase -eq 'error'){throw $status.error}
            if($status.pid -gt 0){return @{ProcessId=[int]$status.pid;Release=$release;State=$state;HelperId=$helperProcess.Id}}
        }
        if($helperProcess.HasExited){throw 'Window gate exited before startup.'}
        Start-Sleep -Milliseconds 25
    }while((Get-Date) -lt $deadline)
    throw 'Window gate startup timed out.'
}
function Complete-ConanWindowGate {
    param($Gate)
    if($Gate){[IO.File]::WriteAllText($Gate.Release,'ready')}
}
