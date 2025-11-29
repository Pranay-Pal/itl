Use this guide when you work on the mobile app. It keeps things simple and lists only the pieces you really need.

## 1. Quick Start

1. *Login and grab a JWT token* using the existing auth API (ask the backend team if you do not have it yet).
2. *Add the header* on every request:
   - Authorization: Bearer <your-token>
3. *Pick the right base URL*, for example: https://your-server.example.com/api (replace with the real host).
4. *Use the endpoints below*. The request and response bodies are plain JSON unless a file upload is mentioned.

## 2. Vocabulary (keep handy)

- section tells you what type of expense you deal with: marketing, office, or personal.
- status shows progress: pending, approved, or rejected. Use all when searching.
- marketing_person_code is usually the staff code. When the app does not send it (office/personal sections), the server creates one automatically.
- Personal expenses can be grouped by month when they are sent for approval. The API calls those grouped rows "summaries".

## 3. Data Cheat Sheet

Every expense item in the responses has these main fields:

| Field | What it means |
|---|---|
| id | Unique expense id |
| section | marketing, office, or personal |
| person_name | Display name shown in the portal |
| marketing_person_code | Code for the staff member (auto-generated if missing) |
| amount | Submitted amount |
| approved_amount | Amount approved so far |
| due_amount | amount - approved_amount |
| status | pending, approved, or rejected |
| from_date / to_date | Date range covered by the entry |
| receipt_url | Download link if a receipt file exists |
| approval_summary_url | PDF link when personal expenses get grouped |
| aggregate_ids | Only for grouped personal rows: ids of the child expenses |


## 4. User App Endpoints (guard: multi_jwt:api)


### 4.1 List expenses


GET /api/expenses


Query helpers (all optional):

| Query | Example | Notes |
|---|---|---|
| section | marketing | default is marketing |
| status | pending | use all for every status |
| month / year | 11 / 2025 | filters by created date |
| search | john | matches person name or staff code |
| group_personal | 0 | only for personal section; 1 (default) groups rows |
| per_page | 10 | override pagination size |

Example:


curl -H "Authorization: Bearer <token>" \
  "https://your-server.example.com/api/expenses?section=personal&month=11&year=2025"


Sample success (trimmed):

json
{
  "data": [
    {
      "id": 42,
      "section": "personal",
      "person_name": "John Doe",
      "amount": 200.5,
      "approved_amount": 0,
      "due_amount": 200.5,
      "status": "pending",
      "aggregate_ids": [40, 41],
      "personal_period_label": "Nov 2025",
      "receipt_urls": ["https://your-server.example.com/storage/...pdf"]
    }
  ],
  "links": { ... pagination ... },
  "meta": { ... pagination ... },
  "totals": {
    "total_expenses": 200.5,
    "approved": 0,
    "due": 200.5
  },
  "filters": {
    "section": "personal",
    "status": "all",
    "group_personal": true
  }
}


### 4.2 Create an expense


POST /api/expenses


Send multipart/form-data if you attach a receipt (pdf, jpg, jpeg, png, max 20 MB). Otherwise JSON works.

Body fields:

- section (optional, default marketing)
- marketing_person_code or marketing_person_name
- amount (required)
- from_date, to_date (required, to_date must be >= from_date)
- description (optional)
- pdf (optional file)

Response: 201 Created with the new expense JSON.

### 4.3 See a single expense


GET /api/expenses/{expenseId}


Returns one expense, including relations (marketing_person, approver if available).

### 4.4 Update a personal expense


PUT /api/expenses/{expenseId}


Rules:

- Only works for section = personal.
- Entry must still be pending.
- Same validation as creation. Receipt file can be replaced.

### 4.5 Delete a personal expense


DELETE /api/expenses/{expenseId}


Only for pending personal expenses. Existing receipt files are removed automatically.

### 4.6 Send personal expenses for approval


POST /api/expenses/personal/send-for-approval


Body (JSON or form-data):

- month (optional, default current month)
- year (optional, default current year)

What happens:

1. Finds all pending personal expenses created in that month.
2. Flags them as submitted.
3. Generates a PDF summary under storage/app/public/marketing_expenses.
4. Returns the summary URL and a grouped JSON row you can show to the user.

json
{
  "success": true,
  "summary_path": "marketing_expenses/personal-expenses-2025_11-abc123.pdf",
  "download_url": "https://your-server.example.com/storage/marketing_expenses/personal-expenses-2025_11-abc123.pdf",
  "summary": { ... grouped expense ... },
  "pending_count": 12
}


## 5. Admin App Endpoints (guard: multi_jwt:api_admin)

Use these if the admin section inside the app needs to review requests.

### 5.1 List expenses for review


GET /api/admin/expenses


Same query options as the user list endpoint. When section=personal and status=pending, the response contains grouped rows ready for approval.

### 5.2 Show a specific expense (or summary)


GET /api/admin/expenses/{expenseId}


If the id belongs to a grouped summary, the response still includes aggregate_ids so you can display the underlying items.

### 5.3 Approve


POST /api/admin/expenses/{expenseId}/approve


Body (JSON):

- approved_amount (required) — amount to approve across the target expense(s)
- approval_note (optional text)
- group_ids (optional array) — send this when approving multiple personal items together

The API automatically spreads the approved amount across the grouped expenses until there is no pending amount left.

Success response includes updated totals and the refreshed summary JSON.

### 5.4 Reject


POST /api/admin/expenses/{expenseId}/reject


Body: same as approve but without approved_amount. All selected items become rejected.

## 6. Error Cheatsheet

- *401 Unauthorized*: token missing or expired. Login again.
- *403 Forbidden*: trying to edit a section you are not allowed to change (for example editing a marketing expense through the personal endpoint).
- *422 Validation error*: payload is incomplete. The response contains an errors object telling you what to fix.

Example 422:

json
{
  "message": "The given data was invalid.",
  "errors": {
    "amount": ["The amount field is required."]
  }
}


## 7. Handy Developer Notes

- Routes live in routes/api.php.
- Main controller: app/Http/Controllers/Api/ExpenseApiController.php.
- JSON formatter: app/Http/Resources/MarketingExpenseResource.php.
- Shared helpers: app/Traits/HandlesMarketingExpenses.php.
- Receipts and PDF summaries are stored on the public disk (php artisan storage:link must be set up for public URLs).
- Quick route check: php artisan route:list --path=expenses.

Need more examples (Postman collection, automated tests, etc.)? Let me know and I will add them.