Add-Type -AssemblyName System.Windows.Forms

$UrlHytaleDownloader = "https://downloader.hytale.com/hytale-downloader.zip"
$Temp = $env:TEMP

$TempFolder = "$Temp\hydl"
$DownloaderFolder = "$TempFolder\Downloader"
$TmpServerFolder = "$TempFolder\Server"

$DownloaderName = "hytale-downloader-windows-amd64.exe"
$ServerArchiveName = "Server.zip"

$DownloaderOutputFile = "$TempFolder\hydl-out.tmp"
$DownloaderErrorFile = "$TempFolder\hydl-err.tmp"
$LatestGameVersionFile = "$TempFolder\hydl-latest.tmp"
$DownloaderSuccessMatch = "successfully downloaded"

$DownloaderUrlNoLine = 1

$RequiredSelectPaths = @(
        @{
            "Callback" = $null
            "CallbackName" = "Folder"
            "TbPos" = "10,50"
            "BtnPos" = "220, 50"
            "Text" = "Your server directory"
            "Name" = "server"
            "Result" = $null
        }
        @{
            "Callback" = $null
            "CallbackName" = "Folder"
            "TbPos" = "10,100"
            "BtnPos" = "220, 100"
            "Text" = "Your mods directory"
            "Name" = "mods"
            "Result" = $null
        }
        @{
            "Callback" = $null
            "CallbackName" = "File"
            "Ext" = "*.exe|*.exe"
            "TbPos" = "10,150"
            "BtnPos" = "220, 150"
            "Text" = "Your java binary (Adoptium is recommended)"
            "Name" = "java"
            "Optional" = $true
            "Result" = $null
        }
    )

# utils functions
function Exit-Error {
    param([Exception]$Err, $Msg = "An error occured")
    Write-Error $Msg
    throw $Err.Message
}

function Test-NullString {
    param($String)
    return [string]::IsNullOrWhiteSpace($String)
}

function Get-FileName {
    param($Uri, [bool]$Ext = $true)
    if ($Ext -eq $true) { return [System.IO.Path]::GetFileName($Uri) }
    return [System.IO.Path]::GetFileNameWithoutExtension($Uri)
}

function Write-Unreachable {
    param($Uri,[bool]$Critical, $Err)
    Write-Host "Unable to reach $Uri"
    if ($Critical) { Exit-Error -Err $Err }
}

function Assert-Path($Path, $Msg) {
    Write-Unreachable $Path $false
    Write-Host $Msg
    Exit-Error
}

function Assert-IncorrectPath($Path, $Msg) {
    if (-not (Test-CorrectPath $Path)) { Assert-Path $Path $Msg }
}

function Test-CorrectPath($Path) {
    if (Test-NullString $Path) {
        return $false
    }

    if (-Not (Test-Path $Path)) {
        return $false
    }
    return $true
}

function Select-Path {
    param($RequiredSelectPaths)

    $form = New-Object System.Windows.Forms.Form
    $form.Width = 500
    $form.Height = 250
    $form.TopMost = $true
    $form.FormBorderStyle = 'FixedDialog'

    function New-Btn($Form, $Txt, $Pos, $Click) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $Txt
        $btn.Location = $Pos

        $btn.Add_Click($Click)

        $Form.Controls.Add($btn)
    }

    function Add-PathSelector {
        param([System.Windows.Forms.Form]$Form, $PathObj)
        [scriptblock]$click = $PathObj.callback
        
        $textBox = New-Object System.Windows.Forms.TextBox
        $textBox.Name = $PathObj.name
        $textBox.Text = $PathObj.text
        $textBox.Location = $PathObj.tbPos
        $textBox.Width = 200
        $Form.Controls.Add($textBox)

        $clk = {
            $textBox.Text =  ($click.Invoke())
            $PathObj.result = $textBox.Text
        }.GetNewClosure()

        New-Btn $Form "Browse" $PathObj.btnPos $clk
    }

    function New-FileSelector {
        param([string]$Ext = "*.*|*.*")
        $selector = New-Object System.Windows.Forms.OpenFileDialog
        $selector.InitialDirectory = [Environment+SpecialFolder]::MyComputer
        $selector.Filter = $Ext
        
        if ($selector.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return $selector.FileName
        }
    }

    function New-FolderSelector {
        $selector = New-Object System.Windows.Forms.FolderBrowserDialog
        $selector.RootFolder = [System.Environment+SpecialFolder]::MyComputer

        if ($selector.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return $selector.SelectedPath
        }
    }

    function Show-IncorrectPath([System.Windows.Forms.Form]$Form, $pos) {
        $label = New-Object System.Windows.Forms.Label
        $label.Text = "Please select correct paths"
        $label.ForeColor = [System.Drawing.Color]::Red
        $label.Location = $pos
        $label.AutoSize = $true
        $Form.Controls.Add($label)
    }

    function Add-Callback {
        param($PathObj)

        if ($PathObj.CallbackName -eq "Folder") { 
            $PathObj.Callback = { New-FolderSelector } 
        }
        if ($PathObj.CallbackName -eq "File") { 
            $PathObj.Callback = { New-FileSelector -Ext $PathObj.Ext }
        }
    }

    foreach ($pathObj in $RequiredSelectPaths) {
        Add-Callback -PathObj $pathObj
        Add-PathSelector -Form $form -PathObj $pathObj
    }

    New-Btn $form "OK" "400,185" {
        foreach ($pathObj in $RequiredSelectPaths) {
            if (-not (Test-CorrectPath -Path $pathObj.result) -and $pathObj.Optional) {
                Show-IncorrectPath -Form $form -Pos "10,185"
                continue
            } else {
                $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
            }
        }
    }

    if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        $form.Close()
        exit 
    } 

    $results = @{}

    foreach ($pathObj in $RequiredSelectPaths) {
        $results.Add($pathObj.name, $pathObj.result)
    }

    return $results
}



