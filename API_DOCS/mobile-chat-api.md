# Mobile Chat API — GenLab V2.0

This document is a concise, copy-ready reference for mobile developers integrating the GenLab chat API.

Base URL
- Example (development): http://127.0.0.1:8000
- Use your production base URL in mobile builds.

Authentication
- Obtain tokens from the existing auth endpoints:
  - User login: `POST /api/user/login` — body: `{ "user_code": "...", "password": "..." }`
  - Admin login: `POST /api/admin/login`
- Use header: `Authorization: Bearer {access_token}` and `Accept: application/json` on all calls.

Guards / Base paths
- User endpoints: prefix `/api/chat` (guard `multi_jwt:api`).
- Admin endpoints: prefix `/api/admin/chat` (guard `multi_jwt:api_admin`).

Common headers
- `Authorization: Bearer {token}`
- `Accept: application/json`
- `Content-Type: application/json` (for JSON payloads)
- `Content-Type: multipart/form-data` (for uploads)

Contact and message identifier formats
- Contact IDs in responses are prefixed: `user:36`, `admin:1`, `group:booking`.

Message schema (representative)
{
  "id": 181,
  "sender_id": 1,
  "sender_type": "admin",
  "sender_name": "Super Admin",
  "sender_avatar": "/storage/avatars/1.jpg",
  "receiver_id": 0,
  "receiver_type": "group",
  "content": "Hey",
  "created_at": "2025-12-22T18:45:19+00:00",
  "read_at": "2025-12-22T19:37:13+00:00",
  "attachments": [ { "url": "/storage/chat_files/x.pdf", "name": "Resume.pdf", "size": 188797 } ],
  "audio_url": null,
  "file_url": null,
  "reactions": { "👍": ["user:37"] },
  "reply_to": { "id": 175, "sender_name": "Manish Sir", "snippet": "Hey" }
}

Endpoints — User (prefix: `/api/chat`)

1) GET /api/chat/contacts
- Purpose: List contacts (users, admins, groups) with last message and unread counts.
- Query: `?q=search` (optional)
- Example response: array of objects `{ id, orig_id, name, type, avatar, last_message, last_message_at, unread_count }`.

2) GET /api/chat/messages/{contactId}
- Purpose: Fetch conversation with a contact or group.
- Path: `{contactId}` uses prefixed form (e.g. `user:36`, `group:booking`).
- Query params: `mark_read=1` to mark returned messages as read.
- Example: `GET /api/chat/messages/user:36?mark_read=1`

3) POST /api/chat/messages
- Purpose: Send a message (text, file, audio, or reply).
- Content types:
  - JSON (text): `Content-Type: application/json`
  - Multipart (files/audio): `multipart/form-data`
- JSON example (text):
  {
    "receiver_id": "user:36",
    "receiver_type": "user",
    "content": "Hello from mobile",
    "reply_to": 304,           // optional message id
    "visible_to": 36,          // optional visibility controls
    "visible_to_type": "user"
  }
- Multipart example (file):
  - form fields: `receiver_id=user:36`, `content=...`, `reply_to=304` and one or more file fields `files[]` or `audio`.
- Response: 201 created message object (same shape as Message schema).

4) POST /api/chat/typing
- Purpose: Broadcast typing indicator.
- Body JSON: `{ "receiver_id": "user:36", "receiver_type": "user", "typing": true }`
- Response: `{ "ok": true }`

5) POST /api/chat/messages/reaction
- Purpose: Toggle reaction on a message (adds or removes).
- Body JSON: `{ "message_id": 123, "emoji": "👍" }`
- Response: `{ "acted": true, "reactions": { "👍": ["user:37"] } }`

6) GET /api/chat/search?q=term
- Purpose: Search contacts/messages. Returns matches with same `contacts` shape.

Admin endpoints (prefix: `/api/admin/chat`)
- All endpoints above are mirrored under `/api/admin/chat` and require an admin token from `/api/admin/login`.

Special content markers
- `AUDIO::path` — internal marker for audio messages; responses include `audio_url`.
- `FILE::path::encodedName` — internal marker for file attachments; responses include `attachments` array and `file_url`.
- `REPLY::base64(json)::...` — server encodes reply metadata; clients should use the provided `reply_to` object in the message response.

Real-time integration
- The server broadcasts events: `ChatMessageSent`, `ChatTyping`, `ChatMessageRead`, `ChatMessageReacted` via Echo/Pusher.
- Mobile clients may either:
  - Use Pusher/Echo-compatible client libraries to subscribe to private channels for real-time updates, or
  - Poll `GET /api/chat/messages/{contactId}` and `GET /api/chat/contacts` periodically.

File uploads and URLs
- Use multipart form-data for `files[]` and `audio` fields. The server stores files on the `public` disk and returns `file_url` / `audio_url` (relative paths). Prepend your `APP_URL` if needed.

Error handling & tips
- 401 Unauthorized: token missing/expired or wrong guard (use admin token at `/api/admin/*`).
- Some dev responses may include leading BOM or HTML in non-API routes — normalize responses before JSON parsing in clients if you encounter this in dev environments.

Quick curl examples
- Login (user):
```
curl -X POST -H "Content-Type: application/json" -d '{"user_code":"MKT002","password":"12345678"}' http://127.0.0.1:8000/api/user/login
```
- Fetch contacts:
```
curl -H "Authorization: Bearer {token}" http://127.0.0.1:8000/api/chat/contacts
```
- Fetch messages and mark read:
```
curl -H "Authorization: Bearer {token}" "http://127.0.0.1:8000/api/chat/messages/user:36?mark_read=1"
```
- Send text message:
```
curl -X POST -H "Authorization: Bearer {token}" -H "Content-Type: application/json" \
  -d '{"receiver_id":"user:36","content":"Hello from mobile"}' \
  http://127.0.0.1:8000/api/chat/messages
```
- Send file (multipart):
```
curl -X POST -H "Authorization: Bearer {token}" \
  -F "receiver_id=user:36" -F "files[]=@/path/to/file.pdf" \
  http://127.0.0.1:8000/api/chat/messages
```

Where to find implementation
- Mobile controller: [app/Http/Controllers/MobileControllers/ChatController.php](app/Http/Controllers/MobileControllers/ChatController.php)
- Routes: [routes/api.php](routes/api.php)

