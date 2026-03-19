$BASE_LATEST_DIR = "$env:APPDATA\Hytale\install\release\package\game\latest"
$BASE_ASSETS_PATH = $BASE_LATEST_DIR + "\Assets.zip"
$BASE_SERVER_PATH = $BASE_LATEST_DIR + "\Server\HytaleServer.jar"

$URL_START_DEV = "https://raw.githubusercontent.com/Deb84/hytale-utils-scripts/main/dev/server/SERVER_START_dev.bat"
$URL_UPDATE = "https://raw.githubusercontent.com/Deb84/hytale-utils-scripts/refs/heads/main/dev/server/update-server.bat"

$BASE_PATHS = $BASE_LATEST_DIR, $BASE_ASSETS_PATH, $BASE_SERVER_PATH

function Exit-Error() { throw "An error occured" }

function Is-NullString($string) { return [string]::IsNullOrWhiteSpace($string) }

function Unable-ToReach($url, [bool]$critical) { 
    Write-Host "Unable to reach $url"
    if ($critical) { Exit-Error }
}

function Assert-Path($path, $msg) {
    Write-Host "Incorrect path trigerred"
    Unable-ToReach $path $false
    Write-Host $msg
    Exit-Error
}

function Throw-IfIncorrectPath($path, $msg) {
    if (-not (IsCorrect-Path $path)) { Assert-Path $path $msg }
}

function IsCorrect-Path($path) {
    Write-Host $path.GetType().FullName
    if (Is-NullString $path) {
        Write-Host "string null"
        return $false
    }

    if (-Not (Test-Path $path)) {
        Write-Host "test path"
        return $false
    }
    return $true
}

function Get-FileName($url) { return [System.IO.Path]::GetFileName($url) }

function Get-RelativePath([string]$p1, [string]$p2) { 
    return $p2.Substring($p1.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar) 
}

function Select-Path() {
    $form = New-Object System.Windows.Forms.Form
    $form.Width = 500
    $form.Height = 250
    $form.TopMost = $true
    $form.FormBorderStyle = 'FixedDialog'

    function New-Btn($_form, $txt, $pos, $click) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $txt
        $btn.Location = $pos

        $btn.Add_Click($click)

        $_form.Controls.Add($btn)
    }

    function Add-PathSelector([System.Windows.Forms.Form]$_form, $pathObj) {
        $click = $pathObj.callback
        
        $textBox = New-Object System.Windows.Forms.TextBox
        $textBox.Name = $pathObj.name
        $textBox.Text = $pathObj.text
        $textBox.Location = $pathObj.tbPos
        $textBox.Width = 200
        $_form.Controls.Add($textBox)

        $clk = {
            $textBox.Text = $click.Invoke($textBox)
            $pathObj.result = $textBox.Text
        }.GetNewClosure()

        New-Btn $_form "Browse" $pathObj.btnPos $clk
    }

    function New-FileSelector([System.Windows.Forms.TextBox]$textBox, [string]$ext) {
        $selector = New-Object System.Windows.Forms.OpenFileDialog
        $selector.InitialDirectory = [Environment+SpecialFolder]::MyComputer
        $selector.Filter = $ext
        
        if ($selector.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return $selector.FileName
        }
    }

    function New-FolderSelector([System.Windows.Forms.TextBox]$textBox) {
        $selector = New-Object System.Windows.Forms.FolderBrowserDialog
        $selector.RootFolder = [System.Environment+SpecialFolder]::MyComputer

        if ($selector.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return $selector.SelectedPath
        }
    }

    function Show-IncorrectPath([System.Windows.Forms.Form]$_form, $pos) {
        $label = New-Object System.Windows.Forms.Label
        $label.Text = "Please select correct paths"
        $label.ForeColor = [System.Drawing.Color]::Red
        $label.Location = $pos
        $label.AutoSize = $true
        $_form.Controls.Add($label)
    }

    $REQUIRED_SELECT_PATHS = @(
        @{
            "callback" = { param($tb) New-FolderSelector $tb }
            "tbPos" = "10,50"
            "btnPos" = "220, 50"
            "text" = "Your server directory"
            "name" = "server"
            "result" = $null
        }
        @{
            "callback" = { param($tb) New-FolderSelector $tb }
            "tbPos" = "10,100"
            "btnPos" = "220, 100"
            "text" = "Your mods directory"
            "name" = "mods"
            "result" = $null
        }
        @{
            "callback" = { param($tb) New-FileSelector $tb "*.exe|*.exe" }
            "tbPos" = "10,150"
            "btnPos" = "220, 150"
            "text" = "Your java binary"
            "name" = "java"
            "result" = $null
        }
    )

    foreach ($pathObj in $REQUIRED_SELECT_PATHS) {
        Add-PathSelector $form $pathObj
    }

    New-Btn $form "OK" "400,185" {
        foreach ($pathObj in $REQUIRED_SELECT_PATHS) {
            if (-not (IsCorrect-Path $pathObj.result)) {
                Show-IncorrectPath $form "10,185"
                continue
            }
        }

        $form.Close()
    }

    [void]$form.ShowDialog()

    
    $results = @{}

    foreach ($pathObj in $REQUIRED_SELECT_PATHS) {
        $results.Add($pathObj.name, $pathObj.result)
    }

    Write-Host $results

    return $results
}

