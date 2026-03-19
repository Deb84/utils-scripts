$BASE_LATEST_DIR = "$env:APPDATA\Hytale\install\release\package\game\latest"
$BASE_ASSETS_PATH = $BASE_LATEST_DIR + "\Assets.zip"
$BASE_SERVER_PATH = $BASE_LATEST_DIR + "\Server\HytaleServer.jar"

$URL_START_DEV = "https://raw.githubusercontent.com/Deb84/hytale-utils-scripts/main/dev/server/SERVER_START_dev.bat"
$URL_UPDATE = "https://raw.githubusercontent.com/Deb84/hytale-utils-scripts/refs/heads/main/dev/server/update-server.bat"

$BASE_PATHS = $BASE_LATEST_DIR, $BASE_ASSETS_PATH, $BASE_SERVER_PATH

function Critical-Error() { throw "An error occured" }

function Is-NullString($string) { return [string]::IsNullOrEmpty($path) }

function Unable-ToReach($url, [bool]$critical) { 
    Write-Host "Unable to reach $url"
    if ($critical) { Critical-Error }
}

function Uncorrect-Path($path, $msg) {
    Unable-ToReach $path $false
    Write-Host $msg
    Critical-Error
}

function Throw-IfUncorrectPath($path, $msg) {
    if (-not (IsCorrect-Path $path)) { Uncorrect-Path $path $msg }
}

function IsCorrect-Path($path) {
    if (Is-NullString $path) {
        return $false
    }

    if (-Not (Test-Path $path)) {
        return $false
    }
    return $true
}

function Get-FileName($url) { return [System.IO.Path]::GetFileName($url) }

function Get-RelativePath([string]$p1, [string]$p2) { 
Write-Host $p1 
Write-Host $p2
return $p2.Substring($p1.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar) 
}

function Show-PathDialog($message, $default) {
    Write-Host $message

    $form = New-Object System.Windows.Forms.Form
    $form.TopMost = $true

    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.RootFolder = [System.Environment+SpecialFolder]::MyComputer
    $dialog.Description = $message

    $dialog.ShowDialog($form) | Out-Null
    $path = $dialog.SelectedPath

    if (-not (Is-NullString $default) -and -not (IsCorrect-Path $path)) {
        return $default
    }

    Throw-IfUncorrectPath $path, "Please select a correct path"

    return $path
}

function Show-FileDialog($message) {
    $form = New-Object System.Windows.Forms.Form
    $form.TopMost = $true

    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = $message
    $dialog.InitialDirectory = [Environment+SpecialFolder]::MyComputer
    $dialog.Filter = "*.exe|*.exe"

    if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        $path = $dialog.FileName
        Throw-IfUncorrectPath $path, "Please select a correct path"
        return $path
    } else {
        Critical-Error
    }
}

function Fast-Copy($path, $dir) {
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


function Download-File($url, $dir) {
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

function Create-StartPathObject(
    $SERVER_DIR,
    $SERVER_PATH,
    $ASSETS_PATH
) {
    return @{
        "YourServerDirPath" = "."
        "YourServerPath" = (Get-RelativePath $SERVER_DIR $SERVER_PATH)
        "Assets.zip" = (Get-RelativePath $SERVER_DIR $ASSETS_PATH)
        "YourJavaPath" = Show-FileDialog "Please select your java executable"
        "YourModsPath" = Show-PathDialog "Please select your mods folder"
    }
}


foreach ($path in $BASE_PATHS) {
    Throw-IfUncorrectPath $path $true
}

$USER_SERVER_DIR = Show-PathDialog "Please select your server folder" 
Set-Location $USER_SERVER_DIR

$SERVER_FILE_PATH = Fast-Copy $BASE_SERVER_PATH $USER_SERVER_DIR
$ASSETS_FILE_PATH = Fast-Copy $BASE_ASSETS_PATH $USER_SERVER_DIR

$FILE_START_DEV = Download-File $URL_START_DEV $USER_SERVER_DIR
$FILE_UPDATE = Download-File $URL_UPDATE $USER_SERVER_DIR

$CONTENT_START_DEV = Get-Content $FILE_START_DEV
$CONTENT_UPDATE = Get-Content $FILE_UPDATE

$START_PATH_OBJECT = Create-StartPathObject $USER_SERVER_DIR $SERVER_FILE_PATH $ASSETS_FILE_PATH

foreach ($k in ($START_PATH_OBJECT).Keys) {
    $CONTENT_START_DEV = $CONTENT_START_DEV -replace $k, $START_PATH_OBJECT[$k]
}

Write-Host $CONTENT_START_DEV

Set-Content $FILE_START_DEV $CONTENT_START_DEV
