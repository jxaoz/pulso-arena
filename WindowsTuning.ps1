$script:WindowsSpiSettings = @{
    winanimations = @{ Get = 0x1042; Set = 0x1043; Value = 0; Form = 'Pointer' }
    winwindragoutline = @{ Get = 0x0026; Set = 0x0025; Value = 0; Form = 'Word' }
    keyboarddelay = @{ Get = 0x0016; Set = 0x0017; Value = 0; Form = 'Word' }
    keyboardrepeat = @{ Get = 0x000A; Set = 0x000B; Value = 31; Form = 'Word' }
    mousecursortrail = @{ Get = 0x005E; Set = 0x005D; Value = 0; Form = 'Word' }
    mousesnapdefault = @{ Get = 0x005F; Set = 0x0060; Value = 0; Form = 'Word' }
    mousepointerdefault = @{ Get = 0x0070; Set = 0x0071; Value = 10; Form = 'Pointer' }
    stickykeys = @{ Get = 0x003A; Set = 0x003B; Value = 0; Form = 'Hotkey'; Words = 2 }
    filterkeys = @{ Get = 0x0032; Set = 0x0033; Value = 0; Form = 'Hotkey'; Words = 6 }
    togglekeyshotkey = @{ Get = 0x0034; Set = 0x0035; Value = 0; Form = 'Hotkey'; Words = 2 }
    mousekeyshotkey = @{ Get = 0x0036; Set = 0x0037; Value = 0; Form = 'Hotkey'; Words = 7 }
}

$processor = '54533251-82be-4824-96c1-47b60b740d00'
$script:WindowsPowerSettings = @{
    poweracminimum = @{ Subgroup = $processor; Setting = '893dee8e-2bef-41e0-89c6-b55d0929964c'; Value = 25; Maximum = 100 }
    poweracmaximum = @{ Subgroup = $processor; Setting = 'bc5038f7-23e0-4960-96da-33abaf5935ec'; Value = 100; Maximum = 100 }
    poweracboost = @{ Subgroup = $processor; Setting = 'be337238-0d82-4146-a960-4f3749d470c7'; Value = 1; Maximum = 6 }
    poweracepp = @{ Subgroup = $processor; Setting = '36687f9e-e3a5-4dbf-b1dc-15eb381c6863'; Value = 30; Maximum = 100 }
    poweracparking = @{ Subgroup = $processor; Setting = '0cc5b647-c1df-4637-891a-dec35c318583'; Value = 100; Maximum = 100 }
    poweracpcie = @{ Subgroup = '501a4d13-42af-4429-9fd1-a8218c268e20'; Setting = 'ee12f906-d277-404b-b6da-e5fa1a576df5'; Value = 0; Maximum = 2 }
    poweracdiskidle = @{ Subgroup = '0012ee47-9041-4b5d-9b77-535fba8b1442'; Setting = '6738e2c4-e8a5-4a42-b16a-e040e769756e'; Value = 0; Maximum = 2147483647 }
}

$script:WindowsRegistrySettings = @{
    deliveryoptimization = @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name = 'DODownloadMode'; Value = 0; Hive = 'LocalMachine'; MinimumBuild = 10586 }
    deliverybackgroundlimit = @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name = 'DOPercentageMaxBackgroundBandwidth'; Value = 10; Hive = 'LocalMachine'; MinimumBuild = 17134 }
    deliveryforegroundlimit = @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name = 'DOPercentageMaxForegroundBandwidth'; Value = 25; Hive = 'LocalMachine'; MinimumBuild = 17134 }
    backgroundapps = @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name = 'LetAppsRunInBackground'; Value = 2; Hive = 'LocalMachine'; MinimumBuild = 15063 }
    backgroundbrowser = @{ Path = 'SOFTWARE\Policies\Microsoft\Edge'; Name = 'BackgroundModeEnabled'; Value = 0; Hive = 'CurrentUser' }
    startupboost = @{ Path = 'SOFTWARE\Policies\Microsoft\Edge'; Name = 'StartupBoostEnabled'; Value = 0; Hive = 'CurrentUser' }
    chromebackground = @{ Path = 'SOFTWARE\Policies\Google\Chrome'; Name = 'BackgroundModeEnabled'; Value = 0; Hive = 'CurrentUser' }
}

