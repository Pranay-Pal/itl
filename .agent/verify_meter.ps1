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

# 2. Fetch Meter Readings
$meterUrl = "$baseUrl/meter-reading"
$headers = @{ Authorization = "Bearer $token"; Accept = "application/json" }

try {
    Write-Host "Fetching Meter Readings..."
    $response = Invoke-RestMethod -Uri $meterUrl -Method Get -Headers $headers
    if ($response -is [string]) {
        $response = $response -replace '^[^\{]+', '' | ConvertFrom-Json
    }
    
    # Inspect the first reading
    if ($response.data.data.Count -gt 0) {
        Write-Host "First Reading Data:"
        $response.data.data[0] | ConvertTo-Json -Depth 5
    }
    else {
        Write-Host "No readings found."
    }
}
catch {
    Write-Host "Fetch Failed: $_"
}
