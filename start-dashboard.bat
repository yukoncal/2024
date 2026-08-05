@echo off
echo Starting YouTube Mission Control Dashboard...
echo Open http://localhost:8080 in your browser.
echo.
start http://localhost:8080
python -m http.server 8080
pause
