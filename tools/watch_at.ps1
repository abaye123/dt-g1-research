# Sends AT commands to a DT G1 (ATS3085S / Glyphix) in "Charging mode".
# Usage: watch_at.ps1 -Commands "AT+WRX=always","AT+WRX=saveMenu"
# The port is found by the Actions USB vendor id. Payload suffix 00 64 00 61 is
# copied from the factory tool; without it the watch only echoes "OK".
param(
    [Parameter(Mandatory = $true)][string[]]$Commands,
    [int]$DelayMs = 1500
)

$dev = Get-CimInstance Win32_PnPEntity |
    Where-Object { $_.PNPDeviceID -match 'VID_10D6' -and $_.Name -match '\((COM\d+)\)' } |
    Select-Object -First 1
if (-not $dev) { throw "No Actions USB serial port found. Is USB mode set to Charging mode?" }
$null = $dev.Name -match '\((COM\d+)\)'
$name = $Matches[1]
"Port: $name"

$port = New-Object System.IO.Ports.SerialPort $name, 2000000, ([System.IO.Ports.Parity]::None), 8, ([System.IO.Ports.StopBits]::One)
$port.ReadTimeout = 500
$port.WriteTimeout = 500
$port.DtrEnable = $true
$port.RtsEnable = $true
$port.Open()
try {
    Start-Sleep -Milliseconds 500
    $null = $port.ReadExisting()
    foreach ($text in $Commands) {
        $bytes = [Text.Encoding]::ASCII.GetBytes($text) + [byte[]](0x00, 0x64, 0x00, 0x61)
        $port.Write($bytes, 0, $bytes.Length)
        Start-Sleep -Milliseconds $DelayMs
        try {
            $reply = $port.ReadExisting()
            "$text -> [" + ($reply -replace "`r", "\r" -replace "`n", "\n") + "]"
        }
        catch {
            # Expected after AT+WRX=mass: the watch drops the serial port.
            "$text -> port closed by watch"
        }
    }
}
finally {
    try { if ($port.IsOpen) { $port.Close() } } catch { }
}
