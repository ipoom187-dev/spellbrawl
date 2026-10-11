# Generates card art with the Google Gemini API from tools/art-prompts.tsv + tools/art-style.txt
# and saves each image as art/<id>.jpg (512x512, centre-cropped). Cards that already have art are skipped.
#
# Needs the key in an environment variable (set it yourself, never commit it):  setx GEMINI_API_KEY "..."
#
# Examples:
#   powershell -ExecutionPolicy Bypass -File tools\gen-art.ps1 -Limit 5            # first 5 cards without art
#   powershell -ExecutionPolicy Bypass -File tools\gen-art.ps1 -Only cthulhu,slippy -Force
#   powershell -ExecutionPolicy Bypass -File tools\gen-art.ps1                     # everything still missing
param(
  [string[]]$Only = @(),
  [int]$Limit = 0,
  [switch]$Force,
  [switch]$Retrim,                              # only re-crop existing art/*.jpg, no generation
  [string]$Model = 'gemini-2.5-flash-image',   # or e.g. imagen-4.0-generate-001
  [int]$Size = 512,
  [string]$Prompt = '',                         # one-off image (board, rug...) instead of cards: full prompt, no style added
  [string]$Name = '',                           # saved as art/<Name>.jpg
  [string]$Aspect = '1:1',                      # e.g. 16:9 for wide backgrounds
  [int]$Width = 1600                            # one-off images are resized to this width
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$key = $env:GEMINI_API_KEY
if (-not $key) { $key = [Environment]::GetEnvironmentVariable('GEMINI_API_KEY', 'User') }
if (-not $key) { Write-Host 'GEMINI_API_KEY is not set. Run: setx GEMINI_API_KEY "your-key" and reopen the terminal.' -ForegroundColor Red; exit 1 }

$root  = Split-Path $PSScriptRoot -Parent
$art   = Join-Path $root 'art'
$style = (Get-Content (Join-Path $PSScriptRoot 'art-style.txt') -Raw -Encoding UTF8).Trim()
$rows  = Import-Csv (Join-Path $PSScriptRoot 'art-prompts.tsv') -Delimiter "`t" -Encoding UTF8
$Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($Only.Count) { $rows = $rows | Where-Object { $Only -contains $_.id } }
if (-not $Force) {
  $rows = $rows | Where-Object { $id = $_.id; -not (@('png', 'jpg', 'jpeg', 'webp') | Where-Object { Test-Path (Join-Path $art "$id.$_") }) }
}
$rows = @($rows)
if ($Limit -gt 0) { $rows = @($rows | Select-Object -First $Limit) }
Write-Host "Cards to generate: $($rows.Count)  (model: $Model)"

function Get-ImageBytes([string]$prompt) {
  $headers = @{ 'x-goog-api-key' = $key }
  if ($Model -like 'imagen*') {
    $url  = "https://generativelanguage.googleapis.com/v1beta/models/${Model}:predict"
    $body = @{ instances = @(@{ prompt = $prompt }); parameters = @{ sampleCount = 1; aspectRatio = $Aspect } }
  } else {
    $url  = "https://generativelanguage.googleapis.com/v1beta/models/${Model}:generateContent"
    $body = @{ contents = @(@{ parts = @(@{ text = $prompt }) })
               generationConfig = @{ responseModalities = @('IMAGE'); imageConfig = @{ aspectRatio = $Aspect } } }
  }
  $json = [Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Depth 10))
  $res  = Invoke-RestMethod -Method Post -Uri $url -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $json -TimeoutSec 180
  if ($Model -like 'imagen*') { $b64 = $res.predictions[0].bytesBase64Encoded }
  else { $b64 = ($res.candidates[0].content.parts | Where-Object { $_.inlineData } | Select-Object -First 1).inlineData.data }
  if (-not $b64) { throw 'No image in the response (the prompt may have been blocked).' }
  [Convert]::FromBase64String($b64)
}

# The model sometimes adds a white margin and/or a dark frame line despite the prompt: find where the
# artwork really starts on each side (on a 128px thumbnail, for speed) and return that rectangle.
function Get-ContentRect($img) {
  $n = 128; $t = New-Object Drawing.Bitmap($img, $n, $n)
  $isBorder = {
    param($xs, $ys)
    $light = 0; $dark = 0; $cnt = 0
    foreach ($x in $xs) { foreach ($y in $ys) {
      $c = $t.GetPixel($x, $y); $v = ($c.R + $c.G + $c.B) / 3; $cnt++
      if ($v -gt 225) { $light++ } elseif ($v -lt 60) { $dark++ } } }
    ($light / $cnt -gt 0.85) -or ($dark / $cnt -gt 0.6) -or (($light + $dark) / $cnt -gt 0.92)
  }
  $max = [int]($n * 0.3); $all = 0..($n - 1)
  $l = 0; while ($l -lt $max -and (& $isBorder @($l) $all)) { $l++ }
  $r = 0; while ($r -lt $max -and (& $isBorder @($n - 1 - $r) $all)) { $r++ }
  $tp = 0; while ($tp -lt $max -and (& $isBorder $all @($tp))) { $tp++ }
  $b = 0; while ($b -lt $max -and (& $isBorder $all @($n - 1 - $b))) { $b++ }
  $t.Dispose()
  # A real margin/frame goes all the way round; a white subject touching one or two edges (e.g. a goose) is not one.
  if (-not ($l -and $r -and $tp -and $b)) { return New-Object Drawing.Rectangle(0, 0, $img.Width, $img.Height) }
  $pad = 2   # a little extra so no sliver of the frame line survives
  if ($l) { $l += $pad }; if ($r) { $r += $pad }; if ($tp) { $tp += $pad }; if ($b) { $b += $pad }
  $sx = $img.Width / $n; $sy = $img.Height / $n
  New-Object Drawing.Rectangle([int]($l * $sx), [int]($tp * $sy), [int](($n - $l - $r) * $sx), [int](($n - $tp - $b) * $sy))
}

