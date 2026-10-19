param(
    [int]$Port = 8080
)

$baseDir = $PSScriptRoot
if (-not $baseDir) {
    $baseDir = Get-Location
}

$listener = New-Object System.Net.HttpListener
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)

try {
    $listener.Start()
} catch {
    Write-Host "Port $Port kullanımda olabilir, alternatif port deneniyor..." -ForegroundColor Yellow
    $Port = 8081
    $prefix = "http://localhost:$Port/"
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add($prefix)
    $listener.Start()
}

$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".htm"  = "text/html; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".gif"  = "image/gif"
    ".svg"  = "image/svg+xml"
    ".webp" = "image/webp"
    ".ico"  = "image/x-icon"
    ".mp3"  = "audio/mpeg"
    ".wav"  = "audio/wav"
    ".ogg"  = "audio/ogg"
    ".gltf" = "model/gltf+json"
    ".glb"  = "model/gltf-binary"
    ".bin"  = "application/octet-stream"
    ".woff" = "font/woff"
    ".woff2"= "font/woff2"
    ".ttf"  = "font/ttf"
}

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  Metin2 Web Oyunu Sunucusu Baslatildi!" -ForegroundColor Green
Write-Host "  Adres: $prefix" -ForegroundColor Yellow
Write-Host "  Dizin: $baseDir" -ForegroundColor Gray
Write-Host "  Durdurmak icin: Ctrl+C" -ForegroundColor DarkGray
Write-Host "=================================================" -ForegroundColor Cyan

# Tarayıcıyı otomatik aç
try {
    Start-Process $prefix
} catch {
    Write-Host "Tarayıcı otomatik açılamadı, lütfen adrese manuel gidin: $prefix" -ForegroundColor Yellow
}

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $urlPath = [System.Uri]::UnescapeDataString($request.Url.LocalPath)
        if ($urlPath -eq "/" -or [string]::IsNullOrWhiteSpace($urlPath)) {
            $urlPath = "/index.html"
        }

        # Guvenli yerel dosya yolu cozumu
        $relativePath = $urlPath.TrimStart("/").Replace("/", [System.IO.Path]::DirectorySeparatorChar)
        $localPath = [System.IO.Path]::Combine($baseDir, $relativePath)

        # CORS ve Guvenlik basliklari
        $response.AddHeader("Access-Control-Allow-Origin", "*")
        $response.AddHeader("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
        $response.AddHeader("Cache-Control", "no-cache, no-store, must-revalidate")

        if ($request.HttpMethod -eq "OPTIONS") {
            $response.StatusCode = 200
            $response.Close()
            continue
        }

        if ([System.IO.File]::Exists($localPath)) {
            $ext = [System.IO.Path]::GetExtension($localPath).ToLowerInvariant()
            $contentType = if ($mimeTypes.ContainsKey($ext)) { $mimeTypes[$ext] } else { "application/octet-stream" }
            $response.ContentType = $contentType

            $bytes = [System.IO.File]::ReadAllBytes($localPath)
            $response.ContentLength64 = $bytes.Length
            $response.StatusCode = 200

            if ($request.HttpMethod -ne "HEAD") {
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] 200 OK: $urlPath" -ForegroundColor Green
        } else {
            $response.StatusCode = 404
            $errBytes = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found: $urlPath")
            $response.ContentLength64 = $errBytes.Length
            $response.ContentType = "text/plain; charset=utf-8"
            $response.OutputStream.Write($errBytes, 0, $errBytes.Length)
            Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] 404 Not Found: $urlPath" -ForegroundColor Red
        }

        $response.Close()
    } catch {
        # İstek işleme sırasında bağlantı kesilmesi vb. durumları yakala
    }
}
