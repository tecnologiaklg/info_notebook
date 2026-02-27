@echo off
:: Verifica se está rodando como administrador
openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo Solicitando permissao de administrador...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Executa o PowerShell com bypass e sem carregar perfil
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Info_Note.ps1"

:: Mantem a janela aberta para ver o resultado
pause