@echo off
rem Wizard Royale launcher (Windows): opens the game in its own app window.
set "GAME=%~dp0index.html"
set "URL=file:///%GAME:\=/%"
set "EDGE=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if exist "%CHROME%" ( start "" "%CHROME%" --app="%URL%" --window-size=1600,1000 & exit /b )
if exist "%EDGE%" ( start "" "%EDGE%" --app="%URL%" --window-size=1600,1000 & exit /b )
start "" "%GAME%"
