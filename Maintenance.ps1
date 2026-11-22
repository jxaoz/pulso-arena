function Get-MaintenanceDefinitions {
    $local = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    $windows = [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
    $programData = [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData)

    @(
        [pscustomobject]@{ Id = 'usertemp'; Title = 'Temporários do usuário'; Description = 'Arquivos .tmp e .temp sem alterações há pelo menos 14 dias.'; Default = $true; Base = $local; Folder = 'Temp'; AgeDays = 14; Extensions = @('.tmp', '.temp') }
        [pscustomobject]@{ Id = 'systemtemp'; Title = 'Temporários do Windows'; Description = 'Arquivos .tmp e .temp com 14 dias ou mais. Algumas pastas exigem privilégios de administrador.'; Default = $false; Base = $windows; Folder = 'Temp'; AgeDays = 14; Extensions = @('.tmp', '.temp') }
        [pscustomobject]@{ Id = 'wer'; Title = 'Relatórios de erros do usuário'; Description = 'Relatórios arquivados de falhas com 30 dias ou mais.'; Default = $false; Base = $local; Folder = 'Microsoft\Windows\WER\ReportArchive'; AgeDays = 30; Extensions = @('.wer', '.dmp', '.mdmp', '.hdmp', '.xml', '.csv', '.cab') }
        [pscustomobject]@{ Id = 'systemwer'; Title = 'Relatórios de erros do Windows'; Description = 'Relatórios arquivados do sistema com 30 dias ou mais. Algumas pastas exigem privilégios de administrador.'; Default = $false; Base = $programData; Folder = 'Microsoft\Windows\WER\ReportArchive'; AgeDays = 30; Extensions = @('.wer', '.dmp', '.mdmp', '.hdmp', '.xml', '.csv', '.cab') }
        [pscustomobject]@{ Id = 'crashdumps'; Title = 'Despejos de falhas antigos'; Description = 'Despejos de memória de aplicativos sem alterações há pelo menos 30 dias.'; Default = $false; Base = $local; Folder = 'CrashDumps'; AgeDays = 30; Extensions = @('.dmp', '.mdmp', '.hdmp') }
        [pscustomobject]@{ Id = 'epiclogs'; Title = 'Registros do Epic Games Launcher'; Description = 'Arquivos de log do inicializador sem alterações há pelo menos 14 dias.'; Default = $false; Base = $local; Folder = 'EpicGamesLauncher\Saved\Logs'; AgeDays = 14; Extensions = @('.log') }
        [pscustomobject]@{ Id = 'fortnitelogs'; Title = 'Registros do Fortnite'; Description = 'Arquivos de log do jogo sem alterações há pelo menos 14 dias.'; Default = $false; Base = $local; Folder = 'FortniteGame\Saved\Logs'; AgeDays = 14; Extensions = @('.log') }
    )
}

function Get-CleanupCategories {
    Get-MaintenanceDefinitions | Select-Object Id, Title, Description, Default
}

function Get-MaintenanceRoot {
    param($Definition)

    if ([string]::IsNullOrWhiteSpace($Definition.Base)) { return }
    $path = [IO.Path]::GetFullPath([IO.Path]::Combine($Definition.Base, $Definition.Folder))
    $driveRoot = [IO.Path]::GetPathRoot($path)
    if ($driveRoot -notmatch '^[A-Za-z]:\\$' -or $path -eq $driveRoot) { return }
    if ([IO.DriveInfo]::new($driveRoot).DriveType -ne [IO.DriveType]::Fixed) { return }
    return $path.TrimEnd('\')
}

function Test-MaintenanceDirectory {
    param([string]$Path)

    $directory = [IO.DirectoryInfo]::new($Path)
    while ($null -ne $directory) {
        $attributes = [IO.File]::GetAttributes($directory.FullName)
        if (-not ($attributes -band [IO.FileAttributes]::Directory) -or ($attributes -band [IO.FileAttributes]::ReparsePoint)) {
            return $false
        }
        $directory = $directory.Parent
    }
    return $true
}

function Initialize-MaintenanceNative {
    if ('OptimizerMaintenance.SafeFile' -as [type]) { return }

    Add-Type -Language CSharp -ErrorAction Stop -TypeDefinition @'
using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace OptimizerMaintenance
{
    public sealed class FileSnapshot
    {
        public string Path { get; internal set; }
        public long Length { get; internal set; }
        public long CreationFileTime { get; internal set; }
        public long ModifiedFileTime { get; internal set; }
        public uint VolumeSerial { get; internal set; }
        public ulong FileIndex { get; internal set; }
    }

    public static class SafeFile
    {
        private const uint ReadAttributes = 0x80;
        private const uint DeleteAccess = 0x10000;
        private const uint ShareReadWriteDelete = 7;
        private const uint OpenExisting = 3;
        private const uint OpenReparsePoint = 0x00200000;
        private const int FileDispositionInfo = 4;
        private const FileAttributes ExcludedAttributes = FileAttributes.Directory | FileAttributes.ReparsePoint |
            FileAttributes.System | FileAttributes.ReadOnly | FileAttributes.Offline;

        [StructLayout(LayoutKind.Sequential)]
        private struct FileTime
        {
            public uint Low;
            public uint High;
            public long ToInt64() { return (long)Combine(High, Low); }
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct FileInformation
        {
            public FileAttributes Attributes;
            public FileTime Creation;
            public FileTime Access;
            public FileTime Modified;
            public uint VolumeSerial;
            public uint SizeHigh;
            public uint SizeLow;
            public uint LinkCount;
            public uint IndexHigh;
            public uint IndexLow;
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true, ExactSpelling = true)]
        private static extern SafeFileHandle CreateFileW(string path, uint access, uint share,
            IntPtr security, uint disposition, uint flags, IntPtr template);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetFileInformationByHandle(SafeFileHandle handle, out FileInformation info);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true, ExactSpelling = true)]
        private static extern uint GetFinalPathNameByHandleW(SafeFileHandle handle, StringBuilder buffer, uint length, uint flags);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool SetFileInformationByHandle(SafeFileHandle handle, int infoClass, ref byte deleteFile, uint length);

        private static ulong Combine(uint high, uint low) { return ((ulong)high << 32) | low; }

        private static FileSnapshot Inspect(SafeFileHandle handle, string path, long cutoffFileTime)
        {
            if (handle.IsInvalid) throw new Win32Exception(Marshal.GetLastWin32Error());
            FileInformation info;
            if (!GetFileInformationByHandle(handle, out info)) throw new Win32Exception(Marshal.GetLastWin32Error());
            if ((info.Attributes & ExcludedAttributes) != 0 || info.LinkCount != 1 ||
                info.Modified.ToInt64() > cutoffFileTime || info.Creation.ToInt64() > cutoffFileTime)
                return null;

            var finalPath = new StringBuilder(512);
            uint length = GetFinalPathNameByHandleW(handle, finalPath, (uint)finalPath.Capacity, 0);
            if (length == 0) throw new Win32Exception(Marshal.GetLastWin32Error());
            if (length >= finalPath.Capacity)
            {
                finalPath.Capacity = checked((int)length);
                length = GetFinalPathNameByHandleW(handle, finalPath, (uint)finalPath.Capacity, 0);
                if (length == 0) throw new Win32Exception(Marshal.GetLastWin32Error());
            }
            if (length >= finalPath.Capacity || !String.Equals(finalPath.ToString(), @"\\?\" + path, StringComparison.OrdinalIgnoreCase))
                return null;

            return new FileSnapshot
            {
                Path = path,
                Length = (long)Combine(info.SizeHigh, info.SizeLow),
                CreationFileTime = info.Creation.ToInt64(),
                ModifiedFileTime = info.Modified.ToInt64(),
                VolumeSerial = info.VolumeSerial,
                FileIndex = Combine(info.IndexHigh, info.IndexLow)
            };
        }

        public static FileSnapshot Read(string path, long cutoffFileTime)
        {
            using (var handle = CreateFileW(@"\\?\" + path, ReadAttributes, ShareReadWriteDelete, IntPtr.Zero,
                OpenExisting, OpenReparsePoint, IntPtr.Zero))
                return Inspect(handle, path, cutoffFileTime);
        }

        public static bool RemoveIfUnchanged(FileSnapshot preview, long cutoffFileTime)
        {
            // The exclusive handle keeps the inspected file stable through the delete operation.
            using (var handle = CreateFileW(@"\\?\" + preview.Path, ReadAttributes | DeleteAccess, 0, IntPtr.Zero,
                OpenExisting, OpenReparsePoint, IntPtr.Zero))
            {
                var current = Inspect(handle, preview.Path, cutoffFileTime);
                if (current == null || current.FileIndex != preview.FileIndex || current.VolumeSerial != preview.VolumeSerial ||
                    current.Length != preview.Length || current.CreationFileTime != preview.CreationFileTime ||
                    current.ModifiedFileTime != preview.ModifiedFileTime)
                    return false;

                byte deleteFile = 1;
                if (!SetFileInformationByHandle(handle, FileDispositionInfo, ref deleteFile, 1))
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                return true;
            }
        }
    }
}
'@
}

function Get-CleanupPreview {
    param([AllowEmptyCollection()][string[]]$Ids = @())

    Initialize-MaintenanceNative
    $totals = [Collections.Generic.List[object]]::new()
    $candidates = [Collections.Generic.List[object]]::new()
    $warnings = [Collections.Generic.List[string]]::new()
    $totalBytes = 0L
    $now = [DateTime]::UtcNow

    foreach ($definition in Get-MaintenanceDefinitions) {
        if ($definition.Id -notin $Ids) { continue }
        $total = [pscustomobject]@{ Id = $definition.Id; Title = $definition.Title; Count = 0; Bytes = 0L }
        $totals.Add($total)
        $root = Get-MaintenanceRoot $definition
        if (-not $root) { continue }
        $cutoff = $now.AddDays(-$definition.AgeDays)
        $cutoffFileTime = $cutoff.ToFileTimeUtc()
        $pending = [Collections.Generic.Stack[string]]::new()
        $pending.Push($root)
        $inaccessible = 0

        while ($pending.Count) {
            $directory = $pending.Pop()
            try {
                if (-not (Test-MaintenanceDirectory $directory)) { continue }
                $children = [IO.Directory]::GetFileSystemEntries($directory)
            } catch {
                if ($_.Exception.GetBaseException() -isnot [IO.DirectoryNotFoundException] -and
                    $_.Exception.GetBaseException() -isnot [IO.FileNotFoundException]) { $inaccessible++ }
                continue
            }

            foreach ($path in $children) {
                try {
                    $attributes = [IO.File]::GetAttributes($path)
                    if ($attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
                    if ($attributes -band [IO.FileAttributes]::Directory) { $pending.Push($path); continue }
                    if ([IO.Path]::GetExtension($path) -notin $definition.Extensions -or [IO.File]::GetLastWriteTimeUtc($path) -gt $cutoff) { continue }
                    $file = [OptimizerMaintenance.SafeFile]::Read($path, $cutoffFileTime)
                    if ($null -eq $file) { continue }
                    $candidates.Add([pscustomobject]@{ Id = $definition.Id; File = $file })
                    $total.Count++
                    $total.Bytes += $file.Length
                    $totalBytes += $file.Length
                } catch { $inaccessible++ }
            }
        }

        if ($inaccessible -gt 0) {
            $warnings.Add(('{0} itens indisponíveis em {1}.' -f $inaccessible, $definition.Title.ToLowerInvariant()))
        }
    }

    [pscustomobject]@{
        Count = $candidates.Count
        Bytes = $totalBytes
        PerCategory = $totals.ToArray()
        Candidates = $candidates.ToArray()
        Warnings = $warnings.ToArray()
    }
}

function Invoke-Cleanup {
    param([Parameter(Mandatory)]$Preview)

    Initialize-MaintenanceNative
    $definitions = @{}
    foreach ($definition in Get-MaintenanceDefinitions) { $definitions[$definition.Id] = $definition }
    $removedCount = 0
    $removedBytes = 0L
    $skippedCount = 0
    $errorCount = 0
    $errors = [Collections.Generic.List[string]]::new()
    $now = [DateTime]::UtcNow

    foreach ($candidate in $Preview.Candidates) {
        $definition = $definitions[$candidate.Id]
        $file = $candidate.File
        if ($null -eq $definition -or $file -isnot [OptimizerMaintenance.FileSnapshot]) { $skippedCount++; continue }

        try {
            $root = Get-MaintenanceRoot $definition
            $path = [IO.Path]::GetFullPath($file.Path)
            if (-not $root -or $path -cne $file.Path -or $path.Substring(2).Contains(':') -or
                -not $path.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase) -or
                [IO.Path]::GetExtension($path) -notin $definition.Extensions -or
                -not (Test-MaintenanceDirectory ([IO.Path]::GetDirectoryName($path)))) { $skippedCount++; continue }

            $cutoffFileTime = $now.AddDays(-$definition.AgeDays).ToFileTimeUtc()
            if ([OptimizerMaintenance.SafeFile]::RemoveIfUnchanged($file, $cutoffFileTime)) {
                $removedCount++
                $removedBytes += $file.Length
            } else { $skippedCount++ }
        } catch {
            $skippedCount++
            $errorCount++
            if ($errors.Count -lt 10) {
                $errors.Add(('{0} · {1}' -f [IO.Path]::GetFileName($file.Path), $_.Exception.GetBaseException().Message))
            }
        }
    }

    [pscustomobject]@{
        RemovedCount = $removedCount
        RemovedBytes = $removedBytes
        SkippedCount = $skippedCount
        ErrorCount = $errorCount
        Errors = $errors.ToArray()
    }
}

function Assert-MaintenanceRestoreAccess {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Abra o aplicativo como administrador para acessar os pontos de restauração do Windows.'
    }
    if ($PSVersionTable.PSEdition -ne 'Desktop') {
        throw 'A Restauração do Sistema exige o Windows PowerShell 5.1. Abra o aplicativo pelo iniciador da pasta.'
    }
    $policy = Get-ItemPropertyValue -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore' -Name 'DisableSR' -ErrorAction SilentlyContinue
    if ($policy -eq 1) { throw 'Uma política do Windows desativou a Restauração do Sistema neste computador.' }
}

function Get-OptimizerRestorePoints {
    Assert-MaintenanceRestoreAccess
    try {
        $points = @(Get-ComputerRestorePoint -ErrorAction Stop -WarningAction SilentlyContinue)
    } catch {
        throw ('O Windows não disponibilizou a lista de pontos. Confira a Proteção do Sistema da unidade do Windows. Detalhe: {0}' -f $_.Exception.Message)
    }

    $points | Sort-Object SequenceNumber -Descending | ForEach-Object {
        $time = $null
        try {
            if ($_.CreationTime -is [DateTime]) { $time = $_.CreationTime }
            else { $time = [Management.ManagementDateTimeConverter]::ToDateTime([string]$_.CreationTime) }
        } catch { }
        [pscustomobject]@{
            SequenceNumber = [int]$_.SequenceNumber
            Description = [string]$_.Description
            CreationTime = $time
        }
    }
}

function New-OptimizerRestorePoint {
    param([ValidateNotNullOrEmpty()][ValidateLength(1, 100)][string]$Description = 'Otimizador gamer')

    $before = @(Get-OptimizerRestorePoints)
    $tag = [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $uniqueDescription = '{0} - {1}' -f $Description.Trim(), $tag
    $checkpointWarnings = @()
    $detail = ''
    try {
        Checkpoint-Computer -Description $uniqueDescription -RestorePointType MODIFY_SETTINGS -ErrorAction Stop -WarningAction SilentlyContinue -WarningVariable checkpointWarnings
    } catch { $detail = $_.Exception.Message }

    $knownNumbers = @($before | ForEach-Object { $_.SequenceNumber })
    for ($attempt = 0; $attempt -lt 4; $attempt++) {
        $created = Get-OptimizerRestorePoints | Where-Object { $_.Description -ceq $uniqueDescription -and $_.SequenceNumber -notin $knownNumbers } | Select-Object -First 1
        if ($created) { return $created }
        if ($detail -or $checkpointWarnings.Count) { break }
        if ($attempt -lt 3) { Start-Sleep -Milliseconds 600 }
    }

    if (-not $detail -and $checkpointWarnings.Count) { $detail = ($checkpointWarnings | ForEach-Object { $_.Message }) -join ' ' }
    $recent = $before | Where-Object { $_.CreationTime -and $_.CreationTime -gt (Get-Date).AddHours(-24) } | Select-Object -First 1
    if ($recent) {
        $message = 'A criação de um novo ponto não foi confirmada. O Windows normalmente limita a criação automática a um ponto por período de 24 horas. Você pode usar o ponto existente ou criar um ponto pela Proteção do Sistema.'
    } else {
        $message = 'A criação do ponto não foi confirmada. Ative a Proteção do Sistema na unidade do Windows e confira o espaço reservado para restauração.'
    }
    if ($detail) { $message += ' ' + $detail }
    throw $message
}
