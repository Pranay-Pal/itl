API Usage Guide
1. List Held/Cancelled Items

Endpoint: GET /api/marketing-person/{user_code}/hold-cancelled
Parameters:
job (Optional): Search by Job Order No.
page (Optional): For pagination.
Response:

{
  "status": "success",
  "data": {
    "current_page": 1,
    "data": [
      {
        "id": 123,
        "job_order_no": "JOB-2023-001",
        "description": "Sample Description associated with item...",
        "status": {
          "label": "Held",
          "type": "warning",
          "reason": "Client Request"
        },
        "enquiry": {
            "id": 5,
            "note": "Enquiry details...",
            "media": [
        {
            "path": "marketing_enquiries/sample.pdf",
            "name": "OriginalName.pdf",
            "url": "http://127.0.0.1:8000/storage/marketing_enquiries/sample.pdf"
        }
        ],
            "created_at": "15/01/2026 10:30 AM"
        }
      }
    ]
  },
  "header": { ... } // Only present if searching by 'job'
}

2. Submit Enquiry

Endpoint: POST /api/marketing-person/{user_code}/hold-cancelled/enquiry
Body (Multipart/Form-Data):
booking_item_id: ID of the item.
note: Text content.
media[]: (Optional) Output files/images.
Response:
