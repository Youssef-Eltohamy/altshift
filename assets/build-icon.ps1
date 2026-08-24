# Builds the simplified KbLangFix mark: multi-size .ico + PNG previews.
# Brand colors sampled from sign.png -> orange #FC6710, white #FDFDFD, black tile.
Add-Type -AssemblyName System.Drawing

$OUT    = $PSScriptRoot
$ORANGE = [System.Drawing.Color]::FromArgb(255, 0xFC, 0x67, 0x10)
$WHITE  = [System.Drawing.Color]::FromArgb(255, 0xFD, 0xFD, 0xFD)
$TILE   = [System.Drawing.Color]::FromArgb(255, 0x0B, 0x0B, 0x0B)

function New-Pen($color, $w) {
    $p = New-Object System.Drawing.Pen $color, $w
    $p.StartCap = 'Round'; $p.EndCap = 'Round'; $p.LineJoin = 'Round'
    return $p
}

function New-RoundRect($x, $y, $w, $h, $r) {
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d  = $r * 2
    $gp.AddArc($x,          $y,          $d, $d, 180, 90)
    $gp.AddArc($x + $w - $d, $y,          $d, $d, 270, 90)
    $gp.AddArc($x + $w - $d, $y + $h - $d, $d, $d,   0, 90)
    $gp.AddArc($x,          $y + $h - $d, $d, $d,  90, 90)
    $gp.CloseFigure()
    return $gp
}

function New-Mark {
    param([int]$Size, [switch]$Compact, [switch]$NoTile)

    $bmp = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.ScaleTransform($Size / 256.0, $Size / 256.0)   # design space is 256x256

    if (-not $NoTile) {
        $rr = New-RoundRect 0.0 0.0 256.0 256.0 56.0
        $br = New-Object System.Drawing.SolidBrush $TILE
        $g.FillPath($br, $rr)
        $br.Dispose(); $rr.Dispose()
    }

    if ($Compact) {
        # tiny sizes: the orange Z alone, fatter — the Y is unreadable below 32px
        $po = New-Pen $ORANGE 40
        $g.DrawLines($po, [System.Drawing.PointF[]]@(
            (New-Object System.Drawing.PointF  56.0,  84.0),
            (New-Object System.Drawing.PointF 200.0,  70.0),
            (New-Object System.Drawing.PointF  60.0, 190.0),
            (New-Object System.Drawing.PointF 204.0, 174.0)))
        $po.Dispose()
    }
    else {
        $pw = New-Pen $WHITE 20
        $g.DrawLine($pw,  80.0,  58.0, 128.0, 128.0)
        $g.DrawLine($pw, 176.0,  58.0, 128.0, 128.0)
        $g.DrawLine($pw, 128.0, 128.0, 127.0, 202.0)
        $pw.Dispose()
        $po = New-Pen $ORANGE 26
        $g.DrawLines($po, [System.Drawing.PointF[]]@(
            (New-Object System.Drawing.PointF  60.0, 124.0),
            (New-Object System.Drawing.PointF 194.0, 112.0),
            (New-Object System.Drawing.PointF  66.0, 188.0),
            (New-Object System.Drawing.PointF 200.0, 174.0)))
        $po.Dispose()
    }

    $g.Dispose()
    return $bmp
}

function Get-PngBytes($bmp) {
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $b = $ms.ToArray(); $ms.Dispose()
    return ,$b          # the comma stops PowerShell unrolling the byte array
}

# --- render every size -------------------------------------------------
$sizes  = @(16, 24, 32, 48, 64, 128, 256)
$frames = @()
foreach ($s in $sizes) {
    $bmp = if ($s -le 24) { New-Mark -Size $s -Compact } else { New-Mark -Size $s }
    $frames += [pscustomobject]@{ Size = $s; Bytes = [byte[]](Get-PngBytes $bmp) }
    if ($s -in 16, 32, 256) { $bmp.Save((Join-Path $OUT "preview-$s.png"), [System.Drawing.Imaging.ImageFormat]::Png) }
    $bmp.Dispose()
}
# transparent variant for use over the dark logo / README headers
$t = New-Mark -Size 512 -NoTile
$t.Save((Join-Path $OUT "mark-transparent-512.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$t.Dispose()

# --- pack the .ico -----------------------------------------------------
$icoPath = Join-Path $OUT "kblangfix.ico"
$fs = [System.IO.File]::Create($icoPath)
$bw = New-Object System.IO.BinaryWriter $fs
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$frames.Count)
$offset = 6 + (16 * $frames.Count)
foreach ($f in $frames) {
    $dim = if ($f.Size -ge 256) { 0 } else { $f.Size }
    $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32)
    $bw.Write([uint32]$f.Bytes.Length); $bw.Write([uint32]$offset)
    $offset += $f.Bytes.Length
}
foreach ($f in $frames) { $bw.Write($f.Bytes) }
$bw.Flush(); $bw.Dispose(); $fs.Dispose()

"ico : $icoPath  ($((Get-Item $icoPath).Length) bytes, sizes: $($sizes -join ', '))"
