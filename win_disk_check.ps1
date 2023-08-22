$CMK_VERSION = "2.2.0p7"

# Load helper function for checkmk output
. $PSScriptRoot\win_helper.ps1

$disks = get-disk
$output = $disks | ForEach-Object {
    $cmkSplatt = @{
        State = if ($_.HealthStatus -ne "Healthy"){3}else{0}
        Service = $_.FriendlyName
        Detail = $_.FriendlyName + " with " + $_.SerialNumber + " is " + $_.HealthStatus
    }
    New-CheckmkService @cmkSplatt
}
$output | Write-CMKOutput