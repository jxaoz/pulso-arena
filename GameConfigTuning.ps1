function New-GameConfigField([string]$Key, [string]$Type, [string]$Value, [switch]$Scale, [switch]$Optional) {
    [pscustomobject]@{ Key = $Key; Type = $Type; Value = $Value; Scale = [bool]$Scale; Optional = [bool]$Optional }
}

function Get-GameConfigDefinition([string]$Id) {
    $fortnite = $Id -in @('framecap','vsync','fullscreen','renderres','shadows','textures','effects','postprocess','viewdistance','nanite','lumen','showfps')
    $inputMode = if ($fortnite) { '' } else { 'GameConfig' }
    $fields = switch ($Id) {
        { $_ -in 'gamefpscap','framecap' } { New-GameConfigField 'FrameRateLimit' 'Number' '' }
        { $_ -in 'gamevsync','vsync' } { New-GameConfigField 'bUseVSync' 'Bool' 'False' }
        { $_ -in 'gamewindowmode','fullscreen' } {
            New-GameConfigField 'FullscreenMode' 'WindowMode' '0'
            New-GameConfigField 'LastConfirmedFullscreenMode' 'WindowMode' '0' -Optional
            New-GameConfigField 'PreferredFullscreenMode' 'WindowMode' '0' -Optional
        }
        gamedynamicres { New-GameConfigField 'bUseDynamicResolution' 'Bool' 'True' }
        { $_ -in 'uescale','renderres' } { New-GameConfigField 'sg.ResolutionQuality' 'Number' '90' -Scale }
        { $_ -in 'ueview','viewdistance' } { New-GameConfigField 'sg.ViewDistanceQuality' 'Quality' '0' -Scale }
        ueaa { New-GameConfigField 'sg.AntiAliasingQuality' 'Quality' '0' -Scale }
        { $_ -in 'ueshadows','shadows' } { New-GameConfigField 'sg.ShadowQuality' 'Quality' '0' -Scale }
        ueglobalillumination { New-GameConfigField 'sg.GlobalIlluminationQuality' 'Quality' '0' -Scale }
        uereflections { New-GameConfigField 'sg.ReflectionQuality' 'Quality' '0' -Scale }
        { $_ -in 'uepostprocess','postprocess' } { New-GameConfigField 'sg.PostProcessQuality' 'Quality' '0' -Scale }
        { $_ -in 'uetextures','textures' } { New-GameConfigField 'sg.TextureQuality' 'Quality' '0' -Scale }
        { $_ -in 'ueeffects','effects' } { New-GameConfigField 'sg.EffectsQuality' 'Quality' '0' -Scale }
        uefoliage { New-GameConfigField 'sg.FoliageQuality' 'Quality' '0' -Scale }
        ueshading { New-GameConfigField 'sg.ShadingQuality' 'Quality' '0' -Scale }
        uelandscape { New-GameConfigField 'sg.LandscapeQuality' 'Quality' '0' -Scale }
        nanite { New-GameConfigField 'bUseNanite' 'Bool' 'False' }
        lumen {
            New-GameConfigField 'DesiredGlobalIlluminationQuality' 'Quality' '0'
            New-GameConfigField 'DesiredReflectionQuality' 'Quality' '0'
            New-GameConfigField 'sg.GlobalIlluminationQuality' 'Quality' '0' -Scale
            New-GameConfigField 'sg.ReflectionQuality' 'Quality' '0' -Scale
        }
        showfps { New-GameConfigField 'bShowFPS' 'Bool' 'True' }
    }
    if (-not $fields) { return }
    if ($Id -eq 'gamefpscap') { $inputMode = 'GameConfigFps' }
    if ($Id -eq 'framecap') { $inputMode = 'Fps' }
    [pscustomobject]@{ Kind = 'GameConfig'; Admin = $false; Input = $inputMode; Fortnite = $fortnite; Fields = @($fields) }
}

function Get-GameConfigRoots {
    $documents = [Environment]::GetFolderPath('MyDocuments')
    $documentsGames = if ($documents) { Join-Path $documents 'My Games' } else { '' }
    [ordered]@{ Local = [Environment]::GetFolderPath('LocalApplicationData'); Documents = $documentsGames }
}

function Get-GameConfigReference([string]$Path) {
    if ($Path -notmatch '^[A-Z]:\\' -or $Path.Substring(2).Contains(':') -or $Path -match '(^|\\)\.{1,2}(\\|$)') {
        throw 'Escolha o arquivo GameUserSettings.ini em uma pasta local compatível.'
    }
    $fullPath = [IO.Path]::GetFullPath($Path)
    $roots = Get-GameConfigRoots
    foreach ($location in $roots.Keys) {
        if (-not $roots[$location]) { continue }
        $root = [IO.Path]::GetFullPath($roots[$location]).TrimEnd('\')
        if (-not $fullPath.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) { continue }
        $relative = $fullPath.Substring($root.Length + 1)
        if ($relative -match '^(?<game>[^\\/:*?"<>|]+)\\Saved\\Config\\(?<platform>Windows(?:Client|NoEditor)?)\\GameUserSettings\.ini$') {
            return [pscustomobject]@{ Location = $location; Game = $Matches.game; Platform = $Matches.platform }
        }
    }
    throw 'Escolha <jogo>\Saved\Config\Windows, WindowsClient ou WindowsNoEditor dentro de %LOCALAPPDATA% ou Documentos\My Games.'
}

function Get-GameConfigPath($Reference) {
    $roots = Get-GameConfigRoots
    if ($Reference.Location -notin @('Local','Documents') -or -not $roots[$Reference.Location] -or
        $Reference.Game -notmatch '^[^\\/:*?"<>|]+$' -or $Reference.Game -in @('.', '..') -or
        $Reference.Platform -notmatch '^Windows(?:Client|NoEditor)?$') { throw 'Localização de configuração inválida.' }
    $path = [IO.Path]::GetFullPath((Join-Path $roots[$Reference.Location] "$($Reference.Game)\Saved\Config\$($Reference.Platform)\GameUserSettings.ini"))
    $checked = Get-GameConfigReference $path
    if ($checked.Location -ne $Reference.Location -or $checked.Game -cne $Reference.Game -or $checked.Platform -cne $Reference.Platform) {
        throw 'O arquivo escolhido não pertence à pasta de configuração esperada.'
    }
    $path
}

function Assert-GameConfigPath([string]$Path) {
    if (-not [IO.File]::Exists($Path)) { throw 'Abra o jogo uma vez e feche-o para gerar um GameUserSettings.ini compatível.' }
    $drive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($Path))
    if ($drive.DriveType -ne [IO.DriveType]::Fixed) { throw 'O arquivo precisa estar em uma unidade local fixa.' }
    $attributes = [IO.File]::GetAttributes($Path)
    if ($attributes -band [IO.FileAttributes]::ReadOnly) { throw 'O arquivo do jogo está marcado como somente leitura.' }
    if ($attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'O arquivo selecionado é um link ou redirecionamento.' }
    $directory = [IO.DirectoryInfo]::new([IO.Path]::GetDirectoryName($Path))
    while ($directory) {
        if ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'O caminho do arquivo passa por um link ou redirecionamento.' }
        $directory = $directory.Parent
    }
}

function Assert-GameConfigClosed($Reference) {
    $gameName = $Reference.Game -replace '[^A-Za-z0-9]', ''
    foreach ($process in Get-Process -ErrorAction SilentlyContinue) {
        $name = $process.ProcessName
        $normalized = $name -replace '[^A-Za-z0-9]', ''
        if ($name -match '(?:^|[-_])(?:Win(?:32|64)(?:[-_])?)?Shipping(?:[-_]|$)' -or
            ($gameName -and ($normalized -eq $gameName -or $normalized -eq ($gameName + 'Client') -or
                $normalized -eq ($gameName + 'Launcher')))) {
            throw 'Feche o jogo e aguarde o processo terminar antes de alterar a configuração.'
        }
    }
}

function Read-GameConfigBytes([IO.Stream]$Stream) {
    if ($Stream.Length -le 0 -or $Stream.Length -gt 2MB) { throw 'O arquivo tem um tamanho incompatível com GameUserSettings.ini.' }
    $buffer = [byte[]]::new([int]$Stream.Length)
    $offset = 0
    while ($offset -lt $buffer.Length) {
        $count = $Stream.Read($buffer, $offset, $buffer.Length - $offset)
        if ($count -eq 0) { throw 'O arquivo mudou durante a leitura. Feche o jogo e tente novamente.' }
        $offset += $count
    }
    return ,$buffer
}

