$baseUrl = "https://mediumslateblue-hummingbird-258203.hostingersite.com/api"
$userCode = "MKT001"
$password = "12345678"

# 1. Login
Write-Host "Logging in..."
$loginUrl = "$baseUrl/user/login"
$loginBody = @{ user_code = $userCode; password = $password; device_name = "AgentVerification" } | ConvertTo-Json
try {
    $loginResponse = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $loginBody -ContentType "application/json"
    if ($loginResponse -is [string]) { $loginResponse = $loginResponse -replace '^[^\{]+', '' | ConvertFrom-Json }
    $token = $loginResponse.access_token
    if (-not $token) { $token = $loginResponse.token }
    Write-Host "Login Successful. Token obtained."
}
catch {
    Write-Error "Login Failed: $_"
    exit
}

$headers = @{ Authorization = "Bearer $token"; Accept = "application/json" }

# 2. Fetch Hold/Cancelled Items
Write-Host "`n--- Fetching Hold/Cancelled Items ---"
$holdUrl = "$baseUrl/marketing-person/$userCode/hold-cancelled"
try {
    $holdResponse = Invoke-RestMethod -Uri $holdUrl -Method Get -Headers $headers
    if ($holdResponse -is [string]) { $holdResponse = $holdResponse -replace '^[^\{]+', '' | ConvertFrom-Json }
    
    $holdData = $holdResponse.data.data
    $holdResponse | ConvertTo-Json -Depth 10 | Out-File -FilePath "d:\itl\.agent\debug_hold_response.json" -Encoding utf8
    Write-Host "Found $($holdData.Count) hold/cancelled items."
    if ($holdData.Count -gt 0) {
        $first = $holdData[0]
        Write-Host "First Item Job Order: $($first.job_order_no)"
        Write-Host "Status: $($first.status.label)"
    }
}
catch {
    Write-Error "Failed to fetch Hold/Cancelled items: $_"
    try { Write-Host "Response: $($_.Response)" } catch {}
}

# 3. Fetch Quotations
Write-Host "`n--- Fetching Quotations ---"
$quoteUrl = "$baseUrl/marketing-person/$userCode/quotations"
try {
    $quoteResponse = Invoke-RestMethod -Uri $quoteUrl -Method Get -Headers $headers
    if ($quoteResponse -is [string]) { $quoteResponse = $quoteResponse -replace '^[^\{]+', '' | ConvertFrom-Json }
    
    $quoteData = $quoteResponse.data.data
    $quoteResponse | ConvertTo-Json -Depth 10 | Out-File -FilePath "d:\itl\.agent\debug_quotation_response.json" -Encoding utf8
    Write-Host "Found $($quoteData.Count) quotations."
    if ($quoteData.Count -gt 0) {
        $first = $quoteData[0]
        Write-Host "First Quote No: $($first.quotation_no)"
        Write-Host "Client: $($first.client_name)"
    }
}
catch {
    Write-Error "Failed to fetch Quotations: $_"
}
