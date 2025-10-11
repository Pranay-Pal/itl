# Chat API (Unified)

This is the complete API for the chat system combining both the streamlined API controller (`App\\Http\\Controllers\\Api\\ChatApiController`) and legacy/full-feature controller (`App\\Http\\Controllers\\ChatController`).

Use this document as the single source of truth for mobile integration.

Base URL
- http://127.0.0.1:8000/api

Authentication
- Users (guard: api)
  - POST /api/user/login
- Admins (guard: api_admin)
  - POST /api/admin/login

Headers
- Authorization: Bearer <token>
- Content-Type: application/json (except multipart uploads)

---

Groups
GET /api/chat/groups
GET /api/admin/chat/groups
Response 200
{
  "success": true,
  "data": [ { "id": 1, "name": "Bookings", "slug": "bookings", "created_by": null, "created_at": "...", "updated_at": "..." } ],
  "message": "Groups retrieved"
}

Create group
POST /api/chat/groups
POST /api/admin/chat/groups
Body
{ "name": "My Group" }
Response 201
{ "success": true, "data": { "id": 12, "name": "My Group", "slug": "my-group", "created_by": 1, "created_at": "...", "updated_at": "..." }, "message": "Group created" }

---

Messages (list)
GET /api/chat/messages?group_id=<id>
GET /api/admin/chat/messages?group_id=<id>
Response 200
{
  "success": true,
  "data": [
    {
      "id": 88,
      "group_id": 12,
      "user_id": 1,
      "user": { "id": 1, "name": "Test User", "avatar": "http://127.0.0.1:8000/storage/avatars/1.jpg", "is_chat_admin": false },
      "sender_name": "Test User",
      "sender_guard": "web",
      "type": "text",
      "content": "Hi there",
      "file_url": null,
      "original_name": null,
      "created_at": "2025-10-01T22:10:00.000000Z",
      "mine": true,
      "reply_to_message_id": null,
      "status": null,
      "reactions": []
    }
  ],
  "pagination": { "current_page": 1, "total": 1, "has_more_pages": false },
  "message": "Messages retrieved"
}

Messages since
GET /api/chat/messages/since?group_id=<id>&after_id=<id>
GET /api/admin/chat/messages/since?group_id=<id>&after_id=<id>
Response 200: same data array as messages

---

Send message (JSON)
POST /api/chat/messages
POST /api/admin/chat/messages
Body (text)
{ "group_id": 12, "type": "text", "content": "Hello" }
Response 201
{ "success": true, "data": { ...message object... }, "message": "Message sent" }

Upload message (multipart)
POST /api/chat/messages/upload
POST /api/admin/chat/messages/upload
Form fields
- group_id: number
- type: image | pdf | voice
- file: binary
- reply_to_message_id: number (optional)
Response 201
{ ...message object... }

---

React to a message
POST /api/chat/messages/{messageId}/reactions
POST /api/admin/chat/messages/{messageId}/reactions
Body
{ "type": "like" | "love" | "Hold" | "Booked" | "Unbooked" }
Response 200
{ "status": "ok" }

Delete message
DELETE /api/chat/messages/{messageId}
DELETE /api/admin/chat/messages/{messageId}
Response 200
{ "status": "deleted" }

Mark as seen
POST /api/chat/mark-seen
POST /api/admin/chat/mark-seen
Body
{ "group_id": 12, "last_id": 88 }
Response 200
{ "status": "ok", "last_seen_id": 88 }

Unread counts
GET /api/chat/unread-counts
GET /api/admin/chat/unread-counts
Response 200
{ "total": 5, "groups": [ { "group_id": 12, "group_name": "Bookings", "unread_count": 3, "latest": { ... } } ] }

Direct threads
GET /api/chat/direct/{userId}  (root admin only; legacy dm-<id>)
GET /api/chat/direct-with/{userId}  (dm2 for non-root)

User search
GET /api/chat/users/search?q=john
GET /api/admin/chat/users/search?q=john

---

Examples (cURL)
# Login (user)
curl -s -X POST http://127.0.0.1:8000/api/user/login -H "Content-Type: application/json" -d '{"user_code":"test123","password":"password123"}'

# List groups
curl -s http://127.0.0.1:8000/api/chat/groups -H "Authorization: Bearer <TOKEN>"

# Send text
curl -s -X POST http://127.0.0.1:8000/api/chat/messages -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" -d '{"group_id":12, "type":"text", "content":"Hello"}'

# Upload image
curl -s -X POST http://127.0.0.1:8000/api/chat/messages/upload -H "Authorization: Bearer <TOKEN>" -F group_id=12 -F type=image -F file=@/path/to/pic.jpg

Notes
- JWT tokens expire; handle refresh via /api/user/refresh or /api/admin/refresh.
- File uploads are copied to public storage for direct access by mobile apps.
- Admin (api_admin) cannot open dm2 in admin view; chat-admins (is_chat_admin) get elevated access for Bookings only.

---

Action endpoints (reply, forward, share, status)

Get single message
GET /api/chat/messages/{messageId}
GET /api/admin/chat/messages/{messageId}

Reply to a message
POST /api/chat/messages/{messageId}/reply
POST /api/admin/chat/messages/{messageId}/reply
Body (JSON)
{ "type": "text" | "file" | "image", "content": "Reply text (if type=text)" }

Forward a message to one or more groups
POST /api/chat/messages/{messageId}/forward
POST /api/admin/chat/messages/{messageId}/forward
Body (JSON)
{ "target_group_ids": [12, 13] }

Share a message (alias of forward)
POST /api/chat/messages/{messageId}/share
POST /api/admin/chat/messages/{messageId}/share
Body (JSON)
{ "target_group_id": 12 }
or
{ "target_group_ids": [12, 13] }

Set message status (Hold/Booked/Cancel)
POST /api/chat/messages/{messageId}/status
POST /api/admin/chat/messages/{messageId}/status
Body (JSON)
{ "status": "hold" | "booked" | "cancel" }

Status mapping and serializer
- hold   → reaction type: "Hold"
- booked → reaction type: "Booked"
- cancel → reaction type: "Unbooked"

The serializer exposes `status` on each message based on the latest reaction among [Hold, Booked, Unbooked]. When `type === 'action'`, a parsed `action` object is included.

Examples (PowerShell-friendly)
```
# Reply (user)
curl.exe -s -X POST http://127.0.0.1:8000/api/chat/messages/123/reply -H "Authorization: Bearer <USER_TOKEN>" -H "Content-Type: application/json" -d "{\"type\":\"text\",\"content\":\"On it!\"}"

# Forward/share (user)
curl.exe -s -X POST http://127.0.0.1:8000/api/chat/messages/123/forward -H "Authorization: Bearer <USER_TOKEN>" -H "Content-Type: application/json" -d "{\"target_group_ids\":[9,10]}"
curl.exe -s -X POST http://127.0.0.1:8000/api/chat/messages/123/share -H "Authorization: Bearer <USER_TOKEN>" -H "Content-Type: application/json" -d "{\"target_group_id\":12}"

# Set status (admin)
curl.exe -s -X POST http://127.0.0.1:8000/api/admin/chat/messages/123/status -H "Authorization: Bearer <ADMIN_TOKEN>" -H "Content-Type: application/json" -d "{\"status\":\"cancel\"}"
```
