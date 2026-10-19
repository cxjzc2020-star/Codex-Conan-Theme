# A background Codex browser can legitimately have zero page targets after the
# last window closes. Verify the original executable, loopback port and exact
# private profile before accepting that browser as our managed session.
function Get-ConanManagedCdpIdentity {
    param([int]$Port,[object]$Codex,[string]$Profile)
    if(-not(Test-DreamSkinCodexPortOwner -Port $Port -Codex $Codex)){return $null}
    $listeners=@(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
    if($listeners.Count -eq 0){return $null}
    foreach($listener in $listeners){
        $owner=Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$listener.OwningProcess)" -ErrorAction SilentlyContinue
        if(-not $owner -or -not(Test-DreamSkinPathEqual -Left $owner.ExecutablePath -Right $Codex.Executable) -or
            -not(Test-DreamSkinCommandLineToken -CommandLine $owner.CommandLine -Token "--user-data-dir=$Profile")){return $null}
    }
    $browser=Get-DreamSkinCdpBrowserIdentity -Port $Port
    if(-not $browser){return $null}
    # Recheck ownership after the HTTP exchange to reject a replaced listener.
    if(-not(Test-DreamSkinCodexPortOwner -Port $Port -Codex $Codex)){return $null}
    return [pscustomobject]@{
        BrowserId=$browser.BrowserId;BrowserWebSocketDebuggerUrl=$browser.WebSocketDebuggerUrl
        Browser=$browser.Browser;TargetCount=@(Get-DreamSkinCdpTargets -Port $Port).Count
    }
}

function Resume-ConanManagedSession {
    param([int]$Port,[object]$Codex,[string]$Profile,[string]$BrowserId)
    $before=Get-ConanManagedCdpIdentity -Port $Port -Codex $Codex -Profile $Profile
    if(-not $before -or $before.BrowserId -cne $BrowserId){throw '原主题后台会话已变化，未唤起其他程序。'}
    # Sending the exact same user-data-dir reaches Electron's existing instance
    # and requests its own normal window activation. Never activate AppsFolder
    # here: it omits this profile and can open an unthemed default session.
    $null=Start-DreamSkinCodexDirect -Codex $Codex -Arguments @(
        '--remote-debugging-address=127.0.0.1',"--remote-debugging-port=$Port","--user-data-dir=$Profile"
    )
    $after=Wait-ConanVerifiedCdp -Port $Port -Codex $Codex -Seconds 12
    if(-not $after -or $after.BrowserId -cne $BrowserId){throw '后台会话尚未恢复窗口；没有关闭正在运行的任务。'}
    return $after
}