function Copy-Fast($path, $dir) {
    try {
        $fileName = Get-FileName $path
        $filePath = "$dir\$fileName"

        Write-Host "Copying $fileName..."
        Copy-Item $path -Destination $dir -ErrorAction Stop
        Write-Host "$fileName copied successfully !"

        return $filePath
    } catch {
        Unable-ToReach $path $true
    }
}


function Get-File($url, $dir) {
   try {
        $fileName = Get-FileName $url
        $filePath = "$dir\$fileName"

        Write-Host "Downloading $fileName..."
        Invoke-WebRequest -Uri $url -OutFile $filePath -ErrorAction Stop
        Write-Host "$fileName downloaded successfully !"
        return $filePath
   } catch {
        Unable-ToReach $url $true
   }
}

function New-StartPathObject(
    $paths,
    $SERVER_PATH,
    $ASSETS_PATH
) {
    return @{
        "YourServerDirPath" = "."
        "YourServerPath" = (Get-RelativePath $paths.server $SERVER_PATH)
        "Assets.zip" = (Get-RelativePath $paths.server $ASSETS_PATH)
        "YourJavaPath" = $paths.java
        "YourModsPath" = $paths.mods
    }
}


foreach ($path in $BASE_PATHS) {
    Throw-IfIncorrectPath $path "Unable to find the games files, the game is installed ?"
}

$paths = Select-Path

$USER_SERVER_DIR = $paths.server
Set-Location $USER_SERVER_DIR


$SERVER_FILE_PATH = Copy-Fast $BASE_SERVER_PATH $USER_SERVER_DIR
$ASSETS_FILE_PATH = Copy-Fast $BASE_ASSETS_PATH $USER_SERVER_DIR

$FILE_START_DEV = Get-File $URL_START_DEV $USER_SERVER_DIR
$FILE_UPDATE = Get-File $URL_UPDATE $USER_SERVER_DIR

$CONTENT_START_DEV = Get-Content $FILE_START_DEV
$CONTENT_UPDATE = Get-Content $FILE_UPDATE

$START_PATH_OBJECT = New-StartPathObject $paths $SERVER_FILE_PATH $ASSETS_FILE_PATH

foreach ($k in $START_PATH_OBJECT.Keys) {
    $CONTENT_START_DEV = $CONTENT_START_DEV -replace $k, $START_PATH_OBJECT[$k]
}

Set-Content $FILE_START_DEV $CONTENT_START_DEV
