$script:ScanCulture = [System.Globalization.CultureInfo]::GetCultureInfo('pt-BR')

function ConvertTo-ScanSize {
    param([double]$Bytes)
    if ($Bytes -ge 1TB) {
        return ($Bytes / 1TB).ToString('0.##', $script:ScanCulture) + ' TiB'
    }
    if ($Bytes -ge 1GB) {
        return ($Bytes / 1GB).ToString('0.##', $script:ScanCulture) + ' GiB'
    }
    if ($Bytes -gt 0) {
        return ($Bytes / 1MB).ToString('0.##', $script:ScanCulture) + ' MiB'
    }
    return '0 B'
}

function Get-ScanText {
    param([AllowNull()][object]$Value)
    $valueText = ([string]$Value).Trim()
    if (!$valueText -or $valueText -match '^(Unknown|Not Specified|Default string|To Be Filled By O\.E\.M\.|System Product Name|System manufacturer|x\.x)$') {
        return 'Não informado'
    }
    return $valueText
}

function New-ScanItem {
    param([string]$Label, [AllowNull()][object]$Value)
    return [pscustomobject]@{ Label = $Label; Value = (Get-ScanText $Value) }
}

function New-ScanGroup {
    param([string]$Title, [object[]]$Items)
    if (!$Items) {
        $Items = @(New-ScanItem 'Dados' 'Não disponíveis nesta leitura')
    }
    return [pscustomobject]@{ Title = $Title; Items = $Items }
}

function Read-ScanCim {
    param(
        [string]$Class,
        [string[]]$Property,
        [System.Collections.Generic.List[string]]$Warnings,
        [string]$Label,
        [string]$Namespace = 'root\cimv2',
        [string]$Filter
    )
    $parameters = @{
        ClassName = $Class
        Property = $Property
        Namespace = $Namespace
        OperationTimeoutSec = 5
        ErrorAction = 'Stop'
    }
    if ($Filter) { $parameters.Filter = $Filter }
    try {
        Get-CimInstance @parameters
    } catch {
        if ($Label) { $Warnings.Add("Leitura indisponível no Windows: $Label.") }
    }
}

function Get-ScanNvidia {
    $driverPaths = @(
        (Join-Path ([Environment]::SystemDirectory) 'nvidia-smi.exe')
        (Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'NVIDIA Corporation\NVSMI\nvidia-smi.exe')
    )
    $executable = $driverPaths | Where-Object { [System.IO.File]::Exists($_) } | Select-Object -First 1
    if (!$executable) { return }

    $process = New-Object System.Diagnostics.Process
    try {
        $process.StartInfo.FileName = $executable
        $process.StartInfo.Arguments = '--query-gpu=name,memory.total,driver_version --format=csv,noheader,nounits'
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.RedirectStandardError = $true
        [void]$process.Start()
        $output = $process.StandardOutput.ReadToEndAsync()
        $errorOutput = $process.StandardError.ReadToEndAsync()
        if (!$process.WaitForExit(2500)) {
            $process.Kill()
            return
        }
        if ($process.ExitCode -ne 0 -or !$output.Wait(500) -or !$errorOutput.Wait(500)) { return }

        foreach ($row in ($output.Result -split '\r?\n')) {
            if ($row -match '^\s*(?<Name>[^,]+),\s*(?<MiB>\d+),\s*(?<Driver>[\d.]+)\s*$') {
                [pscustomobject]@{
                    Name = $Matches.Name.Trim()
                    Bytes = [uint64]$Matches.MiB * 1MB
                    Driver = $Matches.Driver
                }
            }
        }
    } catch {
        return
    } finally {
        $process.Dispose()
    }
}

function Get-ScanDriverMemory {
    param([string]$DeviceId)
    if (!$DeviceId) { return }

    try {
        $pnpPath = 'HKLM:\SYSTEM\CurrentControlSet\Enum\' + $DeviceId
        $adapterKey = Get-ItemPropertyValue -LiteralPath $pnpPath -Name Driver -ErrorAction Stop
        if ($adapterKey -notmatch '^\{4d36e968-e325-11ce-bfc1-08002be10318\}\\[0-9]{4}$') { return }
        $driverPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\' + $adapterKey
        $reported = Get-ItemPropertyValue -LiteralPath $driverPath -Name 'HardwareInformation.qwMemorySize' -ErrorAction Stop
        if ($reported -is [long] -or $reported -is [uint64]) { return [uint64]$reported }
    } catch {
        return
    }
}

