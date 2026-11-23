[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ExecutablePath,
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
if (-not [Environment]::Is64BitProcess -or $env:OS -ne 'Windows_NT') { throw 'Use o PowerShell de 64 bits no Windows.' }
if ($Version -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,5}$') { throw 'Informe a versão no formato principal.secundária.revisão.' }
$productVersion = [version]$Version
if ($productVersion.Major -gt 255 -or $productVersion.Minor -gt 255 -or $productVersion.Build -gt 65535) { throw 'A versão ultrapassa os limites do Windows Installer.' }
$versionText = $productVersion.ToString(3)
foreach ($candidate in @($ExecutablePath, $OutputPath)) {
    if ($candidate -notmatch '^[a-zA-Z]:[\\/]') { throw 'Informe caminhos absolutos em uma unidade local.' }
}
$source = [IO.Path]::GetFullPath($ExecutablePath)
$destination = [IO.Path]::GetFullPath($OutputPath)
if ([IO.Path]::GetExtension($source) -ine '.exe' -or -not [IO.File]::Exists($source)) { throw 'Informe o executável do PrismaFrame.' }
if ([IO.Path]::GetExtension($destination) -ine '.msi') { throw 'O caminho de saída precisa terminar em .msi.' }
$fileInfo = [Diagnostics.FileVersionInfo]::GetVersionInfo($source)
$embeddedVersion = '{0}.{1}.{2}' -f $fileInfo.FileMajorPart, $fileInfo.FileMinorPart, $fileInfo.FileBuildPart
if ($fileInfo.ProductName -ne 'PrismaFrame' -or $embeddedVersion -ne $versionText) { throw 'O produto ou a versão do executável difere do instalador.' }

if (-not ('PrismaFrame.InstallerDatabase' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace PrismaFrame {
    public sealed class InstallerDatabase : IDisposable {
        private uint db;

        [DllImport("msi.dll", EntryPoint="MsiOpenDatabaseW", CharSet=CharSet.Unicode)]
        private static extern uint OpenDatabase(string path, IntPtr mode, out uint handle);
        [DllImport("msi.dll", EntryPoint="MsiDatabaseImportW", CharSet=CharSet.Unicode)]
        private static extern uint DatabaseImport(uint database, string directory, string fileName);
        [DllImport("msi.dll", EntryPoint="MsiDatabaseOpenViewW", CharSet=CharSet.Unicode)]
        private static extern uint OpenView(uint database, string sql, out uint view);
        [DllImport("msi.dll", EntryPoint="MsiViewExecute")]
        private static extern uint ViewExecute(uint view, uint record);
        [DllImport("msi.dll", EntryPoint="MsiCreateRecord")]
        private static extern uint CreateRecord(uint fields);
        [DllImport("msi.dll", EntryPoint="MsiRecordSetStringW", CharSet=CharSet.Unicode)]
        private static extern uint RecordSetString(uint record, uint field, string value);
        [DllImport("msi.dll", EntryPoint="MsiRecordSetStreamW", CharSet=CharSet.Unicode)]
        private static extern uint RecordSetStream(uint record, uint field, string path);
        [DllImport("msi.dll", EntryPoint="MsiGetSummaryInformationW", CharSet=CharSet.Unicode)]
        private static extern uint GetSummary(uint database, string path, uint updates, out uint summary);
        [DllImport("msi.dll", EntryPoint="MsiSummaryInfoSetPropertyW", CharSet=CharSet.Unicode)]
        private static extern uint SetSummary(uint summary, uint id, uint type, int number, IntPtr date, string text);
        [DllImport("msi.dll", EntryPoint="MsiSummaryInfoPersist")]
        private static extern uint PersistSummary(uint summary);
        [DllImport("msi.dll", EntryPoint="MsiDatabaseCommit")]
        private static extern uint DatabaseCommit(uint database);
        [DllImport("msi.dll", EntryPoint="MsiCloseHandle")]
        private static extern uint CloseHandle(uint handle);

        private static void Check(uint status, string operation) {
            if (status != 0)
                throw new InvalidOperationException(operation + " (Windows Installer " + status + ")", new Win32Exception((int)status));
        }

        public InstallerDatabase(string path) {
            Check(OpenDatabase(path, new IntPtr(3), out db), "Criar banco MSI");
        }

        public void Import(string directory, string fileName) {
            Check(DatabaseImport(db, directory, fileName), "Importar " + fileName);
        }

        public void AddStream(string name, string path) {
            uint view;
            Check(OpenView(db, "INSERT INTO `_Streams` (`Name`, `Data`) VALUES (?, ?)", out view), "Abrir streams MSI");
            try {
                uint record = CreateRecord(2);
                if (record == 0) throw new InvalidOperationException("Criar registro MSI");
                try {
                    Check(RecordSetString(record, 1, name), "Nomear stream MSI");
                    Check(RecordSetStream(record, 2, path), "Ler gabinete MSI");
                    Check(ViewExecute(view, record), "Incorporar gabinete MSI");
                } finally { CloseHandle(record); }
            } finally { CloseHandle(view); }
        }

        private static void SummaryText(uint summary, uint id, string value) {
            Check(SetSummary(summary, id, 30, 0, IntPtr.Zero, value), "Escrever metadados MSI");
        }

        private static void SummaryNumber(uint summary, uint id, uint type, int value) {
            Check(SetSummary(summary, id, type, value, IntPtr.Zero, null), "Escrever metadados MSI");
        }

        public void Describe(string packageCode) {
            uint summary;
            Check(GetSummary(db, null, 12, out summary), "Abrir metadados MSI");
            try {
                SummaryNumber(summary, 1, 2, 1252);
                SummaryText(summary, 2, "Installation Database");
                SummaryText(summary, 3, "PrismaFrame");
                SummaryText(summary, 4, "PrismaFrame");
                SummaryText(summary, 7, "x64;1046");
                SummaryText(summary, 9, packageCode);
                SummaryNumber(summary, 14, 3, 500);
                // Compressed source with limited-user installation.
                SummaryNumber(summary, 15, 3, 10);
                SummaryText(summary, 18, "Windows Installer");
                Check(PersistSummary(summary), "Salvar metadados MSI");
            } finally { CloseHandle(summary); }
        }

        public void Commit() {
            Check(DatabaseCommit(db), "Salvar banco MSI");
        }

        public void Dispose() {
            if (db != 0) { CloseHandle(db); db = 0; }
        }
    }
}
'@ -ErrorAction Stop
}

function Import-InstallerTable([string]$Name, [string]$Columns, [string]$Types, [string]$Keys, [string[]]$Rows) {
    $file = "$Name.idt"
    $content = @($Columns, $Types, "$Name|$Keys") + $Rows
    [IO.File]::WriteAllLines((Join-Path $staging $file), @($content | ForEach-Object { $_.Replace('|', "`t").Replace('^', '|') }), $tableEncoding)
    $database.Import($staging, $file)
}

function Import-InstallerSequence([string]$Name, [string[]]$Actions) {
    Import-InstallerTable $Name 'Action|Condition|Sequence' 's72|S255|I2' 'Action' $Actions
}

$upgradeCode = '{7140E3DF-2B19-49F8-997B-C7F93EF413E9}'
$hash = [Security.Cryptography.SHA256]::Create()
try { $productBytes = $hash.ComputeHash([Text.Encoding]::UTF8.GetBytes("$upgradeCode/$versionText")) }
finally { $hash.Dispose() }
$productBytes[7] = ($productBytes[7] -band 15) -bor 64
$productBytes[8] = ($productBytes[8] -band 63) -bor 128
$productCode = ([Guid]::new([byte[]]$productBytes[0..15])).ToString('B').ToUpperInvariant()
$packageCode = [Guid]::NewGuid().ToString('B').ToUpperInvariant()

$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$staging = Join-Path $temporaryRoot ('PrismaFrameMSI-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($staging)
$database = $null
$tableEncoding = [Text.Encoding]::GetEncoding(1252)
try {
    $payload = Join-Path $staging 'PrismaFrame.exe'
    [IO.File]::Copy($source, $payload)
    $cabinetFile = Join-Path $staging 'Payload.cab'
    $dbFile = Join-Path $staging 'PrismaFrame.msi'
    [IO.File]::WriteAllLines((Join-Path $staging 'package.ddf'), @(
        '.OPTION EXPLICIT', '.Set Cabinet=on', '.Set Compress=on', '.Set CompressionType=MSZIP',
        '.Set CabinetNameTemplate=Payload.cab', '.Set DiskDirectory1=.', '.Set RptFileName=package.rpt', '.Set InfFileName=package.inf',
        'PrismaFrame.exe AppExecutable'
    ), [Text.Encoding]::ASCII)
    Push-Location -LiteralPath $staging
    try {
        $cabLog = & (Join-Path ([Environment]::SystemDirectory) 'makecab.exe') /F 'package.ddf' 2>&1
        if ($LASTEXITCODE -ne 0 -or -not [IO.File]::Exists($cabinetFile)) { throw "Falha ao comprimir o executável. $($cabLog -join ' ')" }
    } finally { Pop-Location }

    $database = [PrismaFrame.InstallerDatabase]::new($dbFile)
    [IO.File]::WriteAllText((Join-Path $staging '_ForceCodepage.idt'), "`r`n`r`n1252`t_ForceCodepage`r`n", [Text.Encoding]::ASCII)
    $database.Import($staging, '_ForceCodepage.idt')
    $database.Describe($packageCode)
    Import-InstallerTable 'Property' 'Property|Value' 's72|l0' 'Property' @(
        "ProductCode|$productCode", "ProductVersion|$versionText", "UpgradeCode|$upgradeCode", 'ProductName|PrismaFrame',
        'Manufacturer|PrismaFrame', 'ProductLanguage|1046', 'INSTALLLEVEL|1', 'ARPNOMODIFY|1',
        'ARPURLINFOABOUT|https://github.com/jxaoz/pulso-arena', 'SecureCustomProperties|PRISMAFRAME_OLDER;PRISMAFRAME_NEWER'
    )
    Import-InstallerTable 'Directory' 'Directory|Directory_Parent|DefaultDir' 's72|S72|l255' 'Directory' @(
        'TARGETDIR||SourceDir', 'LocalAppDataFolder|TARGETDIR|.', 'UserPrograms|LocalAppDataFolder|Programs:.',
        'INSTALLFOLDER|UserPrograms|PRISMA~1^PrismaFrame:.', 'ProgramMenuFolder|TARGETDIR|.'
    )
    Import-InstallerTable 'Component' 'Component|ComponentId|Directory_|Attributes|Condition|KeyPath' 's72|S38|s72|i2|S255|S72' 'Component' @(
        'AppComponent|{6D789419-5393-49F7-A4A9-6966FFE4225C}|INSTALLFOLDER|260||AppKey',
        'MenuComponent|{9702A6C1-452F-4BFE-B0E9-01091DCF2B2E}|ProgramMenuFolder|260||MenuKey'
    )
    Import-InstallerTable 'Feature' 'Feature|Feature_Parent|Title|Description|Display|Level|Directory_|Attributes' 's38|S38|L64|L255|I2|i2|S72|i2' 'Feature' @(
        'MainFeature||PrismaFrame|Otimizador de jogos para Windows|1|1|INSTALLFOLDER|0'
    )
    Import-InstallerTable 'FeatureComponents' 'Feature_|Component_' 's38|s72' 'Feature_|Component_' @(
        'MainFeature|AppComponent', 'MainFeature|MenuComponent'
    )
    $fileSize = (Get-Item -LiteralPath $payload).Length
    $fileVersion = "$embeddedVersion.$($fileInfo.FilePrivatePart)"
    Import-InstallerTable 'File' 'File|Component_|FileName|FileSize|Version|Language|Attributes|Sequence' 's72|s72|l255|i4|S72|S20|I2|i2' 'File' @(
        "AppExecutable|AppComponent|PRISMA~1.EXE^PrismaFrame.exe|$fileSize|$fileVersion||16896|1"
    )
    Import-InstallerTable 'Media' 'DiskId|LastSequence|DiskPrompt|Cabinet|VolumeLabel|Source' 'i2|i2|L64|S255|S32|S72' 'DiskId' @(
        '1|1||#Payload.cab||'
    )
    Import-InstallerTable 'Registry' 'Registry|Root|Key|Name|Value|Component_' 's72|i2|l255|L255|L0|s72' 'Registry' @(
        'AppKey|1|Software\PrismaFrame\Installer|InstalledVersion|[ProductVersion]|AppComponent',
        'MenuKey|1|Software\PrismaFrame\Installer|StartMenuShortcut|#1|MenuComponent'
    )
    Import-InstallerTable 'Shortcut' 'Shortcut|Directory_|Name|Component_|Target|Arguments|Description|Hotkey|Icon_|IconIndex|ShowCmd|WkDir|DisplayResourceDLL|DisplayResourceId|DescriptionResourceDLL|DescriptionResourceId' 's72|s72|l128|s72|s72|S255|L255|I2|S72|I2|I2|S72|S255|I2|S255|I2' 'Shortcut' @(
        'OpenPrismaFrame|ProgramMenuFolder|PRISMA~1^PrismaFrame|MenuComponent|[#AppExecutable]||Abrir o PrismaFrame||||1|INSTALLFOLDER||||'
    )
    Import-InstallerTable 'Upgrade' 'UpgradeCode|VersionMin|VersionMax|Language|Attributes|Remove|ActionProperty' 's38|S20|S20|S255|i4|S255|s72' 'UpgradeCode|VersionMin|VersionMax|Language|Attributes' @(
        "$upgradeCode||$versionText||0||PRISMAFRAME_OLDER", "$upgradeCode|$versionText|||2||PRISMAFRAME_NEWER"
    )
    Import-InstallerTable 'LaunchCondition' 'Condition|Description' 's255|l255' 'Condition' @(
        'Installed OR (VersionNT64 AND WindowsBuild >= 10240)|O PrismaFrame requer Windows 10 ou 11 de 64 bits.',
        'NOT ALLUSERS|Instale o PrismaFrame para a sua conta do Windows.',
        'Installed OR NOT PRISMAFRAME_NEWER|Uma versão mais recente do PrismaFrame já está instalada.'
    )
    Import-InstallerTable 'Dialog' 'Dialog|HCentering|VCentering|Width|Height|Attributes|Title|Control_First|Control_Default|Control_Cancel' 's72|i2|i2|i2|i2|i4|L128|s50|S50|S50' 'Dialog' @(
        'InstallPrismaFrame|50|50|310|122|3|Instalar PrismaFrame|Install|Install|Cancel'
    )
    Import-InstallerTable 'Control' 'Dialog_|Control|Type|X|Y|Width|Height|Attributes|Property|Text|Control_Next|Help' 's72|s50|s20|i2|i2|i2|i2|I4|S50|L0|S50|L50' 'Dialog_|Control' @(
        'InstallPrismaFrame|Heading|Text|16|12|277|17|3||Instalar o PrismaFrame||',
        'InstallPrismaFrame|Details|Text|16|35|277|45|3||O aplicativo será instalado para a sua conta, com um atalho no menu Iniciar.||',
        'InstallPrismaFrame|Install|PushButton|174|92|58|17|3||Instalar|Cancel|',
        'InstallPrismaFrame|Cancel|PushButton|239|92|58|17|3||Cancelar|Install|'
    )
    Import-InstallerTable 'ControlEvent' 'Dialog_|Control_|Event|Argument|Condition|Ordering' 's72|s50|s50|l255|S255|I2' 'Dialog_|Control_|Event|Argument|Condition' @(
        'InstallPrismaFrame|Install|EndDialog|Return|1|1', 'InstallPrismaFrame|Cancel|EndDialog|Exit|1|1'
    )
    $prepare = @('FindRelatedProducts||25', 'LaunchConditions||100', 'ValidateProductID||700', 'CostInitialize||800', 'FileCost||900', 'CostFinalize||1000')
    Import-InstallerSequence 'InstallUISequence' ($prepare + @('InstallPrismaFrame|NOT Installed|1200', 'ExecuteAction||1300'))
    Import-InstallerSequence 'InstallExecuteSequence' ($prepare + @(
        'InstallValidate||1400', 'InstallInitialize||1500', 'RemoveExistingProducts|PRISMAFRAME_OLDER|1501',
        'ProcessComponents||1600', 'UnpublishFeatures||1800', 'RemoveRegistryValues||2600', 'RemoveShortcuts||3200',
        'RemoveFiles||3500', 'RemoveFolders||3600', 'InstallFiles||4000', 'CreateShortcuts||4500', 'WriteRegistryValues||5000',
        'RegisterUser||6000', 'RegisterProduct||6100', 'PublishFeatures||6300', 'PublishProduct||6400', 'InstallFinalize||6600'
    ))
    Import-InstallerSequence 'AdminExecuteSequence' @(
        'CostInitialize||800', 'FileCost||900', 'CostFinalize||1000', 'InstallValidate||1400', 'InstallInitialize||1500',
        'InstallAdminPackage||3900', 'InstallFiles||4000', 'InstallFinalize||6600'
    )

    $database.AddStream('Payload.cab', $cabinetFile)
    $database.Commit()
    $database.Dispose()
    $database = $null
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
    [IO.File]::Copy($dbFile, $destination, $true)
    [pscustomobject]@{
        OutputPath = $destination; Version = $versionText; ProductCode = $productCode
        Bytes = (Get-Item -LiteralPath $destination).Length
        SHA256 = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
    }
} finally {
    if ($database) { $database.Dispose() }
    $resolved = [IO.Path]::GetFullPath($staging)
    if ($resolved.StartsWith((Join-Path $temporaryRoot 'PrismaFrameMSI-'), [StringComparison]::OrdinalIgnoreCase) -and [IO.Directory]::Exists($resolved)) {
        [IO.Directory]::Delete($resolved, $true)
    }
}
