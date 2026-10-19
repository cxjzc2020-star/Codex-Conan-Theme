# Chromium reads Windows' proxy settings, but the native chat transport may not.
# Pass an existing local system proxy to this launch's children only.
function Get-ConanProxyEndpoint {
    param([bool]$Enabled, [string]$Server)
    if (-not $Enabled -or [string]::IsNullOrWhiteSpace($Server)) { return $null }
    $candidate = $Server.Trim()
    if ($candidate.Contains('=')) {
        $entries = @{}
        foreach ($entry in $candidate.Split(';')) {
            $pair = $entry.Split('=', 2)
            if ($pair.Count -eq 2) { $entries[$pair[0].Trim().ToLowerInvariant()] = $pair[1].Trim() }
        }
        if ($entries.ContainsKey('https')) { $candidate = $entries['https'] }
        elseif ($entries.ContainsKey('http')) { $candidate = $entries['http'] }
        else { return $null }
    }
    if ($candidate -notmatch '^[a-z]+://') { $candidate = 'http://' + $candidate }
    $uri = $null
    if (-not [Uri]::TryCreate($candidate, [UriKind]::Absolute, [ref]$uri)) { return $null }
    $address = $null
    $loopback = $uri.DnsSafeHost -eq 'localhost' -or
        ([Net.IPAddress]::TryParse($uri.DnsSafeHost, [ref]$address) -and [Net.IPAddress]::IsLoopback($address))
    if ($uri.Scheme -ne 'http' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment -or
        $uri.AbsolutePath -ne '/' -or $uri.Port -lt 1 -or
        -not $loopback) { return $null }
    return $uri.GetLeftPart([UriPartial]::Authority)
}

function Enable-ConanLaunchProxy {
    param([object]$InternetSettings)
    foreach ($name in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY')) {
        if ([Environment]::GetEnvironmentVariable($name, 'Process')) {
            return [pscustomobject]@{ mode = 'existing-environment'; changed = $false }
        }
    }
    if ($null -eq $InternetSettings) {
        $InternetSettings = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
    }
    $enabled = $InternetSettings -and $InternetSettings.ProxyEnable -eq 1
    $server = if ($InternetSettings) { [string]$InternetSettings.ProxyServer } else { '' }
    $endpoint = Get-ConanProxyEndpoint -Enabled ([bool]$enabled) -Server $server
    if (-not $endpoint) { return [pscustomobject]@{ mode = 'unchanged'; changed = $false } }
    foreach ($name in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY')) {
        [Environment]::SetEnvironmentVariable($name, $endpoint, 'Process')
    }
    $bypass = @([Environment]::GetEnvironmentVariable('NO_PROXY', 'Process') -split ',' | Where-Object { $_ })
    foreach ($hostName in @('localhost', '127.0.0.1', '::1')) {
        if ($bypass -notcontains $hostName) { $bypass += $hostName }
    }
    [Environment]::SetEnvironmentVariable('NO_PROXY', ($bypass -join ','), 'Process')
    return [pscustomobject]@{ mode = 'system-loopback'; changed = $true; endpoint = $endpoint }
}
