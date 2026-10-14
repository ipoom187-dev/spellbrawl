# Puts a picture the user sent onto a card: centre-crops it square, resizes to 512x512 and saves art/<id>.jpg
# (replacing any older art/<id>.png|jpg|webp so the new picture is the one the game shows).
#
#   powershell -ExecutionPolicy Bypass -File tools\add-art.ps1 -Image "C:\path\to\picture.jpg" -Id kobang
#   powershell -ExecutionPolicy Bypass -File tools\add-art.ps1 -Image "C:\path\to\picture.jpg" -Name "Squidzilla the Elder"
param(
  [Parameter(Mandatory)][string]$Image,
  [string]$Id = '',
  [string]$Name = '',      # card name as shown in the game (looked up in index.html when -Id is not given)
  [int]$Size = 512
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
$art = Join-Path $root 'art'

if (-not $Id) {
  if (-not $Name) { throw 'Give -Id <card id> or -Name "<card name>".' }
  $html = [IO.File]::ReadAllText((Join-Path $root 'index.html'), [Text.Encoding]::UTF8)
  $esc = [regex]::Escape($Name.Replace("'", "\'"))
  $m = [regex]::Matches($html, "(?:def|fam)\('([A-Za-z0-9_]+)',\s*\{\s*name:\s*['`"]$esc['`"]")
  if ($m.Count -ne 1) { throw "Card name '$Name' matched $($m.Count) cards; pass -Id instead." }
  $Id = $m[0].Groups[1].Value
}
if ($Id -notmatch '^[A-Za-z0-9_]+$') { throw "Bad card id '$Id'." }

$img = [Drawing.Image]::FromFile((Resolve-Path $Image))
try {
  $s = [Math]::Min($img.Width, $img.Height)
  $src = New-Object Drawing.Rectangle([int](($img.Width - $s) / 2), [int](($img.Height - $s) / 2), $s, $s)
  $bmp = New-Object Drawing.Bitmap($Size, $Size)
  $g = [Drawing.Graphics]::FromImage($bmp); $g.InterpolationMode = 'HighQualityBicubic'
  $g.DrawImage($img, (New-Object Drawing.Rectangle(0, 0, $Size, $Size)), $src, 'Pixel')
  foreach ($ext in 'png', 'jpg', 'jpeg', 'webp') { $old = Join-Path $art "$Id.$ext"; if (Test-Path $old) { Remove-Item $old -Force } }
  $out = Join-Path $art "$Id.jpg"
  $enc = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
  $ep = New-Object Drawing.Imaging.EncoderParameters(1)
  $ep.Param[0] = New-Object Drawing.Imaging.EncoderParameter([Drawing.Imaging.Encoder]::Quality, [long]88)
  $bmp.Save($out, $enc, $ep)
  $g.Dispose(); $bmp.Dispose()
  $crop = if ($img.Width -ne $img.Height) { ' (centre-cropped to square)' } else { '' }
  Write-Host "saved art/$Id.jpg  ${Size}x${Size} from $($img.Width)x$($img.Height)$crop"
} finally { $img.Dispose() }
