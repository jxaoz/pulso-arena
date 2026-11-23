[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

function New-RoundedPath([single]$X, [single]$Y, [single]$Width, [single]$Height, [single]$Radius) {
    $path = [Drawing.Drawing2D.GraphicsPath]::new()
    $diameter = [single]($Radius * 2)
    $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
    $path.AddArc(($X + $Width - $diameter), $Y, $diameter, $diameter, 270, 90)
    $path.AddArc(($X + $Width - $diameter), ($Y + $Height - $diameter), $diameter, $diameter, 0, 90)
    $path.AddArc($X, ($Y + $Height - $diameter), $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-IconFrame([int]$Size) {
    $bitmap = [Drawing.Bitmap]::new($Size, $Size, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $png = [IO.MemoryStream]::new()
    $background = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#151A2A'))
    $outline = [Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml('#337496'), 1.6)
    $cyan = [Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml('#72EBFF'), 3.3)
    $violet = [Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml('#7771FF'), 3.3)
    $panel = New-RoundedPath 3 3 58 58 15
    $upperCapsule = New-RoundedPath 15 21 31 10 5
    $lowerCapsule = New-RoundedPath 21 34 31 10 5
    try {
        $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $scale = [single]($Size / 64)
        $graphics.ScaleTransform($scale, $scale)
        $graphics.FillPath($background, $panel)
        $graphics.DrawPath($outline, $panel)
        $graphics.DrawPath($cyan, $upperCapsule)
        $graphics.DrawPath($violet, $lowerCapsule)
        $bitmap.Save($png, [Drawing.Imaging.ImageFormat]::Png)
        [pscustomobject]@{ Size = $Size; Bytes = $png.ToArray() }
    } finally {
        foreach ($item in $lowerCapsule, $upperCapsule, $panel, $violet, $cyan, $outline, $background, $png, $graphics, $bitmap) {
            $item.Dispose()
        }
    }
}

function New-PrismaFrameIcon([string]$IconPath) {
    Add-Type -AssemblyName System.Drawing
    $frames = @(16, 24, 32, 48, 64, 128, 256 | ForEach-Object { New-IconFrame $_ })
    $file = [IO.File]::Open($IconPath, [IO.FileMode]::CreateNew)
    $writer = [IO.BinaryWriter]::new($file)
    try {
        $writer.Write([uint16]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]$frames.Count)
        $offset = [uint32](6 + 16 * $frames.Count)
        foreach ($frame in $frames) {
            $encodedSize = [byte]($frame.Size % 256)
            $writer.Write($encodedSize)
            $writer.Write($encodedSize)
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([uint16]1)
            $writer.Write([uint16]32)
            $writer.Write([uint32]$frame.Bytes.Length)
            $writer.Write($offset)
            $offset += [uint32]$frame.Bytes.Length
        }
        foreach ($frame in $frames) { $writer.Write([byte[]]$frame.Bytes) }
    } finally {
        $writer.Dispose()
    }
}

function Assert-PrismaFrameExecutable([string]$Path, [string[]]$Resources) {
    $file = [IO.File]::OpenRead($Path)
    $reader = [IO.BinaryReader]::new($file)
    try {
        if ($reader.ReadUInt16() -ne 0x5A4D) { throw 'O arquivo gerado não é um executável do Windows.' }
        $file.Position = 0x3C
        $header = $reader.ReadUInt32()
        $file.Position = $header
        if ($reader.ReadUInt32() -ne 0x4550 -or $reader.ReadUInt16() -ne 0x8664) { throw 'O arquivo gerado não usa a arquitetura x64.' }
        $file.Position = $header + 24
        if ($reader.ReadUInt16() -ne 0x20B) { throw 'O arquivo gerado não é PE de 64 bits.' }
        $file.Position = $header + 24 + 68
        if ($reader.ReadUInt16() -ne 2) { throw 'O arquivo gerado não usa o subsistema gráfico do Windows.' }
    } finally {
        $reader.Dispose()
    }

    $assembly = [Reflection.Assembly]::Load([IO.File]::ReadAllBytes($Path))
    $actual = @($assembly.GetManifestResourceNames() | Sort-Object)
    $expected = @($Resources | Sort-Object)
    if (($actual -join "`n") -cne ($expected -join "`n")) { throw 'O conjunto de recursos do executável diverge do esperado.' }
}

if (-not [Environment]::Is64BitProcess -or $env:OS -ne 'Windows_NT') { throw 'Abra o PowerShell de 64 bits no Windows para compilar.' }
if ($OutputPath -notmatch '^(?:[A-Za-z]:[\\/]|\\\\[^\\]+\\[^\\]+\\)' -or [IO.Path]::GetExtension($OutputPath) -ine '.exe') {
    throw 'Informe o caminho absoluto de um arquivo .exe em -OutputPath.'
}
$destination = [IO.Path]::GetFullPath($OutputPath)
$windows = [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
$compiler = Join-Path $windows 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$winPowerShell = Join-Path $windows 'System32\WindowsPowerShell\v1.0\powershell.exe'
foreach ($required in @($compiler, $winPowerShell)) {
    if (-not [IO.File]::Exists($required)) { throw "Requisito de compilação ausente em $required." }
}
$locateSma = 'if ($PSVersionTable.PSEdition -ne "Desktop" -or $PSVersionTable.PSVersion -lt [version]"5.1") { exit 1 }; [System.Management.Automation.PSObject].Assembly.Location'
$encodedLookup = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($locateSma))
$sma = & $winPowerShell -NoLogo -NoProfile -NonInteractive -EncodedCommand $encodedLookup
if ($LASTEXITCODE -ne 0 -or $sma -isnot [string] -or -not [IO.File]::Exists($sma)) {
    throw 'Não foi possível localizar a biblioteca do Windows PowerShell 5.1.'
}

$manifest = Join-Path $PSScriptRoot 'PrismaFrame.manifest'
$source = Join-Path $PSScriptRoot 'PrismaFrameHost.cs'
$embeddedFiles = @(
    'PrismaFrame.ps1', 'PrismaFrame.xaml', 'Tweaks.ps1', 'Scanner.ps1', 'Maintenance.ps1',
    'Tuning.ps1', 'Recommendations.ps1', 'WindowsTuning.ps1', 'GameConfigTuning.ps1', 'NvidiaTuning.ps1'
)
$resources = foreach ($fileName in $embeddedFiles) {
    $path = Join-Path $PSScriptRoot $fileName
    if (-not [IO.File]::Exists($path)) { throw "Recurso ausente em $path." }
    [pscustomobject]@{ Path = $path; Name = "PrismaFrame.$fileName" }
}
foreach ($required in @($manifest, $source)) {
    if (-not [IO.File]::Exists($required)) { throw "Arquivo de compilação ausente em $required." }
}

$staging = Join-Path ([IO.Path]::GetTempPath()) ('PrismaFrameBuild-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($staging)
$icon = Join-Path $staging 'PrismaFrame.ico'
$compiled = Join-Path $staging 'PrismaFrame.exe'
try {
    New-PrismaFrameIcon $icon
    $arguments = @(
        '/nologo', '/target:winexe', '/platform:x64', '/optimize+', '/debug-', '/codepage:65001',
        "/out:$compiled", "/win32manifest:$manifest", "/win32icon:$icon",
        "/reference:$sma", '/reference:System.Windows.Forms.dll', '/reference:System.Drawing.dll'
    )
    $arguments += @($resources | ForEach-Object { "/resource:$($_.Path),$($_.Name),private" })
    $arguments += $source
    $diagnostics = & $compiler @arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw ("A compilação falhou.`n" + ($diagnostics -join "`n")) }
    if ($diagnostics) { Write-Verbose ($diagnostics -join "`n") }
    Assert-PrismaFrameExecutable $compiled @($resources.Name)

    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
    [IO.File]::Copy($compiled, $destination, $true)
    $artifact = Get-Item -LiteralPath $destination
    [pscustomobject]@{
        OutputPath = $artifact.FullName
        Bytes = $artifact.Length
        SHA256 = (Get-FileHash -LiteralPath $artifact.FullName -Algorithm SHA256).Hash
        EmbeddedResources = $resources.Count
    }
} finally {
    [IO.File]::Delete($compiled)
    [IO.File]::Delete($icon)
    [IO.Directory]::Delete($staging, $false)
}