function New-Dir {
    param($Path) 
    if (-not (Test-Path $Path)) { New-Item -Path $Path -ItemType Directory | Out-Null }
} 

function Get-File {
    param($Url, $Dir)
    try {
        $fileName = Get-FileName $Url
        $filePath = "$Dir\$fileName"

        New-Dir -Path $Dir

        Write-Host "Downloading $fileName..."
        Invoke-WebRequest -Uri $url -OutFile $filePath -ErrorAction Stop
        Write-Host "$fileName downloaded successfully !"

        return $filePath
    } catch {
        Write-Unreachable -uri $url -critical $true -err $_.Exception
    }
}

function Remove-File {
    param($Paths)
    foreach ($Path in $Paths) {
        if (Test-Path $Path) { Remove-Item $Path -Recurse }
    }
}

function New-Extraction {
    param($Path, $Dir)
    try {
        New-Dir $Dir

        Write-Host "Extracting $Path to $Dir"
        Expand-Archive -Path $Path -DestinationPath $Dir
        Write-Host "Successfully extracted!"
    } catch {
        Exit-Error -Err $_.Exception
    }
}



# buisness fonction
function Enter-DownloaderAuth {
    param($DownloaderAuthUrl, $DownloaderUrlNoLine)
    if ([Uri]::IsWellFormedUriString($DownloaderAuthUrl, [UriKind]::Absolute)) {
        Start-Process $DownloaderAuthUrl
    }
}

$procName = Get-FileName -Uri $DownloaderName -Ext $false
$proc = Get-Process -Name $procName -ErrorAction SilentlyContinue
if ($proc) { $proc | Stop-Process -Force}

Remove-File $TempFolder

New-Dir $TmpServerFolder
New-Dir $DownloaderFolder

# Select-Path $RequiredSelectPaths

$pathHytaleDownloader = Get-File -Url $UrlHytaleDownloader -Dir "$DownloaderFolder"

New-Extraction -Path $pathHytaleDownloader -Dir $DownloaderFolder

$versionProc = Start-Process "$DownloaderFolder\$DownloaderName" `
    -ArgumentList "-print-version" `
    -PassThru `
    -RedirectStandardOutput $LatestGameVersionFile `
    -WindowStyle Hidden

do {
    $version = Get-Content $LatestGameVersionFile
} while (Test-NullString $version)

$versionProc.WaitForExit()

$downloader = Start-Process "$DownloaderFolder\$DownloaderName" `
    -ArgumentList "-download-path $TmpServerFolder\$ServerArchiveName" `
    -RedirectStandardOutput $DownloaderOutputFile `
    -RedirectStandardError $DownloaderErrorFile `
    -PassThru `
    -WindowStyle Hidden

do {
    $output = Get-Content $DownloaderOutputFile
    $errors = Get-Content $DownloaderErrorFile -Raw | Where-Object { -not (Test-NullString $_) }
}
while ((Test-NullString $output) -and (Test-NullString $errors))

if ($errors.Count -ne 0) {
    Write-Error $errors
    Exit-Error "An error occured with hytale-downloader-windows-amd64.exe"
}

Enter-DownloaderAuth -DownloaderAuthUrl $output[$DownloaderUrlNoLine] -DownloaderUrlCodeLine $DownloaderUrlNoLine

# Display the download output in realtime
$lastLine = $null
do {
    $currentLine = Get-Content $DownloaderOutputFile | Select-Object -Last 1
    if ($currentLine -eq $lastLine) { continue }

    Write-Host $currentLine

    $success = $currentLine -match $DownloaderSuccessMatch
    $lastLine = $currentLine
} while (-not $success)

$downloader.WaitForExit()

New-Extraction -Path "$TmpServerFolder\$ServerArchiveName" -Dir $TmpServerFolder



