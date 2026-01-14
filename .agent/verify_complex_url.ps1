$baseUrl = "https://mediumslateblue-hummingbird-258203.hostingersite.com/api"
$userCode = "MKT001"
$password = "12345678"

Write-Host "Logging in..."
$loginUrl = "$baseUrl/user/login"
$loginBody = @{ user_code = $userCode; password = $password; device_name = "AgentVerification" } | ConvertTo-Json
$loginResponse = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $loginBody -ContentType "application/json"
if ($loginResponse -is [string]) { $loginResponse = $loginResponse -replace '^[^\{]+', '' | ConvertFrom-Json }
$token = $loginResponse.access_token

# Complex URL from JSON sample (id 20255)
# JSON: "url": "https:\/\/mediumslateblue-hummingbird-258203.hostingersite.com\/superadmin\/reporting\/letters\/show\/%28133691%29%20PROJECT\/WORK%20CIRCLE-8\/2025\/4648%20%2005\/12\/20\/Admixture_Complete-20251228115852-gdRgNp.pdf"
# Decoded path roughly: .../show/(133691) PROJECT/WORK CIRCLE-8/2025/4648  05/12/20/Admixture_Complete...

$complexUrl = "https://mediumslateblue-hummingbird-258203.hostingersite.com/superadmin/reporting/letters/show/%28133691%29%20PROJECT/WORK%20CIRCLE-8/2025/4648%20%2005/12/20/Admixture_Complete-20251228115852-gdRgNp.pdf"
$rewriteUrl = $complexUrl.Replace("/superadmin/", "/api/")

Write-Host "Testing Rewrite URL: $rewriteUrl"

try {
    $client = New-Object System.Net.Http.HttpClient
    $client.DefaultRequestHeaders.Add("Authorization", "Bearer $token")
    
    $response = $client.GetAsync($rewriteUrl).Result
    
    if ($response.IsSuccessStatusCode) {
        $bytes = $response.Content.ReadAsByteArrayAsync().Result
        $headerBytes = $bytes[0..4]
        $headerStr = [System.Text.Encoding]::ASCII.GetString($headerBytes)
        Write-Host "Header: $headerStr"
        if ($headerStr.StartsWith("%PDF")) { 
            Write-Host "SUCCESS: Valid PDF found." -ForegroundColor Green 
        }
        else {
            Write-Host "INVALID CONTENT: $headerStr" -ForegroundColor Red
        }
    }
    else {
        Write-Host "FAILED: $($response.StatusCode)" -ForegroundColor Red
        # If 404, the API route doesn't match this complex structure
    }
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
