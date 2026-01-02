# API Sample Fetcher Workflow (Auto-Auth)

This workflow automates fetching sample JSON responses from your API endpoints, handling authentication automatically.

## Implementation

The system consists of:
1.  **Script**: `.agent/api_scripts/fetch.ps1` (PowerShell)
2.  **Config**: `.agent/api_scripts/endpoints.json` (List of endpoints)
3.  **Credentials**: `.agent/api_scripts/credentials.json` (Login info)
4.  **Output**: `.agent/api_samples/` (JSON files saved here)

## How to Use

### 1. Setup Credentials
Edit `.agent/api_scripts/credentials.json` with your real login details:
```json
{
  "user_code": "MKT001",
  "password": "your_password",
  "user_type": "user"
}
```

### 2. Configure Endpoints
Edit `.agent/api_scripts/endpoints.json`.
*   Note: The script automatically replaces `MKT001` or `{user_code}` in your URLs with the `user_code` from `credentials.json`.

### 3. Run the Script
Open a terminal in `.agent/api_scripts/` and run:
```powershell
.\fetch.ps1
```

### 4. Review Output
Check `.agent/api_samples/` for the generated JSON files.

// turbo
