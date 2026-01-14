$baseUrl = "https://mediumslateblue-hummingbird-258203.hostingersite.com/api"
$userCode = "MKT001"
$password = "12345678"

Write-Host "Logging in..."
$loginUrl = "$baseUrl/user/login"
$loginBody = @{ user_code = $userCode; password = $password; device_name = "AgentVerification" } | ConvertTo-Json
$loginResponse = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $loginBody -ContentType "application/json"
if ($loginResponse -is [string]) { $loginResponse = $loginResponse -replace '^[^\{]+', '' | ConvertFrom-Json }
$token = $loginResponse.access_token

$fileUrl = "https://mediumslateblue-hummingbird-258203.hostingersite.com/superadmin/reporting/letters/show/yguhhijhukj/merged_booking_15791-20260104193905-2V4v9R.pdf"
$urlWithToken = "$fileUrl?token=$token"

Write-Host "Downloading $urlWithToken..."

try {
    $tempFile = [System.IO.Path]::GetTempFileName()
    
    # Try with token in URL and NO headers (simulate browser/webview)
    $client = New-Object System.Net.Http.HttpClient
    
    $response = $client.GetAsync($urlWithToken).Result
    if ($response.IsSuccessStatusCode) {
        $bytes = $response.Content.ReadAsByteArrayAsync().Result
        [System.IO.File]::WriteAllBytes($tempFile, $bytes)
         
        $headerBytes = $bytes[0..4]
        $headerStr = [System.Text.Encoding]::ASCII.GetString($headerBytes)
         
        Write-Host "Header: $headerStr"
        if ($headerStr.StartsWith("%PDF")) {
            Write-Host "SUCCESS: Valid PDF with token param." -ForegroundColor Green
        }
        else {
            Write-Host "Invalid: $headerStr" -ForegroundColor Red
        }
    }
    else {
        Write-Host "HTTP Error: $($response.StatusCode)" -ForegroundColor Red
    }
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