function Get-ScanGpuVendor {
    param([string]$DeviceId, [string]$Name)
    if ($DeviceId -match 'VEN_10DE\b' -or $Name -match '\b(NVIDIA|GeForce|Quadro)\b') { return 'NVIDIA' }
    if ($DeviceId -match 'VEN_(1002|1022)\b' -or $Name -match '\b(AMD|Radeon|ATI)\b') { return 'AMD' }
    if ($DeviceId -match 'VEN_8086\b' -or $Name -match '\bIntel\b') { return 'Intel' }
    return $null
}

function Select-ScanProfileGpu {
    param([object[]]$Readings, [AllowNull()][object]$PrimaryDisplay)
    if (!$Readings) { return }

    if ($PrimaryDisplay) {
        $nativeDeviceId = [string]$PrimaryDisplay.AdapterId
        if ($nativeDeviceId) {
            $matching = @($Readings | Where-Object { $_.DeviceId -eq $nativeDeviceId })
            if ($matching.Count -eq 1) {
                return [pscustomobject]@{ Reading = $matching[0]; Source = 'PrimaryDisplay' }
            }
        }
        $matching = @($Readings | Where-Object { $_.Name -eq $PrimaryDisplay.Adapter })
        if ($matching.Count -eq 1) {
            return [pscustomobject]@{ Reading = $matching[0]; Source = 'PrimaryDisplay' }
        }
    }
    $active = @($Readings | Where-Object { $_.HasDisplayMode })
    if ($active.Count -eq 1) {
        return [pscustomobject]@{ Reading = $active[0]; Source = 'ActiveCim' }
    }
    if ($Readings.Count -eq 1) {
        return [pscustomobject]@{ Reading = $Readings[0]; Source = 'SingleHardware' }
    }
    $dedicated = @($Readings | Where-Object { $_.IsDedicated })
    if ($dedicated.Count -eq 1) {
        return [pscustomobject]@{ Reading = $dedicated[0]; Source = 'DedicatedCandidate' }
    }
}

