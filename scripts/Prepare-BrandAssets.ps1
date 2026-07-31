param(
    [Parameter(Mandatory = $true)]
    [string]$IconSource,

    [Parameter(Mandatory = $true)]
    [string]$WordmarkSource
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$workspace = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$assetCatalog = Join-Path $workspace "Bolagscenter\Resources\Assets.xcassets"
$appIconDirectory = Join-Path $assetCatalog "AppIcon.appiconset"
$markDirectory = Join-Path $assetCatalog "NorthBridgeMark.imageset"
$wordmarkDirectory = Join-Path $assetCatalog "NorthBridgeWordmark.imageset"

New-Item -ItemType Directory -Force -Path $markDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $wordmarkDirectory | Out-Null

function Export-OpaqueImage {
    param(
        [string]$Source,
        [string]$Destination,
        [int]$Width,
        [int]$Height
    )

    $sourceImage = [System.Drawing.Image]::FromFile((Resolve-Path $Source).Path)
    try {
        $output = New-Object System.Drawing.Bitmap $Width, $Height, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($output)
            try {
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.DrawImage($sourceImage, 0, 0, $Width, $Height)
            }
            finally {
                $graphics.Dispose()
            }

            $output.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $output.Dispose()
        }
    }
    finally {
        $sourceImage.Dispose()
    }
}

function Export-OpaqueCroppedImage {
    param(
        [string]$Source,
        [string]$Destination,
        [int]$CropX,
        [int]$CropY,
        [int]$CropWidth,
        [int]$CropHeight,
        [int]$Width,
        [int]$Height
    )

    $sourceImage = [System.Drawing.Image]::FromFile((Resolve-Path $Source).Path)
    try {
        $output = New-Object System.Drawing.Bitmap $Width, $Height, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($output)
            try {
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $destinationRectangle = New-Object System.Drawing.Rectangle 0, 0, $Width, $Height
                $graphics.DrawImage(
                    $sourceImage,
                    $destinationRectangle,
                    $CropX,
                    $CropY,
                    $CropWidth,
                    $CropHeight,
                    [System.Drawing.GraphicsUnit]::Pixel
                )
            }
            finally {
                $graphics.Dispose()
            }

            $output.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $output.Dispose()
        }
    }
    finally {
        $sourceImage.Dispose()
    }
}

Export-OpaqueImage `
    -Source $IconSource `
    -Destination (Join-Path $appIconDirectory "NorthBridge-AppIcon-1024.png") `
    -Width 1024 `
    -Height 1024

Export-OpaqueImage `
    -Source $IconSource `
    -Destination (Join-Path $markDirectory "NorthBridgeMark.png") `
    -Width 512 `
    -Height 512

$wordmark = [System.Drawing.Image]::FromFile((Resolve-Path $WordmarkSource).Path)
try {
    $cropX = [Math]::Round($wordmark.Width * 0.07)
    $cropY = [Math]::Round($wordmark.Height * 0.30)
    $cropWidth = [Math]::Round($wordmark.Width * 0.86)
    $cropHeight = [Math]::Round($wordmark.Height * 0.40)
    $targetWidth = 1600
    $targetHeight = [Math]::Round($targetWidth * $cropHeight / $cropWidth)
}
finally {
    $wordmark.Dispose()
}

Export-OpaqueCroppedImage `
    -Source $WordmarkSource `
    -Destination (Join-Path $wordmarkDirectory "NorthBridgeWordmark.png") `
    -CropX $cropX `
    -CropY $cropY `
    -CropWidth $cropWidth `
    -CropHeight $cropHeight `
    -Width $targetWidth `
    -Height $targetHeight

$expectedAssets = @(
    @{
        Path = Join-Path $appIconDirectory "NorthBridge-AppIcon-1024.png"
        Width = 1024
        Height = 1024
    },
    @{
        Path = Join-Path $markDirectory "NorthBridgeMark.png"
        Width = 512
        Height = 512
    },
    @{
        Path = Join-Path $wordmarkDirectory "NorthBridgeWordmark.png"
        Width = $targetWidth
        Height = $targetHeight
    }
)

foreach ($asset in $expectedAssets) {
    $image = [System.Drawing.Image]::FromFile($asset.Path)
    try {
        if ($image.Width -ne $asset.Width -or $image.Height -ne $asset.Height) {
            throw "Unexpected asset dimensions for $($asset.Path)."
        }

        if ($image.PixelFormat.ToString().Contains("Alpha")) {
            throw "Asset contains an alpha channel: $($asset.Path)."
        }

        Write-Output "$($asset.Path): $($image.Width)x$($image.Height), $($image.PixelFormat)"
    }
    finally {
        $image.Dispose()
    }
}
