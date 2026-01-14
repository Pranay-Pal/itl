$baseUrl = "https://mediumslateblue-hummingbird-258203.hostingersite.com/api"
$userCode = "MKT001"
$password = "12345678"

Write-Host "Logging in..."
$loginUrl = "$baseUrl/user/login"
$loginBody = @{ user_code = $userCode; password = $password; device_name = "AgentVerification" } | ConvertTo-Json
$loginResponse = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $loginBody -ContentType "application/json"
if ($loginResponse -is [string]) { $loginResponse = $loginResponse -replace '^[^\{]+', '' | ConvertFrom-Json }
$token = $loginResponse.access_token

$complexUrl = "https://mediumslateblue-hummingbird-258203.hostingersite.com/superadmin/reporting/letters/show/%28133691%29%20PROJECT/WORK%20CIRCLE-8/2025/4648%20%2005/12/20/Admixture_Complete-20251228115852-gdRgNp.pdf"

# Strategy: Replace /superadmin/ with /api/ AND encode slashes in the middle part?
# The URL structure is .../show/{ref}/{filename}
# Ref = %28133691%29%20PROJECT/WORK%20CIRCLE-8/2025/4648%20%2005/12/20
# Filename = Admixture_Complete-20251228115852-gdRgNp.pdf

# Identify Parts
$prefix = "https://mediumslateblue-hummingbird-258203.hostingersite.com/superadmin/reporting/letters/show/"
$suffixIndex = $complexUrl.LastIndexOf("/")
$filename = $complexUrl.Substring($suffixIndex + 1)
$refPart = $complexUrl.Substring($prefix.Length, $suffixIndex - $prefix.Length)

Write-Host "Ref Part: $refPart"

# Encode / in Ref Part
$encodedRef = $refPart.Replace("/", "%2F")
$encodedUrl = "https://mediumslateblue-hummingbird-258203.hostingersite.com/api/reporting/letters/show/$encodedRef/$filename"

Write-Host "Testing Encoded URL: $encodedUrl"

try {
    $client = New-Object System.Net.Http.HttpClient
    $client.DefaultRequestHeaders.Add("Authorization", "Bearer $token")
    
    $response = $client.GetAsync($encodedUrl).Result
    if ($response.IsSuccessStatusCode) {
        $bytes = $response.Content.ReadAsByteArrayAsync().Result
        $headerBytes = $bytes[0..4]
        $headerStr = [System.Text.Encoding]::ASCII.GetString($headerBytes)
        Write-Host "Header: $headerStr"
        if ($headerStr.StartsWith("%PDF")) { Write-Host "SUCCESS: Valid PDF with encoded slashes." -ForegroundColor Green }
    }
    else {
        Write-Host "Encoded URL Failed: $($response.StatusCode)" -ForegroundColor Red
    }
}
catch { Write-Host "Error: $_" }
