$baseUrl = "https://mediumslateblue-hummingbird-258203.hostingersite.com/api"
$userCode = "MKT001"
$password = "12345678"

# 1. Login
$loginUrl = "$baseUrl/user/login"
$loginBody = @{
    user_code   = $userCode
    password    = $password
    device_name = "AgentVerification"
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $loginBody -ContentType "application/json"
    if ($loginResponse -is [string]) {
        $loginResponse = $loginResponse -replace '^[^\{]+', '' | ConvertFrom-Json
    }
    $token = $loginResponse.access_token
    if (-not $token) { $token = $loginResponse.token }
    Write-Host "Login Successful."
}
catch {
    Write-Host "Login Failed: $_"
    exit
}

# 2. Upload Reading with Description
$uploadUrl = "$baseUrl/meter-reading/upload"
$description = "Test Description Agent $(Get-Date -Format 'HH:mm:ss')"
$currentReading = 12345

Write-Host "Uploading Reading with description: $description"

# Multipart form data is tricky in pure PowerShell Invoke-RestMethod without external libs for some versions.
# using a simple approach or creating boundary manually.
# For simplicity, if the backend accepts JSON for this endpoint (some do), we could try that too.
# But MeterService uses MultipartRequest.
# Let's use curl.exe if available as it handles multipart easier, or construct body.

# Trying curl for multipart
$curlArgs = @(
    "-s",
    "-X", "POST",
    "-H", "Authorization: Bearer $token",
    "-H", "Accept: application/json",
    "-F", "current_reading=$currentReading",
    "-F", "description=$description",
    "$uploadUrl"
)

$uploadOutput = & curl.exe $curlArgs
Write-Host "Upload Response: $uploadOutput"

# 3. Verify Persistence
Start-Sleep -Seconds 2
$meterUrl = "$baseUrl/meter-reading"
$headers = @{ Authorization = "Bearer $token"; Accept = "application/json" }

try {
    Write-Host "Verifying Persistence..."
    $response = Invoke-RestMethod -Uri $meterUrl -Method Get -Headers $headers
    if ($response -is [string]) {
        $response = $response -replace '^[^\{]+', '' | ConvertFrom-Json
    }
    
    $latest = $response.data.data[0]
    Write-Host "Latest ID: $($latest.id)"
    Write-Host "Latest Description: '$($latest.description)'"
    
    if ($latest.description -eq $description) {
        Write-Host "SUCCESS: Description persisted."
    }
    else {
        Write-Host "FAILURE: Description mismatch or null."
    }
}
catch {
    Write-Host "Fetch Failed: $_"
}
