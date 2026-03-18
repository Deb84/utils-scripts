cd /d "%~dp0"
set SERVER_PATH=%appdata%\Hytale\install\release\package\game\latest
set "DEV_PATH="

robocopy "%SERVER_PATH%\Server" ".\Server" /E
copy /Y "%SERVER_PATH%\Server\HytaleServer.jar" "%DEV_PATH%"
copy /Y "%SERVER_PATH%\Assets.zip" "."
