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
        # Regex to remove anything before the first '{'
        $loginResponse = $loginResponse -replace '^[^\{]+', ''
        
        try {
            $loginResponse = $loginResponse | ConvertFrom-Json
        }
        catch {
            Write-Host "JSON Parse Error: $_"
            Write-Host "Raw Response: $loginResponse"
            exit
        }
    }

    $token = $loginResponse.access_token
    if (-not $token) { $token = $loginResponse.token }
    
    if (-not $token) {
        Write-Host "Login Failed: No token found in response."
        $loginResponse | ConvertTo-Json
        exit
    }

    Write-Host "Login Successful. Token: $($token.Substring(0, 10))..."
}
catch {
    Write-Host "Login Failed: $_"
    exit
}

$headers = @{
    Authorization = "Bearer $token"
    Accept        = "application/json"
}

# 2. Test Token on Meter Reading (Known Good)
$meterUrl = "$baseUrl/meter-reading"
try {
    Write-Host "Testing Token on: $meterUrl"
    $meterResponse = Invoke-RestMethod -Uri $meterUrl -Method Get -Headers $headers
    Write-Host "Meter Reading Success (Token is valid)."
}
catch {
    Write-Host "Meter Reading Failed: $_"
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        Write-Host "Body: $($reader.ReadToEnd())"
    }
}

# 3. Get Overview
$month = 12
$year = 2024
$overviewUrl = "$baseUrl/marketing-dashboard/$userCode/overview?month=$month&year=$year"

try {
    Write-Host "Fetching Overview from: $overviewUrl"
    $overviewResponse = Invoke-RestMethod -Uri $overviewUrl -Method Get -Headers $headers
    
    # Print the raw JSON (formatted)
    $overviewResponse | ConvertTo-Json -Depth 10
}
catch {
    Write-Host "Overview Fetch Failed:"
    Write-Host $_
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        Write-Host "Body: $($reader.ReadToEnd())"
    }
}
