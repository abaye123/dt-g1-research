# Keeps the watch available in ADFU download mode (10d6:10d6) for a while, so Zadig
# has an unhurried window to bind WinUSB. Whenever the watch is in Charging mode
# (serial, PID B00A), it re-sends AT+WRX=adfu. It never sends any write/erase command.
param([int]$Seconds = 150)

function Send-Adfu($name) {
    $port = New-Object System.IO.Ports.SerialPort $name, 2000000, ([System.IO.Ports.Parity]::None), 8, ([System.IO.Ports.StopBits]::One)
    $port.ReadTimeout = 400; $port.WriteTimeout = 400; $port.DtrEnable = $true; $port.RtsEnable = $true
    try {
        $port.Open()
        $bytes = [Text.Encoding]::ASCII.GetBytes('AT+WRX=adfu') + [byte[]](0x00, 0x64, 0x00, 0x61)
        $port.Write($bytes, 0, $bytes.Length)
        Start-Sleep -Milliseconds 300
    } catch { } finally { try { if ($port.IsOpen) { $port.Close() } } catch { } }
}

$deadline = (Get-Date).AddSeconds($Seconds)
$last = ''
while ((Get-Date) -lt $deadline) {
    $adfu = Get-CimInstance Win32_PnPEntity -Filter "DeviceID like '%VID_10D6&PID_10D6%'" -ErrorAction SilentlyContinue
    $com  = Get-CimInstance Win32_PnPEntity -Filter "DeviceID like '%VID_10D6&PID_B00A%'" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '\((COM\d+)\)' }
    $mass = Get-CimInstance Win32_PnPEntity -Filter "DeviceID like '%VID_10D6&PID_B00B%'" -ErrorAction SilentlyContinue
    if ($adfu) {
        $winusb = $adfu.Service -eq 'WinUSB'
        $state = if ($winusb) { 'ADFU+WinUSB(bound!)' } else { 'ADFU(no driver yet)' }
        if ($state -ne $last) { "{0:HH:mm:ss} {1}" -f (Get-Date), $state; $last = $state }
        if ($winusb) { "WinUSB is bound - stopping keepalive so the port is free for the dump."; break }
    }
    elseif ($com) {
        if ($last -ne 'charging->sending adfu') { "{0:HH:mm:ss} charging mode, sending adfu" -f (Get-Date); $last = 'charging->sending adfu' }
        $m = $com.Name -match '\((COM\d+)\)'; Send-Adfu $Matches[1]
    }
    elseif ($mass) {
        if ($last -ne 'mass') { "{0:HH:mm:ss} MASS STORAGE - cannot re-send adfu from here (no serial). Set Charging mode." -f (Get-Date); $last = 'mass' }
    }
    Start-Sleep -Milliseconds 1200
}
"keepalive done"
