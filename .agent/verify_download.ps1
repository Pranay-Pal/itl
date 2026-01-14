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
Write-Host "Downloading $fileUrl..."

try {
    $tempFile = [System.IO.Path]::GetTempFileName()
    # Use HttpClient for more control and similarity to app
    $client = New-Object System.Net.Http.HttpClient
    $client.DefaultRequestHeaders.Add("Authorization", "Bearer $token")
    
    $response = $client.GetAsync($fileUrl).Result
    if ($response.IsSuccessStatusCode) {
        $bytes = $response.Content.ReadAsByteArrayAsync().Result
        [System.IO.File]::WriteAllBytes($tempFile, $bytes)
         
        # Read first 5 bytes
        $headerBytes = $bytes[0..4]
        $headerStr = [System.Text.Encoding]::ASCII.GetString($headerBytes)
         
        Write-Host "Header: $headerStr"
        if ($headerStr.StartsWith("%PDF")) {
            Write-Host "Valid PDF" -ForegroundColor Green
        }
        else {
            Write-Host "Invalid: $headerStr" -ForegroundColor Red
            $text = [System.Text.Encoding]::UTF8.GetString($bytes)
            Write-Host $text.Substring(0, [Math]::Min(500, $text.Length))
        }
    }
    else {
        Write-Host "HTTP Error: $($response.StatusCode)" -ForegroundColor Red
    }
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
