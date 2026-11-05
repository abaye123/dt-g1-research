# Asks a DT G1 (ATS3085S / Glyphix) in "Charging mode" to expose its real disks over USB.
# Sends the same AT commands as the factory tool ser_set_real_u_py2.exe, to one port only.
# Payload suffix 00 64 00 61 is copied byte for byte from that tool.
param([string]$PortName = "COM8")

function Send-Command($port, [string]$text) {
    $bytes = [Text.Encoding]::ASCII.GetBytes($text) + [byte[]](0x00, 0x64, 0x00, 0x61)
    $port.Write($bytes, 0, $bytes.Length)
    Start-Sleep -Milliseconds 500
    $reply = $port.ReadExisting()
    "$text -> [" + ($reply -replace "`r", "\r" -replace "`n", "\n") + "]"
    return
}

$port = New-Object System.IO.Ports.SerialPort $PortName, 2000000, ([System.IO.Ports.Parity]::None), 8, ([System.IO.Ports.StopBits]::One)
$port.ReadTimeout = 500
$port.WriteTimeout = 500
$port.DtrEnable = $true
$port.RtsEnable = $true
$port.Open()
try {
    Start-Sleep -Milliseconds 500
    $null = $port.ReadExisting()
    Send-Command $port "AT+WRX=always"
    Send-Command $port "AT+WRX=realUpan"
    Send-Command $port "AT+WRX=mass"
}
finally {
    try { $port.Close() } catch { "close: $($_.Exception.Message)" }
}
