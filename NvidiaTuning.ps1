# IDs, enum values and ABI layout are from the NVIDIA NVAPI SDK.
# https://github.com/NVIDIA/nvapi/blob/main/NvApiDriverSettings.h
# https://docs.nvidia.com/nvapi/group__drsapi.html

function Get-NvidiaTuningDefinition([string]$Id) {
    $setting = switch ($Id) {
        nvpstate          { 0x1057EB71, 1, 'Executable' }
        nvtexture         { 0x00CE2691, 10, 'Executable' }
        shadercache       { 0x00198FFF, 1, '' }
        nvlowlatency      { 0x007BA09E, 1, 'Executable' }
        nvfpscap          { 0x10835002, 0, 'ExecutableFps', 20, 1000 }
        nvvsyngeneric     { 0x00A879CF, 0x08416747, 'Executable' }
        gamebackgroundfps { 0x10835016, 0, 'ExecutableFps', 20, 200 }
        nvpreferredrefresh { 0x0064B541, 1, 'Executable' }
        nvogltriplebuffer { 0x20FDD1F9, 1, 'Executable' }
        nvoglthreaded     { 0x20C1221E, 1, 'Executable' }
        nvfxaaoff         { 0x1074C972, 0, 'Executable' }
        nvtrilinear       { 0x002ECAF2, 1, 'Executable' }
        nvanisosample     { 0x00E73211, 1, 'Executable' }
        nvshadercachesize { 0x00AC8497, 10240, '' }
        default { return }
    }
    $minimum = $null
    $maximum = $null
    if ($setting.Count -eq 5) { $minimum = $setting[3]; $maximum = $setting[4] }
    [pscustomobject]@{ Kind = 'Nvidia'; Input = [string]$setting[2]; Admin = $false; Setting = [uint32]$setting[0]; Value = [uint32]$setting[1]; MinFps = $minimum; MaxFps = $maximum }
}

