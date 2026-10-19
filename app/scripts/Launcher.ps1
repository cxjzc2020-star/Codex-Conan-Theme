[CmdletBinding()]
param([switch]$Preview, [switch]$Launch, [string]$SmokePath, [double]$SmokeSeconds = 1.2, [string]$PreviewResultPath)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Core.ps1')
. (Join-Path $PSScriptRoot 'Media.ps1')

function Start-ConanWorker {
    param([string]$Action)
    if ($ui.worker -and -not $ui.worker.HasExited) { throw '正在处理上一个操作，请稍后。' }
    $ui.resultPath = Join-Path $script:ConanStateRoot ('operation-' + [guid]::NewGuid().ToString('N') + '.json')
    Write-ConanStatus $ui.resultPath 'working' '正在处理…'
    $workerScript = Join-Path $PSScriptRoot 'Theme.ps1'
    $arguments = '-NoProfile -STA -ExecutionPolicy RemoteSigned -File "' + $workerScript + '" -Action ' + $Action + ' -ResultPath "' + $ui.resultPath + '"'
    $ui.worker = Start-Process -FilePath (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') `
        -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if ($ui.status) { $ui.status.Text = '正在处理…'; $ui.status.Foreground = '#AABBD1' }
}

try {
    $settings = Read-ConanSettings
    if ($Preview) {
        $result = Show-ConanIntro -Settings $settings -CapturePath $SmokePath -TestSeconds $(if ($SmokePath -or $PreviewResultPath) { $SmokeSeconds } else { 0 })
        if ($PreviewResultPath) { Write-ConanJson $PreviewResultPath $result }
        exit 0
    }
    $ui = @{ worker=$null; resultPath=$null; status=$null }
    if ($Launch) {
        Start-ConanWorker 'Start'
        $ui.worker.WaitForExit()
        $launchResult = Get-ConanOperationResult -Path $ui.resultPath -HasExited $true -ExitCode $ui.worker.ExitCode
        if ($launchResult.state -eq 'error') { [void][Windows.MessageBox]::Show($launchResult.message,'Codex · 柯南之夜'); exit 1 }
        exit 0
    }
    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Codex · 柯南之夜" Width="1040" Height="740" MinWidth="840" MinHeight="680"
        WindowStartupLocation="CenterScreen" Background="#081426" Foreground="#EFF5FF" FontFamily="Microsoft YaHei UI">
  <Window.Resources>
    <Style TargetType="Button">
      <Setter Property="Background" Value="#172F4B"/><Setter Property="Foreground" Value="#EFF5FF"/>
      <Setter Property="BorderBrush" Value="#304763"/><Setter Property="Padding" Value="16,10"/>
      <Setter Property="Cursor" Value="Hand"/><Setter Property="Margin" Value="0,0,8,0"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <Border x:Name="ButtonSurface" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="7" Padding="{TemplateBinding Padding}">
          <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
        </Border><ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ButtonSurface" Property="Opacity" Value="0.8"/></Trigger>
          <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="ButtonSurface" Property="BorderBrush" Value="#E54D61"/></Trigger>
          <Trigger Property="IsEnabled" Value="False"><Setter TargetName="ButtonSurface" Property="Opacity" Value="0.45"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style TargetType="TextBox"><Setter Property="Background" Value="#0A192D"/><Setter Property="Foreground" Value="#C5D5E8"/>
      <Setter Property="BorderBrush" Value="#263D59"/><Setter Property="Padding" Value="10"/><Setter Property="Margin" Value="0,12,0,14"/>
    </Style>
    <Style TargetType="CheckBox"><Setter Property="Foreground" Value="#C5D5E8"/><Setter Property="Margin" Value="0,8,20,0"/></Style>
  </Window.Resources>
  <Grid Background="#081426">
    <Grid.ColumnDefinitions><ColumnDefinition Width="260"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
    <Border BorderBrush="#263D59" BorderThickness="0,0,1,0">
      <Grid Margin="28,38">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
        <StackPanel>
          <TextBlock Text="C O N A N" FontSize="29" FontWeight="Light"/>
          <TextBlock Text="N I G H T   E D I T I O N" FontSize="10" Foreground="#79BCDF" Margin="0,12,0,0"/>
          <Border Height="3" Width="34" Background="#E54D61" HorizontalAlignment="Left" Margin="0,28,0,26"/>
          <TextBlock Text="让每次出发，&#x0a;都有一点仪式感。" FontSize="20" LineHeight="34"/>
        </StackPanel>
        <StackPanel Grid.Row="1" VerticalAlignment="Center">
          <Image x:Name="ThemeArtwork" Height="110" Stretch="UniformToFill" Margin="0,0,0,24"/>
          <TextBlock Text="01   播放开场" Foreground="#EFF5FF" FontSize="13" Margin="0,0,0,18"/>
          <TextBlock Text="02   打开 Codex" Foreground="#AABBD1" FontSize="13" Margin="0,0,0,18"/>
          <TextBlock Text="03   进入深蓝之夜" Foreground="#AABBD1" FontSize="13"/>
        </StackPanel>
        <TextBlock Grid.Row="2" Text="本地素材 · 应用内开场&#x0a;基于开源社区壁纸引擎" Foreground="#7890AB" FontSize="11" LineHeight="22"/>
      </Grid>
    </Border>
    <ScrollViewer Grid.Column="1" VerticalScrollBarVisibility="Auto">
      <StackPanel Margin="32,30,32,24">
        <TextBlock Text="布置你的工作序幕" FontSize="25" FontWeight="SemiBold"/>
        <TextBlock Text="选一段开场，再选一张壁纸。它们可以分别更换。" Foreground="#AABBD1" Margin="0,9,0,24"/>
        <Border Background="#10213A" CornerRadius="12" BorderBrush="#263D59" BorderThickness="1" Padding="20" Margin="0,0,0,16">
          <StackPanel>
            <TextBlock Text="启动开场" FontSize="16" FontWeight="SemiBold"/>
            <TextBlock Text="MP4 视频 / GIF 动图 · 默认静音 · Esc 可跳过" Foreground="#AABBD1" FontSize="11" Margin="0,7,0,0"/>
            <TextBox x:Name="IntroPath" IsReadOnly="True" ToolTip="本地开场素材路径"/>
            <WrapPanel>
              <Button x:Name="PickIntro" Content="选择开场素材"/><Button x:Name="PreviewIntro" Content="播放预览"/><Button x:Name="ClearIntro" Content="清空"/>
            </WrapPanel>
            <WrapPanel Margin="0,6,0,0"><CheckBox x:Name="IntroEnabled" Content="启用开场"/><CheckBox x:Name="Muted" Content="静音"/>
              <TextBlock Text="最长秒数" VerticalAlignment="Center" Foreground="#AABBD1" Margin="0,8,8,0"/>
              <TextBox x:Name="MaxSeconds" Width="48" Text="6" Margin="0,8,0,0" Padding="5,2" ToolTip="1 到 30 秒；视频提前结束时会自动关闭"/>
            </WrapPanel>
          </StackPanel>
        </Border>
        <Border Background="#10213A" CornerRadius="12" BorderBrush="#263D59" BorderThickness="1" Padding="20" Margin="0,0,0,18">
          <StackPanel>
            <TextBlock Text="界面壁纸" FontSize="16" FontWeight="SemiBold"/>
            <TextBlock Text="PNG / JPEG / WebP 图片，或静音循环的 MP4 / WebM 视频" TextWrapping="Wrap" Foreground="#AABBD1" FontSize="11" Margin="0,7,0,0"/>
            <TextBox x:Name="WallpaperPath" IsReadOnly="True" ToolTip="本地壁纸素材路径"/>
            <WrapPanel><Button x:Name="PickWallpaper" Content="选择界面壁纸"/><Button x:Name="ClearWallpaper" Content="清空"/><Button x:Name="ResetMedia" Content="恢复内置素材"/></WrapPanel>
          </StackPanel>
        </Border>
        <CheckBox x:Name="UseSystemProxy" Content="网络兼容：让聊天连接使用 Windows 已启用的本机代理"/>
        <TextBlock Text="仅在首次聊天反复重连且正在使用本机代理时开启；完全退出 Codex 后生效。" TextWrapping="Wrap" Foreground="#AABBD1" FontSize="11" Margin="0,0,0,12"/>
        <TextBlock Text="首次启用壁纸：先保存工作并完全退出 Codex，再从这里启动。独立配置可能需要重新登录；进入应用后请切换到 Codex 模式。" TextWrapping="Wrap" Foreground="#B4C5DA" FontSize="11" LineHeight="20" Margin="0,0,0,16"/>
        <WrapPanel Margin="0,0,0,14">
          <Button x:Name="StartCodex" Content="启动 · 柯南之夜" Background="#BD3D51" BorderBrush="#E54D61" FontWeight="SemiBold"/>
          <Button x:Name="PlainCodex" Content="普通打开 Codex"/><Button x:Name="Restore" Content="暂停壁纸"/>
        </WrapPanel>
        <TextBlock x:Name="Status" Text="已附带柯南壁纸与开场视频。可直接预览，也可选择自己的素材。" TextWrapping="Wrap" Foreground="#AABBD1" FontSize="11" LineHeight="20"/>
      </StackPanel>
    </ScrollViewer>
  </Grid>
</Window>
'@
    $window = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader($xaml)))
    $window.Height = [Math]::Min(740, [Windows.SystemParameters]::WorkArea.Height - 40)
    $window.MinHeight = [Math]::Min(680, $window.Height)
    $controls = @{}
    foreach ($name in @('IntroPath','WallpaperPath','IntroEnabled','Muted','MaxSeconds','UseSystemProxy','Status')) { $controls[$name] = $window.FindName($name) }
    $ui.status = $controls.Status
    $controls.IntroPath.Text = $settings.introPath
    $controls.WallpaperPath.Text = $settings.wallpaperPath
    $controls.IntroEnabled.IsChecked = $settings.introEnabled
    $controls.Muted.IsChecked = $settings.muted
    $controls.UseSystemProxy.IsChecked = $settings.useSystemProxy
    $controls.MaxSeconds.Text = "$($settings.maxSeconds)"
    $cover = Join-Path $script:ConanRoot 'media\wallpaper.png'
    if (Test-Path -LiteralPath $cover) { $window.FindName('ThemeArtwork').Source = [Windows.Media.Imaging.BitmapImage]::new([Uri]$cover) }

    function Save-ConanForm {
        $seconds = 0
        if (-not [int]::TryParse($controls.MaxSeconds.Text, [ref]$seconds)) { throw '最长秒数请输入 1–30 的整数。' }
        $settings.introPath = $controls.IntroPath.Text
        $settings.wallpaperPath = $controls.WallpaperPath.Text
        $settings.useBundledIntro = Test-ConanBundledMediaPath -Path $settings.introPath -Kind Intro
        $settings.useBundledWallpaper = Test-ConanBundledMediaPath -Path $settings.wallpaperPath -Kind Wallpaper
        $settings.introEnabled = [bool]$controls.IntroEnabled.IsChecked
        $settings.muted = [bool]$controls.Muted.IsChecked
        $settings.useSystemProxy = [bool]$controls.UseSystemProxy.IsChecked
        $settings.maxSeconds = $seconds
        Save-ConanSettings $settings
    }
    function Show-ConanUiError { param([object]$Failure) $ui.status.Text = $Failure.Exception.Message; $ui.status.Foreground = '#FF9DA9' }
    function Select-ConanFile {
        param([string]$Kind)
        $dialog = New-Object Microsoft.Win32.OpenFileDialog
        $dialog.Filter = if ($Kind -eq 'Intro') { '开场视频或动图|*.mp4;*.gif' } else { '图片或视频壁纸|*.png;*.jpg;*.jpeg;*.webp;*.mp4;*.webm' }
        $dialog.CheckFileExists = $true
        if ($dialog.ShowDialog($window)) {
            if ($Kind -eq 'Intro') { $controls.IntroPath.Text = $dialog.FileName }
            else { $controls.WallpaperPath.Text = $dialog.FileName }
            Save-ConanForm
            $ui.status.Text = '素材选择已保存在本机。'
        }
    }
    $window.FindName('PickIntro').Add_Click({ try { Select-ConanFile 'Intro' } catch { Show-ConanUiError $_ } })
    $window.FindName('PickWallpaper').Add_Click({ try { Select-ConanFile 'Wallpaper' } catch { Show-ConanUiError $_ } })
    $window.FindName('ClearIntro').Add_Click({ try { $controls.IntroPath.Text = ''; Save-ConanForm } catch { Show-ConanUiError $_ } })
    $window.FindName('ClearWallpaper').Add_Click({ try { $controls.WallpaperPath.Text = ''; Save-ConanForm } catch { Show-ConanUiError $_ } })
    $window.FindName('ResetMedia').Add_Click({
        try {
            $defaults = Get-ConanDefaultSettings
            Resolve-ConanBundledMedia $defaults
            $controls.IntroPath.Text = $defaults.introPath
            $controls.WallpaperPath.Text = $defaults.wallpaperPath
            Save-ConanForm
            $ui.status.Text = '已恢复内置柯南素材。'
        } catch { Show-ConanUiError $_ }
    })
    $window.FindName('PreviewIntro').Add_Click({
        try {
            Save-ConanForm
            $result = Show-ConanIntro -Settings $settings
            if ($result.PSObject.Properties.Name -contains 'failure' -and $result.failure) { $ui.status.Text = $result.failure }
            else { $ui.status.Text = '预览结束。素材不会上传到网络。' }
        } catch { Show-ConanUiError $_ }
    })
    $window.FindName('StartCodex').Add_Click({
        try { Save-ConanForm; Start-ConanWorker 'Start' }
        catch { Show-ConanUiError $_ }
    })
    $window.FindName('PlainCodex').Add_Click({ try { Save-ConanForm; Start-ConanWorker 'Plain' } catch { Show-ConanUiError $_ } })
    $window.FindName('Restore').Add_Click({ try { Start-ConanWorker 'Restore' } catch { Show-ConanUiError $_ } })
    $timer = New-Object Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(500)
    $timer.Add_Tick({
        if ($ui.worker) {
            $exited = $ui.worker.HasExited
            $exitCode = if ($exited) { $ui.worker.ExitCode } else { 0 }
            $result = Get-ConanOperationResult -Path $ui.resultPath -HasExited $exited -ExitCode $exitCode
            $ui.status.Text = $result.message
            $ui.status.Foreground = if ($result.state -eq 'error') { '#FF9DA9' } else { '#AABBD1' }
        }
    })
    $timer.Start()
    $window.Add_Closing({
        param($sender, $eventArgs)
        if (-not $SmokePath) {
            try { Save-ConanForm } catch { $eventArgs.Cancel=$true; Show-ConanUiError $_ }
        }
    })
    $smokeTimer = $null
    if ($SmokePath) {
        $smokeTimer = New-Object Windows.Threading.DispatcherTimer
        $smokeTimer.Interval = [TimeSpan]::FromSeconds($SmokeSeconds)
        $smokeTimer.Add_Tick({ Save-ConanWindowImage -Window $window -Path $SmokePath; $window.Close() })
        $smokeTimer.Start()
    }
    try { [void]$window.ShowDialog() }
    finally { $timer.Stop(); if ($smokeTimer) { $smokeTimer.Stop() } }
} catch {
    if ($SmokePath -or $PreviewResultPath) { throw }
    [void][Windows.MessageBox]::Show($_.Exception.Message,'Codex · 柯南之夜')
    exit 1
}
