# Sends AT commands to the watch and prints every byte that comes back, as a hex dump and as text.
# Read-only probe: it does NOT send AT+WRX=mass, so the serial port stays open and we can read replies.
# The payload suffix 00 64 00 61 is copied from the factory tool.
param(
    [Parameter(Mandatory = $true)][string[]]$Commands,
    [int]$ReadMs = 2500
)

$dev = Get-CimInstance Win32_PnPEntity |
    Where-Object { $_.PNPDeviceID -match 'VID_10D6' -and $_.Name -match '\((COM\d+)\)' } |
    Select-Object -First 1
if (-not $dev) { throw "No Actions USB serial port found. Set USB mode to Charging mode." }
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
    Start-Sleep -Milliseconds 400
    $null = $port.ReadExisting()
    foreach ($text in $Commands) {
        "=== $text"
        $bytes = [Text.Encoding]::ASCII.GetBytes($text) + [byte[]](0x00, 0x64, 0x00, 0x61)
        $port.Write($bytes, 0, $bytes.Length)
        $buf = New-Object System.Collections.Generic.List[byte]
        $deadline = (Get-Date).AddMilliseconds($ReadMs)
        while ((Get-Date) -lt $deadline) {
            try {
                while ($port.BytesToRead -gt 0) {
                    $buf.Add([byte]$port.ReadByte())
                    $deadline = (Get-Date).AddMilliseconds($ReadMs)
                }
            }
            catch { break }
            Start-Sleep -Milliseconds 40
        }
        $arr = $buf.ToArray()
        "bytes: $($arr.Count)"
        if ($arr.Count -gt 0) {
            $txt = ([Text.Encoding]::ASCII.GetString($arr) -replace "`r", "\r" -replace "`n", "\n`n")
            "text: $txt"
            $hex = ($arr | Select-Object -First 256 | ForEach-Object { $_.ToString('x2') }) -join ' '
            "hex : $hex"
        }
    }
}
finally {
    try { if ($port.IsOpen) { $port.Close() } } catch { }
}
