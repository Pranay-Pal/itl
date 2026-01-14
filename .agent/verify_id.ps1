$baseUrl = "https://mediumslateblue-hummingbird-258203.hostingersite.com/api"
$userCode = "MKT001"
$password = "12345678"

Write-Host "Logging in..."
$loginUrl = "$baseUrl/user/login"
$loginBody = @{ user_code = $userCode; password = $password; device_name = "AgentVerification" } | ConvertTo-Json
$loginResponse = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $loginBody -ContentType "application/json"
if ($loginResponse -is [string]) { $loginResponse = $loginResponse -replace '^[^\{]+', '' | ConvertFrom-Json }
$token = $loginResponse.access_token

$bookingId = "20255"
$filename = "Admixture_Complete-20251228115852-gdRgNp.pdf"

# Construct specific URL using ID instead of complex ref
$idUrl = "https://mediumslateblue-hummingbird-258203.hostingersite.com/api/reporting/letters/show/$bookingId/$filename"

Write-Host "Testing ID URL: $idUrl"

try {
    $client = New-Object System.Net.Http.HttpClient
    $client.DefaultRequestHeaders.Add("Authorization", "Bearer $token")
    
    $response = $client.GetAsync($idUrl).Result
    if ($response.IsSuccessStatusCode) {
        $bytes = $response.Content.ReadAsByteArrayAsync().Result
        $headerBytes = $bytes[0..4]
        $headerStr = [System.Text.Encoding]::ASCII.GetString($headerBytes)
        Write-Host "Header: $headerStr"
        if ($headerStr.StartsWith("%PDF")) { Write-Host "SUCCESS: Valid PDF by ID." -ForegroundColor Green }
    }
    else {
        Write-Host "ID URL Failed: $($response.StatusCode)" -ForegroundColor Red
    }
}
catch { Write-Host "Error: $_" }