function ConvertFrom-GameConfigBytes([byte[]]$Bytes) {
    $prefixLength = 0
    if ($Bytes.Length -ge 4 -and $Bytes[0] -eq 0xff -and $Bytes[1] -eq 0xfe -and $Bytes[2] -eq 0 -and $Bytes[3] -eq 0) {
        $encoding = [Text.UTF32Encoding]::new($false, $true, $true); $prefixLength = 4
    } elseif ($Bytes.Length -ge 4 -and $Bytes[0] -eq 0 -and $Bytes[1] -eq 0 -and $Bytes[2] -eq 0xfe -and $Bytes[3] -eq 0xff) {
        $encoding = [Text.UTF32Encoding]::new($true, $true, $true); $prefixLength = 4
    } elseif ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xef -and $Bytes[1] -eq 0xbb -and $Bytes[2] -eq 0xbf) {
        $encoding = [Text.UTF8Encoding]::new($true, $true); $prefixLength = 3
    } elseif ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xff -and $Bytes[1] -eq 0xfe) {
        $encoding = [Text.UnicodeEncoding]::new($false, $true, $true); $prefixLength = 2
    } elseif ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xfe -and $Bytes[1] -eq 0xff) {
        $encoding = [Text.UnicodeEncoding]::new($true, $true, $true); $prefixLength = 2
    } else { $encoding = [Text.UTF8Encoding]::new($false, $true) }
    try { $content = $encoding.GetString($Bytes, $prefixLength, $Bytes.Length - $prefixLength) }
    catch [Text.DecoderFallbackException] {
        if ($prefixLength) { throw 'A codificação declarada pelo arquivo está inválida.' }
        $encoding = [Text.Encoding]::GetEncoding(28591)
        $content = $encoding.GetString($Bytes)
    }
    if ($content.IndexOf([char]0) -ge 0) { throw 'O arquivo contém dados binários ou uma codificação sem identificação.' }
    [pscustomobject]@{ Text = $content; Encoding = $encoding }
}

function Get-GameConfigDocument([IO.Stream]$Stream, $Definition) {
    $document = ConvertFrom-GameConfigBytes (Read-GameConfigBytes $Stream)
    $sections = @{}
    $active = ''
    $wanted = @{}
    foreach ($field in $Definition.Fields) { $wanted[$field.Key] = $true }
    $mainKeys = @('FrameRateLimit','bUseVSync','FullscreenMode','LastConfirmedFullscreenMode','bUseDynamicResolution','ResolutionSizeX','ResolutionSizeY')
    foreach ($key in $mainKeys) { $wanted[$key] = $true }
    foreach ($line in [regex]::Matches($document.Text, '[^\r\n]*(?:\r\n|\r|\n|$)')) {
        if (-not $line.Length) { continue }
        $content = $line.Value.TrimEnd("`r", "`n")
        if ($content -match '^\s*\[(?<section>[^\[\]]+)\]\s*(?:[;#].*)?$') {
            $active = $Matches.section.Trim()
            if ($active -notmatch '^(?:/Script/[A-Za-z0-9_]+\.[A-Za-z0-9_]*GameUserSettings|ScalabilityGroups)$') { $active = ''; continue }
            if ($sections.ContainsKey($active)) { throw 'O arquivo contém seções de configuração duplicadas.' }
            $sections[$active] = @{}
            continue
        }
        if (-not $active) { continue }
        $assignment = [regex]::Match($content, '^(?<left>[ \t]*(?<key>[A-Za-z][A-Za-z0-9_.]*)[ \t]*=[ \t]*)(?<value>[^ \t;#]*)(?<right>[ \t]*(?:[;#].*)?)$')
        if (-not $assignment.Success -or -not $wanted.ContainsKey($assignment.Groups['key'].Value)) { continue }
        $key = $assignment.Groups['key'].Value
        if ($sections[$active].ContainsKey($key)) { throw "O arquivo contém $key mais de uma vez na mesma seção." }
        $value = $assignment.Groups['value']
        $sections[$active][$key] = [pscustomobject]@{ Value = $value.Value; Start = $line.Index + $value.Index; Length = $value.Length }
    }
    $userSections = @($sections.Keys | Where-Object { $_ -like '/Script/*' })
    if ($Definition.Fortnite) {
        $userSection = '/Script/FortniteGame.FortGameUserSettings'
        if ($userSection -notin $userSections) { throw 'O arquivo selecionado não contém a seção do Fortnite.' }
    } else {
        if ($userSections.Count -gt 1) {
            $userSections = @($userSections | Where-Object {
                $sectionKeys = $sections[$_].Keys
                @($mainKeys | Where-Object { $_ -in $sectionKeys }).Count -gt 0
            })
        }
        if ($userSections.Count -ne 1) { throw 'O arquivo precisa conter uma seção principal Unreal GameUserSettings identificável.' }
        $userSection = $userSections[0]
    }
    [pscustomobject]@{ Text = $document.Text; Encoding = $document.Encoding; Sections = $sections; UserSection = $userSection }
}

