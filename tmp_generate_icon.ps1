using namespace System.Drawing
using namespace System.Drawing.Drawing2D
using namespace System.Drawing.Imaging

Add-Type -AssemblyName System.Drawing

$sourcePath = "C:\Users\pc\.gemini\antigravity\brain\03ae8e20-fdb2-484a-8500-19764c14b169\media__1774106512420.png"
$projectResPath = "c:\Users\pc\.gemini\antigravity\scratch\vsp_application\android\app\src\main\res"

if (-Not (Test-Path $sourcePath)) {
    Write-Host "Source image not found."
    exit 1
}

$bmp = [Bitmap]::FromFile($sourcePath)

$sizes = @{
    "drawable-mdpi"   = @{ total=24; padding=2 }
    "drawable-hdpi"   = @{ total=36; padding=3 }
    "drawable-xhdpi"  = @{ total=48; padding=4 }
    "drawable-xxhdpi" = @{ total=72; padding=6 }
    "drawable-xxxhdpi"= @{ total=96; padding=8 }
}

foreach ($key in $sizes.Keys) {
    if (-Not (Test-Path "$projectResPath\$key")) {
        New-Item -ItemType Directory -Force -Path "$projectResPath\$key" | Out-Null
    }
    
    $props = $sizes[$key]
    $size = $props["total"]
    $padding = $props["padding"]
    $innerSize = $size - ($padding * 2)

    $outBmp = New-Object Bitmap $size, $size
    $g = [Graphics]::FromImage($outBmp)
    $g.SmoothingMode = [SmoothingMode]::HighQuality
    $g.InterpolationMode = [InterpolationMode]::HighQualityBicubic
    
    # Scale into inner
    $rect = New-Object Rectangle $padding, $padding, $innerSize, $innerSize
    $g.DrawImage($bmp, $rect)
    $g.Dispose()
    
    # Process transparency and color
    for ($y = 0; $y -lt $size; $y++) {
        for ($x = 0; $x -lt $size; $x++) {
            $px = $outBmp.GetPixel($x, $y)
            $brightness = [int]($px.R * 0.299 + $px.G * 0.587 + $px.B * 0.114)
            # Alpha based on brightness * original alpha
            $a = [int]($brightness * ($px.A / 255.0))
            if ($a -gt 255) { $a = 255 }
            if ($a -lt 0) { $a = 0 }
            
            $newPx = [Color]::FromArgb($a, 255, 255, 255)
            $outBmp.SetPixel($x, $y, $newPx)
        }
    }
    
    $outPath = "$projectResPath\$key\ic_notification.png"
    $outBmp.Save($outPath, [ImageFormat]::Png)
    $outBmp.Dispose()
    Write-Host "Created $outPath"
}

$bmp.Dispose()
Write-Host "Done"