function Save-Square([byte[]]$bytes, [string]$path) {
  $ms  = New-Object IO.MemoryStream(, $bytes)
  $img = [Drawing.Image]::FromStream($ms)
  $c   = Get-ContentRect $img
  $s   = [Math]::Min($c.Width, $c.Height)
  $src = New-Object Drawing.Rectangle([int]($c.X + ($c.Width - $s) / 2), [int]($c.Y + ($c.Height - $s) / 2), $s, $s)
  $bmp = New-Object Drawing.Bitmap($Size, $Size)
  $g   = [Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = 'HighQualityBicubic'
  $g.DrawImage($img, (New-Object Drawing.Rectangle(0, 0, $Size, $Size)), $src, 'Pixel')
  $enc = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
  $ep  = New-Object Drawing.Imaging.EncoderParameters(1)
  $ep.Param[0] = New-Object Drawing.Imaging.EncoderParameter([Drawing.Imaging.Encoder]::Quality, [long]88)
  $bmp.Save($path, $enc, $ep)
  $g.Dispose(); $bmp.Dispose(); $img.Dispose(); $ms.Dispose()
}

if ($Prompt) {   # one-off image: keep its aspect ratio, just resize to -Width
  if (-not $Name) { Write-Host 'Give -Name too (saved as art/<Name>.jpg).' -ForegroundColor Red; exit 1 }
  $ms  = New-Object IO.MemoryStream(, (Get-ImageBytes $Prompt))
  $img = [Drawing.Image]::FromStream($ms)
  $h   = [int]($img.Height * $Width / $img.Width)
  $bmp = New-Object Drawing.Bitmap($Width, $h)
  $g   = [Drawing.Graphics]::FromImage($bmp); $g.InterpolationMode = 'HighQualityBicubic'
  $g.DrawImage($img, 0, 0, $Width, $h)
  $enc = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
  $ep  = New-Object Drawing.Imaging.EncoderParameters(1)
  $ep.Param[0] = New-Object Drawing.Imaging.EncoderParameter([Drawing.Imaging.Encoder]::Quality, [long]88)
  $out = Join-Path $art "$Name.jpg"; $bmp.Save($out, $enc, $ep)
  $g.Dispose(); $bmp.Dispose(); $img.Dispose(); $ms.Dispose()
  Write-Host "saved $out (${Width}x$h)" -ForegroundColor Green
  exit 0
}

if ($Retrim) {   # re-crop images already in art/ (no API calls)
  $files = Get-ChildItem $art -Filter *.jpg | Where-Object { $_.Name -ne 'board.jpg' -and (-not $Only.Count -or $Only -contains $_.BaseName) }
  foreach ($f in $files) { Save-Square ([IO.File]::ReadAllBytes($f.FullName)) $f.FullName; Write-Host "retrimmed $($f.BaseName)" }
  exit 0
}

$ok = 0; $failed = @()
$i = 0
foreach ($r in $rows) {
  $i++
  $prompt = "$($r.prompt). $style"
  $out = Join-Path $art "$($r.id).jpg"
  for ($try = 1; $try -le 4; $try++) {
    try {
      Save-Square (Get-ImageBytes $prompt) $out
      Write-Host "[$i/$($rows.Count)] $($r.id) ok" -ForegroundColor Green; $ok++; break
    } catch {
      $msg = $_.Exception.Message
      $code = 0; try { $code = [int]$_.Exception.Response.StatusCode } catch {}
      if (($code -eq 429 -or $code -ge 500) -and $try -lt 4) {
        $wait = 15 * $try; Write-Host "[$i] $($r.id): busy ($code), waiting ${wait}s..." -ForegroundColor Yellow; Start-Sleep $wait
      } else {
        Write-Host "[$i] $($r.id) FAILED: $msg" -ForegroundColor Red; $failed += $r.id; break
      }
    }
  }
  Start-Sleep -Milliseconds 800
}
Write-Host ""
Write-Host "Done: $ok generated, $($failed.Count) failed."
if ($failed.Count) { Write-Host "Retry with: -Only $($failed -join ',')" -ForegroundColor Yellow }