function Test-GameConfigValue([string]$Value, [string]$Type) {
    switch ($Type) {
        Bool { return $Value -match '^(?:True|False)$' }
        Number { return $Value -match '^-?\d{1,6}(?:\.\d{1,12})?$' }
        Quality { return $Value -match '^[0-4]$' }
        WindowMode { return $Value -match '^[0-2]$' }
        default { return $false }
    }
}

function Compare-GameConfigValue([string]$Current, [string]$Expected, [string]$Type) {
    if (-not (Test-GameConfigValue $Current $Type) -or -not (Test-GameConfigValue $Expected $Type)) { return $false }
    if ($Type -eq 'Number') {
        $culture = [Globalization.CultureInfo]::InvariantCulture
        return [decimal]::Parse($Current, $culture) -eq [decimal]::Parse($Expected, $culture)
    }
    $Current -eq $Expected
}

function Get-GameConfigField($Document, $Field) {
    $section = if ($Field.Scale) { 'ScalabilityGroups' } else { $Document.UserSection }
    $record = if ($Document.Sections.ContainsKey($section)) { $Document.Sections[$section][$Field.Key] }
    if ($null -eq $record) {
        if ($Field.Optional) { return }
        throw "Este jogo ainda não salvou a opção $($Field.Key). Verifique a opção no menu do jogo ou use um título compatível."
    }
    if (-not (Test-GameConfigValue $record.Value $Field.Type)) { throw "O valor atual de $($Field.Key) usa um formato não reconhecido." }
    $record
}

function Get-GameConfigPlan([string]$Id, $Options) {
    $definition = Get-GameConfigDefinition $Id
    if (-not $definition) { throw 'Ajuste de jogo desconhecido.' }
    $reference = if ($definition.Fortnite) { [pscustomobject]@{ Location = 'Local'; Game = 'FortniteGame'; Platform = 'WindowsClient' } }
        else { Get-GameConfigReference ([string]$Options.ConfigPath) }
    $path = Get-GameConfigPath $reference
    Assert-GameConfigPath $path
    Assert-GameConfigClosed $reference
    $stream = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try { $document = Get-GameConfigDocument $stream $definition }
    finally { $stream.Dispose() }
    $before = [Collections.Generic.List[object]]::new()
    $after = [Collections.Generic.List[object]]::new()
    foreach ($field in $definition.Fields) {
        $record = Get-GameConfigField $document $field
        if (-not $record) { continue }
        $desired = $field.Value
        if ($field.Key -eq 'FrameRateLimit') {
            $fps = [string]$Options.Fps
            $maximum = if ($definition.Fortnite) { 360 } else { 1000 }
            if ($fps -notmatch '^\d{2,4}$' -or [int]$fps -lt 30 -or [int]$fps -gt $maximum) { throw "Informe um limite inteiro entre 30 e $maximum FPS." }
            $desired = ([int]$fps).ToString([Globalization.CultureInfo]::InvariantCulture) + '.000000'
        }
        $before.Add([pscustomobject]@{ Key = $field.Key; Value = [string]$record.Value })
        $after.Add([pscustomobject]@{ Key = $field.Key; Value = $desired })
    }
    [pscustomobject]@{
        Before = [pscustomobject]@{ Config = $reference; Section = $document.UserSection; Fields = $before.ToArray() }
        After = [pscustomobject]@{ Config = $reference; Section = $document.UserSection; Fields = $after.ToArray() }
        Summary = $reference.Game
    }
}

function Get-GameConfigStateFields($Definition, $State) {
    if ($null -eq $State -or -not $State.Section -or -not $State.Config) { throw 'Backup de configuração incompleto.' }
    if ($Definition.Fortnite -and ($State.Config.Location -ne 'Local' -or $State.Config.Game -ne 'FortniteGame' -or $State.Config.Platform -ne 'WindowsClient')) {
        throw 'O backup do Fortnite aponta para um caminho incompatível.'
    }
    $settings = @{}
    foreach ($entry in @($State.Fields)) {
        $definitionField = @($Definition.Fields | Where-Object Key -eq $entry.Key)
        if ($definitionField.Count -ne 1 -or $settings.ContainsKey($entry.Key) -or -not (Test-GameConfigValue ([string]$entry.Value) $definitionField[0].Type)) {
            throw 'O backup contém um valor de configuração não reconhecido.'
        }
        $settings[$entry.Key] = [string]$entry.Value
    }
    foreach ($field in $Definition.Fields) {
        if (-not $field.Optional -and -not $settings.ContainsKey($field.Key)) { throw 'O backup não contém todas as opções obrigatórias.' }
    }
    $settings
}

