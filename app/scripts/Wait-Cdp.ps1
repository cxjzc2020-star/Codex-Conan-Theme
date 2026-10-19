# Readiness polling is cheap HTTP only. Process/port ownership is still verified
# by the existing helper before any renderer mutation is permitted.
function Wait-ConanVerifiedCdp {
    param([int]$Port,[object]$Codex,[int]$Seconds=35)
    $deadline=(Get-Date).AddSeconds($Seconds)
    do {
        $response=$null
        try {
            $request=[Net.HttpWebRequest]::Create("http://127.0.0.1:$Port/json/list")
            $request.Proxy=$null; $request.AllowAutoRedirect=$false
            $request.Timeout=300; $request.ReadWriteTimeout=300
            $response=$request.GetResponse()
            $reader=New-Object IO.StreamReader($response.GetResponseStream())
            try {
                $buffer=New-Object char[] 2097153
                $count=$reader.ReadBlock($buffer,0,$buffer.Length)
                if($count -ge $buffer.Length){throw 'Readiness response too large.'}
                $targets=(-join $buffer[0..([Math]::Max(0,$count-1))]) | ConvertFrom-Json
            } finally { $reader.Dispose() }
            if(@($targets | Where-Object {$_.type -eq 'page' -and $_.url -like 'app://*'}).Count -gt 0) {
                $verified=Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $Codex
                if($verified){return $verified}
            }
        } catch { }
        finally { if($response){$response.Dispose()} }
        Start-Sleep -Milliseconds 120
    } while((Get-Date) -lt $deadline)
    return $null
}
