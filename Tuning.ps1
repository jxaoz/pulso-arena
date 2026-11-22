function New-TuningValue($Path, $Name, $Value, $Type = 'DWord') {
    [pscustomobject]@{ Path = $Path; Name = $Name; Value = $Value; Type = $Type; Exists = $true }
}

function Get-TuningDefinition([string]$Id) {
    $gameBar = 'Software\Microsoft\GameBar'
    $dvr = 'Software\Microsoft\Windows\CurrentVersion\GameDVR'
    $advanced = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $mouse = 'Control Panel\Mouse'
    $values = switch ($Id) {
        gamemode { New-TuningValue $gameBar 'AutoGameModeEnabled' 1 }
        dvr {
            New-TuningValue $dvr 'AppCaptureEnabled' 0
            New-TuningValue 'System\GameConfigStore' 'GameDVR_Enabled' 0
        }
        mouseaccel {
            New-TuningValue $mouse 'MouseSpeed' '0' 'String'
            New-TuningValue $mouse 'MouseThreshold1' '0' 'String'
            New-TuningValue $mouse 'MouseThreshold2' '0' 'String'
        }
        transparency { New-TuningValue 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0 }
        taskbarwidgets { New-TuningValue $advanced 'TaskbarDa' 0 }
        taskbarsearch { New-TuningValue 'Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 0 }
        taskbarview { New-TuningValue $advanced 'ShowTaskViewButton' 0 }
        menudelay { New-TuningValue 'Control Panel\Desktop' 'MenuShowDelay' '150' 'String' }
        capturesaudio { New-TuningValue $dvr 'AudioCaptureEnabled' 0 }
        snapoff { New-TuningValue 'Control Panel\Desktop' 'WindowArrangementActive' '0' 'String' }
        powerhigh { return [pscustomobject]@{ Kind = 'Power'; Plan = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' } }
        powerbalanced { return [pscustomobject]@{ Kind = 'Power'; Plan = '381b4222-f694-41f0-9685-ff5bb260df2e' } }
        default { throw 'Ajuste automático desconhecido.' }
    }
    if ($Id -eq 'taskbarwidgets' -and [Environment]::OSVersion.Version.Build -lt 22000) { throw 'Widgets da barra de tarefas requerem o Windows 11.' }
    [pscustomobject]@{ Kind = 'Registry'; Values = @($values) }
}

function Get-TuningValue($Definition) {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($Definition.Path)
    try {
        if ($key -and $key.GetValueNames() -contains $Definition.Name) {
            return [pscustomobject]@{
                Path = $Definition.Path; Name = $Definition.Name; Exists = $true
                Type = $key.GetValueKind($Definition.Name).ToString()
                Value = $key.GetValue($Definition.Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            }
        }
        [pscustomobject]@{ Path = $Definition.Path; Name = $Definition.Name; Exists = $false; Type = ''; Value = $null }
    } finally { if ($key) { $key.Dispose() } }
}

function Test-TuningValue($Expected, $Actual) {
    if ($Expected.Exists -ne $Actual.Exists) { return $false }
    if (-not $Expected.Exists) { return $true }
    if ($Expected.Type -ne $Actual.Type) { return $false }
    (ConvertTo-Json -InputObject $Expected.Value -Compress) -ceq (ConvertTo-Json -InputObject $Actual.Value -Compress)
}

function Set-TuningValue($Definition) {
    $root = [Microsoft.Win32.Registry]::CurrentUser
    if ($Definition.Exists) {
        $key = $root.CreateSubKey($Definition.Path)
        try {
            $value = switch ($Definition.Type) {
                DWord { [int]$Definition.Value }
                QWord { [long]$Definition.Value }
                Binary { ,([byte[]]$Definition.Value) }
                None { ,([byte[]]$Definition.Value) }
                MultiString { ,([string[]]$Definition.Value) }
                default { [string]$Definition.Value }
            }
            $key.SetValue($Definition.Name, $value, [Microsoft.Win32.RegistryValueKind]$Definition.Type)
        } finally { $key.Dispose() }
    } else {
        $key = $root.OpenSubKey($Definition.Path, $true)
        try { if ($key) { $key.DeleteValue($Definition.Name, $false) } }
        finally { if ($key) { $key.Dispose() } }
    }
    if (-not (Test-TuningValue $Definition (Get-TuningValue $Definition))) { throw 'O Windows não confirmou a alteração no Registro.' }
}

function Get-TuningPowerPlan {
    $value = (& "$env:SystemRoot\System32\powercfg.exe" /getactivescheme 2>&1 | Out-String)
    $match = [regex]::Match($value, '[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}')
    if ($LASTEXITCODE -ne 0 -or -not $match.Success) { throw 'Não foi possível identificar o plano de energia ativo.' }
    $match.Value
}

function Set-TuningPowerPlan([string]$Plan) {
    $result = (& "$env:SystemRoot\System32\powercfg.exe" /setactive $Plan 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw "O plano está indisponível ou o acesso foi negado. $result" }
    if ((Get-TuningPowerPlan) -ne $Plan) { throw 'O Windows não confirmou o plano de energia solicitado.' }
}

function Get-TuningFolder {
    Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Pulso Arena\Backups'
}

function Read-TuningBackup([string]$File) {
    Get-Content -LiteralPath $File -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}

function Write-TuningBackup($Item) {
    $folder = Get-TuningFolder
    [void][IO.Directory]::CreateDirectory($folder)
    $file = Join-Path $folder ($Item.Token + '.json')
    $temporary = Join-Path $folder ([Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($temporary, (ConvertTo-Json -InputObject $Item -Depth 12), [Text.UTF8Encoding]::new($false))
        if ([IO.File]::Exists($file)) { [IO.File]::Replace($temporary, $file, [System.Management.Automation.Language.NullString]::Value) }
        else { [IO.File]::Move($temporary, $file) }
    } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}

function Get-OptimizerBackups {
    $folder = Get-TuningFolder
    if (-not [IO.Directory]::Exists($folder)) { return }
    $items = foreach ($file in Get-ChildItem -LiteralPath $folder -Filter '*.json' -File -ErrorAction Stop) {
        try { Read-TuningBackup $file.FullName } catch { Write-Warning "Backup ilegível: $($file.Name)." }
    }
    $items | Sort-Object TimeUtc -Descending
}

function Invoke-TuningLock([scriptblock]$Operation) {
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $mutex = [Threading.Mutex]::new($false, "Local\PulsoArena-$sid")
    $locked = $false
    try {
        try { $locked = $mutex.WaitOne([TimeSpan]::FromSeconds(5)) }
        catch [Threading.AbandonedMutexException] { $locked = $true }
        if (-not $locked) { throw 'Outro ajuste está em andamento. Tente novamente em alguns segundos.' }
        & $Operation
    } finally {
        if ($locked) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}

function Invoke-OptimizerTweak([string]$Id, [string]$Title) {
    Invoke-TuningLock {
        $definition = Get-TuningDefinition $Id
        $item = [pscustomobject]@{
            Token = [Guid]::NewGuid().ToString('N'); TimeUtc = [DateTime]::UtcNow.ToString('o'); Status = 'Pendente'
            Id = $Id; Title = $Title; Kind = $definition.Kind; Before = $null; After = $null
        }
        if ($definition.Kind -eq 'Registry') {
            $item.After = @($definition.Values)
            $item.Before = @($item.After | ForEach-Object { Get-TuningValue $_ })
            for ($index = 0; $index -lt $item.After.Count; $index++) {
                if (-not (Test-TuningValue $item.After[$index] $item.Before[$index])) { break }
            }
            if ($index -eq $item.After.Count) { return 'O Registro já contém os valores desse ajuste.' }
        } else {
            $item.Before = Get-TuningPowerPlan
            $item.After = $definition.Plan
            if ($item.Before -eq $item.After) { return 'Este plano de energia já está ativo.' }
        }
        Write-TuningBackup $item
        try {
            if ($definition.Kind -eq 'Registry') {
                foreach ($value in $item.After) { Set-TuningValue $value }
            } else { Set-TuningPowerPlan $item.After }
            $item.Status = 'Aplicado'
            Write-TuningBackup $item
        } catch {
            throw "A aplicação não foi concluída. O backup foi registrado em Recuperação. $($_.Exception.Message)"
        }
        if ($definition.Kind -eq 'Registry') { return 'Valores salvos e verificados. Saia e entre na sessão para carregar alterações de interface, se necessário.' }
        'Plano ativado e verificado.'
    }
}

function Undo-OptimizerTweak([string]$Token) {
    Invoke-TuningLock {
        if ($Token -notmatch '^[0-9a-f]{32}$') { throw 'Identificador de backup inválido.' }
        $item = Read-TuningBackup (Join-Path (Get-TuningFolder) ($Token + '.json'))
        if ($item.Token -ne $Token -or $item.Status -notin @('Aplicado', 'Pendente')) { throw 'Este backup já foi restaurado ou está indisponível.' }
        $definition = Get-TuningDefinition $item.Id
        if ($item.Kind -ne $definition.Kind) { throw 'O backup não corresponde ao tipo do ajuste.' }
        if ($item.Kind -eq 'Registry') {
            if (@($item.Before).Count -ne $definition.Values.Count -or @($item.After).Count -ne $definition.Values.Count) { throw 'Backup do Registro incompleto.' }
            for ($index = 0; $index -lt $definition.Values.Count; $index++) {
                $expected = $definition.Values[$index]
                $before = $item.Before[$index]
                $after = $item.After[$index]
                if ($before.Path -ne $expected.Path -or $before.Name -ne $expected.Name -or
                    $after.Path -ne $expected.Path -or $after.Name -ne $expected.Name -or
                    -not (Test-TuningValue $expected $after)) { throw 'O backup contém valores não autorizados.' }
                $current = Get-TuningValue $expected
                if (-not (Test-TuningValue $before $current) -and -not (Test-TuningValue $after $current)) {
                    throw 'O valor atual mudou fora deste ajuste. Revise as alterações recentes antes de restaurar.'
                }
            }
            foreach ($value in $item.Before) { Set-TuningValue $value }
        } else {
            $latest = Get-OptimizerBackups | Where-Object { $_.Kind -eq 'Power' -and $_.Status -in @('Aplicado', 'Pendente') } | Select-Object -First 1
            if ($latest.Token -ne $Token) { throw 'Restaure primeiro o ajuste de energia mais recente.' }
            $active = Get-TuningPowerPlan
            if ($item.After -ne $definition.Plan -or $item.Before -notmatch '^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$') { throw 'Backup do plano inválido.' }
            if ($active -ne $item.Before -and $active -ne $item.After) { throw 'O plano atual foi alterado depois deste backup.' }
            if ($active -ne $item.Before) { Set-TuningPowerPlan $item.Before }
        }
        $item.Status = 'Restaurado'
        Write-TuningBackup $item
        'Configuração anterior restaurada.'
    }
}