function Initialize-NvidiaTuning {
    if ('PulsoArena.NvidiaProfiles' -as [type]) { return }
    Add-Type -Language CSharp -ErrorAction Stop -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;

namespace PulsoArena {
    public sealed class NvidiaSnapshot {
        public string Profile { get; set; }
        public string Binding { get; set; }
        public bool Override { get; set; }
        public uint Value { get; set; }
        public bool EffectiveKnown { get; set; }
        public uint EffectiveValue { get; set; }
    }

    public sealed class NvidiaProfiles : IDisposable {
        private const int UnicodeBytes = 4096;
        private const int ProfileSize = 4 + UnicodeBytes + 16;
        private const int ApplicationSize = 8 + (5 * UnicodeBytes) + 4;
        // NVDRS_SETTING_V1 is packed to 4 bytes. Each value union is 4100 bytes.
        private const int SettingIdOffset = 4 + UnicodeBytes;
        private const int SettingTypeOffset = SettingIdOffset + 4;
        private const int SettingLocationOffset = SettingIdOffset + 8;
        private const int SettingIsPredefinedOffset = SettingIdOffset + 12;
        private const int SettingCurrentOffset = SettingIdOffset + 20 + 4100;
        private const int SettingSize = SettingCurrentOffset + 4100;

        private const int SettingNotFound = -160;
        private const int ExecutableNotFound = -166;
        private const int AmbiguousExecutable = -182;
        private const int AccessDenied = -175;
        private IntPtr library;
        private IntPtr session;
        private bool initialized;
        private QueryInterface query;

        [DllImport("kernel32.dll", EntryPoint="LoadLibraryExW", CharSet=CharSet.Unicode, SetLastError=true)]
        private static extern IntPtr LoadLibraryEx(string fileName, IntPtr file, uint flags);
        [DllImport("kernel32.dll", CharSet=CharSet.Ansi, SetLastError=true)]
        private static extern IntPtr GetProcAddress(IntPtr module, string name);
        [DllImport("kernel32.dll", SetLastError=true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool FreeLibrary(IntPtr module);

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate IntPtr QueryInterface(uint id);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate int NoArgument();
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate int HandleArgument(IntPtr handle);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate int NewSession(out IntPtr result);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate int ActiveGpuList([Out] IntPtr[] handles, out uint count);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate int ProfileHandle(IntPtr handle, out IntPtr profile);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate int ProfileBuffer(IntPtr handle, IntPtr profile, IntPtr buffer);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate int FindApplication(IntPtr handle, IntPtr exe, out IntPtr profile, IntPtr app);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate int CreateProfile(IntPtr handle, IntPtr info, out IntPtr profile);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate int DeleteProfile(IntPtr handle, IntPtr profile);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate int SettingName(uint id, IntPtr name);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate int ReadSetting(IntPtr handle, IntPtr profile, uint id, IntPtr setting);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate int DeleteSetting(IntPtr handle, IntPtr profile, uint id);

        private sealed class Buffer : IDisposable {
            public readonly IntPtr Pointer;
            public Buffer(int length, int version = 0) {
                Pointer = Marshal.AllocHGlobal(length);
                Marshal.Copy(new byte[length], 0, Pointer, length);
                if (version != 0) Write(0, (uint)(length | (version << 16)));
            }
            public uint Read(int offset) { return unchecked((uint)Marshal.ReadInt32(Pointer, offset)); }
            public void Write(int offset, uint value) { Marshal.WriteInt32(Pointer, offset, unchecked((int)value)); }
            public string ReadString(int offset) {
                string text = Marshal.PtrToStringUni(IntPtr.Add(Pointer, offset), UnicodeBytes / 2);
                int end = text.IndexOf('\0');
                return end < 0 ? text : text.Substring(0, end);
            }
            public void WriteString(int offset, string text) {
                byte[] encoded = Encoding.Unicode.GetBytes(text + '\0');
                if (encoded.Length > UnicodeBytes) throw new ArgumentException("O caminho excede o limite do driver NVIDIA.");
                Marshal.Copy(encoded, 0, IntPtr.Add(Pointer, offset), encoded.Length);
            }
            public void Dispose() { Marshal.FreeHGlobal(Pointer); }
        }

        public NvidiaProfiles() {
            try {
                if (!Environment.Is64BitProcess) throw new InvalidOperationException("O ajuste NVIDIA exige o Windows PowerShell de 64 bits.");
                string path = Path.Combine(Environment.SystemDirectory, "nvapi64.dll");
                library = LoadLibraryEx(path, IntPtr.Zero, 0x00000800);
                if (library == IntPtr.Zero) throw new InvalidOperationException("O driver NVIDIA com NVAPI não está disponível neste PC.");
                IntPtr address = GetProcAddress(library, "nvapi_QueryInterface");
                if (address == IntPtr.Zero) throw new InvalidOperationException("O driver NVIDIA não expõe a interface NVAPI.");
                query = (QueryInterface)Marshal.GetDelegateForFunctionPointer(address, typeof(QueryInterface));
                Check(Api<NoArgument>(0x0150E828)(), "inicializar o driver");
                initialized = true;
                uint gpuCount;
                Check(Api<ActiveGpuList>(0xE5AC921F)(new IntPtr[64], out gpuCount), "localizar a GPU NVIDIA");
                if (gpuCount == 0) throw new InvalidOperationException("Nenhuma GPU NVIDIA ativa foi encontrada.");
                Check(Api<NewSession>(0x0694D52E)(out session), "abrir a sessão de perfis");
                Check(Api<HandleArgument>(0x375DBD6B)(session), "ler a base de perfis");
            } catch { Dispose(); throw; }
        }

        private T Api<T>(uint id) where T : class {
            IntPtr address = query(id);
            if (address == IntPtr.Zero) throw new NotSupportedException("O driver NVIDIA não oferece a API necessária ao ajuste.");
            return (T)(object)Marshal.GetDelegateForFunctionPointer(address, typeof(T));
        }

        private static void Check(int status, string operation) {
            if (status == 0) return;
            if (status == AccessDenied || status == -137) {
                throw new UnauthorizedAccessException("O driver recusou acesso à configuração. Verifique as permissões no Painel de Controle NVIDIA.");
            }
            if (status == SettingNotFound || status == -104) {
                throw new NotSupportedException("O driver NVIDIA atual não oferece este ajuste.");
            }
            throw new InvalidOperationException("Falha ao " + operation + " (NVAPI " + status + ").");
        }

        public bool Supports(uint id) {
            using (var name = new Buffer(UnicodeBytes)) {
                int status = Api<SettingName>(0xD61CBE6E)(id, name.Pointer);
                if (status == SettingNotFound || status == -104) return false;
                Check(status, "verificar a disponibilidade do ajuste");
                return !String.IsNullOrEmpty(name.ReadString(0));
            }
        }

        public static string ManagedName(string executable) {
            using (SHA256 hash = SHA256.Create()) {
                byte[] key = hash.ComputeHash(Encoding.UTF8.GetBytes(PathKey(executable)));
                return "Pulso Arena " + BitConverter.ToString(key, 0, 12).Replace("-", "");
            }
        }

        private static string PathKey(string path) { return String.IsNullOrEmpty(path) ? String.Empty : path.Replace('\\', '/').ToLowerInvariant(); }

        private IntPtr GetProfile(string executable, out string profile, out string binding) {
            IntPtr handle = IntPtr.Zero;
            profile = null;
            binding = null;
            if (String.IsNullOrEmpty(executable)) {
                Check(Api<ProfileHandle>(0x617BFF9F)(session, out handle), "localizar o perfil global");
            } else {
                using (var queryName = new Buffer(UnicodeBytes))
                using (var app = new Buffer(ApplicationSize, 4)) {
                    queryName.WriteString(0, executable.Replace('\\', '/'));
                    int status = Api<FindApplication>(0xEEE566B2)(session, queryName.Pointer, out handle, app.Pointer);
                    if (status == ExecutableNotFound) return IntPtr.Zero;
                    if (status == AmbiguousExecutable) throw new InvalidOperationException("O driver encontrou associações ambíguas para o executável selecionado.");
                    Check(status, "localizar o perfil do executável");
                    binding = app.ReadString(8);
                    string bindingKey = PathKey(binding);
                    string requested = PathKey(executable);
                    bool matchesPath = bindingKey.Length > 0 &&
                        (String.Equals(bindingKey, requested, StringComparison.Ordinal) || requested.EndsWith("/" + bindingKey, StringComparison.Ordinal));
                    if (!matchesPath) throw new InvalidOperationException("O perfil NVIDIA não corresponde ao executável selecionado.");
                    if (bindingKey.IndexOf('/') < 0 && Array.IndexOf(new[] {
                        "game.exe", "client.exe", "launcher.exe", "launch.exe", "start.exe", "setup.exe",
                        "unity.exe", "ue4game.exe", "ue5game.exe", "unrealgame.exe"
                    }, bindingKey) >= 0) {
                        throw new InvalidOperationException("O perfil NVIDIA usa um nome de executável genérico e pode atender a outros programas. Selecione o executável específico do jogo.");
                    }
                }
            }
            using (var info = ReadProfileInfo(handle)) {
                profile = info.ReadString(4);
                if (String.IsNullOrWhiteSpace(profile)) throw new InvalidOperationException("O driver não retornou um perfil identificável.");
                if (!String.IsNullOrEmpty(executable) && info.Read(4 + UnicodeBytes + 8) != 1) {
                    throw new InvalidOperationException("Este perfil NVIDIA é compartilhado por vários executáveis. Use o Painel de Controle NVIDIA para revisar a associação antes de alterá-lo.");
                }
            }
            return handle;
        }

        private Buffer ReadProfileInfo(IntPtr handle) {
            var info = new Buffer(ProfileSize, 1);
            try { Check(Api<ProfileBuffer>(0x61CD6FD6)(session, handle, info.Pointer), "ler a identidade do perfil"); return info; }
            catch { info.Dispose(); throw; }
        }

        public NvidiaSnapshot Read(string executable, uint id) {
            string profile;
            string binding;
            IntPtr handle = GetProfile(executable, out profile, out binding);
            if (handle == IntPtr.Zero) {
                // A title without a profile inherits the current global configuration.
                string ignoredName;
                string ignoredBinding;
                IntPtr global = GetProfile(null, out ignoredName, out ignoredBinding);
                NvidiaSnapshot inherited = ReadValues(global, id);
                return new NvidiaSnapshot { EffectiveKnown = inherited.EffectiveKnown, EffectiveValue = inherited.EffectiveValue };
            }
            NvidiaSnapshot result = ReadValues(handle, id);
            result.Profile = profile;
            result.Binding = binding;
            return result;
        }

        private NvidiaSnapshot ReadValues(IntPtr handle, uint id) {
            using (var setting = new Buffer(SettingSize, 1)) {
                int result = Api<ReadSetting>(0x73BF8338)(session, handle, id, setting.Pointer);
                if (result == SettingNotFound) return new NvidiaSnapshot();
                Check(result, "ler o valor do perfil");
                if (setting.Read(SettingTypeOffset) != 0) throw new NotSupportedException("O perfil usa um tipo de ajuste diferente do esperado.");
                uint value = setting.Read(SettingCurrentOffset);
                bool hasOverride = setting.Read(SettingLocationOffset) == 0 && setting.Read(SettingIsPredefinedOffset) == 0;
                return new NvidiaSnapshot { Override = hasOverride, Value = hasOverride ? value : 0, EffectiveKnown = true, EffectiveValue = value };
            }
        }

        public static bool Matches(string executable, NvidiaSnapshot current, NvidiaSnapshot expected) {
            if (expected.Profile == null) {
                if (current.Profile == null) return !current.Override;
                return !current.Override && !String.IsNullOrEmpty(executable) &&
                    String.Equals(current.Profile, ManagedName(executable), StringComparison.Ordinal) &&
                    String.Equals(PathKey(current.Binding), PathKey(executable), StringComparison.Ordinal);
            }
            if (current.Profile == null && !expected.Override && !String.IsNullOrEmpty(executable)) {
                return String.Equals(expected.Profile, ManagedName(executable), StringComparison.Ordinal) &&
                    String.Equals(PathKey(expected.Binding), PathKey(executable), StringComparison.Ordinal);
            }
            return String.Equals(current.Profile, expected.Profile, StringComparison.Ordinal) &&
                String.Equals(current.Binding, expected.Binding, StringComparison.OrdinalIgnoreCase) &&
                current.Override == expected.Override && (!expected.Override || current.Value == expected.Value);
        }

        private IntPtr CreateExecutableProfile(string executable, string profile) {
            IntPtr result;
            using (var info = new Buffer(ProfileSize, 1)) {
                info.WriteString(4, profile);
                Check(Api<CreateProfile>(0xCC176068)(session, info.Pointer, out result), "criar o perfil do jogo");
            }
            using (var app = new Buffer(ApplicationSize, 4)) {
                app.WriteString(8, executable.Replace('\\', '/'));
                app.WriteString(8 + UnicodeBytes, Path.GetFileName(executable));
                Check(Api<ProfileBuffer>(0x4347A9DE)(session, result, app.Pointer), "associar o executável ao perfil");
            }
            string committedProfile;
            string committedBinding;
            IntPtr verified = GetProfile(executable, out committedProfile, out committedBinding);
            if (verified != result || committedProfile != profile || PathKey(committedBinding) != PathKey(executable)) {
                throw new InvalidOperationException("O driver não preservou a associação exclusiva para o caminho completo do jogo.");
            }
            return result;
        }

        public bool Change(string executable, uint id, NvidiaSnapshot desired, NvidiaSnapshot expected) {
            NvidiaSnapshot current = Read(executable, id);
            if (!Matches(executable, current, expected)) {
                throw new InvalidOperationException("O perfil NVIDIA mudou desde a prévia. Revise o valor atual antes de continuar.");
            }
            if (Matches(executable, current, desired)) return false;
            string profile;
            string binding;
            IntPtr handle = GetProfile(executable, out profile, out binding);
            if (handle == IntPtr.Zero) {
                if (!desired.Override || String.IsNullOrEmpty(executable) || desired.Profile != ManagedName(executable)) {
                    throw new InvalidOperationException("O perfil original do jogo não está mais disponível.");
                }
                handle = CreateExecutableProfile(executable, desired.Profile);
            }
            if (desired.Override) {
                using (var setting = new Buffer(SettingSize, 1)) {
                    setting.Write(SettingIdOffset, id);
                    setting.Write(SettingCurrentOffset, desired.Value);
                    Check(Api<ProfileBuffer>(0x577DD202)(session, handle, setting.Pointer), "aplicar o valor ao perfil");
                }
            } else {
                Check(Api<DeleteSetting>(0xE4A26362)(session, handle, id), "remover o valor personalizado");
                // Only remove the empty, app-owned profile. Preserve independent tweaks.
                if (!String.IsNullOrEmpty(executable) && profile == ManagedName(executable)) {
                    using (var info = ReadProfileInfo(handle)) {
                        uint profileFlags = info.Read(4 + UnicodeBytes + 4);
                        uint applications = info.Read(4 + UnicodeBytes + 8);
                        uint settings = info.Read(4 + UnicodeBytes + 12);
                        if (profileFlags == 0 && applications == 1 && settings == 0) {
                            Check(Api<DeleteProfile>(0x17093206)(session, handle), "remover o perfil exclusivo vazio");
                        }
                    }
                }
            }
            if (!Matches(executable, Read(executable, id), desired)) {
                throw new InvalidOperationException("O valor proposto não foi confirmado na sessão NVIDIA.");
            }
            return true;
        }

        public void Save() { Check(Api<HandleArgument>(0xFCBC7E14)(session), "salvar os perfis NVIDIA"); }

        public void Dispose() {
            try {
                if (session != IntPtr.Zero) Api<HandleArgument>(0xDAD9CFF8)(session);
            } finally {
                session = IntPtr.Zero;
                try { if (initialized) Api<NoArgument>(0xD22BDD7E)(); }
                finally {
                    initialized = false;
                    if (library != IntPtr.Zero) { FreeLibrary(library); library = IntPtr.Zero; }
                }
            }
        }
    }
}
'@
}

function Get-NvidiaExecutable([string]$Path, [switch]$AllowMissing) {
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path -notmatch '^[a-zA-Z]:[\\/]' -or $Path.Substring(2).Contains(':')) {
        throw 'Selecione um executável .exe local do jogo.'
    }
    $full = [IO.Path]::GetFullPath($Path)
    if ([IO.Path]::GetExtension($full) -ine '.exe' -or $full.Length -ge 2048 -or (-not $AllowMissing -and -not [IO.File]::Exists($full))) {
        throw 'Selecione um executável .exe existente do jogo.'
    }
    $full
}

function New-NvidiaTuningState([string]$Executable, $Native) {
    [pscustomobject]@{ Executable = $Executable; Profile = $Native.Profile; Binding = $Native.Binding; Override = [bool]$Native.Override; Value = [uint32]$Native.Value }
}

function ConvertTo-NvidiaSnapshot($State) {
    $native = New-Object PulsoArena.NvidiaSnapshot
    if ($State.Profile) { $native.Profile = [string]$State.Profile }
    if ($State.Binding) { $native.Binding = [string]$State.Binding }
    $native.Override = [bool]$State.Override
    $native.Value = [uint32]$State.Value
    $native
}

function Get-NvidiaTuningPlan($Id, $Options) {
    $definition = Get-NvidiaTuningDefinition $Id
    if (-not $definition) { throw 'Ajuste NVIDIA desconhecido.' }
    $exe = if ($definition.Input) { Get-NvidiaExecutable $Options.Executable } else { '' }
    $value = $definition.Value
    if ($definition.Input -eq 'ExecutableFps') {
        $fps = 0
        if (-not [int]::TryParse([string]$Options.Fps, [ref]$fps) -or $fps -lt $definition.MinFps -or $fps -gt $definition.MaxFps) {
            throw "Digite um limite inteiro de $($definition.MinFps) a $($definition.MaxFps) FPS."
        }
        $value = [uint32]$fps
    }
    if ($Id -eq 'nvshadercachesize' -and [IO.DriveInfo]::new([IO.Path]::GetPathRoot($env:LOCALAPPDATA)).AvailableFreeSpace -lt 15GB) {
        throw 'Há menos de 15 GB livres na unidade do cache. Mantenha um limite menor no Painel de Controle NVIDIA.'
    }
    Initialize-NvidiaTuning
    $driver = New-Object PulsoArena.NvidiaProfiles
    try {
        if (-not $driver.Supports($definition.Setting)) { throw 'O driver NVIDIA atual não oferece este ajuste.' }
        $current = $driver.Read($exe, $definition.Setting)
        $before = New-NvidiaTuningState $exe $current
        if ($current.EffectiveKnown -and $current.EffectiveValue -eq $value) {
            return [pscustomobject]@{ Before = $before; After = $before }
        }
        $after = New-NvidiaTuningState $exe $current
        if (-not $after.Profile) {
            $after.Profile = [PulsoArena.NvidiaProfiles]::ManagedName($exe)
            $after.Binding = $exe.Replace('\', '/').ToLowerInvariant()
        }
        $after.Override = $true
        $after.Value = $value
        [pscustomobject]@{ Before = $before; After = $after }
    } finally { $driver.Dispose() }
}

function Test-NvidiaTuningState($Id, $State) {
    $definition = Get-NvidiaTuningDefinition $Id
    if (-not $definition) { throw 'Ajuste NVIDIA desconhecido.' }
    $exe = if ($definition.Input) { Get-NvidiaExecutable $State.Executable -AllowMissing } else { '' }
    Initialize-NvidiaTuning
    $driver = New-Object PulsoArena.NvidiaProfiles
    try {
        $current = $driver.Read($exe, $definition.Setting)
        [PulsoArena.NvidiaProfiles]::Matches($exe, $current, (ConvertTo-NvidiaSnapshot $State))
    } finally { $driver.Dispose() }
}

function Set-NvidiaTuningState($Id, $State, $Expected) {
    $definition = Get-NvidiaTuningDefinition $Id
    if (-not $definition) { throw 'Ajuste NVIDIA desconhecido.' }
    $exe = if ($definition.Input) { Get-NvidiaExecutable $State.Executable -AllowMissing } else { '' }
    $expectedExe = if ($definition.Input) { Get-NvidiaExecutable $Expected.Executable -AllowMissing } else { '' }
    if ($exe -ine $expectedExe) { throw 'O executável difere do perfil aprovado.' }
    Initialize-NvidiaTuning
    $driver = New-Object PulsoArena.NvidiaProfiles
    try {
        if (-not $driver.Supports($definition.Setting)) { throw 'O driver NVIDIA atual não oferece este ajuste.' }
        if ($driver.Change($exe, $definition.Setting, (ConvertTo-NvidiaSnapshot $State), (ConvertTo-NvidiaSnapshot $Expected))) {
            $driver.Save()
        }
    } finally { $driver.Dispose() }
    if (-not (Test-NvidiaTuningState $Id $State)) { throw 'O driver NVIDIA não confirmou o valor depois de salvar.' }
}
