# Renders the Hebrew screen and icon as PNG, because the watch app fonts have no Hebrew glyphs.
# Font: Varela Round (SIL Open Font License), see design/OFL.txt.
param([string]$Out, [string]$FontFile)
Add-Type -AssemblyName System.Drawing
$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$pfc.AddFontFile($FontFile)
$family = $pfc.Families[0]
function Heb([int[]]$c) { [string]::Join('', [char[]]$c) }
function New-Fmt { $f = New-Object System.Drawing.StringFormat([System.Drawing.StringFormatFlags]::DirectionRightToLeft); $f.Alignment = 'Center'; $f.LineAlignment = 'Center'; $f }
function Color($r, $g, $b, $a = 255) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }
function New-G($bmp) { $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'; $g }
function Rounded($x, $y, $w, $h, $r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $p.AddArc($x, $y, 2*$r, 2*$r, 180, 90); $p.AddArc($x+$w-2*$r, $y, 2*$r, 2*$r, 270, 90)
  $p.AddArc($x+$w-2*$r, $y+$h-2*$r, 2*$r, 2*$r, 0, 90); $p.AddArc($x, $y+$h-2*$r, 2*$r, 2*$r, 90, 90); $p.CloseFigure(); $p
}
function Star($g, $cx, $cy, $r, $brush) {
  $pts = New-Object 'System.Drawing.PointF[]' 8
  for ($i = 0; $i -lt 8; $i++) { $a = $i * [Math]::PI / 4; $d = if ($i % 2) { $r * 0.32 } else { $r }; $pts[$i] = New-Object System.Drawing.PointF(($cx + $d * [Math]::Cos($a)), ($cy + $d * [Math]::Sin($a))) }
  $g.FillPolygon($brush, $pts)
}
function Text($g, $t, $size, $y, $brush, $style = 'Regular') {
  $font = New-Object System.Drawing.Font($family, $size, [System.Drawing.FontStyle]::$style, [System.Drawing.GraphicsUnit]::Pixel)
  $g.DrawString($t, $font, $brush, (New-Object System.Drawing.RectangleF(0, ($y - 45), 466, 90)), (New-Fmt))
}

$bmp = New-Object System.Drawing.Bitmap 466, 466
$g = New-G $bmp
$rect = New-Object System.Drawing.Rectangle(0, 0, 466, 466)
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, (Color 59 31 140), (Color 214 51 132), 60.0)
$g.FillRectangle($bg, $rect)
$g.FillEllipse((New-Object System.Drawing.SolidBrush (Color 255 255 255 18)), -70, -90, 300, 300)
$g.FillEllipse((New-Object System.Drawing.SolidBrush (Color 255 200 80 26)), 250, 270, 280, 280)
$ring = New-Object System.Drawing.Pen((Color 255 214 90), 6)
$g.DrawEllipse($ring, 9, 9, 448, 448)

$gold = New-Object System.Drawing.SolidBrush (Color 255 214 90)
$white = [System.Drawing.Brushes]::White
$mint = New-Object System.Drawing.SolidBrush (Color 120 240 210)
$ink = New-Object System.Drawing.SolidBrush (Color 59 31 140)
foreach ($s in @(@(92,150,13),@(380,132,16),@(66,270,9),@(402,282,11),@(150,62,8),@(322,70,9))) { Star $g $s[0] $s[1] $s[2] $gold }

# Small watch drawing
$g.FillPath($mint, (Rounded 218 40 30 20 6)); $g.FillPath($mint, (Rounded 218 106 30 20 6))
$g.FillEllipse($white, 197, 47, 72, 72)
$g.FillEllipse($ink, 205, 55, 56, 56)
$hand = New-Object System.Drawing.Pen((Color 255 214 90), 5); $hand.StartCap = 'Round'; $hand.EndCap = 'Round'
$g.DrawLine($hand, 233, 83, 233, 66); $g.DrawLine($hand, 233, 83, 246, 91)

Text $g (Heb 0x05DC,0x05DE,0x05D9,0x20,0x05D6,0x05D4,0x20,0x05E9,0x05D9,0x05D9,0x05DA,0x3F) 44 170 $gold
$g.FillPath($white, (Rounded 88 208 290 56 28))
Text $g (Heb 0x05DE,0x05E6,0x05D0,0x05EA,0x20,0x05D0,0x05EA,0x20,0x05D4,0x05E9,0x05E2,0x05D5,0x05DF,0x3F) 32 236 $ink
Text $g (Heb 0x05D4,0x05E9,0x05E2,0x05D5,0x05DF,0x20,0x05E9,0x05D9,0x05D9,0x05DA) 32 300 $white
Text $g (Heb 0x05DC,0x05D0,0x05D1,0x05D9,0x05D2,0x05D3,0x05D5,0x05E8) 54 362 $gold 'Bold'
$bmp.Save("$Out\screen.png", [System.Drawing.Imaging.ImageFormat]::Png)

$ic = New-Object System.Drawing.Bitmap 192, 192
$h = New-G $ic; $h.Clear([System.Drawing.Color]::Transparent)
$ib = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, 192, 192)), (Color 59 31 140), (Color 214 51 132), 60.0)
$h.FillEllipse($ib, 4, 4, 184, 184)
$f = New-Object System.Drawing.Font($family, 124, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$h.DrawString('?', $f, $gold, (New-Object System.Drawing.RectangleF(0, 0, 192, 192)), (New-Fmt))
$ic.Save("$Out\icon.png", [System.Drawing.Imaging.ImageFormat]::Png)
