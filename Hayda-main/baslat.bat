@echo off
title Metin2 Web Oyunu Sunucusu
echo Metin2 Sunucusu Baslatiliyor...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"
pause
