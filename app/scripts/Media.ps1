Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

function Show-ConanIntro {
    param([object]$Settings, [string]$CapturePath, [double]$TestSeconds = 0)
    if (-not $Settings.introEnabled) { return [pscustomobject]@{state='disabled'} }
    if (-not [Windows.SystemParameters]::ClientAreaAnimation -and -not $TestSeconds) {
        return [pscustomobject]@{state='reduced-motion'}
    }
    $ctx = @{ state='placeholder'; media=$null; picture=$null; gif=$null; stream=$null; opened=$false; timer=$null; failure=$null; animated=$false }
    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Conan · Opening" Width="960" Height="590" WindowStyle="None"
        ResizeMode="NoResize" WindowStartupLocation="CenterScreen" Background="#071225"
        Foreground="#EFF5FF" Topmost="True" ShowInTaskbar="True">
  <Border BorderBrush="#304763" BorderThickness="1">
    <Grid Background="#071225">
      <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="64"/></Grid.RowDefinitions>
      <Grid x:Name="Stage" ClipToBounds="True">
        <Grid.Background><LinearGradientBrush StartPoint="0,1" EndPoint="1,0">
          <GradientStop Color="#071225" Offset="0"/><GradientStop Color="#18395B" Offset="1"/>
        </LinearGradientBrush></Grid.Background>
        <StackPanel x:Name="Placeholder" VerticalAlignment="Center" HorizontalAlignment="Center">
          <TextBlock Text="C O N A N" FontSize="56" FontWeight="Light" HorizontalAlignment="Center"/>
          <Border Background="#E54D61" Height="3" Width="46" Margin="0,22,0,24"/>
          <TextBlock Text="N I G H T   E D I T I O N" Foreground="#8DC9EC" FontSize="13" HorizontalAlignment="Center"/>
          <TextBlock Text="选择一段视频，让每次出发都有仪式感。" Foreground="#AABBD1" Margin="0,24,0,0" FontSize="14"/>
        </StackPanel>
      </Grid>
      <Grid Grid.Row="1" Margin="24,0">
        <StackPanel VerticalAlignment="Center">
          <TextBlock Text="CODEX · 柯南之夜" FontSize="13" FontWeight="SemiBold"/>
          <TextBlock x:Name="PlaybackStatus" Text="素材预览 · 不会启动或修改 Codex" FontSize="11" Foreground="#AABBD1" Margin="0,4,0,0"/>
        </StackPanel>
        <Button x:Name="Skip" Content="跳过  Esc" HorizontalAlignment="Right" VerticalAlignment="Center"
                Background="#17304D" Foreground="#EFF5FF" BorderBrush="#304763" Padding="18,8"/>
      </Grid>
    </Grid>
  </Border>
</Window>
'@
    $window = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader($xaml)))
    $stage = $window.FindName('Stage')
    $placeholder = $window.FindName('Placeholder')
    $playbackStatus = $window.FindName('PlaybackStatus')
    $window.Width = [Math]::Min(960, [Windows.SystemParameters]::WorkArea.Width - 48)
    $window.Height = [Math]::Min(590, [Windows.SystemParameters]::WorkArea.Height - 48)
    $window.FindName('Skip').Add_Click({ $ctx.state = 'skipped'; $window.Close() })
    $window.Add_KeyDown({ if ($_.Key -eq 'Escape') { $ctx.state = 'skipped'; $window.Close() } })
    $window.Add_MouseLeftButtonDown({ try { $window.DragMove() } catch {} })
    $mediaPath = $Settings.introPath
    if ($mediaPath) {
        try {
            if (-not (Test-Path -LiteralPath $mediaPath -PathType Leaf)) { throw '开场文件已移动或不存在，请重新选择。' }
            $info = Get-Item -LiteralPath $mediaPath
            if ($info.Length -lt 1 -or $info.Length -gt 150MB) { throw '开场素材须非空且不超过 150 MB。' }
            $extension = [IO.Path]::GetExtension($mediaPath).ToLowerInvariant()
            if ($extension -eq '.mp4') {
                $ctx.state = 'video'
                $ctx.media = New-Object Windows.Controls.MediaElement
                $ctx.media.LoadedBehavior = 'Manual'
                $ctx.media.UnloadedBehavior = 'Close'
                $ctx.media.Stretch = 'Uniform'
                $ctx.media.IsMuted = $Settings.muted
                $ctx.media.Source = [Uri]$mediaPath
                $ctx.media.Add_MediaOpened({ $ctx.opened = $true; $placeholder.Visibility = 'Collapsed' })
                $ctx.media.Add_MediaEnded({ $ctx.state = 'ended'; $window.Close() })
                $ctx.media.Add_MediaFailed({
                    $ctx.failure = '视频无法解码。请使用 H.264 编码的 MP4，或改用 GIF。'
                    $playbackStatus.Text = $ctx.failure
                    $placeholder.Visibility = 'Visible'
                })
                [void]$stage.Children.Add($ctx.media)
                $window.Add_ContentRendered({ $ctx.media.Play() })
                $playbackStatus.Text = '本地视频 · Esc 跳过'
            } elseif ($extension -eq '.gif') {
                # PictureBox uses Windows' native animated GIF playback, including frame disposal.
                Add-Type -AssemblyName System.Windows.Forms, System.Drawing, WindowsFormsIntegration
                $ctx.state = 'gif'
                $ctx.stream = [IO.File]::OpenRead($mediaPath)
                $ctx.gif = [Drawing.Image]::FromStream($ctx.stream)
                $ctx.animated = [Drawing.ImageAnimator]::CanAnimate($ctx.gif)
                $ctx.opened = $true
                $ctx.picture = New-Object Windows.Forms.PictureBox
                $ctx.picture.Dock = 'Fill'
                $ctx.picture.SizeMode = 'Zoom'
                $ctx.picture.BackColor = [Drawing.Color]::FromArgb(7,18,37)
                $ctx.picture.Image = $ctx.gif
                $hostControl = New-Object Windows.Forms.Integration.WindowsFormsHost
                $hostControl.Child = $ctx.picture
                [void]$stage.Children.Add($hostControl)
                $placeholder.Visibility = 'Collapsed'
                $playbackStatus.Text = '本地动图 · Esc 跳过'
            } else { throw '开场支持 MP4 或 GIF。WebM 可用于 Codex 内的动态壁纸。' }
        } catch {
            $ctx.failure = $_.Exception.Message
            $playbackStatus.Text = $ctx.failure
        }
    }
    $duration = if ($TestSeconds -gt 0) { $TestSeconds } elseif ($mediaPath) { $Settings.maxSeconds } else { 2.2 }
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $ctx.timer = New-Object Windows.Threading.DispatcherTimer
    $ctx.timer.Interval = [TimeSpan]::FromMilliseconds(100)
    $ctx.timer.Add_Tick({
        if ($watch.Elapsed.TotalSeconds -ge $duration) {
            if ($CapturePath) { Save-ConanWindowImage -Window $window -Path $CapturePath }
            $window.Close()
        }
    })
    $window.Add_ContentRendered({ $watch.Restart(); $ctx.timer.Start() })
    try { [void]$window.ShowDialog() }
    finally {
        $ctx.timer.Stop()
        if ($ctx.media) { $ctx.media.Close() }
        if ($ctx.picture) { $ctx.picture.Image = $null; $ctx.picture.Dispose() }
        if ($ctx.gif) { $ctx.gif.Dispose() }
        if ($ctx.stream) { $ctx.stream.Dispose() }
    }
    return [pscustomobject]@{ state=$ctx.state; opened=$ctx.opened; failure=$ctx.failure; animated=$ctx.animated }
}

function Save-ConanWindowImage {
    param([Windows.Window]$Window, [string]$Path)
    $Window.UpdateLayout()
    $surface = $Window.Content
    $bitmap = New-Object Windows.Media.Imaging.RenderTargetBitmap(
        [int]$surface.ActualWidth, [int]$surface.ActualHeight, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($surface)
    $encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path))
    $output = [IO.File]::Create($Path)
    try { $encoder.Save($output) } finally { $output.Dispose() }
}
