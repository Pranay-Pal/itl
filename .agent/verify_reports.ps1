$baseUrl = "https://mediumslateblue-hummingbird-258203.hostingersite.com/api"
$userCode = "MKT001"
$password = "12345678"

# 1. Login
$loginUrl = "$baseUrl/user/login"
$loginBody = @{ user_code = $userCode; password = $password; device_name = "AgentVerification" } | ConvertTo-Json
$loginResponse = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $loginBody -ContentType "application/json"
if ($loginResponse -is [string]) { $loginResponse = $loginResponse -replace '^[^\{]+', '' | ConvertFrom-Json }
$token = $loginResponse.access_token
if (-not $token) { $token = $loginResponse.token }

# 2. Fetch Reports (Tab 1)
$reportsUrl = "$baseUrl/marketing-person/$userCode/reports?page=1"
$headers = @{ Authorization = "Bearer $token"; Accept = "application/json" }

Write-Host "Fetching Reports..."
$response = Invoke-RestMethod -Uri $reportsUrl -Method Get -Headers $headers
if ($response -is [string]) { $response = $response -replace '^[^\{]+', '' | ConvertFrom-Json }

$items = $response.data
$found = $false
foreach ($item in $items) {
    if ($item.report_url) {
        Write-Host "Found Report URL: $($item.report_url)"
        $found = $true
        break
    }
}
if (-not $found) { Write-Host "No reports with report_url found in first page." }

# 3. Fetch By Letter (Tab 2)
$letterUrl = "$baseUrl/marketing-person/$userCode/bookings/view-by-letter?page=1"
Write-Host "Fetching Letters from: $letterUrl"
Write-Host "Fetching Letters..."
$lResponse = Invoke-RestMethod -Uri $letterUrl -Method Get -Headers $headers
if ($lResponse -is [string]) { $lResponse = $lResponse -replace '^[^\{]+', '' | ConvertFrom-Json }

Write-Host "Response Keys: $($lResponse.data.PSObject.Properties.Name -join ', ')"

# Try to find the list. It might be 'bookings' or 'data'
$lItems = $lResponse.data.bookings
if (-not $lItems) { $lItems = $lResponse.data.data }

Write-Host "Found $($lItems.Count) items."

foreach ($item in $lItems) {
    Write-Host "Checking Letter ID: $($item.id)"
    
    if ($item.upload_letter_url) {
        Write-Host "  Found Main Letter URL: $($item.upload_letter_url)"
    }
    
    if ($item.invoice_url) {
        Write-Host "  Found Invoice URL: $($item.invoice_url)"
    }
    
    if ($item.report_files) {
        foreach ($f in $item.report_files) {
            Write-Host "  Found Report File URL: $($f.url)"
        }
    }
}