function Get-WindowsTuningDefinition([string]$Id, $Options) {
    if ($script:WindowsRegistrySettings.ContainsKey($Id)) {
        $entry = $script:WindowsRegistrySettings[$Id]
        $machinePolicy = $entry.Hive -eq 'LocalMachine'
        return [pscustomobject]@{
            Kind = 'Registry'; Input = ''; Admin = $machinePolicy
            MinimumBuild = [int]$entry.MinimumBuild; RequiresPolicyEdition = $machinePolicy
            Values = @(New-TuningValue $entry.Path $entry.Name $entry.Value 'DWord' $entry.Hive)
        }
    }
    if ($Id -in @('gamegpu', 'flipmodel', 'hags') -or $script:WindowsSpiSettings.ContainsKey($Id) -or $script:WindowsPowerSettings.ContainsKey($Id)) {
        $inputKind = if ($Id -eq 'gamegpu') { 'Executable' } else { '' }
        $minimumBuild = switch ($Id) {
            gamegpu { 17134 }
            flipmodel { 22621 }
            hags { 19041 }
            default { 0 }
        }
        return [pscustomobject]@{
            Kind = 'WindowsAction'; Input = $inputKind; Admin = ($Id -eq 'hags')
            MinimumBuild = $minimumBuild; RequiresPolicyEdition = $false; Values = @()
        }
    }
}

function Initialize-WindowsTuningNative {
    if ('Pulso.WindowsTuningNative' -as [type]) { return }
    Add-Type -Language CSharp -ErrorAction Stop -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace Pulso
{
    public static class WindowsTuningNative
    {
        private const uint PersistAndNotify = 3;
        private const uint HotkeyEnabled = 4;

        [DllImport("user32.dll", EntryPoint="SystemParametersInfoW", SetLastError=true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool ReadParameter(uint action, uint words, out uint value, uint flags);

        [DllImport("user32.dll", EntryPoint="SystemParametersInfoW", SetLastError=true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool BufferParameter(uint action, uint bytes, [In, Out] uint[] data, uint flags);

        [DllImport("user32.dll", EntryPoint="SystemParametersInfoW", SetLastError=true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool WriteParameter(uint action, uint value, IntPtr pointer, uint flags);

        [DllImport("powrprof.dll")]
        private static extern uint PowerGetActiveScheme(IntPtr root, out IntPtr scheme);
        [DllImport("powrprof.dll")]
        private static extern uint PowerReadACValueIndex(IntPtr root, ref Guid scheme, ref Guid subgroup, ref Guid setting, out uint value);
        [DllImport("powrprof.dll")]
        private static extern uint PowerWriteACValueIndex(IntPtr root, ref Guid scheme, ref Guid subgroup, ref Guid setting, uint value);
        [DllImport("powrprof.dll")]
        private static extern uint PowerSetActiveScheme(IntPtr root, ref Guid scheme);
        [DllImport("kernel32.dll")]
        private static extern IntPtr LocalFree(IntPtr value);

        public static uint ReadPreference(uint action)
        {
            uint value;
            if (!ReadParameter(action, 0, out value, 0))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            return value;
        }

        public static void WritePreference(uint action, uint value, bool usePointer)
        {
            uint parameter = usePointer ? 0 : value;
            IntPtr pointer = usePointer ? new IntPtr(value) : IntPtr.Zero;
            if (!WriteParameter(action, parameter, pointer, PersistAndNotify))
                throw new Win32Exception(Marshal.GetLastWin32Error());
        }

        private static uint[] ReadHotkeyParameters(uint action, int length)
        {
            var values = new uint[length];
            values[0] = (uint) (sizeof(uint) * length);
            if (!BufferParameter(action, values[0], values, 0))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            return values;
        }

        public static uint ReadHotkey(uint action, int length)
        {
            return (ReadHotkeyParameters(action, length)[1] & HotkeyEnabled) == 0 ? 0u : 1u;
        }

        public static void WriteHotkey(uint get, uint set, int length, uint value, uint expected)
        {
            var values = ReadHotkeyParameters(get, length);
            uint current = (values[1] & HotkeyEnabled) == 0 ? 0u : 1u;
            if (current != expected)
                throw new InvalidOperationException("O atalho do Windows mudou desde a conferência.");
            values[1] = value == 0 ? values[1] & ~HotkeyEnabled : values[1] | HotkeyEnabled;
            if (!BufferParameter(set, values[0], values, PersistAndNotify))
                throw new Win32Exception(Marshal.GetLastWin32Error());
        }

        private static void Check(uint status)
        {
            if (status != 0) throw new Win32Exception((int) status);
        }

        public static Guid GetActiveScheme()
        {
            IntPtr scheme;
            Check(PowerGetActiveScheme(IntPtr.Zero, out scheme));
            try { return (Guid) Marshal.PtrToStructure(scheme, typeof(Guid)); }
            finally { LocalFree(scheme); }
        }

        public static void ActivateScheme(Guid scheme)
        {
            Check(PowerSetActiveScheme(IntPtr.Zero, ref scheme));
        }

        public static uint ReadAc(Guid scheme, Guid subgroup, Guid setting)
        {
            uint value;
            Check(PowerReadACValueIndex(IntPtr.Zero, ref scheme, ref subgroup, ref setting, out value));
            return value;
        }

        public static void WriteAc(Guid scheme, Guid subgroup, Guid setting, uint value, uint expected)
        {
            if (ReadAc(scheme, subgroup, setting) != expected)
                throw new InvalidOperationException("O ajuste do plano mudou desde a conferência.");
            Check(PowerWriteACValueIndex(IntPtr.Zero, ref scheme, ref subgroup, ref setting, value));
            if (GetActiveScheme() == scheme)
                ActivateScheme(scheme);
        }
    }
}
'@
}

function Get-WindowsBuildNumber {
    [int](Get-ItemPropertyValue -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'CurrentBuildNumber' -ErrorAction Stop)
}

function Get-WindowsExecutable([string]$Path, [switch]$MustExist) {
    if ($Path -notmatch '^[A-Za-z]:\\' -or $Path.Substring(2).Contains(':')) { throw 'Selecione um arquivo executável local do jogo.' }
    $fullPath = [IO.Path]::GetFullPath($Path)
    if ([IO.Path]::GetExtension($fullPath) -ine '.exe' -or ($MustExist -and -not [IO.File]::Exists($fullPath))) {
        throw 'Selecione o arquivo .exe que inicia o jogo.'
    }
    $fullPath
}

function Get-WindowsGraphicsPreference([string]$Id, [string]$Target) {
    $path = 'Software\Microsoft\DirectX\UserGpuPreferences'
    $property = if ($Id -eq 'gamegpu') { 'GpuPreference' } else { 'SwapEffectUpgradeEnable' }
    $current = Get-TuningValue (New-TuningValue $path $Target '' 'String' 'CurrentUser')
    if ($current.Exists -and $current.Type -ne 'String') { throw 'A preferência de vídeo tem um formato que o aplicativo não reconhece.' }
    $raw = [string]$current.Value
    $pattern = '(?i)(?<![^;])\s*' + [regex]::Escape($property) + '\s*=\s*(?<Value>[^;]*)(?:;|$)'
    $parts = [regex]::Matches($raw, $pattern)
    if ($parts.Count -gt 1) { throw 'O Windows retornou mais de uma entrada para essa opção gráfica.' }
    $part = if ($parts.Count) { $parts[0] }
    $entry = if ($part) { $part.Groups['Value'].Value }
    [pscustomobject]@{
        Entry = $entry; Exists = $current.Exists; Raw = $raw; Part = $part
        Property = $property; Registry = $current
    }
}

function Get-WindowsHagsCapability {
    if ((Get-WindowsBuildNumber) -lt 19041) { return $false }
    $report = Join-Path ([IO.Path]::GetTempPath()) ('PulsoArena-DxDiag-' + [guid]::NewGuid().ToString('N') + '.txt')
    $process = $null
    try {
        $arguments = '/whql:off /t "' + $report + '"'
        $process = Start-Process -FilePath (Join-Path ([Environment]::SystemDirectory) 'dxdiag.exe') -ArgumentList $arguments -WindowStyle Hidden -PassThru -ErrorAction Stop
        if (-not $process.WaitForExit(15000)) { throw 'O diagnóstico de vídeo excedeu o tempo de espera.' }
        if (-not [IO.File]::Exists($report)) { throw 'O Windows não gerou o diagnóstico de vídeo.' }
        [IO.File]::ReadAllText($report) -match 'DriverSupportState\s*:\s*Stable\s+Enabled\s*:\s*(True|False)\b'
    } finally {
        if ($process) {
            if (-not $process.HasExited) { $process.Kill(); [void]$process.WaitForExit(1000) }
            $process.Dispose()
        }
        if ([IO.File]::Exists($report)) { [IO.File]::Delete($report) }
    }
}

function Get-WindowsHagsRegistry {
    New-TuningValue 'SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2 'DWord' 'LocalMachine'
}

function Get-WindowsSpiValue($Entry) {
    Initialize-WindowsTuningNative
    if ($Entry.Form -eq 'Hotkey') { return [Pulso.WindowsTuningNative]::ReadHotkey($Entry.Get, $Entry.Words) }
    $current = [Pulso.WindowsTuningNative]::ReadPreference($Entry.Get)
    if ($Entry.Get -eq 0x005E -and $current -le 1) { return 0 }
    $current
}

function Get-WindowsTuningPlan([string]$Id, $Options) {
    if ($script:WindowsSpiSettings.ContainsKey($Id)) {
        $spi = $script:WindowsSpiSettings[$Id]
        return [pscustomobject]@{ Before = [pscustomobject]@{ Value = Get-WindowsSpiValue $spi }; After = [pscustomobject]@{ Value = $spi.Value } }
    }
    if ($script:WindowsPowerSettings.ContainsKey($Id)) {
        Initialize-WindowsTuningNative
        $power = $script:WindowsPowerSettings[$Id]
        $scheme = [Pulso.WindowsTuningNative]::GetActiveScheme()
        $current = [Pulso.WindowsTuningNative]::ReadAc($scheme, $power.Subgroup, $power.Setting)
        $desired = $power.Value
        if ($Id -eq 'poweracminimum') {
            $maximum = $script:WindowsPowerSettings.poweracmaximum
            $upperLimit = [Pulso.WindowsTuningNative]::ReadAc($scheme, $maximum.Subgroup, $maximum.Setting)
            $desired = [math]::Max($current, [math]::Min([uint32]$upperLimit, [uint32]$desired))
        }
        if ($Id -eq 'poweracboost' -and $current -gt 0) { $desired = $current }
        if ($Id -eq 'poweracepp' -and $current -lt $desired) { $desired = $current }
        return [pscustomobject]@{ Before = [pscustomobject]@{ Scheme = $scheme.ToString(); Value = $current }; After = [pscustomobject]@{ Scheme = $scheme.ToString(); Value = $desired } }
    }
    if ($Id -eq 'hags') {
        if (-not (Get-WindowsHagsCapability)) { throw 'O Windows e o driver não confirmaram suporte ao agendamento de GPU por hardware.' }
        $setting = Get-WindowsHagsRegistry
        $current = Get-TuningValue $setting
        if ($current.Exists -and $current.Type -ne 'DWord') { throw 'O valor de agendamento tem um formato inesperado no Registro.' }
        return [pscustomobject]@{ Before = [pscustomobject]@{ Exists = $current.Exists; Value = $current.Value }; After = [pscustomobject]@{ Exists = $true; Value = 2 } }
    }
    if ($Id -eq 'gamegpu' -or $Id -eq 'flipmodel') {
        $build = Get-WindowsBuildNumber
        if ($Id -eq 'gamegpu') {
            if ($build -lt 17134) { throw 'A preferência de GPU por jogo exige o Windows 10 1803 ou posterior.' }
            $target = Get-WindowsExecutable $Options.Executable -MustExist
            $desired = '2'
        } else {
            if ($build -lt 22621) { throw 'A otimização de jogos em janela exige o Windows 11 22H2 ou posterior.' }
            $target = 'DirectXUserGlobalSettings'
            $desired = '1'
        }
        $current = Get-WindowsGraphicsPreference $Id $target
        return [pscustomobject]@{
            Before = [pscustomobject]@{ Target = $target; Entry = $current.Entry; Exists = $current.Exists }
            After = [pscustomobject]@{ Target = $target; Entry = $desired; Exists = $true }
        }
    }
    throw 'O ajuste do Windows é desconhecido.'
}

function Test-WindowsTuningState([string]$Id, $State) {
    if ($script:WindowsSpiSettings.ContainsKey($Id)) {
        return ((Get-WindowsSpiValue $script:WindowsSpiSettings[$Id]) -eq $State.Value)
    }
    if ($script:WindowsPowerSettings.ContainsKey($Id)) {
        Initialize-WindowsTuningNative
        $power = $script:WindowsPowerSettings[$Id]
        return ([Pulso.WindowsTuningNative]::ReadAc([guid]$State.Scheme, $power.Subgroup, $power.Setting) -eq $State.Value)
    }
    if ($Id -eq 'hags') {
        $current = Get-TuningValue (Get-WindowsHagsRegistry)
        return ([bool]$current.Exists -eq [bool]$State.Exists -and (-not $current.Exists -or ($current.Type -eq 'DWord' -and $current.Value -eq $State.Value)))
    }
    if ($Id -eq 'gamegpu' -or $Id -eq 'flipmodel') {
        $target = if ($Id -eq 'gamegpu') { Get-WindowsExecutable $State.Target } else { 'DirectXUserGlobalSettings' }
        if ($target -ine $State.Target) { return $false }
        return ((Get-WindowsGraphicsPreference $Id $target).Entry -ceq $State.Entry)
    }
    throw 'O ajuste do Windows é desconhecido.'
}

function Set-WindowsTuningState([string]$Id, $State, $Expected) {
    if (Test-WindowsTuningState $Id $State) { return }
    if (-not (Test-WindowsTuningState $Id $Expected)) { throw 'O ajuste do Windows mudou desde a conferência.' }
    if ($script:WindowsSpiSettings.ContainsKey($Id)) {
        $spi = $script:WindowsSpiSettings[$Id]
        $value = [uint32]$State.Value
        $maximum = switch ($Id) {
            keyboarddelay { 3 }
            keyboardrepeat { 31 }
            mousecursortrail { 1024 }
            mousepointerdefault { 20 }
            default { 1 }
        }
        if ($value -gt $maximum -or ($Id -eq 'mousepointerdefault' -and $value -eq 0)) { throw 'O backup contém um valor de interface inválido.' }
        if ($spi.Form -eq 'Hotkey') { [Pulso.WindowsTuningNative]::WriteHotkey($spi.Get, $spi.Set, $spi.Words, $value, [uint32]$Expected.Value) }
        else { [Pulso.WindowsTuningNative]::WritePreference($spi.Set, $value, ($spi.Form -eq 'Pointer')) }
    } elseif ($script:WindowsPowerSettings.ContainsKey($Id)) {
        $power = $script:WindowsPowerSettings[$Id]
        $value = [uint32]$State.Value
        if ($State.Scheme -ne $Expected.Scheme -or $value -gt $power.Maximum) { throw 'O backup do plano contém opções que não correspondem ao ajuste.' }
        [Pulso.WindowsTuningNative]::WriteAc([guid]$State.Scheme, $power.Subgroup, $power.Setting, $value, [uint32]$Expected.Value)
    } elseif ($Id -eq 'hags') {
        $setting = Get-WindowsHagsRegistry
        $setting.Exists = [bool]$State.Exists
        $setting.Value = [int]$State.Value
        Set-TuningValue $setting
    } else {
        if ($State.Target -ine $Expected.Target) { throw 'O backup de vídeo não corresponde ao executável ou à opção original.' }
        $target = if ($Id -eq 'gamegpu') { Get-WindowsExecutable $State.Target } else { 'DirectXUserGlobalSettings' }
        $current = Get-WindowsGraphicsPreference $Id $target
        if ($current.Entry -cne $Expected.Entry) { throw 'A preferência de vídeo do Windows mudou desde a conferência.' }
        $raw = $current.Raw
        $replacement = ''
        if ($null -ne $State.Entry) {
            if ([string]$State.Entry -notmatch '^\d{1,2}\s*$') { throw 'O backup contém uma preferência gráfica inválida.' }
            $replacement = $current.Property + '=' + $State.Entry + ';'
        }
        if ($current.Part) { $raw = $raw.Remove($current.Part.Index, $current.Part.Length).Insert($current.Part.Index, $replacement) }
        elseif ($replacement) {
            if ($raw.Length -gt 0 -and -not $raw.EndsWith(';', [StringComparison]::Ordinal)) { $raw += ';' }
            $raw += $replacement
        }
        $desired = New-TuningValue $current.Registry.Path $target $raw 'String' 'CurrentUser'
        $desired.Exists = ($raw.Length -gt 0 -or [bool]$State.Exists)
        Set-TuningValue $desired
    }
    if (-not (Test-WindowsTuningState $Id $State)) { throw 'O Windows não confirmou o novo valor.' }
}
