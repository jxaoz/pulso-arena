param([switch]$SelfTest, [string]$CaptureDirectory, [switch]$OpenRecovery, $EmbeddedRuntime)

$ErrorActionPreference = 'Stop'
$script:appRoot = $PSScriptRoot
$script:prismaRuntime = $EmbeddedRuntime
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
foreach ($name in 'Tweaks.ps1','Scanner.ps1','Maintenance.ps1','Tuning.ps1','Recommendations.ps1') {
    $source = if ($EmbeddedRuntime) { [scriptblock]::Create($EmbeddedRuntime.ReadText($name)) } else { Join-Path $PSScriptRoot $name }
    . $source
}

$xaml = if ($EmbeddedRuntime) { $EmbeddedRuntime.ReadText('PrismaFrame.xaml') }
    else { Get-Content -LiteralPath (Join-Path $PSScriptRoot 'PrismaFrame.xaml') -Raw -Encoding UTF8 }
$reader = [Xml.XmlNodeReader]::new([xml]$xaml)
try { $script:window = [Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Close() }
$script:ui = @{}
foreach ($name in 'Navigation','SecondaryNav','PageCaption','PageScroll','PageBody','StatusText','WorkIndicator','SessionLabel') {
    $script:ui[$name] = $script:window.FindName($name)
}

$script:color = @{
    Text = '#F0F5FC'; Muted = '#A7B7CC'; Accent = '#72EBFF'; Line = '#243149'; Panel = '#101520'
    Faint = '#7788A1'; Blue = '#B3AFFE'; Warm = '#FFCB69'; Bad = '#FF9EBB'; Pink = '#FF65AA'; Mint = '#58EDB6'
}
$script:brushes = @{}
$script:nav = @{}
$script:page = ''
$script:filter = 'Todos'
$script:scan = $null
$script:scannerTab = 'Perfil'
$script:preview = $null
$script:cleanupFlags = @{}
$script:restorePoints = @()
$script:restoreRead = $false
$script:restoreError = ''
$script:work = $null
$script:selectedExecutable = ''
$script:selectedGameConfig = ''
$script:automationDefinitions = @{}
foreach ($tweak in $script:Tweaks) {
    if ($tweak.Mode -eq 'Auto') { $script:automationDefinitions[$tweak.Id] = Get-TuningDefinition $tweak.Id }
}
$script:isAdmin = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($script:isAdmin) { $script:ui.SessionLabel.Text = 'MODO ADMINISTRADOR' }

$script:icons = @{
    home = 'M2,10 L12,2 22,10 M5,9 L5,21 10,21 10,15 14,15 14,21 19,21 19,9'
    tune = 'M3,6 L8,6 M12,6 L21,6 M8,3 L8,9 M3,12 L14,12 M18,12 L21,12 M18,9 L18,15 M3,18 L6,18 M10,18 L21,18 M6,15 L6,21'
    scan = 'M2,7 L2,2 7,2 M17,2 L22,2 22,7 M22,17 L22,22 17,22 M7,22 L2,22 2,17 M5,12 L9,12 11,7 14,17 16,12 19,12'
    clean = 'M15,2 L18,4 12,11 M7,9 L15,13 11,21 2,17 Z M7,14 L5,18 M10,15 L8,19'
    shield = 'M12,2 L20,5 20,12 C20,16 17,19 12,22 C7,19 4,16 4,12 L4,5 Z M8,12 L11,15 16,9'
    book = 'M3,4 L8,4 Q11,4 12,7 Q13,4 16,4 L21,4 21,19 16,19 Q13,19 12,21 Q11,19 8,19 L3,19 Z M12,8 L12,20'
    cpu = 'M6,5 L18,5 18,19 6,19 Z M3,8 L6,8 M3,12 L6,12 M3,16 L6,16 M18,8 L21,8 M18,12 L21,12 M18,16 L21,16 M9,2 L9,5 M15,2 L15,5 M9,19 L9,22 M15,19 L15,22 M9,9 L15,9 15,15 9,15 Z'
    gpu = 'M3,6 L21,6 21,18 3,18 Z M3,9 L1,9 1,20 M18,18 L18,21 M16,18 L16,21 M16,12 A4,4 0 1 0 8,12 A4,4 0 1 0 16,12 M12,10 L12,14 M10,12 L14,12'
    ram = 'M2,7 L22,7 22,17 2,17 Z M5,11 L8,11 M11,11 L14,11 M17,11 L20,11 M5,17 L5,20 M9,17 L9,20 M15,17 L15,20 M19,17 L19,20'
    arrow = 'M3,12 L20,12 M14,6 L20,12 14,18'
    bolt = 'M13,2 L5,13 11,13 9,22 20,10 14,10 Z'
}

function Get-UBrush([string]$Hex) {
    if (-not $script:brushes.ContainsKey($Hex)) {
        $brush = [Windows.Media.BrushConverter]::new().ConvertFromInvariantString($Hex)
        $brush.Freeze()
        $script:brushes[$Hex] = $brush
    }
    $script:brushes[$Hex]
}

function New-UText([string]$Value, [double]$Size = 14, [string]$Color = $script:color.Text, [string]$Weight = 'Normal') {
    $item = [Windows.Controls.TextBlock]::new()
    $item.Text = $Value
    $item.FontSize = $Size
    $item.Foreground = Get-UBrush $Color
    $item.FontWeight = [Windows.FontWeightConverter]::new().ConvertFromInvariantString($Weight)
    $item.TextWrapping = 'Wrap'
    $item
}

function New-UPanel([switch]$Horizontal) {
    $panel = [Windows.Controls.StackPanel]::new()
    if ($Horizontal) { $panel.Orientation = 'Horizontal' }
    $panel
}

function New-UCard($Child, [string]$Background = $script:color.Panel, [int]$Padding = 17) {
    $card = [Windows.Controls.Border]::new()
    $card.Background = Get-UBrush $Background
    $card.BorderBrush = Get-UBrush $script:color.Line
    $card.BorderThickness = [Windows.Thickness]::new(1)
    $card.CornerRadius = [Windows.CornerRadius]::new(13)
    $card.Padding = [Windows.Thickness]::new($Padding)
    $card.Child = $Child
    $card
}

function New-UIcon([string]$Name, [string]$Color = $script:color.Accent, [double]$Size = 18) {
    $icon = [Windows.Shapes.Path]::new()
    $icon.Data = [Windows.Media.Geometry]::Parse($script:icons[$Name])
    $icon.Stroke = Get-UBrush $Color
    $icon.StrokeThickness = 1.55
    $icon.StrokeStartLineCap = 'Round'
    $icon.StrokeEndLineCap = 'Round'
    $icon.StrokeLineJoin = 'Round'
    $icon.Stretch = 'Uniform'
    $icon.Width = $Size
    $icon.Height = $Size
    $icon.VerticalAlignment = 'Center'
    $icon
}

function New-UButton([string]$Label, [string]$Style, [scriptblock]$Click, [string]$Icon = '') {
    $button = [Windows.Controls.Button]::new()
    $button.Style = $script:window.FindResource($Style)
    [Windows.Automation.AutomationProperties]::SetName($button, $Label)
    if ($Icon) {
        $content = New-UPanel -Horizontal
        $image = New-UIcon $Icon '#A9B9D0' 15
        $image.Margin = '0,0,10,0'
        [void]$content.Children.Add($image)
        $labelText = [Windows.Controls.TextBlock]::new()
        $labelText.Text = $Label
        $labelText.VerticalAlignment = 'Center'
        [void]$content.Children.Add($labelText)
        $button.Content = $content
    } else { $button.Content = $Label }
    if ($Click) { $button.Add_Click([Windows.RoutedEventHandler]$Click) }
    $button
}

function New-UGrid([int]$Columns) {
    $grid = [Windows.Controls.Primitives.UniformGrid]::new()
    $grid.Columns = $Columns
    $grid.Margin = '-5,0,-5,0'
    $grid
}

function Add-UGridItem($Grid, $Item) {
    $Item.Margin = '5,0,5,10'
    [void]$Grid.Children.Add($Item)
}

function Add-PageItem($Item) { [void]$script:ui.PageBody.Children.Add($Item) }

function Add-PageIntro([string]$Title, [string]$Subtitle) {
    $titleText = New-UText $Title 33 $script:color.Text 'Bold'
    $titleText.Margin = '0,0,0,5'
    Add-PageItem $titleText
    $subtitleText = New-UText $Subtitle 14 $script:color.Muted
    $subtitleText.Margin = '0,0,0,20'
    Add-PageItem $subtitleText
}

function Add-PageSection([string]$Title, [string]$Detail = '') {
    $row = [Windows.Controls.DockPanel]::new()
    $row.Margin = '0,16,0,10'
    if ($Detail) {
        $caption = New-UText $Detail 12 $script:color.Muted
        $caption.VerticalAlignment = 'Center'
        [Windows.Controls.DockPanel]::SetDock($caption, 'Right')
        [void]$row.Children.Add($caption)
    }
    [void]$row.Children.Add((New-UText $Title 19 $script:color.Text 'SemiBold'))
    Add-PageItem $row
}

function Set-OptimizerStatus([string]$Message, [switch]$Problem) {
    $script:ui.StatusText.Text = $Message
    $script:ui.StatusText.ToolTip = $Message
    $script:ui.StatusText.Foreground = Get-UBrush $(if ($Problem) { $script:color.Bad } else { $script:color.Muted })
}

function Show-OptimizerDialog([string]$Title, [string]$Copy, [string]$Accept = 'Entendi', [switch]$Confirm, $Form, [scriptblock]$Validate) {
    $dialog = [Windows.Window]::new()
    $dialog.Owner = $script:window
    $dialog.Title = $Title
    $dialog.ShowInTaskbar = $false
    $dialog.WindowStartupLocation = 'CenterOwner'
    $dialog.Background = Get-UBrush '#111926'
    $dialog.Width = 540
    $dialog.SizeToContent = 'Height'
    $dialog.ResizeMode = 'NoResize'
    $body = New-UPanel
    $body.Margin = '24,20,24,24'
    $titleText = New-UText $Title 23 $script:color.Text 'Bold'
    $titleText.Margin = '0,0,0,12'
    [void]$body.Children.Add($titleText)
    $scroll = [Windows.Controls.ScrollViewer]::new()
    $scroll.MaxHeight = 340
    $scroll.VerticalScrollBarVisibility = 'Auto'
    $scroll.Content = New-UText $Copy 14 $script:color.Muted
    [void]$body.Children.Add($scroll)
    if ($Form) { [void]$body.Children.Add($Form) }
    $buttons = New-UPanel -Horizontal
    $buttons.HorizontalAlignment = 'Right'
    $buttons.Margin = '0,20,0,0'
    if ($Confirm) {
        $cancel = New-UButton 'Cancelar' 'BaseButton' {}
        $cancel.IsCancel = $true
        $cancel.Margin = '0,0,8,0'
        [void]$buttons.Children.Add($cancel)
    }
    $okHandler = { if (-not $Validate -or (& $Validate)) { $dialog.DialogResult = $true } }.GetNewClosure()
    $ok = New-UButton $Accept 'PrimaryButton' $okHandler
    $ok.IsDefault = $true
    [void]$buttons.Children.Add($ok)
    [void]$body.Children.Add($buttons)
    $dialog.Content = $body
    [bool]$dialog.ShowDialog()
}

function Start-OptimizerWork([string]$Operation, $Value, [string]$Message, [scriptblock]$Complete) {
    if ($script:work) {
        Set-OptimizerStatus 'Aguarde a operação em andamento.'
        return
    }
    $command = [PowerShell]::Create()
    $background = {
        param($Root, $Operation, $Value, $Runtime)
        $ErrorActionPreference = 'Stop'
        $script:prismaRuntime = $Runtime
        $provider = switch ($Operation) {
            Scan { 'Scanner.ps1' }
            { $_ -in 'Preview','Clean','RestoreList','RestoreNew' } { 'Maintenance.ps1' }
            { $_ -in 'Apply','ApplyBatch','Undo' } { 'Tuning.ps1' }
            default { throw 'Operação desconhecida.' }
        }
        $source = if ($Runtime) { [scriptblock]::Create($Runtime.ReadText($provider)) } else { Join-Path $Root $provider }
        . $source
        switch ($Operation) {
            Scan { Get-OptimizationScan }
            Preview { Get-CleanupPreview -Ids @($Value) }
            Clean { Invoke-Cleanup -Preview $Value }
            RestoreList { Get-OptimizerRestorePoints }
            RestoreNew { New-OptimizerRestorePoint -Description 'PrismaFrame' }
            Apply { Invoke-OptimizerTweak -Id $Value.Id -Title $Value.Title -Options $Value.Options }
            ApplyBatch { Invoke-OptimizerTweakBatch -Items @($Value) }
            Undo { Undo-OptimizerTweak -Token $Value }
        }
    }
    try {
        [void]$command.AddScript($background.ToString()).AddArgument($script:appRoot).AddArgument($Operation).AddArgument($Value).AddArgument($script:prismaRuntime)
        $script:work = [pscustomobject]@{ Engine = $command; Handle = $command.BeginInvoke(); Complete = $Complete; Operation = $Operation }
        $script:ui.WorkIndicator.Visibility = 'Visible'
        Set-OptimizerStatus $Message
        $script:workTimer.Start()
    } catch {
        $command.Dispose()
        $script:work = $null
        Set-OptimizerStatus $_.Exception.Message -Problem
    }
}

function Complete-OptimizerWork {
    if (-not $script:work -or -not $script:work.Handle.IsCompleted) { return }
    $job = $script:work
    $script:work = $null
    $script:workTimer.Stop()
    $script:ui.WorkIndicator.Visibility = 'Collapsed'
    try {
        $result = @($job.Engine.EndInvoke($job.Handle))
        if ($job.Engine.Streams.Error.Count) { throw $job.Engine.Streams.Error[0] }
        & $job.Complete $result
    } catch {
        $message = if ($job.Engine.Streams.Error.Count) { $job.Engine.Streams.Error[0].Exception.Message } else { $_.Exception.Message }
        if ($SelfTest) { throw "[$($job.Operation)] $message" }
        Set-OptimizerStatus $message -Problem
        if ($job.Operation -in @('RestoreList','RestoreNew')) {
            $script:restoreError = $message
            if ($script:page -eq 'Recuperação') { Show-OptimizerPage 'Recuperação' -KeepScroll }
        } else {
            if ($job.Operation -eq 'Undo' -and $script:page -eq 'Recuperação') { Show-OptimizerPage 'Recuperação' -KeepScroll }
            [void](Show-OptimizerDialog 'Operação interrompida' $message)
        }
    } finally { $job.Engine.Dispose() }
}

$script:workTimer = [Windows.Threading.DispatcherTimer]::new()
$script:workTimer.Interval = [TimeSpan]::FromMilliseconds(130)
$script:workTimer.Add_Tick({ Complete-OptimizerWork })

function New-LandingArt {
    $canvas = [Windows.Controls.Canvas]::new()
    $canvas.Width = 501
    $canvas.Height = 284
    $canvas.HorizontalAlignment = 'Right'
    $canvas.VerticalAlignment = 'Center'
    $canvas.IsHitTestVisible = $false
    $geometry = @(
        @{ X=111; Y=18; W=435; H=69; R=32; Edge='#4665FE'; Light='#47BAFF' },
        @{ X=-29; Y=81; W=426; H=69; R=34; Edge='#073CFE'; Light='#5284FF' },
        @{ X=226; Y=144; W=350; H=69; R=34; Edge='#0BB9E8'; Light='#67F8FF' },
        @{ X=-46; Y=207; W=454; H=68; R=34; Edge='#2723F6'; Light='#7B72FF' },
        @{ X=387; Y=-43; W=83; H=351; R=31; Edge='#025A92'; Light='#61E8FE' }
    )
    foreach ($item in $geometry) {
        $form = [Windows.Shapes.Rectangle]::new()
        $form.Width = $item.W; $form.Height = $item.H
        $form.RadiusX = $item.R; $form.RadiusY = $item.R
        $form.Stroke = Get-UBrush $item.Edge
        $form.StrokeThickness = 4
        $glow = [Windows.Media.Effects.DropShadowEffect]::new()
        $glow.Color = [Windows.Media.ColorConverter]::ConvertFromString($item.Light)
        $glow.ShadowDepth = 0; $glow.BlurRadius = 23; $glow.Opacity = .72
        $form.Effect = $glow
        [Windows.Controls.Canvas]::SetLeft($form, $item.X)
        [Windows.Controls.Canvas]::SetTop($form, $item.Y)
        [void]$canvas.Children.Add($form)

        $light = [Windows.Shapes.Rectangle]::new()
        $light.Width = $item.W - 3; $light.Height = $item.H - 3
        $light.RadiusX = $item.R; $light.RadiusY = $item.R
        $light.Stroke = Get-UBrush $item.Light
        $light.Opacity = .84; $light.StrokeThickness = 1.2
        [Windows.Controls.Canvas]::SetLeft($light, $item.X + 1.5)
        [Windows.Controls.Canvas]::SetTop($light, $item.Y + 1.5)
        [void]$canvas.Children.Add($light)
    }
    foreach ($mark in @(@(371,23,'#55E8FF'),@(441,201,'#FF5DAB'),@(351,258,'#FFCB69'),@(84,126,'#43E6A6'))) {
        $bar = [Windows.Shapes.Rectangle]::new()
        $bar.Width = 22; $bar.Height = 3; $bar.RadiusX = 1.5; $bar.RadiusY = 1.5
        $bar.Fill = Get-UBrush $mark[2]
        [Windows.Controls.Canvas]::SetLeft($bar, $mark[0])
        [Windows.Controls.Canvas]::SetTop($bar, $mark[1])
        [void]$canvas.Children.Add($bar)
    }
    $canvas
}

function Show-HomePage {
    $hero = [Windows.Controls.Grid]::new()
    $hero.Height = 284
    $hero.ClipToBounds = $true
    $hero.Background = [Windows.Media.LinearGradientBrush]::new(
        [Windows.Media.ColorConverter]::ConvertFromString('#0A0E17'), [Windows.Media.ColorConverter]::ConvertFromString('#080A11'), 8)
    [void]$hero.Children.Add((New-LandingArt))
    $shade = [Windows.Controls.Border]::new()
    $shade.HorizontalAlignment = 'Left'
    $shade.Width = 487
    $shade.Margin = '1,1,0,1'
    $shade.CornerRadius = [Windows.CornerRadius]::new(12,0,0,12)
    $shade.Background = [Windows.Media.LinearGradientBrush]::new(
        [Windows.Media.ColorConverter]::ConvertFromString('#FF0A0E17'), [Windows.Media.ColorConverter]::ConvertFromString('#000A0E17'), 0)
    [void]$hero.Children.Add($shade)
    $heroCopy = New-UPanel
    $heroCopy.Margin = '27,0,20,0'
    $heroCopy.VerticalAlignment = 'Center'
    $heroCopy.HorizontalAlignment = 'Left'
    $eyebrow = New-UText 'FPS, LATÊNCIA E ESTABILIDADE' 11 $script:color.Accent 'Bold'
    $eyebrow.Margin = '1,0,0,9'
    [void]$heroCopy.Children.Add($eyebrow)
    $headline = New-UText 'Desempenho para' 45 $script:color.Text 'Bold'
    $headline.Margin = '0,0,0,-7'
    [void]$heroCopy.Children.Add($headline)
    [void]$heroCopy.Children.Add((New-UText 'seus jogos' 45 $script:color.Accent 'Bold'))
    $copy = New-UText 'Descubra quais ajustes testar primeiro com o processador, a placa de vídeo e a tela do seu PC.' 14 '#C3CEDD'
    $copy.MaxWidth = 370
    $copy.HorizontalAlignment = 'Left'
    $copy.Margin = '1,10,0,16'
    [void]$heroCopy.Children.Add($copy)
    $actions = New-UPanel -Horizontal
    $scanAction = if ($script:scan) { 'Ver meu perfil' } else { 'Escanear e personalizar' }
    $open = New-UButton $scanAction 'PrimaryButton' {
        $script:scannerTab = 'Perfil'
        Show-OptimizerPage 'Scanner do PC'
        if (-not $script:scan -and -not $script:work) { Invoke-PCScan }
    }
    $open.Margin = '0,0,9,0'
    [void]$actions.Children.Add($open)
    [void]$actions.Children.Add((New-UButton 'Ver ajustes automáticos' 'BaseButton' { $script:filter = 'Auto'; $script:searchTerm = ''; Show-OptimizerPage 'Ajustes' }))
    [void]$heroCopy.Children.Add($actions)
    [void]$hero.Children.Add($heroCopy)
    $heroCard = New-UCard $hero '#0A0E17' 0
    $heroCard.Background = $hero.Background
    $hero.Background = $null
    $heroCard.BorderBrush = Get-UBrush '#293C63'
    Add-PageItem $heroCard

    $hardwareDetail = if ($script:scan) { 'Dados do scanner local' } else { 'Verificação local do hardware' }
    Add-PageSection 'Configuração do PC' $hardwareDetail
    $hardware = New-UGrid 3
    $summary = if ($script:scan) { $script:scan.Summary } else { [pscustomobject]@{ CPU='A detectar'; GPU='A detectar'; RAM='A detectar' } }
    $hardwareItems = @(
        @{ Icon='cpu'; Label='PROCESSADOR'; Value=$summary.CPU; Hue=$script:color.Accent },
        @{ Icon='gpu'; Label='PLACA DE VÍDEO'; Value=$summary.GPU; Hue=$script:color.Blue },
        @{ Icon='ram'; Label='MEMÓRIA'; Value=$summary.RAM; Hue=$script:color.Mint }
    )
    foreach ($item in $hardwareItems) {
        $part = New-UPanel
        $labelRow = New-UPanel -Horizontal
        $icon = New-UIcon $item.Icon $item.Hue 17
        $icon.Margin = '0,0,8,0'
        [void]$labelRow.Children.Add($icon)
        [void]$labelRow.Children.Add((New-UText $item.Label 10 $script:color.Muted 'SemiBold'))
        [void]$part.Children.Add($labelRow)
        $value = New-UText $item.Value 16 $script:color.Text 'SemiBold'
        $value.Margin = '0,9,0,3'
        [void]$part.Children.Add($value)
        Add-UGridItem $hardware (New-UCard $part)
    }
    Add-PageItem $hardware
    Add-PageSection 'Ferramentas'
    $toolsGrid = New-UGrid 3
    foreach ($item in @(
        @{ Icon='tune'; Hue=$script:color.Blue; Title='Biblioteca de ajustes'; Copy="$($script:Tweaks.Count) ajustes gratuitos para jogos, Windows, vídeo, rede e entrada."; Page='Ajustes'; Action='Abrir biblioteca' },
        @{ Icon='clean'; Hue=$script:color.Pink; Title='Limpeza do sistema'; Copy='Confira arquivos temporários e o espaço recuperável antes de excluir.'; Page='Limpeza'; Action='Analisar arquivos' },
        @{ Icon='shield'; Hue=$script:color.Warm; Title='Ponto de restauração'; Copy='Crie um ponto do Windows e reverta ajustes automáticos pelo histórico local.'; Page='Recuperação'; Action='Abrir recuperação' }
    )) {
        $column = New-UPanel
        [void]$column.Children.Add((New-UIcon $item.Icon $item.Hue 20))
        $column.Children[0].HorizontalAlignment = 'Left'
        $title = New-UText $item.Title 16 $script:color.Text 'SemiBold'
        $title.Margin = '0,8,0,4'
        [void]$column.Children.Add($title)
        $description = New-UText $item.Copy 12 $script:color.Muted
        $description.MinHeight = 34
        [void]$column.Children.Add($description)
        $destination = $item.Page
        $click = { Open-OptimizerDestination $destination }.GetNewClosure()
        $button = New-UButton $item.Action 'ChipButton' $click
        $button.HorizontalAlignment = 'Left'
        $button.Margin = '0,9,0,0'
        [void]$column.Children.Add($button)
        Add-UGridItem $toolsGrid (New-UCard $column)
    }
    Add-PageItem $toolsGrid
}

$script:categoryLabels = @{ Todos='Todos'; Destaques='Destaques'; Auto='Automáticos'; Jogos='Jogos'; Fortnite='Fortnite'; Windows='Windows'; GPU='Vídeo'; Entrada='Entrada'; Rede='Rede'; Debloat='Debloat'; Hardware='Hardware' }
$script:modeLabels = @{ Auto='Automático'; Windows='Configurações do Windows'; Manual='Guia manual'; Link='Guia com link oficial' }
$script:searchTerm = ''

function Open-OptimizerTarget([string]$Target) {
    try {
        if ($Target -notmatch '^(https://\S+|ms-settings:[a-z0-9-]+)$') { throw 'O destino não é válido.' }
        Start-Process -FilePath $Target -ErrorAction Stop
    } catch { [void](Show-OptimizerDialog 'Não foi possível abrir' $_.Exception.Message) }
}

function Select-OptimizerGameFile([string]$Property, [string]$Current, [Windows.Window]$Owner) {
    $picker = [Microsoft.Win32.OpenFileDialog]::new()
    $picker.CheckFileExists = $true
    $picker.CheckPathExists = $true
    $picker.Multiselect = $false
    if ($Property -eq 'ConfigPath') {
        $picker.Title = 'Escolher GameUserSettings.ini do jogo'
        $picker.Filter = 'Configuração Unreal (GameUserSettings.ini)|GameUserSettings.ini'
        $picker.InitialDirectory = [Environment]::GetFolderPath('LocalApplicationData')
    } else {
        $picker.Title = 'Escolher o executável principal do jogo'
        $picker.Filter = 'Executável do jogo (*.exe)|*.exe'
    }
    if ($Current -and [IO.File]::Exists($Current)) {
        $picker.InitialDirectory = [IO.Path]::GetDirectoryName($Current)
        $picker.FileName = [IO.Path]::GetFileName($Current)
    }
    if (-not $Owner) { $Owner = $script:window }
    if ($picker.ShowDialog($Owner)) { $picker.FileName }
}

function Add-OptimizerFilePicker($Form, $Options, [string]$Property, [string]$Caption) {
    $title = New-UText $Caption 12 $script:color.Text 'SemiBold'
    $title.Margin = '0,11,0,5'
    [void]$Form.Children.Add($title)
    $row = [Windows.Controls.DockPanel]::new()
    $location = New-UText 'Nenhum arquivo selecionado' 12 $script:color.Muted
    $location.TextWrapping = 'NoWrap'
    $location.TextTrimming = 'CharacterEllipsis'
    $location.VerticalAlignment = 'Center'
    if ($Options.$Property) { $location.Text = $Options.$Property; $location.ToolTip = $Options.$Property }
    $pick = {
        $path = Select-OptimizerGameFile $Property $Options.$Property ([Windows.Window]::GetWindow($location))
        if ($path) { $Options.$Property = $path; $location.Text = $path; $location.ToolTip = $path }
    }.GetNewClosure()
    $choose = New-UButton 'Escolher arquivo' 'ChipButton' $pick
    [Windows.Automation.AutomationProperties]::SetName($choose, "Escolher arquivo · $Caption")
    $choose.Margin = '12,0,0,0'
    [Windows.Controls.DockPanel]::SetDock($choose, 'Right')
    [void]$row.Children.Add($choose)
    [void]$row.Children.Add($location)
    [void]$Form.Children.Add($row)
}

function Show-AutomaticTweak($Tweak, [string]$Copy) {
    if ($script:work) { Set-OptimizerStatus 'Aguarde a operação em andamento.'; return }
    $definition = $script:automationDefinitions[$Tweak.Id]
    $issue = Get-TuningCompatibilityIssue $definition
    if ($issue) {
        [void](Show-OptimizerDialog 'Ajuste indisponível nesta versão do Windows' $issue)
        return
    }
    if ($definition.Admin -and -not $script:isAdmin) {
        if (Show-OptimizerDialog $Tweak.Title "$Copy`n`nEste ajuste requer acesso de administrador. Em Recuperação, use Reabrir como administrador." 'Abrir Recuperação' -Confirm) {
            Show-OptimizerPage 'Recuperação'
        }
        return
    }
    $inputMode = [string]$definition.Input
    $options = [pscustomobject]@{ Executable = ''; ConfigPath = ''; Fps = $null }
    $form = New-UPanel
    if ($inputMode -like 'Executable*') {
        $options.Executable = $script:selectedExecutable
        Add-OptimizerFilePicker $form $options 'Executable' 'Executável principal do jogo (.exe)'
    }
    if ($inputMode -like 'GameConfig*') {
        $options.ConfigPath = $script:selectedGameConfig
        Add-OptimizerFilePicker $form $options 'ConfigPath' 'Configuração local do jogo (GameUserSettings.ini)'
        $hint = New-UText 'Procure na pasta Saved\Config do jogo em %LOCALAPPDATA% ou em Documentos\My Games.' 11 $script:color.Muted
        $hint.Margin = '0,5,0,0'
        [void]$form.Children.Add($hint)
    }
    $fpsBox = $null
    $minimum = 30; $maximum = 1000
    if ($Tweak.Id -eq 'framecap') { $maximum = 360 }
    if ($inputMode -like '*Fps') {
        if ($definition.MinFps) { $minimum = $definition.MinFps }
        if ($definition.MaxFps) { $maximum = $definition.MaxFps }
        $fpsLabel = New-UText "Limite de quadros ($minimum a $maximum FPS)" 12 $script:color.Text 'SemiBold'
        $fpsLabel.Margin = '0,11,0,5'
        [void]$form.Children.Add($fpsLabel)
        $fpsBox = [Windows.Controls.TextBox]::new()
        $fpsBox.Style = $script:window.FindResource([Windows.Controls.TextBox])
        $fpsBox.Width = 122
        $fpsBox.HorizontalAlignment = 'Left'
        $fpsBox.MaxLength = 4
        [Windows.Automation.AutomationProperties]::SetName($fpsBox, $fpsLabel.Text)
        $refresh = if ($script:scan -and $script:scan.Profile.PrimaryHz) { $script:scan.Profile.PrimaryHz } else { 60 }
        $fpsBox.Text = [string][Math]::Max($minimum, [Math]::Min($maximum, $refresh))
        [void]$form.Children.Add($fpsBox)
    }
    $errorLabel = New-UText '' 12 $script:color.Bad
    $errorLabel.Margin = '0,7,0,0'
    $errorLabel.Visibility = 'Collapsed'
    [void]$form.Children.Add($errorLabel)
    $validate = {
        $message = ''
        $number = 0
        if ($inputMode -like 'Executable*' -and -not [IO.File]::Exists($options.Executable)) { $message = 'Escolha o executável principal do jogo.' }
        elseif ($inputMode -like 'GameConfig*' -and -not [IO.File]::Exists($options.ConfigPath)) { $message = 'Escolha um GameUserSettings.ini compatível.' }
        elseif ($fpsBox -and (-not [int]::TryParse($fpsBox.Text, [ref]$number) -or $number -lt $minimum -or $number -gt $maximum)) {
            $message = "Digite um valor inteiro entre $minimum e $maximum FPS."
        }
        $errorLabel.Text = $message
        $errorLabel.Visibility = if ($message) { 'Visible' } else { 'Collapsed' }
        if ($message) { return $false }
        if ($fpsBox) { $options.Fps = $number }
        $true
    }.GetNewClosure()
    $copy += "`n`nA configuração anterior fica no histórico de Recuperação."
    if (-not (Show-OptimizerDialog $Tweak.Title $Copy 'Aplicar ajuste' -Confirm -Form $form -Validate $validate)) { return }
    if ($options.Executable) { $script:selectedExecutable = $options.Executable }
    if ($options.ConfigPath) { $script:selectedGameConfig = $options.ConfigPath }
    $payload = [pscustomobject]@{ Id = $Tweak.Id; Title = $Tweak.Title; Options = $options }
    Start-OptimizerWork 'Apply' $payload 'Aplicando e verificando o ajuste…' {
        param($Result)
        Set-OptimizerStatus ([string]$Result[0])
        [void](Show-OptimizerDialog 'Ajuste verificado' ([string]$Result[0]))
    }
}

function Show-TweakDetails($Tweak) {
    $copy = "$($Tweak.Summary)`n`n$($Tweak.Instructions)"
    switch ($Tweak.Mode) {
        Auto { Show-AutomaticTweak $Tweak $copy }
        Windows { if (Show-OptimizerDialog $Tweak.Title $copy 'Abrir configurações' -Confirm) { Open-OptimizerTarget $Tweak.Target } }
        Link { if (Show-OptimizerDialog $Tweak.Title $copy 'Abrir site oficial' -Confirm) { Open-OptimizerTarget $Tweak.Target } }
        Manual { [void](Show-OptimizerDialog $Tweak.Title $copy) }
    }
}

function Show-GeneralOptimizationPack {
    if ($script:work) { Set-OptimizerStatus 'Aguarde a operação em andamento.'; return }
    $form = New-UPanel
    $boxes = foreach ($id in 'gamemode', 'transparency', 'winanimations', 'dvr') {
        $tweak = $script:Tweaks | Where-Object Id -eq $id | Select-Object -First 1
        $check = [Windows.Controls.CheckBox]::new()
        $check.Content = $tweak.Title
        $check.Foreground = Get-UBrush $script:color.Text
        $check.Margin = '0,9,0,0'
        $check.IsChecked = $id -eq 'gamemode' -or $id -eq 'transparency'
        [void]$form.Children.Add($check)
        $detail = New-UText $tweak.Summary 12 $script:color.Muted
        $detail.Margin = '18,3,0,0'
        [void]$form.Children.Add($detail)
        [pscustomobject]@{ Check = $check; Tweak = $tweak }
    }
    $validator = { [bool]($boxes | Where-Object { $_.Check.IsChecked } | Select-Object -First 1) }.GetNewClosure()
    $copy = 'Escolha os ajustes do Windows que quer aplicar de uma vez. Cada alteração pode ser desfeita pelo histórico em Recuperação.'
    if (-not (Show-OptimizerDialog 'Pacote básico para jogos' $copy 'Aplicar selecionados' -Confirm -Form $form -Validate $validator)) { return }
    $payload = @($boxes | Where-Object { $_.Check.IsChecked } | ForEach-Object {
        [pscustomobject]@{ Id = $_.Tweak.Id; Title = $_.Tweak.Title; Options = [pscustomobject]@{} }
    })
    Start-OptimizerWork 'ApplyBatch' $payload 'Aplicando os ajustes selecionados…' {
        param($Result)
        $problems = @($Result | Where-Object { -not $_.Success }).Count
        Set-OptimizerStatus "Pacote processado · $problems com erro." -Problem:($problems -gt 0)
        $lines = $Result | ForEach-Object { "$($_.Title)`n$($_.Message)" }
        [void](Show-OptimizerDialog 'Resultado do pacote' ($lines -join "`n`n"))
    }
}

function Update-TweakCards {
    if ($script:page -ne 'Ajustes') { return }
    $script:tweakGrid.Children.Clear()
    $terms = @($script:searchTerm.Trim() -split '\s+' | Where-Object { $_ })
    $culture = [Globalization.CultureInfo]::GetCultureInfo('pt-BR').CompareInfo
    $comparison = [Globalization.CompareOptions]::IgnoreNonSpace -bor [Globalization.CompareOptions]::IgnoreCase
    $shown = 0
    $catalog = $script:Tweaks
    if ($script:filter -eq 'Auto') {
        $catalog = @($script:Tweaks | Where-Object Mode -eq 'Auto')
        $platform = @($catalog | Where-Object { $script:automationDefinitions[$_.Id].Kind -in @('Registry', 'Power', 'WindowsAction') })
        $contextual = @($catalog | Where-Object { $script:automationDefinitions[$_.Id].Kind -in @('Nvidia', 'GameConfig') })
        $catalog = $platform + $contextual
    }
    foreach ($tweak in $catalog) {
        if ($script:filter -eq 'Destaques' -and -not $tweak.Featured) { continue }
        if ($script:filter -notin @('Todos','Destaques','Auto') -and $script:filter -ne $tweak.Category) { continue }
        $haystack = "$($tweak.Title) $($tweak.Summary) $($tweak.Instructions) $($tweak.Category) $($script:modeLabels[$tweak.Mode])"
        $matches = $true
        foreach ($term in $terms) { if ($culture.IndexOf($haystack, $term, $comparison) -lt 0) { $matches = $false; break } }
        if (-not $matches) { continue }
        $shown++
        $column = New-UPanel
        $metaColor = if ($tweak.Mode -eq 'Auto') { $script:color.Accent } else { $script:color.Blue }
        $typeLabel = $script:modeLabels[$tweak.Mode]
        if ($tweak.Mode -eq 'Auto') {
            $type = $script:automationDefinitions[$tweak.Id]
            if ($type.Kind -eq 'Nvidia') { $typeLabel += ' · NVIDIA' }
            elseif ($type.Kind -eq 'GameConfig' -and -not $type.Fortnite) { $typeLabel += ' · Unreal' }
            if ($type.Admin) { $typeLabel += ' · Admin' }
        }
        $meta = New-UText "$($script:categoryLabels[$tweak.Category])  /  $typeLabel" 11 $metaColor 'SemiBold'
        [void]$column.Children.Add($meta)
        $title = New-UText $tweak.Title 17 $script:color.Text 'SemiBold'
        $title.Margin = '0,5,0,4'
        [void]$column.Children.Add($title)
        $summary = New-UText $tweak.Summary 13 $script:color.Muted
        $summary.MinHeight = 37
        [void]$column.Children.Add($summary)
        $current = $tweak
        $click = { Show-TweakDetails $current }.GetNewClosure()
        $label = if ($tweak.Mode -eq 'Auto') { 'Revisar e aplicar' } else { 'Ver como fazer' }
        $action = New-UButton $label 'ChipButton' $click
        [Windows.Automation.AutomationProperties]::SetName($action, "$label · $($tweak.Title)")
        $action.HorizontalAlignment = 'Left'
        $action.Margin = '0,10,0,0'
        [void]$column.Children.Add($action)
        Add-UGridItem $script:tweakGrid (New-UCard $column)
    }
    $script:tweakResults.Text = if ($shown -eq 0) { 'Nenhum ajuste encontrado. Tente outro termo ou categoria.' } else { "$shown de $($script:Tweaks.Count) ajustes" }
}

function Select-TweakFilter([string]$Category) {
    $script:filter = $Category
    foreach ($key in $script:filterButtons.Keys) {
        $button = $script:filterButtons[$key]
        $button.Background = Get-UBrush $(if ($key -eq $Category) { '#132943' } else { '#151D2D' })
        $button.Foreground = Get-UBrush $(if ($key -eq $Category) { $script:color.Accent } else { $script:color.Muted })
        $button.BorderBrush = Get-UBrush $(if ($key -eq $Category) { '#4885AD' } else { '#2B3A50' })
    }
    Update-TweakCards
}

function Show-TweaksPage {
    $autoCount = $script:automationDefinitions.Count
    Add-PageIntro 'Biblioteca de ajustes' "$($script:Tweaks.Count) opções gratuitas · $autoCount aplicáveis no app, com instruções para as demais."
    $batch = New-UButton 'Revisar pacote básico' 'PrimaryButton' { Show-GeneralOptimizationPack }
    $batch.HorizontalAlignment = 'Left'
    $batch.Margin = '0,0,0,15'
    Add-PageItem $batch
    $search = [Windows.Controls.TextBox]::new()
    [Windows.Automation.AutomationProperties]::SetName($search, 'Buscar por nome, descrição ou termo')
    $search.ToolTip = 'Busque por FPS, Reflex, inicialização ou qualquer termo.'
    $search.Text = $script:searchTerm
    $search.Margin = '0,3,0,13'
    $search.MaxWidth = 390
    $search.HorizontalAlignment = 'Stretch'
    $search.Add_TextChanged({ param($Sender, $EventArgs) $script:searchTerm = $Sender.Text; Update-TweakCards })
    Add-PageItem (New-UText 'Buscar ajustes' 12 $script:color.Muted 'SemiBold')
    $searchHost = [Windows.Controls.DockPanel]::new()
    $searchHost.HorizontalAlignment = 'Left'
    $searchHost.Width = 380
    [void]$searchHost.Children.Add($search)
    Add-PageItem $searchHost
    $chips = [Windows.Controls.WrapPanel]::new()
    $script:filterButtons = @{}
    foreach ($category in 'Todos','Destaques','Jogos','Auto','Windows','GPU','Entrada','Rede','Debloat','Hardware','Fortnite') {
        $key = $category
        $choose = { Select-TweakFilter $key }.GetNewClosure()
        $button = New-UButton $script:categoryLabels[$key] 'ChipButton' $choose
        $button.Margin = '0,0,7,6'
        $script:filterButtons[$key] = $button
        [void]$chips.Children.Add($button)
    }
    Add-PageItem $chips
    $script:tweakResults = New-UText '' 12 $script:color.Muted
    $script:tweakResults.Margin = '0,6,0,10'
    Add-PageItem $script:tweakResults
    $script:tweakGrid = New-UGrid 2
    Add-PageItem $script:tweakGrid
    Select-TweakFilter $script:filter
}

function Invoke-PCScan {
    Start-OptimizerWork 'Scan' $null 'Consultando o hardware e o Windows…' {
        param($Result)
        if ($Result.Count -ne 1) { throw 'O scanner não retornou um relatório completo.' }
        $script:scan = $Result[0]
        Set-OptimizerStatus 'Verificação concluída.'
        if ($script:page -in @('Scanner do PC', 'Visão geral')) { Show-OptimizerPage $script:page -KeepScroll }
    }
}

function Copy-OptimizerScan {
    $report = [Collections.Generic.List[string]]::new()
    $report.Add('PrismaFrame — Scanner do PC')
    foreach ($group in $script:scan.Groups) {
        $report.Add(''); $report.Add($group.Title)
        foreach ($item in $group.Items) { $report.Add("$($item.Label) — $($item.Value)") }
    }
    foreach ($warning in $script:scan.Warnings) { $report.Add($warning) }
    try {
        [Windows.Clipboard]::SetText(($report -join [Environment]::NewLine))
        Set-OptimizerStatus 'Relatório copiado para a área de transferência.'
    } catch { [void](Show-OptimizerDialog 'Não foi possível copiar' $_.Exception.Message) }
}

function Open-RecommendedTweak([string]$Id) {
    $tweak = $script:Tweaks | Where-Object Id -eq $Id | Select-Object -First 1
    if ($tweak) { Show-TweakDetails $tweak }
}

function Add-ProfileRecommendations($Profile) {
    $recommendations = @(Get-GameRecommendations $Profile)
    if (-not $recommendations.Count) { return }
    Add-PageSection 'Ajustes para este PC' 'Personalize um jogo por vez a partir do seu hardware'
    $cards = New-UGrid 2
    foreach ($item in $recommendations) {
        $column = New-UPanel
        $title = New-UText $item.Title 16 $script:color.Text 'SemiBold'
        $title.Margin = '0,0,0,5'
        [void]$column.Children.Add($title)
        [void]$column.Children.Add((New-UText $item.Reason 13 $script:color.Muted))
        if ($item.Id -in $script:Tweaks.Id) {
            $tweakId = $item.Id
            $open = { Open-RecommendedTweak $tweakId }.GetNewClosure()
            $label = if ($script:automationDefinitions.ContainsKey($tweakId)) { 'Revisar e aplicar' } else { 'Ver instruções' }
            $action = New-UButton $label 'ChipButton' $open
            [Windows.Automation.AutomationProperties]::SetName($action, "$label · $($item.Title)")
            $action.HorizontalAlignment = 'Left'
            $action.Margin = '0,10,0,0'
            [void]$column.Children.Add($action)
        }
        Add-UGridItem $cards (New-UCard $column)
    }
    Add-PageItem $cards
}

function Select-ScannerTab([string]$Tab) {
    $script:scannerTab = $Tab
    Show-OptimizerPage 'Scanner do PC'
}

function Show-ScannerPage {
    Add-PageIntro 'Scanner do PC' 'Veja o hardware detectado pelo Windows e os ajustes sugeridos para os seus jogos.'
    $actions = New-UPanel -Horizontal
    $label = if ($script:scan) { 'Escanear novamente' } else { 'Escanear meu PC' }
    $scanButton = New-UButton $label 'PrimaryButton' { Invoke-PCScan }
    $scanButton.Margin = '0,0,8,0'
    [void]$actions.Children.Add($scanButton)
    if ($script:scan) { [void]$actions.Children.Add((New-UButton 'Copiar relatório' 'BaseButton' { Copy-OptimizerScan })) }
    Add-PageItem $actions
    if (-not $script:scan) {
        $empty = New-UCard (New-UText 'O relatório inclui processador, GPU e VRAM, módulos de RAM, unidades, telas, rede e versão do Windows.' 14 $script:color.Muted)
        $empty.Margin = '0,18,0,0'
        Add-PageItem $empty
        return
    }
    $tabs = New-UPanel -Horizontal
    $tabs.Margin = '0,15,0,0'
    $profileStyle = if ($script:scannerTab -eq 'Perfil') { 'PrimaryButton' } else { 'BaseButton' }
    $specStyle = if ($script:scannerTab -eq 'Especificações') { 'PrimaryButton' } else { 'BaseButton' }
    $profileTab = New-UButton 'Perfil para jogos' $profileStyle { Select-ScannerTab 'Perfil' }
    $profileTab.Margin = '0,0,8,0'
    [void]$tabs.Children.Add($profileTab)
    [void]$tabs.Children.Add((New-UButton 'Especificações' $specStyle { Select-ScannerTab 'Especificações' }))
    Add-PageItem $tabs
    if ($script:scannerTab -eq 'Perfil') { Add-ProfileRecommendations $script:scan.Profile; return }
    Add-PageSection 'Hardware detectado' 'Dados reportados pelo Windows e pelos drivers'
    foreach ($warning in $script:scan.Warnings) { Add-PageItem (New-UText $warning 13 $script:color.Warm) }
    $cards = New-UGrid 2
    foreach ($group in $script:scan.Groups) {
        $column = New-UPanel
        $title = New-UText $group.Title 17 $script:color.Accent 'SemiBold'
        $title.Margin = '0,0,0,8'
        [void]$column.Children.Add($title)
        foreach ($item in $group.Items) {
            $labelText = New-UText $item.Label 11 $script:color.Muted 'SemiBold'
            $labelText.Margin = '0,5,0,0'
            [void]$column.Children.Add($labelText)
            [void]$column.Children.Add((New-UText $item.Value 13))
        }
        Add-UGridItem $cards (New-UCard $column)
    }
    Add-PageItem $cards
}

function Format-CleanupSize([long]$Size) {
    $culture = [Globalization.CultureInfo]::GetCultureInfo('pt-BR')
    if ($Size -ge 1GB) { return ([double]($Size / 1GB)).ToString('0.##', $culture) + ' GiB' }
    if ($Size -ge 1MB) { return ([double]($Size / 1MB)).ToString('0.##', $culture) + ' MiB' }
    if ($Size -ge 1KB) { return ([double]($Size / 1KB)).ToString('0.##', $culture) + ' KiB' }
    "$Size bytes"
}

function Format-CleanupCount([int]$Count) {
    if ($Count -eq 1) { return '1 arquivo' }
    "$Count arquivos"
}

function Change-CleanupFlag($Sender) {
    $new = [bool]$Sender.IsChecked
    if ($script:cleanupFlags[$Sender.Tag] -eq $new) { return }
    $script:cleanupFlags[$Sender.Tag] = $new
    $script:preview = $null
    $script:previewSignature = ''
    if ($script:cleanupDetails) { $script:cleanupDetails.Children.Clear() }
    Set-OptimizerStatus 'Seleção alterada. Analise os arquivos para atualizar a prévia.'
}

function Get-CleanupSelection { $script:cleanupFlags.Keys | Where-Object { $script:cleanupFlags[$_] } | Sort-Object }

function Invoke-CleanupPreviewUI {
    $selection = @(Get-CleanupSelection)
    if (-not $selection.Count) { Set-OptimizerStatus 'Selecione pelo menos uma categoria.' -Problem; return }
    $signature = $selection -join '|'
    $complete = {
        param($Result)
        Complete-CleanupPreviewUI $Result $signature
    }.GetNewClosure()
    Start-OptimizerWork 'Preview' $selection 'Inspecionando arquivos elegíveis…' $complete
}

function Complete-CleanupPreviewUI($Result, [string]$Signature) {
    if ($Signature -ne (@(Get-CleanupSelection) -join '|')) { Set-OptimizerStatus 'A seleção mudou durante a análise. Gere uma nova prévia.'; return }
    if ($Result.Count -ne 1) { throw 'A análise não retornou os resultados esperados.' }
    $script:preview = $Result[0]
    $script:previewSignature = $Signature
    Set-OptimizerStatus 'Prévia pronta para revisão.'
    if ($script:page -eq 'Limpeza') { Show-CleanupResult }
}

function Invoke-CleanupUI {
    if ($script:work -or -not $script:preview -or -not $script:preview.Count) { return }
    if ($script:previewSignature -ne (@(Get-CleanupSelection) -join '|')) { return }
    $current = $script:preview
    $size = Format-CleanupSize $current.Bytes
    if (-not (Show-OptimizerDialog 'Confirmar limpeza' "$(Format-CleanupCount $current.Count) para excluir · até $size. A exclusão é permanente. Arquivos que mudaram ou estão em uso serão ignorados." 'Excluir arquivos' -Confirm)) { return }
    Start-OptimizerWork 'Clean' $current 'Revalidando e removendo os arquivos…' {
        param($Result)
        $item = $Result[0]
        $script:preview = $null
        $script:previewSignature = ''
        if ($script:page -eq 'Limpeza') { Show-CleanupResult }
        $size = Format-CleanupSize $item.RemovedBytes
        $message = "Exclusão de $(Format-CleanupCount $item.RemovedCount) · $size de espaço recuperado · $($item.SkippedCount) no total ignorados."
        Set-OptimizerStatus $message
        if ($item.Errors.Count) { $message += "`n`n" + ($item.Errors -join "`n") }
        [void](Show-OptimizerDialog 'Limpeza concluída' $message)
    }
}

function Show-CleanupResult {
    $script:cleanupDetails.Children.Clear()
    if (-not $script:preview) { return }
    $column = New-UPanel
    $item = $script:preview
    $title = New-UText "$(Format-CleanupSize $item.Bytes) recuperáveis" 20 $script:color.Accent 'SemiBold'
    $title.Margin = '0,0,0,6'
    [void]$column.Children.Add($title)
    foreach ($entry in $item.PerCategory) {
        [void]$column.Children.Add((New-UText "$($entry.Title) · $(Format-CleanupCount $entry.Count) · $(Format-CleanupSize $entry.Bytes)" 13 $script:color.Muted))
    }
    foreach ($warning in $item.Warnings) { [void]$column.Children.Add((New-UText $warning 13 $script:color.Warm)) }
    $go = New-UButton 'Revisar e excluir' 'PrimaryButton' { Invoke-CleanupUI }
    $go.Margin = '0,13,0,0'
    $go.HorizontalAlignment = 'Left'
    $go.IsEnabled = $item.Count -gt 0
    [void]$column.Children.Add($go)
    $card = New-UCard $column '#10202D'
    $card.BorderBrush = Get-UBrush '#325275'
    [void]$script:cleanupDetails.Children.Add($card)
}

function Show-CleanupPage {
    Add-PageIntro 'Limpeza do sistema' 'Libere espaço com arquivos temporários e registros antigos. Confira a prévia antes de excluir.'
    $button = New-UButton 'Analisar arquivos' 'PrimaryButton' { Invoke-CleanupPreviewUI }
    $button.HorizontalAlignment = 'Left'
    Add-PageItem $button
    $script:cleanupDetails = New-UPanel
    $script:cleanupDetails.Margin = '0,16,0,0'
    Add-PageItem $script:cleanupDetails
    Show-CleanupResult
    Add-PageSection 'Categorias de limpeza' 'Selecione os tipos de arquivo que deseja analisar'
    foreach ($item in Get-CleanupCategories) {
        if (-not $script:cleanupFlags.ContainsKey($item.Id)) { $script:cleanupFlags[$item.Id] = $item.Default }
        $column = New-UPanel
        $check = [Windows.Controls.CheckBox]::new()
        $check.Content = $item.Title
        $check.FontSize = 14
        $check.FontWeight = 'SemiBold'
        $check.Tag = $item.Id
        $check.IsChecked = $script:cleanupFlags[$item.Id]
        $check.Add_Checked({ param($Sender, $EventArgs) Change-CleanupFlag $Sender })
        $check.Add_Unchecked({ param($Sender, $EventArgs) Change-CleanupFlag $Sender })
        [void]$column.Children.Add($check)
        $copy = New-UText $item.Description 13 $script:color.Muted
        $copy.Margin = '19,4,0,0'
        [void]$column.Children.Add($copy)
        $card = New-UCard $column $script:color.Panel 12
        $card.Margin = '0,0,0,8'
        Add-PageItem $card
    }
}

function Open-OptimizerSystemTool([string]$Name) {
    try { Start-Process -FilePath (Join-Path ([Environment]::SystemDirectory) $Name) -ErrorAction Stop }
    catch { [void](Show-OptimizerDialog 'Não foi possível abrir' $_.Exception.Message) }
}

function Open-OptimizerAsAdmin {
    if ($script:work) { Set-OptimizerStatus 'Aguarde a operação em andamento.'; return }
    try {
        if ($script:prismaRuntime) {
            Start-Process -FilePath $script:prismaRuntime.ExecutablePath -Verb RunAs -ArgumentList '--recovery' -ErrorAction Stop
        } else {
            $exe = Join-Path $PSHOME 'powershell.exe'
            $scriptPath = Join-Path $script:appRoot 'PrismaFrame.ps1'
            Start-Process -FilePath $exe -Verb RunAs -WindowStyle Hidden -ArgumentList "-NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File `"$scriptPath`" -OpenRecovery" -ErrorAction Stop
        }
        $script:window.Close()
    } catch { Set-OptimizerStatus 'A elevação foi cancelada ou o Windows não concedeu acesso.' -Problem }
}

function Invoke-RestoreListUI {
    Start-OptimizerWork 'RestoreList' $null 'Consultando pontos de restauração…' {
        param($Result)
        $script:restorePoints = @($Result)
        $script:restoreRead = $true
        $script:restoreError = ''
        Set-OptimizerStatus "$($script:restorePoints.Count) pontos listados pelo Windows."
        if ($script:page -eq 'Recuperação') { Show-OptimizerPage 'Recuperação' -KeepScroll }
    }
}

function Invoke-NewRestoreUI {
    if ($script:work) { Set-OptimizerStatus 'Aguarde a operação em andamento.'; return }
    if (-not (Show-OptimizerDialog 'Criar ponto de restauração' 'O Windows fará um checkpoint de arquivos e configurações do sistema. A Proteção do Sistema deve estar ativa na unidade do Windows.' 'Criar ponto' -Confirm)) { return }
    Start-OptimizerWork 'RestoreNew' $null 'Pedindo ao Windows para criar um ponto…' {
        param($Result)
        if ($Result.Count -ne 1) { throw 'O Windows não confirmou a criação de um ponto.' }
        $point = $Result[0]
        $script:restorePoints = @($point) + @($script:restorePoints | Where-Object SequenceNumber -ne $point.SequenceNumber)
        $script:restoreRead = $true
        $script:restoreError = ''
        Set-OptimizerStatus "Ponto de restauração confirmado pelo Windows · $($point.Description)."
        if ($script:page -eq 'Recuperação') { Show-OptimizerPage 'Recuperação' -KeepScroll }
    }
}

function Invoke-RestoreBackupUI([string]$Token, [string]$Title) {
    if ($script:work) { Set-OptimizerStatus 'Aguarde a operação em andamento.'; return }
    if (-not (Show-OptimizerDialog 'Desfazer ajuste' "O PrismaFrame vai restaurar a configuração salva antes de aplicar “$Title”." 'Restaurar configuração' -Confirm)) { return }
    Start-OptimizerWork 'Undo' $Token 'Restaurando e verificando a configuração…' {
        param($Result)
        Set-OptimizerStatus ([string]$Result[0])
        if ($script:page -eq 'Recuperação') { Show-OptimizerPage 'Recuperação' -KeepScroll }
    }
}

function Show-RecoveryPage {
    Add-PageIntro 'Recuperação' 'Crie pontos de restauração do Windows e desfaça os ajustes automáticos pelo histórico local.'
    $content = New-UPanel
    [void]$content.Children.Add((New-UText 'Proteção do Sistema' 18 $script:color.Accent 'SemiBold'))
    $guidance = if ($script:isAdmin) { 'Confira se a proteção da unidade do Windows está ativa. O Windows normalmente aceita um novo ponto por dia.' }
        else { 'Abra o PrismaFrame como administrador para criar ou listar pontos do Windows.' }
    $paragraph = New-UText $guidance 13 $script:color.Muted
    $paragraph.Margin = '0,6,0,13'
    [void]$content.Children.Add($paragraph)
    $buttons = [Windows.Controls.WrapPanel]::new()
    if ($script:isAdmin) {
        $create = New-UButton 'Criar ponto' 'PrimaryButton' { Invoke-NewRestoreUI }
        $create.Margin = '0,0,8,6'
        [void]$buttons.Children.Add($create)
        $list = New-UButton 'Listar pontos' 'BaseButton' { Invoke-RestoreListUI }
        $list.Margin = '0,0,8,6'
        [void]$buttons.Children.Add($list)
    } else {
        $admin = New-UButton 'Reabrir como administrador' 'PrimaryButton' { Open-OptimizerAsAdmin }
        $admin.Margin = '0,0,8,6'
        [void]$buttons.Children.Add($admin)
    }
    $protection = New-UButton 'Abrir Proteção do Sistema' 'BaseButton' { Open-OptimizerSystemTool 'SystemPropertiesProtection.exe' }
    $protection.Margin = '0,0,8,6'
    [void]$buttons.Children.Add($protection)
    $restore = New-UButton 'Abrir Restauração do Sistema' 'BaseButton' { Open-OptimizerSystemTool 'rstrui.exe' }
    $restore.Margin = '0,0,8,6'
    [void]$buttons.Children.Add($restore)
    [void]$content.Children.Add($buttons)
    if ($script:restoreError) {
        $problem = New-UText $script:restoreError 13 $script:color.Bad
        $problem.Margin = '0,8,0,0'
        [void]$content.Children.Add($problem)
    }
    if ($script:restoreRead) {
        if (-not $script:restorePoints.Count) { [void]$content.Children.Add((New-UText 'O Windows não listou pontos de restauração.' 13 $script:color.Muted)) }
        foreach ($point in $script:restorePoints) {
            $time = if ($point.CreationTime -is [DateTime]) { $point.CreationTime.ToString('dd/MM/yyyy HH:mm') } else { [string]$point.CreationTime }
            $line = New-UText "$time · $($point.Description)" 13 $script:color.Text
            $line.Margin = '0,5,0,0'
            [void]$content.Children.Add($line)
        }
    }
    Add-PageItem (New-UCard $content)
    Add-PageSection 'Histórico de ajustes automáticos'
    $backups = @(Get-OptimizerBackups)
    if (-not $backups.Count) { Add-PageItem (New-UCard (New-UText 'Os backups aparecem aqui após a primeira alteração automática.' 14 $script:color.Muted)); return }
    foreach ($backup in $backups) {
        $row = [Windows.Controls.DockPanel]::new()
        if ($backup.Status -in @('Aplicado', 'Pendente')) {
            $token = $backup.Token
            $title = $backup.Title
            $handler = { Invoke-RestoreBackupUI $token $title }.GetNewClosure()
            $undoButton = New-UButton 'Desfazer' 'ChipButton' $handler
            $undoButton.Margin = '12,0,0,0'
            $undoButton.VerticalAlignment = 'Center'
            [Windows.Controls.DockPanel]::SetDock($undoButton, 'Right')
            [void]$row.Children.Add($undoButton)
        }
        $details = New-UPanel
        $time = ([DateTimeOffset]::Parse($backup.TimeUtc)).ToLocalTime().ToString('dd/MM/yyyy HH:mm')
        [void]$details.Children.Add((New-UText $backup.Title 15 $script:color.Text 'SemiBold'))
        [void]$details.Children.Add((New-UText "$time · $($backup.Status)" 12 $script:color.Muted))
        if ($backup.Options) {
            $subject = if ($backup.Options.Executable) { $backup.Options.Executable } else { $backup.Options.ConfigPath }
            if ($subject) { [void]$details.Children.Add((New-UText $subject 11 $script:color.Muted)) }
        }
        [void]$row.Children.Add($details)
        $card = New-UCard $row $script:color.Panel 12
        $card.Margin = '0,0,0,8'
        Add-PageItem $card
    }
}

function Show-ReferencesPage {
    Add-PageIntro 'Referências' 'Documentação oficial sobre as opções do jogo, do driver e do Windows.'
    $links = New-UGrid 2
    foreach ($source in $script:Sources) {
        $address = $source.Url
        $open = { Open-OptimizerTarget $address }.GetNewClosure()
        $button = New-UButton $source.Label 'BaseButton' $open
        $button.HorizontalContentAlignment = 'Left'
        $button.ToolTip = $address
        Add-UGridItem $links $button
    }
    Add-PageItem $links
}

function Show-OptimizerPage([string]$Name, [switch]$KeepScroll) {
    $offset = if ($KeepScroll -and $script:page -eq $Name) { $script:ui.PageScroll.VerticalOffset } else { 0 }
    $script:page = $Name
    $script:ui.PageCaption.Text = $Name
    foreach ($key in $script:nav.Keys) {
        $button = $script:nav[$key]
        $button.Background = Get-UBrush $(if ($key -eq $Name) { '#14273B' } else { '#000C101A' })
        $button.BorderBrush = Get-UBrush $(if ($key -eq $Name) { '#366485' } else { '#000C101A' })
        $button.Foreground = Get-UBrush $(if ($key -eq $Name) { '#9BF3FF' } else { '#AFBCCF' })
    }
    $script:ui.PageBody.Children.Clear()
    switch ($Name) {
        'Visão geral' { Show-HomePage }
        'Ajustes' { Show-TweaksPage }
        'Scanner do PC' { Show-ScannerPage }
        'Limpeza' { Show-CleanupPage }
        'Recuperação' { Show-RecoveryPage }
        'Referências' { Show-ReferencesPage }
    }
    $script:ui.PageScroll.ScrollToVerticalOffset($offset)
}

function Open-OptimizerDestination([string]$Name) {
    if ($Name -eq 'Ajustes') { $script:filter = 'Todos'; $script:searchTerm = '' }
    Show-OptimizerPage $Name
}

foreach ($route in @(
    @{ Name='Visão geral'; Icon='home' }, @{ Name='Ajustes'; Icon='tune' }, @{ Name='Scanner do PC'; Icon='scan' },
    @{ Name='Limpeza'; Icon='clean' }, @{ Name='Recuperação'; Icon='shield' }, @{ Name='Referências'; Icon='book' }
)) {
    $destination = $route.Name
    $click = { Open-OptimizerDestination $destination }.GetNewClosure()
    $button = New-UButton $route.Name 'NavButton' $click $route.Icon
    $button.Margin = '0,0,0,5'
    $script:nav[$route.Name] = $button
    $slot = if ($route.Name -eq 'Referências') { $script:ui.SecondaryNav } else { $script:ui.Navigation }
    [void]$slot.Children.Add($button)
}

$script:window.Add_Closing({
    param($Sender, $EventArgs)
    if ($script:work) {
        $EventArgs.Cancel = $true
        Set-OptimizerStatus 'Aguarde a conclusão da operação antes de fechar.'
    }
})

function Write-OptimizerCapture([string]$Name) {
    if (-not $CaptureDirectory) { return }
    $root = [Windows.FrameworkElement]$script:window.Content
    $root.UpdateLayout()
    $width = [int][Math]::Ceiling($root.ActualWidth)
    $height = [int][Math]::Ceiling($root.ActualHeight)
    $bitmap = [Windows.Media.Imaging.RenderTargetBitmap]::new($width, $height, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($root)
    $png = [Windows.Media.Imaging.PngBitmapEncoder]::new()
    $png.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream = [IO.File]::Create((Join-Path $CaptureDirectory ($Name + '.png')))
    try { $png.Save($stream) } finally { $stream.Dispose() }
}

function Wait-OptimizerSelfTestWork {
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    while ($script:work -and [DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 100
        Complete-OptimizerWork
    }
    if ($script:work) { throw 'A operação de teste excedeu 60 segundos.' }
}

if ($SelfTest) {
    $generalCount = @($script:Tweaks | Where-Object Category -ne 'Fortnite').Count
    $generalAutomatic = @($script:Tweaks | Where-Object { $_.Category -ne 'Fortnite' -and $_.Mode -eq 'Auto' }).Count
    if ($script:automationDefinitions.Count * 2 -le $script:Tweaks.Count -or $generalAutomatic * 2 -le $generalCount) {
        throw 'A biblioteca deve ter maioria automática, incluindo a seleção sem Fortnite.'
    }
    if (@($script:Tweaks.Id | Sort-Object -Unique).Count -ne $script:Tweaks.Count) { throw 'Há IDs duplicados na biblioteca.' }
    if ($script:automationDefinitions.gamegpu.Input -ne 'Executable' -or $script:automationDefinitions.gamefpscap.Input -ne 'GameConfigFps' -or
        $script:automationDefinitions.nvfpscap.Input -ne 'ExecutableFps') { throw 'Faltam controles de seleção de jogo em ajustes automáticos.' }
    Show-OptimizerPage 'Visão geral'
    $script:window.Show()
    try {
        Write-OptimizerCapture '01-visao-geral'
        $clickArgs = [Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent)
        $script:nav['Referências'].RaiseEvent($clickArgs)
        if ($script:page -ne 'Referências') { throw 'O menu não abriu a página selecionada.' }
        $script:filter = 'Jogos'
        Show-OptimizerPage 'Ajustes'
        Write-OptimizerCapture '02-ajustes'
        if ($script:tweakGrid.Children.Count -lt 15) { throw 'Filtro de jogos incompleto.' }
        Select-TweakFilter 'Auto'
        if ($script:tweakGrid.Children.Count -ne $script:automationDefinitions.Count) { throw 'Filtro de ajustes automáticos incompleto.' }
        Write-OptimizerCapture '07-automaticos'
        $script:filter = 'Fortnite'
        Show-OptimizerPage 'Ajustes'
        if ($script:tweakGrid.Children.Count -lt 8) { throw 'Filtro Fortnite incompleto.' }
        $script:searchTerm = 'reflex'
        Update-TweakCards
        if ($script:tweakGrid.Children.Count -lt 1) { throw 'Pesquisa sem resultados.' }
        Show-OptimizerPage 'Scanner do PC'
        Invoke-PCScan
        Wait-OptimizerSelfTestWork
        if (-not $script:scan.Groups.Count) { throw 'Scanner sem grupos.' }
        $currentRecommendations = @(Get-GameRecommendations $script:scan.Profile)
        if (-not $currentRecommendations.Count) { throw 'Perfil de jogos ausente.' }
        if (@($currentRecommendations | Where-Object Id -notin $script:Tweaks.Id).Count) { throw 'Referência de ajuste inválida no perfil de jogos.' }
        $amdProfile = [pscustomobject]@{ GPUVendor = 'AMD'; GpuCount = 1; PrimaryHz = 165; VRAMGiB = 12; RAMGiB = 32; CPUCores = 8; PrimaryWidth = 2560; PrimaryHeight = 1440 }
        $amdRecommendations = @(Get-GameRecommendations $amdProfile)
        if (-not ($amdRecommendations.Title -match '165 Hz') -or -not ($amdRecommendations.Title -match 'Radeon') -or 'gamesuperres' -notin $amdRecommendations.Id) { throw 'O perfil de outra GPU e tela não se ajustou.' }
        $unknownProfile = [pscustomobject]@{ GpuCount = 2 }
        if (-not ((@(Get-GameRecommendations $unknownProfile)).Title -match 'qual GPU')) { throw 'O perfil com múltiplas GPUs não orientou sobre o adaptador.' }
        Write-OptimizerCapture '03-scanner'
        Select-ScannerTab 'Especificações'
        Write-OptimizerCapture '06-especificacoes'
        Show-OptimizerPage 'Limpeza'
        Invoke-CleanupPreviewUI
        Wait-OptimizerSelfTestWork
        if ($null -eq $script:preview) { throw 'Prévia de limpeza ausente.' }
        Write-OptimizerCapture '04-limpeza'
        if ($EmbeddedRuntime) {
            $unrecognized = [pscustomobject]@{ Id = 'self-test'; Title = 'Autoteste'; Options = [pscustomobject]@{} }
            Start-OptimizerWork 'Apply' $unrecognized 'Validando o módulo integrado…' {}
            try { Wait-OptimizerSelfTestWork; throw 'O módulo aceitou um ajuste inexistente.' }
            catch { if ($_.Exception.Message -notmatch 'Ajuste automático desconhecido') { throw } }
        }
        Show-OptimizerPage 'Recuperação'
        Write-OptimizerCapture '05-recuperacao'
        Show-OptimizerPage 'Referências'
        if ($script:Sources.Count -lt 8) { throw 'Referências ausentes.' }
        Show-OptimizerPage 'Visão geral'
        Set-OptimizerStatus 'Verificação concluída.'
        Write-OptimizerCapture '01-visao-geral'
        "OK: $($script:automationDefinitions.Count)/$($script:Tweaks.Count) automáticos; $generalAutomatic/$generalCount fora do Fortnite; $($script:scan.Groups.Count) grupos de hardware."
    } finally { $script:window.Close() }
} else {
    Show-OptimizerPage $(if ($OpenRecovery) { 'Recuperação' } else { 'Visão geral' })
    if (-not $OpenRecovery) {
        $script:window.Add_ContentRendered({ if (-not $script:scan -and -not $script:work) { Invoke-PCScan } })
    }
    [void]$script:window.ShowDialog()
}
