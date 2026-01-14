$baseUrl = "https://mediumslateblue-hummingbird-258203.hostingersite.com/api"
$userCode = "MKT001"
$password = "12345678"

Write-Host "Logging in..."
$loginUrl = "$baseUrl/user/login"
$loginBody = @{ user_code = $userCode; password = $password; device_name = "AgentVerification" } | ConvertTo-Json
$loginResponse = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $loginBody -ContentType "application/json"
if ($loginResponse -is [string]) { $loginResponse = $loginResponse -replace '^[^\{]+', '' | ConvertFrom-Json }
$token = $loginResponse.access_token

$originalUrl = "https://mediumslateblue-hummingbird-258203.hostingersite.com/superadmin/reporting/letters/show/yguhhijhukj/merged_booking_15791-20260104193905-2V4v9R.pdf"
# Attempt to replace 'superadmin' with 'api'
$altUrl = $originalUrl.Replace("/superadmin/", "/api/")
# Attempt to remove 'superadmin' 
$altUrl2 = $originalUrl.Replace("/superadmin/", "/")

Write-Host "Testing Alt URL 1: $altUrl"

try {
    $client = New-Object System.Net.Http.HttpClient
    $client.DefaultRequestHeaders.Add("Authorization", "Bearer $token")
    
    $response = $client.GetAsync($altUrl).Result
    if ($response.IsSuccessStatusCode) {
        $bytes = $response.Content.ReadAsByteArrayAsync().Result
        $headerBytes = $bytes[0..4]
        $headerStr = [System.Text.Encoding]::ASCII.GetString($headerBytes)
        Write-Host "Header 1: $headerStr"
        if ($headerStr.StartsWith("%PDF")) { Write-Host "FOUND VALID PDF AT ALT URL 1" -ForegroundColor Green }
    }
    else {
        Write-Host "Alt URL 1 Failed: $($response.StatusCode)" -ForegroundColor Yellow
    }
}
catch { Write-Host "Alt URL 1 Error: $_" }

Write-Host "Testing Alt URL 2: $altUrl2"

try {
    $client2 = New-Object System.Net.Http.HttpClient
    $client2.DefaultRequestHeaders.Add("Authorization", "Bearer $token")
    
    $response2 = $client2.GetAsync($altUrl2).Result
    if ($response2.IsSuccessStatusCode) {
        $bytes = $response2.Content.ReadAsByteArrayAsync().Result
        $headerBytes = $bytes[0..4]
        $headerStr = [System.Text.Encoding]::ASCII.GetString($headerBytes)
        Write-Host "Header 2: $headerStr"
        if ($headerStr.StartsWith("%PDF")) { Write-Host "FOUND VALID PDF AT ALT URL 2" -ForegroundColor Green }
    }
    else {
        Write-Host "Alt URL 2 Failed: $($response2.StatusCode)" -ForegroundColor Yellow
    }
}
catch { Write-Host "Alt URL 2 Error: $_" }
