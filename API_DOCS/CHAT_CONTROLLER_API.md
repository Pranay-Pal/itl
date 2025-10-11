# Chat Controller API (Full Reference)

This document describes the REST API implemented by `App\Http\Controllers\ChatController` and the new JWT-protected routes defined under `routes/api.php`.

Base URL
- Local: http://127.0.0.1:8000/api

Authentication
- Users: JWT guard `api` (login at POST /api/user/login)
- Admins: JWT guard `api_admin` (login at POST /api/admin/login)
- Legacy web sessions also supported for browser usage.

Headers
- Authorization: Bearer <token>
- Content-Type: application/json

Guard behavior summary
- Admin category: superadmin, admin, api_admin
- User category: api, web
- Chat admins: web/api users with users.is_chat_admin = true (gets elevated access for Bookings group)

Groups
GET /api/chat/groups
GET /api/admin/chat/groups
- Returns available chat groups in an ordered list with latest message preview and unread counts.
- Response 200: Array of groups
[
  {
    "id": 1,
    "name": "Bookings",
    "avatar": "http://127.0.0.1:8000/storage/avatars/5.jpg",
    "latest": {
      "id": 45,
      "type": "text",
      "content": "Hello",
      "sender_name": "Super Admin",
      "created_at": "2025-10-01T21:52:57.000000Z"
    },
    "last_msg_id": 45,
    "last_msg_at": "2025-10-01T21:52:57.000000Z",
    "unread": 3
  }
]

Create group
POST /api/chat/groups
POST /api/admin/chat/groups
Body
{ "name": "Project Team" }
Response 201
{ "success": true, "data": { "id": 12, "name": "Project Team", "slug": "project-team", "created_by": 1, "created_at": "..." } }

Messages (list)
GET /api/chat/messages?group_id=<id>
GET /api/admin/chat/messages?group_id=<id>
- Returns the latest 200 messages in chronological order.
Response 200
[
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
]

Messages since id
GET /api/chat/messages/since?group_id=<id>&after_id=<id>
GET /api/admin/chat/messages/since?group_id=<id>&after_id=<id>
Response 200: same shape as messages

Send message
POST /api/chat/messages
POST /api/admin/chat/messages
Body (text)
{ "group_id": 12, "type": "text", "content": "Hello" }
Body (file: multipart/form-data)
- group_id: 12
- type: image | pdf | voice
- file: <binary file>
Optional
- reply_to_message_id: <id>
Response 201
{ ...message object... }

React to a message (admin-only)
POST /api/chat/messages/{messageId}/reactions
POST /api/admin/chat/messages/{messageId}/reactions
Body
{ "type": "Hold" | "Booked" | "Unbooked" | "like" | "love" | ... }
Response 200
{ "status": "ok" }

Delete message (sender or admin)
DELETE /api/chat/messages/{messageId}
DELETE /api/admin/chat/messages/{messageId}
Response 200
{ "status": "deleted" }

Prompt delete (legacy alias)
POST /api/chat/messages/{messageId}/prompt-delete
POST /api/admin/chat/messages/{messageId}/prompt-delete
Response 200
{ "status": "deleted" }

Direct threads
- Admin to user (legacy dm-<id>):
  GET /api/chat/direct/{userId}
  GET /api/admin/chat/direct/{userId}
- Symmetric DM between two non-root users (dm2-a-b):
  GET /api/chat/direct-with/{userId}
  GET /api/admin/chat/direct-with/{userId}
Response 200
{ "id": <group_id>, "name": "<display name>" }

Mark seen
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

Search users
GET /api/chat/users/search?q=john
GET /api/admin/chat/users/search?q=john
Response 200: [ { "id": 5, "name": "John", "email": "john@example.com" } ]

Set chat admin (root admin only)
POST /api/chat/users/{userId}/set-admin
POST /api/admin/chat/users/{userId}/set-admin
Body
{ "is_admin": true }
Response 200
{ "id": 5, "name": "John", "is_chat_admin": true }

Notes
- Admin-category viewers cannot open dm2 groups in admin view.
- Chat admins (is_chat_admin = true) get elevated visibility for Bookings group only.
- File uploads are copied to public/storage for direct access; ensure storage:link or rely on auto-copy implemented.
- Avatars are returned when available.

Examples (curl)
# Login (user)
curl -s -X POST http://127.0.0.1:8000/api/user/login -H "Content-Type: application/json" -d '{"user_code":"test123","password":"password123"}'

# List groups
curl -s http://127.0.0.1:8000/api/chat/groups -H "Authorization: Bearer <TOKEN>"

# Send text
curl -s -X POST http://127.0.0.1:8000/api/chat/messages -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" -d '{"group_id":12, "type":"text", "content":"Hello"}'

# Send image
curl -s -X POST http://127.0.0.1:8000/api/chat/messages -H "Authorization: Bearer <TOKEN>" -F group_id=12 -F type=image -F file=@/path/to/pic.jpg

---

Action endpoints

Get single message
GET /api/chat/messages/{messageId}
GET /api/admin/chat/messages/{messageId}

Reply to a message
POST /api/chat/messages/{messageId}/reply
POST /api/admin/chat/messages/{messageId}/reply
Body
{ "type": "text" | "file" | "image", "content": "Reply text (if type=text)" }

Forward/share a message
POST /api/chat/messages/{messageId}/forward  (body: { "target_group_ids": [12, 13] })
POST /api/chat/messages/{messageId}/share    (body: { "target_group_id": 12 } or { "target_group_ids": [12,13] })

Set status (Hold/Booked/Cancel)
POST /api/chat/messages/{messageId}/status  (body: { "status": "hold" | "booked" | "cancel" })
Notes: status is recorded via reactions compatible with UI: hold→Hold, booked→Booked, cancel→Unbooked. Serializer exposes latest status.
