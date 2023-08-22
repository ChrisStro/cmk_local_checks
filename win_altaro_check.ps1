$ApiBaseUrl         = "http://localhost:35113/api" # is only accessible from host
$Username           = "USERWITHLOCALADMINRIGHTS"
$Password           = "PASSWORD"
$Domain             = "DOMAIN"
$AltaroCmdletsPath  = "C:\Program Files\Altaro\Altaro Backup\Cmdlets"

# Internal Functions
function Start-AltaroApiSession {
    $uri = $ApiBaseUrl + "/sessions/start"
    $body = @{
        ServerAddress   = "LOCALHOST";
        ServerPort      = "35107";
        Username        = $username;
        Password        = $password;
        Domain          = $domain
    }
    $result = Invoke-RestMethod -Uri $uri `
        -Method Post -ContentType "application/json" `
        -Body (ConvertTo-Json $body)
    if ($result.Success) {
        $Script:AlatroToken = $result.data
    } else {
        throw $result
    }
}
function Stop-AltaroApiSession {
    $uri = $ApiBaseUrl + "/sessions/end/" + $Script:AlatroToken
    $result = Invoke-RestMethod -Uri $uri `
        -Method Post -ContentType "application/json"
    if (!$result.Success) {
        throw $result
    }
}

# Guard functions
if (-not (Test-Path -Path $AltaroCmdletsPath)) {
    Write-Warning "Could not find builtin altaro  Cmdlets"
    break
}

# Load helper function for checkmk output
. $PSScriptRoot\win_helper.ps1

# Override Write-Host with Write-Output to get data into pipeline from BuiltIn Altaro CMDLETS
New-Alias -Name Write-Host -Value Write-Output

# main
Start-AltaroApiSession
$ConfiguredAltaroVms    = & $AltaroCmdletsPath\GetVirtualMachines.ps1 $Script:AlatroToken | ConvertFrom-Json | Select-Object -ExpandProperty VirtualMachines | Where-Object Configured -eq $true
Stop-AltaroApiSession

$CMKServices            = $ConfiguredAltaroVms | foreach-object {
    $cmkSplatt          = @{
        State           = if ($_.LastBackupResult -eq "Success") { [cmkstatus]::OK } else { [cmkstatus]::CRIT }
        Service         = "Altaro VM Backup: $($_.VirtualMachineName)"
        Detail          = "VM: $($_.VirtualMachineName) Host: $($_.HostName) Duration: $($_.LastBackupDuration) Result: $($_.LastBackupResult)"
    }
    New-CheckmkService @cmkSplatt
}

# Output
$CMKServices | Write-CMKOutput