function Get-ScanDisplayMode {
    if (!('OptimizerScan.DisplayProbe' -as [type])) {
        Add-Type -Language CSharp -ErrorAction Stop -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace OptimizerScan
{
    public sealed class DisplayReading
    {
        public string Device;
        public string Monitor;
        public string DeviceId;
        public string Adapter;
        public string AdapterId;
        public bool Primary;
        public uint Width;
        public uint Height;
        public uint Frequency;
    }

    public static class DisplayProbe
    {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct DisplayDevice
        {
            public int Size;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string Name;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string Description;
            public uint Flags;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string Id;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string Key;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct DeviceMode
        {
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string Name;
            public ushort SpecVersion, DriverVersion, Size, DriverExtra;
            public uint Fields;
            public int PositionX, PositionY;
            public uint DisplayOrientation, DisplayFixedOutput;
            public short Color, Duplex, YResolution, TTOption, Collate;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string FormName;
            public ushort LogPixels;
            public uint BitsPerPel, PelsWidth, PelsHeight, DisplayFlags, DisplayFrequency;
            public uint ICMMethod, ICMIntent, MediaType, DitherType, Reserved1, Reserved2, PanningWidth, PanningHeight;
        }

        [DllImport("user32.dll", EntryPoint = "EnumDisplayDevicesW", CharSet = CharSet.Unicode, ExactSpelling = true)]
        private static extern bool EnumDisplayDevices(string device, uint index, ref DisplayDevice display, uint flags);

        [DllImport("user32.dll", EntryPoint = "EnumDisplaySettingsW", CharSet = CharSet.Unicode, ExactSpelling = true)]
        private static extern bool EnumDisplaySettings(string device, int mode, ref DeviceMode current);

        private static DisplayDevice NewDevice()
        {
            return new DisplayDevice { Size = Marshal.SizeOf(typeof(DisplayDevice)) };
        }

        public static DisplayReading[] ReadActive()
        {
            const uint attachedToDesktop = 1, primaryDevice = 4, mirroringDriver = 8, getInterfaceName = 1;
            const int currentSettings = -1;
            var displays = new List<DisplayReading>();
            for (uint adapterIndex = 0; adapterIndex < 64; adapterIndex++)
            {
                var adapter = NewDevice();
                if (!EnumDisplayDevices(null, adapterIndex, ref adapter, 0)) break;
                if ((adapter.Flags & attachedToDesktop) == 0 || (adapter.Flags & mirroringDriver) != 0) continue;

                var mode = new DeviceMode { Size = (ushort)Marshal.SizeOf(typeof(DeviceMode)) };
                if (!EnumDisplaySettings(adapter.Name, currentSettings, ref mode)) continue;

                bool foundMonitor = false;
                for (uint monitorIndex = 0; monitorIndex < 64; monitorIndex++)
                {
                    var monitor = NewDevice();
                    if (!EnumDisplayDevices(adapter.Name, monitorIndex, ref monitor, getInterfaceName)) break;
                    if ((monitor.Flags & attachedToDesktop) == 0) continue;
                    displays.Add(CreateReading(adapter, monitor, mode, primaryDevice));
                    foundMonitor = true;
                }
                if (!foundMonitor) displays.Add(CreateReading(adapter, NewDevice(), mode, primaryDevice));
            }
            return displays.ToArray();
        }

        private static DisplayReading CreateReading(DisplayDevice adapter, DisplayDevice monitor, DeviceMode mode, uint primaryDevice)
        {
            return new DisplayReading
            {
                Device = adapter.Name,
                Monitor = monitor.Description,
                DeviceId = monitor.Id,
                Adapter = adapter.Description,
                AdapterId = adapter.Id,
                Primary = (adapter.Flags & primaryDevice) != 0,
                Width = mode.PelsWidth,
                Height = mode.PelsHeight,
                Frequency = mode.DisplayFrequency
            };
        }
    }
}
'@
    }
    return [OptimizerScan.DisplayProbe]::ReadActive()
}

function ConvertFrom-ScanEdid {
    param([uint16[]]$Characters)
    return (-join ($Characters | Where-Object { $_ -gt 0 } | ForEach-Object { [char]$_ })).Trim()
}

function Get-ScanDisplayItems {
    param([object[]]$VideoControllers, [object[]]$DisplayModes, [System.Collections.Generic.List[string]]$Warnings)

    $modelByIdentity = @{}
    $edidModels = @(Read-ScanCim -Class WmiMonitorID -Namespace 'root\wmi' -Property InstanceName,Active,UserFriendlyName,ManufacturerName -Filter 'Active=True')
    foreach ($edid in $edidModels) {
        $name = ConvertFrom-ScanEdid $edid.UserFriendlyName
        if (!$name) { $name = ConvertFrom-ScanEdid $edid.ManufacturerName }
        if (!$name) { continue }
        $key = ([string]$edid.InstanceName) -replace '_\d+$'
        if ($key) { $modelByIdentity[$key] = $name }
    }

    $shown = @{}
    foreach ($display in $DisplayModes) {
        $name = $display.Monitor
        if ($display.DeviceId -match '(?i)DISPLAY#([^#]+)#([^#]+)#') {
            $key = 'DISPLAY\{0}\{1}' -f $Matches[1], $Matches[2]
            if ($modelByIdentity.ContainsKey($key)) {
                $name = $modelByIdentity[$key]
                $shown[$key] = $true
            }
        }
        if (!$name) { $name = 'Tela ' + ($display.Device -replace '^.*DISPLAY') }
        if ($display.Primary) { $name += ' (principal)' }

        $details = '{0} × {1} px' -f $display.Width, $display.Height
        if ($display.Frequency -gt 1) { $details += ' · {0} Hz' -f $display.Frequency }
        New-ScanItem $name $details
    }
    foreach ($key in $modelByIdentity.Keys) {
        if (!$shown.ContainsKey($key)) {
            New-ScanItem 'Monitor identificado por EDID' $modelByIdentity[$key]
        }
    }
    if (!$DisplayModes) {
        foreach ($video in $VideoControllers) {
            if ($video.CurrentHorizontalResolution -gt 0 -and $video.CurrentVerticalResolution -gt 0) {
                $mode = '{0} × {1} px' -f $video.CurrentHorizontalResolution, $video.CurrentVerticalResolution
                if ($video.CurrentRefreshRate -gt 1) { $mode += ' · {0} Hz' -f $video.CurrentRefreshRate }
                New-ScanItem ('Modo informado pela GPU · ' + (Get-ScanText $video.Name)) $mode
            }
        }
        $Warnings.Add('Os modos individuais das telas não foram expostos nesta sessão.')
    }
}

function Get-OptimizationScan {
    $warnings = New-Object 'System.Collections.Generic.List[string]'
    $groups = New-Object 'System.Collections.Generic.List[object]'
    $processors = @(Read-ScanCim -Class Win32_Processor -Property Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed,L2CacheSize,L3CacheSize,LoadPercentage -Warnings $warnings -Label 'processador')
    $system = Read-ScanCim -Class Win32_OperatingSystem -Property Caption,Version,BuildNumber,OSArchitecture,FreePhysicalMemory,TotalVisibleMemorySize,SystemDrive -Warnings $warnings -Label 'Windows' | Select-Object -First 1
    $computer = Read-ScanCim -Class Win32_ComputerSystem -Property Manufacturer,Model,TotalPhysicalMemory | Select-Object -First 1
    $videoControllers = @(Read-ScanCim -Class Win32_VideoController -Property Name,PNPDeviceID,DriverVersion,CurrentHorizontalResolution,CurrentVerticalResolution,CurrentRefreshRate -Warnings $warnings -Label 'placa de vídeo')
    $memoryModules = @(Read-ScanCim -Class Win32_PhysicalMemory -Property DeviceLocator,Capacity,Speed,ConfiguredClockSpeed,SMBIOSMemoryType,Manufacturer,PartNumber -Warnings $warnings -Label 'módulos de RAM')
    $boards = @(Read-ScanCim -Class Win32_BaseBoard -Property Manufacturer,Product,Version -Warnings $warnings -Label 'placa-mãe')
    $bios = Read-ScanCim -Class Win32_BIOS -Property Manufacturer,SMBIOSBIOSVersion,ReleaseDate -Warnings $warnings -Label 'BIOS' | Select-Object -First 1

    $cpuItems = foreach ($cpu in $processors) {
        New-ScanItem 'Modelo' $cpu.Name
        if ($cpu.NumberOfCores -gt 0 -and $cpu.NumberOfLogicalProcessors -gt 0) {
            New-ScanItem 'Núcleos e processadores lógicos' ('{0} núcleos · {1} threads' -f $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors)
        }
        if ($cpu.MaxClockSpeed -gt 0) {
            $clock = ([double]$cpu.MaxClockSpeed / 1000).ToString('0.00', $script:ScanCulture)
            New-ScanItem 'Frequência de referência (Windows)' "$clock GHz"
        }
        if ($cpu.L2CacheSize -gt 0) { New-ScanItem 'Cache L2' (ConvertTo-ScanSize ($cpu.L2CacheSize * 1KB)) }
        if ($cpu.L3CacheSize -gt 0) { New-ScanItem 'Cache L3' (ConvertTo-ScanSize ($cpu.L3CacheSize * 1KB)) }
        if ($null -ne $cpu.LoadPercentage) { New-ScanItem 'Carga no momento da leitura' ('{0}%' -f $cpu.LoadPercentage) }
    }
    $groups.Add((New-ScanGroup 'Processador' $cpuItems))

    $nvidia = @()
    if ($videoControllers | Where-Object { (Get-ScanGpuVendor $_.PNPDeviceID $_.Name) -eq 'NVIDIA' } | Select-Object -First 1) {
        $nvidia = @(Get-ScanNvidia)
    }
    $gpuReadings = New-Object 'System.Collections.Generic.List[object]'
    $gpuItems = foreach ($video in $videoControllers) {
        $name = Get-ScanText $video.Name
        $vendor = Get-ScanGpuVendor $video.PNPDeviceID $video.Name
        $sameModel = @($nvidia | Where-Object { $_.Name -eq $name })
        $matchingNvidia = if ($sameModel.Count -eq 1) { $sameModel[0] }
        $driverBytes = if ($matchingNvidia) { $matchingNvidia.Bytes } else { Get-ScanDriverMemory $video.PNPDeviceID }
        $isDedicated = [bool]($matchingNvidia -or
            ($vendor -eq 'NVIDIA' -and $name -match '\b(GTX|RTX|Quadro|Tesla|TITAN|GeForce MX)\b') -or
            ($vendor -eq 'AMD' -and $name -match '\b(RX\s+\d{3,4}\w*|Radeon\s+(Pro\s+W|VII\b))') -or
            ($vendor -eq 'Intel' -and $name -match '\bArc(?:\(TM\))?\s+[AB]\d{3}M?\b'))
        if (($vendor -or $video.PNPDeviceID -match '^PCI\\') -and $name -ne 'Não informado') {
            $gpuReadings.Add([pscustomobject]@{
                DeviceId = $video.PNPDeviceID
                Name = $name
                Vendor = $vendor
                DedicatedBytes = $(if ($isDedicated -and $driverBytes -gt 0) { $driverBytes } else { $null })
                IsDedicated = $isDedicated
                HasDisplayMode = ($video.CurrentHorizontalResolution -gt 0 -and $video.CurrentVerticalResolution -gt 0)
            })
        }
        $details = New-Object 'System.Collections.Generic.List[string]'
        if ($driverBytes -gt 0) {
            $source = if ($matchingNvidia) { 'VRAM NVIDIA' } else { 'memória informada pelo driver' }
            $details.Add(('{0} de {1}' -f (ConvertTo-ScanSize $driverBytes), $source))
        } else {
            $details.Add('Capacidade dedicada não confirmada')
        }
        if ($matchingNvidia -and $matchingNvidia.Driver) { $details.Add(('driver NVIDIA {0}' -f $matchingNvidia.Driver)) }
        if ($video.DriverVersion) { $details.Add(('driver Windows {0}' -f $video.DriverVersion)) }
        New-ScanItem $name ($details -join ' · ')
    }
    $groups.Add((New-ScanGroup 'Placa de vídeo' $gpuItems))

    $memoryBytes = 0
    foreach ($module in $memoryModules) { $memoryBytes += [uint64]$module.Capacity }
    if ($memoryBytes -le 0 -and $computer -and $computer.TotalPhysicalMemory -gt 0) {
        $memoryBytes = [uint64]$computer.TotalPhysicalMemory
    }
    $memoryTypes = @{ 20 = 'DDR'; 21 = 'DDR2'; 24 = 'DDR3'; 26 = 'DDR4'; 30 = 'LPDDR4'; 34 = 'DDR5'; 35 = 'LPDDR5' }
    $memoryItems = @(
        if ($memoryBytes -gt 0) {
            $memoryLabel = if ($memoryModules.Count -gt 0) { 'RAM instalada' } else { 'RAM detectada pelo Windows' }
            New-ScanItem $memoryLabel (ConvertTo-ScanSize $memoryBytes)
        }
        if ($system -and $system.TotalVisibleMemorySize -gt 0 -and $null -ne $system.FreePhysicalMemory) {
            New-ScanItem 'RAM utilizável / disponível na leitura' ('{0} / {1}' -f (ConvertTo-ScanSize ($system.TotalVisibleMemorySize * 1KB)), (ConvertTo-ScanSize ($system.FreePhysicalMemory * 1KB)))
        }
        $moduleIndex = 0
        foreach ($module in $memoryModules) {
            $moduleIndex++
            $moduleLabel = Get-ScanText $module.DeviceLocator
            if ($moduleLabel -eq 'Não informado') { $moduleLabel = "Módulo $moduleIndex" }
            $moduleDetails = New-Object 'System.Collections.Generic.List[string]'
            if ($module.Capacity -gt 0) { $moduleDetails.Add((ConvertTo-ScanSize $module.Capacity)) }
            $memoryType = $memoryTypes[[int]$module.SMBIOSMemoryType]
            if ($memoryType) { $moduleDetails.Add($memoryType) }
            if ($module.ConfiguredClockSpeed -gt 0) {
                $moduleDetails.Add(('{0} MT/s configurados' -f $module.ConfiguredClockSpeed))
            }
            if ($module.Speed -gt 0 -and $module.Speed -ne $module.ConfiguredClockSpeed) {
                $moduleDetails.Add(('{0} MT/s nominais' -f $module.Speed))
            }
            foreach ($propertyValue in @($module.Manufacturer, $module.PartNumber)) {
                $propertyText = Get-ScanText $propertyValue
                if ($propertyText -ne 'Não informado') { $moduleDetails.Add($propertyText) }
            }
            New-ScanItem $moduleLabel ($moduleDetails -join ' · ')
        }
    )
    $groups.Add((New-ScanGroup 'Memória RAM' $memoryItems))

    try { $displayModes = @(Get-ScanDisplayMode) } catch { $displayModes = @() }
    $primaryDisplay = $displayModes | Where-Object { $_.Primary } | Select-Object -First 1
    if (!$primaryDisplay -and $displayModes.Count -eq 1) { $primaryDisplay = $displayModes[0] }
    $displayItems = @(Get-ScanDisplayItems $videoControllers $displayModes $warnings)
    $groups.Add((New-ScanGroup 'Monitores' $displayItems))

    $disks = @(Read-ScanCim -Class MSFT_PhysicalDisk -Namespace 'root\Microsoft\Windows\Storage' -Property FriendlyName,MediaType,BusType,Size,HealthStatus)
    $diskTypes = @{ 3 = 'HDD'; 4 = 'SSD'; 5 = 'SCM' }
    $busTypes = @{ 1 = 'SCSI'; 2 = 'ATAPI'; 3 = 'ATA'; 4 = 'IEEE 1394'; 6 = 'Fibre Channel'; 7 = 'USB'; 8 = 'RAID'; 9 = 'iSCSI'; 10 = 'SAS'; 11 = 'SATA'; 12 = 'SD'; 13 = 'MMC'; 14 = 'Virtual'; 15 = 'Virtual baseado em arquivo'; 16 = 'Espaços de Armazenamento'; 17 = 'NVMe'; 18 = 'SCM'; 19 = 'UFS' }
    $diskHealth = @{ 0 = 'integridade normal'; 1 = 'integridade em alerta'; 2 = 'integridade crítica' }
    $diskItems = if ($disks) {
        foreach ($disk in $disks) {
            $details = @(
                $diskTypes[[int]$disk.MediaType]
                $busTypes[[int]$disk.BusType]
                if ($disk.Size -gt 0) { ConvertTo-ScanSize $disk.Size }
                if ($null -ne $disk.HealthStatus) { $diskHealth[[int]$disk.HealthStatus] }
            ) | Where-Object { $_ }
            New-ScanItem (Get-ScanText $disk.FriendlyName) ($details -join ' · ')
        }
    } else {
        $fallbackDisks = @(Read-ScanCim -Class Win32_DiskDrive -Property Model,Size,InterfaceType -Warnings $warnings -Label 'discos físicos')
        foreach ($disk in $fallbackDisks) {
            $details = @(
                $disk.InterfaceType
                if ($disk.Size -gt 0) { ConvertTo-ScanSize $disk.Size }
            ) | Where-Object { $_ }
            New-ScanItem (Get-ScanText $disk.Model) ($details -join ' · ')
        }
    }
    $groups.Add((New-ScanGroup 'Discos físicos' $diskItems))

    $volumes = @(Read-ScanCim -Class Win32_LogicalDisk -Property DeviceID,Size,FreeSpace,FileSystem,VolumeName -Filter 'DriveType=3' -Warnings $warnings -Label 'volumes locais')
    $volumeItems = foreach ($volume in ($volumes | Sort-Object DeviceID)) {
        $volumeLabel = [string]$volume.DeviceID
        if ($volume.VolumeName) { $volumeLabel += ' · ' + (Get-ScanText $volume.VolumeName) }
        $details = New-Object 'System.Collections.Generic.List[string]'
        if ($volume.FileSystem) { $details.Add($volume.FileSystem) }
        if ($volume.Size -gt 0 -and $null -ne $volume.FreeSpace) {
            $ratio = ([double]$volume.FreeSpace / [double]$volume.Size).ToString('P0', $script:ScanCulture)
            $details.Add(('{0} livres de {1} ({2})' -f (ConvertTo-ScanSize $volume.FreeSpace), (ConvertTo-ScanSize $volume.Size), $ratio))
        }
        New-ScanItem $volumeLabel ($details -join ' · ')
    }
    $groups.Add((New-ScanGroup 'Volumes locais' $volumeItems))

    $net = @(Read-ScanCim -Class MSFT_NetAdapter -Namespace 'root\StandardCimv2' -Property Name,InterfaceDescription,MediaConnectState,HardwareInterface,NdisPhysicalMedium,ReceiveLinkSpeed,TransmitLinkSpeed -Filter 'HardwareInterface=True' -Warnings $warnings -Label 'adaptadores de rede')
    $networkItems = foreach ($adapter in ($net | Sort-Object MediaConnectState,Name)) {
        $state = switch ($adapter.MediaConnectState) {
            1 { 'Conectado' }
            2 { 'Desconectado' }
            default { 'Estado não informado' }
        }
        $details = Get-ScanText $adapter.InterfaceDescription
        $details += ' · ' + $state
        if ($adapter.MediaConnectState -eq 1 -and $adapter.ReceiveLinkSpeed -gt 0 -and $adapter.TransmitLinkSpeed -gt 0) {
            $receive = ([double]$adapter.ReceiveLinkSpeed / 1000000).ToString('0.##', $script:ScanCulture)
            $transmit = ([double]$adapter.TransmitLinkSpeed / 1000000).ToString('0.##', $script:ScanCulture)
            $details += (' · link {0}↓ / {1}↑ Mb/s' -f $receive, $transmit)
        }
        New-ScanItem (Get-ScanText $adapter.Name) $details
    }
    $groups.Add((New-ScanGroup 'Rede física' $networkItems))

    $systemItems = @(
        if ($system) {
            New-ScanItem 'Edição' $system.Caption
            $version = $system.Version
            $build = $system.BuildNumber
            try {
                $versionKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
                $details = Get-ItemProperty -LiteralPath $versionKey -Name DisplayVersion,UBR -ErrorAction Stop
                if ($details.DisplayVersion) { $version = $details.DisplayVersion }
                if ($null -ne $details.UBR) { $build = '{0}.{1}' -f $build, $details.UBR }
            } catch {
                # A versão numérica do CIM permanece disponível para outras edições do Windows.
            }
            New-ScanItem 'Versão e compilação' ('{0} · build {1}' -f $version, $build)
            New-ScanItem 'Arquitetura' $system.OSArchitecture
        }
        if ($computer) {
            New-ScanItem 'Fabricante / modelo do PC' ('{0} / {1}' -f (Get-ScanText $computer.Manufacturer), (Get-ScanText $computer.Model))
        }
    )
    $groups.Add((New-ScanGroup 'Windows' $systemItems))

    $boardItems = @(
        foreach ($board in $boards) {
            New-ScanItem 'Placa-mãe' ('{0} · {1}' -f (Get-ScanText $board.Manufacturer), (Get-ScanText $board.Product))
            $revision = Get-ScanText $board.Version
            if ($revision -ne 'Não informado') { New-ScanItem 'Revisão da placa-mãe' $revision }
        }
        if ($bios) {
            New-ScanItem 'Fabricante do BIOS/UEFI' $bios.Manufacturer
            New-ScanItem 'Versão do BIOS/UEFI' $bios.SMBIOSBIOSVersion
            if ($bios.ReleaseDate -is [datetime]) { New-ScanItem 'Data do BIOS/UEFI' ($bios.ReleaseDate.ToString('d', $script:ScanCulture)) }
        }
    )
    $groups.Add((New-ScanGroup 'Placa-mãe e BIOS' $boardItems))

    $mainCpu = $processors | Select-Object -First 1
    $gpuSelection = Select-ScanProfileGpu $gpuReadings.ToArray() $primaryDisplay
    $mainGpu = if ($gpuSelection) { $gpuSelection.Reading }
    $cpuName = if ($mainCpu) { $mainCpu.Name }
    $gpuName = if ($mainGpu) { $mainGpu.Name } else { $null }
    $ramSummary = if ($memoryBytes -gt 0) { ConvertTo-ScanSize $memoryBytes } else { 'Não detectada' }
    $populatedModules = @($memoryModules | Where-Object { $_.Capacity -gt 0 })
    $systemVolume = if ($system -and $system.SystemDrive) {
        $volumes | Where-Object { $_.DeviceID -eq $system.SystemDrive } | Select-Object -First 1
    }
    $hasSsd = if ($disks | Where-Object { $_.MediaType -eq 4 } | Select-Object -First 1) {
        $true
    } elseif ($disks -and -not ($disks | Where-Object { $_.MediaType -notin @(3, 5) } | Select-Object -First 1)) {
        $false
    } else {
        $null
    }
    $hasEthernet = if ($net | Where-Object { $_.NdisPhysicalMedium -eq 14 -and $_.MediaConnectState -eq 1 } | Select-Object -First 1) {
        $true
    } elseif ($net -and -not ($net | Where-Object { $_.NdisPhysicalMedium -lt 1 -or ($_.NdisPhysicalMedium -eq 14 -and $_.MediaConnectState -ne 2) } | Select-Object -First 1)) {
        $false
    } else {
        $null
    }

    return [pscustomobject]@{
        Groups = $groups.ToArray()
        Summary = [pscustomobject]@{
            CPU = (Get-ScanText $cpuName)
            GPU = (Get-ScanText $gpuName)
            RAM = $ramSummary
        }
        Profile = [pscustomobject]@{
            CPUName = $(if ($cpuName -and (Get-ScanText $cpuName) -ne 'Não informado') { $cpuName.Trim() } else { $null })
            CPUCores = $(if ($mainCpu -and $mainCpu.NumberOfCores -gt 0) { [int]$mainCpu.NumberOfCores } else { $null })
            GPUName = $gpuName
            GPUVendor = $(if ($mainGpu) { $mainGpu.Vendor } else { $null })
            GPUSelection = $(if ($gpuSelection) { $gpuSelection.Source } else { $null })
            VRAMGiB = $(if ($mainGpu -and $mainGpu.DedicatedBytes -gt 0) { [double]$mainGpu.DedicatedBytes / 1GB } else { $null })
            GpuCount = $(if ($gpuReadings.Count -gt 0) { $gpuReadings.Count } else { $null })
            RAMGiB = $(if ($memoryBytes -gt 0) { [double]$memoryBytes / 1GB } else { $null })
            DIMMs = $(if ($populatedModules.Count -gt 0) { $populatedModules.Count } else { $null })
            PrimaryHz = $(if ($primaryDisplay -and $primaryDisplay.Frequency -gt 1) { [int]$primaryDisplay.Frequency } else { $null })
            PrimaryWidth = $(if ($primaryDisplay -and $primaryDisplay.Width -gt 0) { [int]$primaryDisplay.Width } else { $null })
            PrimaryHeight = $(if ($primaryDisplay -and $primaryDisplay.Height -gt 0) { [int]$primaryDisplay.Height } else { $null })
            HasSSD = $hasSsd
            HasEthernetLink = $hasEthernet
            SystemVolumeFreeGiB = $(if ($systemVolume -and $null -ne $systemVolume.FreeSpace) { [double]$systemVolume.FreeSpace / 1GB } else { $null })
        }
        Warnings = $warnings.ToArray()
    }
}
