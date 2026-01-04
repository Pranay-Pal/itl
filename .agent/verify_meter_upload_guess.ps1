$baseUrl = "https://mediumslateblue-hummingbird-258203.hostingersite.com/api"
$userCode = "MKT001"
$password = "12345678"

# 1. Login
$loginUrl = "$baseUrl/user/login"
$loginBody = @{ user_code = $userCode; password = $password; device_name = "AgentVerification" } | ConvertTo-Json
$loginResponse = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $loginBody -ContentType "application/json"
if ($loginResponse -is [string]) {
    $loginResponse = $loginResponse -replace '^[^\{]+', '' | ConvertFrom-Json
}
$token = $loginResponse.access_token
if (-not $token) { $token = $loginResponse.token }

if (-not $token) {
    Write-Host "Login Failed: No token."
    exit
}

# 2. Upload with multiple guesses
$uploadUrl = "$baseUrl/meter-reading/upload"
$currentReading = 55555
$descValue = "Probe Desc"

Write-Host "Uploading Probe Reading..."

# Send multiple potential fields
$curlArgs = @(
    "-s", "-X", "POST",
    "-H", "Authorization: Bearer $token",
    "-H", "Accept: application/json",
    "-F", "current_reading=$currentReading",
    "-F", "description=$descValue",
    "-F", "desc=$descValue",
    "-F", "note=$descValue",
    "-F", "notes=$descValue",
    "-F", "remark=$descValue",
    "-F", "remarks=$descValue",
    "-F", "comment=$descValue",
    "$uploadUrl"
)

$uploadOutput = & curl.exe $curlArgs
Write-Host "Upload Response: $uploadOutput"

# 3. Verify
Start-Sleep -Seconds 2
$meterUrl = "$baseUrl/meter-reading"
$headers = @{ Authorization = "Bearer $token"; Accept = "application/json" }
$response = Invoke-RestMethod -Uri $meterUrl -Method Get -Headers $headers
if ($response -is [string]) { $response = $response -replace '^[^\{]+', '' | ConvertFrom-Json }

$latest = $response.data.data[0]
Write-Host "Latest ID: $($latest.id)"
Write-Host "Latest Description: '$($latest.description)'"
