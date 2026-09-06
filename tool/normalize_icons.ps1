# Normalizes launcher icon variant foregrounds so every glyph occupies the
# same fraction of the canvas (0.55 — matches classy/glassy), and regenerates
# the rainbow legacy mipmaps over the #080808 launcher background.
Add-Type -AssemblyName System.Drawing

function Get-BBox([System.Drawing.Bitmap]$bmp) {
    $minX = $bmp.Width; $minY = $bmp.Height; $maxX = -1; $maxY = -1
    for ($y = 0; $y -lt $bmp.Height; $y++) {
        for ($x = 0; $x -lt $bmp.Width; $x++) {
            if ($bmp.GetPixel($x, $y).A -gt 8) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    return @($minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1))
}

function Normalize-Foreground([string]$srcPath, [string]$outPath, [int]$canvas, [double]$targetRatio) {
    $src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $srcPath))
    $b = Get-BBox $src
    $scale = ($canvas * $targetRatio) / [math]::Max($b[2], $b[3])
    $nw = [int][math]::Round($b[2] * $scale)
    $nh = [int][math]::Round($b[3] * $scale)

    $out = New-Object System.Drawing.Bitmap($canvas, $canvas)
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $dst = New-Object System.Drawing.Rectangle([int](($canvas - $nw) / 2), [int](($canvas - $nh) / 2), $nw, $nh)
    $srcRect = New-Object System.Drawing.Rectangle($b[0], $b[1], $b[2], $b[3])
    $g.DrawImage($src, $dst, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    $src.Dispose()

    $out.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $out.Dispose()
    Write-Output "$outPath written (glyph ${nw}x${nh})"
}

function Make-LegacyMipmap([string]$fgPath, [string]$outPath, [int]$size) {
    $fg = [System.Drawing.Bitmap]::FromFile((Resolve-Path $fgPath))
    $out = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.Clear([System.Drawing.ColorTranslator]::FromHtml('#080808'))
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($fg, (New-Object System.Drawing.Rectangle(0, 0, $size, $size)))
    $g.Dispose()
    $fg.Dispose()

    $out.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $out.Dispose()
    Write-Output "$outPath written (${size}x${size})"
}

# 1. Rainbow foreground: normalize to 0.55 glyph ratio (was 0.93).
Normalize-Foreground 'assets\images\logo\vsync_foreground_rainbow.png' 'assets\images\logo\vsync_foreground_rainbow.png' 1024 0.55
Copy-Item 'assets\images\logo\vsync_foreground_rainbow.png' 'android\app\src\main\res\drawable-nodpi\ic_launcher_foreground_rainbow.png' -Force
Write-Output 'drawable-nodpi copy updated'

# 2. Default preview: transparent white-V foreground at the same 0.55 ratio
#    (replaces the full-bleed rendered icon that looked oversized in the picker).
Normalize-Foreground 'assets\images\logo\foreground_white.png' 'assets\images\logo\vsync_foreground_default.png' 1024 0.55

# 3. Rainbow legacy mipmaps (API < 26 fallback + some launchers).
$fg = 'android\app\src\main\res\drawable-nodpi\ic_launcher_foreground_rainbow.png'
Make-LegacyMipmap $fg 'android\app\src\main\res\mipmap-mdpi\ic_launcher_rainbow.png' 48
Make-LegacyMipmap $fg 'android\app\src\main\res\mipmap-hdpi\ic_launcher_rainbow.png' 72
Make-LegacyMipmap $fg 'android\app\src\main\res\mipmap-xhdpi\ic_launcher_rainbow.png' 96
Make-LegacyMipmap $fg 'android\app\src\main\res\mipmap-xxhdpi\ic_launcher_rainbow.png' 144
Make-LegacyMipmap $fg 'android\app\src\main\res\mipmap-xxxhdpi\ic_launcher_rainbow.png' 192

# 4. Verify: re-measure glyph ratios of everything the picker shows.
foreach ($f in @('assets\images\logo\app_icon_legacy.png',
                 'assets\images\logo\vsync_foreground_default.png',
                 'assets\images\logo\vsync_foreground_classy.png',
                 'assets\images\logo\vsync_foreground_glassy.png',
                 'assets\images\logo\vsync_foreground_rainbow.png')) {
    $bmp = [System.Drawing.Bitmap]::FromFile((Resolve-Path $f))
    $b = Get-BBox $bmp
    $ratio = [math]::Round([math]::Max($b[2], $b[3]) / $bmp.Width, 3)
    Write-Output "$f : $($bmp.Width)x$($bmp.Height) glyph $($b[2])x$($b[3]) ratio $ratio"
    $bmp.Dispose()
}