function Test-GameConfigDocumentState($Document, $Definition, $State, $Settings) {
    if ($Document.UserSection -ne $State.Section) { return $false }
    foreach ($field in $Definition.Fields) {
        if (-not $Settings.ContainsKey($field.Key)) { continue }
        $record = Get-GameConfigField $Document $field
        if (-not $record -or -not (Compare-GameConfigValue $record.Value $Settings[$field.Key] $field.Type)) { return $false }
    }
    $true
}

function Test-GameConfigState([string]$Id, $State) {
    $definition = Get-GameConfigDefinition $Id
    if (-not $definition) { throw 'Ajuste de jogo desconhecido.' }
    $settings = Get-GameConfigStateFields $definition $State
    $path = Get-GameConfigPath $State.Config
    Assert-GameConfigPath $path
    $stream = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try { Test-GameConfigDocumentState (Get-GameConfigDocument $stream $definition) $definition $State $settings }
    finally { $stream.Dispose() }
}

function Set-GameConfigState([string]$Id, $State, $Expected) {
    $definition = Get-GameConfigDefinition $Id
    if (-not $definition) { throw 'Ajuste de jogo desconhecido.' }
    $settings = Get-GameConfigStateFields $definition $State
    $oldSettings = Get-GameConfigStateFields $definition $Expected
    $path = Get-GameConfigPath $State.Config
    if ($path -ne (Get-GameConfigPath $Expected.Config) -or $State.Section -ne $Expected.Section -or
        $settings.Count -ne $oldSettings.Count -or @($settings.Keys | Where-Object { -not $oldSettings.ContainsKey($_) }).Count) {
        throw 'O ajuste e sua cópia anterior se referem a opções diferentes.'
    }
    Assert-GameConfigPath $path
    Assert-GameConfigClosed $State.Config
    $temporary = Join-Path ([IO.Path]::GetDirectoryName($path)) ('.pulso-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    $stream = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::Read -bor [IO.FileShare]::Delete))
    try {
        $document = Get-GameConfigDocument $stream $definition
        if (-not (Test-GameConfigDocumentState $document $definition $Expected $oldSettings)) {
            throw 'O valor atual mudou depois da leitura. Faça uma nova revisão do ajuste.'
        }
        $updates = foreach ($field in $definition.Fields) {
            if (-not $settings.ContainsKey($field.Key)) { continue }
            $record = Get-GameConfigField $document $field
            $value = $settings[$field.Key]
            if ($record.Value -cne $value) { [pscustomobject]@{ Start = $record.Start; Length = $record.Length; Value = $value } }
        }
        if (-not $updates) { return }
        $newText = [Text.StringBuilder]::new($document.Text)
        foreach ($update in $updates | Sort-Object Start -Descending) {
            [void]$newText.Remove($update.Start, $update.Length).Insert($update.Start, $update.Value)
        }
        $tempFile = [IO.File]::Open($temporary, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try {
            $preamble = $document.Encoding.GetPreamble()
            $body = $document.Encoding.GetBytes($newText.ToString())
            $tempFile.Write($preamble, 0, $preamble.Length)
            $tempFile.Write($body, 0, $body.Length)
            $tempFile.Flush($true)
        } finally { $tempFile.Dispose() }
        Assert-GameConfigPath $path
        Assert-GameConfigClosed $State.Config
        $current = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::Read -bor [IO.FileShare]::Delete))
        try { $currentDocument = ConvertFrom-GameConfigBytes (Read-GameConfigBytes $current) }
        finally { $current.Dispose() }
        if ($currentDocument.Text -cne $document.Text -or $currentDocument.Encoding.CodePage -ne $document.Encoding.CodePage -or
            $currentDocument.Encoding.GetPreamble().Length -ne $document.Encoding.GetPreamble().Length) {
            throw 'O arquivo mudou durante a operação. Nenhuma alteração foi aplicada.'
        }
        [IO.File]::Replace($temporary, $path, [System.Management.Automation.Language.NullString]::Value)
    } finally {
        $stream.Dispose()
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
    }
    if (-not (Test-GameConfigState $Id $State)) { throw 'Não foi possível confirmar a alteração gravada no arquivo de jogo.' }
}
