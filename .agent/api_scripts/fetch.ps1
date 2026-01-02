# Fetch API Samples Script with Auto-Auth
# Usage: .\fetch.ps1

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$EndpointsFile = Join-Path $ScriptDir "endpoints.json"
$CredentialsFile = Join-Path $ScriptDir "credentials.json"
$OutputDir = Join-Path $ScriptDir "..\api_samples"
$BaseUrl = "https://mediumslateblue-hummingbird-258203.hostingersite.com/api"

# Ensure Output Directory Exists
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
    Write-Host "Created output directory: $OutputDir" -ForegroundColor Green
}

# 1. Load Credentials
if (-not (Test-Path $CredentialsFile)) {
    Write-Host "Error: credentials.json not found. Please create it with user_code and password." -ForegroundColor Red
    exit 1
}
$Creds = Get-Content $CredentialsFile | ConvertFrom-Json
$UserCode = $Creds.user_code
$Password = $Creds.password
$UserType = $Creds.user_type

# 2. Perform Login
Write-Host "Logging in as $UserCode..." -NoNewline
try {
    $LoginUrl = "$BaseUrl/user/login"
    if ($UserType -eq "admin") { $LoginUrl = "$BaseUrl/admin/login" }

    $LoginBody = @{
        user_code = $UserCode
        password  = $Password
    } | ConvertTo-Json

    $LoginResponse = Invoke-RestMethod -Uri $LoginUrl -Method Post -Body $LoginBody -ContentType "application/json"

    # Handle scenario where response is returned as a string with BOM or garbage
    if ($LoginResponse -is [string]) {
        # Remove any non-JSON characters (simplistic approach: find first '{')
        $FirstBrace = $LoginResponse.IndexOf("{")
        if ($FirstBrace -ge 0) {
            $CleanJson = $LoginResponse.Substring($FirstBrace)
            $LoginResponse = $CleanJson | ConvertFrom-Json
        }
    }

    $Token = $LoginResponse.access_token

    if ([string]::IsNullOrWhiteSpace($Token)) {
        Write-Host " FAILED (No token returned)" -ForegroundColor Red
        Write-Host "Response Body: $($LoginResponse | ConvertTo-Json -Depth 5)" -ForegroundColor Yellow
        exit 1
    }
    Write-Host " SUCCESS" -ForegroundColor Green
}
catch {
    Write-Host " FAILED" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor DarkGray
    exit 1
}

# 3. Load & Fetch Endpoints
if (-not (Test-Path $EndpointsFile)) {
    Write-Host "Error: endpoints.json not found." -ForegroundColor Red
    exit 1
}

$Endpoints = Get-Content $EndpointsFile | ConvertFrom-Json

Write-Host "Fetching $($Endpoints.Count) endpoints..." -ForegroundColor Cyan

foreach ($ep in $Endpoints) {
    # Replace placeholders in URL if any (e.g., {user_code})
    $Url = $ep.url.Replace("{user_code}", $UserCode).Replace("MKT001", $UserCode) 
    # Note: The simple replace above handles both explicit placeholder and the default MKT001 if present in json
    
    $Name = $ep.name
    $Method = $ep.method
    
    Write-Host "Fetching [$Name] ($Method $Url)..." -NoNewline

    try {
        $Params = @{
            Uri         = $Url
            Method      = $Method
            Headers     = @{
                "Authorization" = "Bearer $Token"
                "Accept"        = "application/json"
            }
            ContentType = "application/json"
        }

        $Response = Invoke-RestMethod @Params
        
        # Save Response
        $JsonOutput = $Response | ConvertTo-Json -Depth 10
        $OutputFile = Join-Path $OutputDir "$Name.json"
        
        # Helper to prettify JSON if needed, but ConvertTo-Json usually does okay for depth
        $JsonOutput | Set-Content -Path $OutputFile
        
        Write-Host " OK" -ForegroundColor Green
    }
    catch {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor DarkGray
    }
}

Write-Host "Done! Check .agent\api_samples for results." -ForegroundColor Green
