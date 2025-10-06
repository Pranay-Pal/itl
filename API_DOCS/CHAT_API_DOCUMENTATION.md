# Chat API Documentation

## Base URL
```
http://127.0.0.1:8000/api
```

## Authentication
This API uses JWT (JSON Web Token) authentication with two different guards:
- **User Authentication**: `/api/user/login` (for regular users)
- **Admin Authentication**: `/api/admin/login` (for admin users)

### Login Endpoints

#### User Login
```http
POST /api/user/login
Content-Type: application/json

{
    "user_code": "test123",
    "password": "password123"
}
```

**Response:**
```json
{
    "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
    "token_type": "bearer",
    "expires_in": 3600
}
```

#### Admin Login
```http
POST /api/admin/login
Content-Type: application/json

{
    "email": "admin@example.com",
    "password": "admin123"
}
```

**Response:**
```json
{
    "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
    "token_type": "bearer",
    "expires_in": 3600
}
```

## Headers
All chat API requests require authentication:
```
Authorization: Bearer {your_jwt_token}
Content-Type: application/json
```

## Chat API Endpoints

### 1. Get Chat Groups

#### User Endpoint
```http
GET /api/chat/groups
Authorization: Bearer {user_token}
```

#### Admin Endpoint
```http
GET /api/admin/chat/groups
Authorization: Bearer {admin_token}
```

**Response:**
```json
{
    "success": true,
    "data": [
        {
            "id": 1,
            "name": "General Chat",
            "slug": "general-chat",
            "created_by": 1,
            "created_at": "2025-10-01T21:49:49.000000Z",
            "updated_at": "2025-10-01T21:49:49.000000Z"
        }
    ],
    "message": "Groups retrieved"
}
```

### 2. Create Chat Group

#### User Endpoint
```http
POST /api/chat/groups
Authorization: Bearer {user_token}
Content-Type: application/json

{
    "name": "My New Group"
}
```

#### Admin Endpoint
```http
POST /api/admin/chat/groups
Authorization: Bearer {admin_token}
Content-Type: application/json

{
    "name": "Admin Group"
}
```

**Response:**
```json
{
    "success": true,
    "data": {
        "id": 8,
        "name": "My New Group",
        "slug": "my-new-group",
        "created_by": 1,
        "created_at": "2025-10-01T21:49:49.000000Z",
        "updated_at": "2025-10-01T21:49:49.000000Z"
    },
    "message": "Group created"
}
```

### 3. Get Messages

#### User Endpoint
```http
GET /api/chat/messages?group_id=1
Authorization: Bearer {user_token}
```

#### Admin Endpoint
```http
GET /api/admin/chat/messages?group_id=1
Authorization: Bearer {admin_token}
```

**Response:**
```json
{
    "success": true,
    "data": [
        {
            "id": 1,
            "group_id": 1,
            "user_id": 1,
            "type": "text",
            "content": "Hello everyone!",
            "sender_guard": "api",
            "sender_name": "John Doe",
            "created_at": "2025-10-01T21:52:57.000000Z"
        }
    ],
    "pagination": {
        "current_page": 1,
        "total": 10,
        "has_more_pages": false
    },
    "message": "Messages retrieved"
}
```

### 4. Send Message

#### User Endpoint
```http
POST /api/chat/messages
Authorization: Bearer {user_token}
Content-Type: application/json

{
    "group_id": 1,
    "type": "text",
    "content": "Hello, this is my message!"
}
```

#### Admin Endpoint
```http
POST /api/admin/chat/messages
Authorization: Bearer {admin_token}
Content-Type: application/json

{
    "group_id": 1,
    "type": "text",
    "content": "Admin message here"
}
```

**Message Types:**
- `text` - Regular text message
- `file` - File attachment
- `image` - Image attachment

**Response:**
```json
{
    "success": true,
    "data": {
        "id": 8,
        "group_id": 1,
        "user_id": 1,
        "type": "text",
        "content": "Hello, this is my message!",
        "sender_guard": "api",
        "sender_name": "John Doe",
        "created_at": "2025-10-01T21:52:57.000000Z"
    },
    "message": "Message sent"
}
```

### 5. React to Message

#### User Endpoint
```http
POST /api/chat/messages/{message_id}/reactions
Authorization: Bearer {user_token}
Content-Type: application/json

{
    "type": "like"
}
```

#### Admin Endpoint
```http
POST /api/admin/chat/messages/{message_id}/reactions
Authorization: Bearer {admin_token}
Content-Type: application/json

{
    "type": "Hold"
}
```

**Reaction Types:**
- `Hold`
- `Booked`
- `Cancel`
- `Reply`
- `Forward`
- `Share`

### 6. Get Unread Message Counts

#### User Endpoint
```http
GET /api/chat/unread-counts
Authorization: Bearer {user_token}
```

#### Admin Endpoint
```http
GET /api/admin/chat/unread-counts
Authorization: Bearer {admin_token}
```

**Response:**
```json
{
    "success": true,
    "data": {
        "total_unread": 5,
        "groups": [
            {
                "group_id": 1,
                "group_name": "General Chat",
                "unread_count": 3
            },
            {
                "group_id": 2,
                "group_name": "Project Team",
                "unread_count": 2
            }
        ]
    },
    "message": "Unread counts retrieved"
}
```

### 7. Search Users

#### User Endpoint
```http
GET /api/chat/users/search?q=john
Authorization: Bearer {user_token}
```

#### Admin Endpoint
```http
GET /api/admin/chat/users/search?q=john
Authorization: Bearer {admin_token}
```

**Response:**
```json
{
    "success": true,
    "data": [
        {
            "id": 1,
            "name": "John Doe",
            "email": "john@example.com",
            "user_code": "john123"
        }
    ],
    "message": "Users found"
}
```

## Error Responses

### Authentication Errors
```json
{
    "success": false,
    "message": "Not authenticated"
}
```
**HTTP Status:** 401

### Validation Errors
```json
{
    "success": false,
    "message": "Error: The type field is required."
}
```
**HTTP Status:** 500

### Permission Errors
```json
{
    "success": false,
    "message": "Not a member"
}
```
**HTTP Status:** 403

## Test Credentials

### User Account
- **User Code:** `test123`
- **Password:** `password123`

### Admin Account  
- **Email:** `admin@example.com`
- **Password:** `admin123`

## Sample Integration Code

### JavaScript/React Example
```javascript
// Login function
async function loginUser(userCode, password) {
    const response = await fetch('http://127.0.0.1:8000/api/user/login', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            user_code: userCode,
            password: password
        })
    });
    
    const data = await response.json();
    if (data.access_token) {
        localStorage.setItem('chat_token', data.access_token);
        return data.access_token;
    }
    throw new Error('Login failed');
}

// Get chat groups
async function getChatGroups() {
    const token = localStorage.getItem('chat_token');
    const response = await fetch('http://127.0.0.1:8000/api/chat/groups', {
        headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
        }
    });
    
    const data = await response.json();
    return data.data; // Returns array of groups
}

// Send message
async function sendMessage(groupId, message) {
    const token = localStorage.getItem('chat_token');
    const response = await fetch('http://127.0.0.1:8000/api/chat/messages', {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            group_id: groupId,
            type: 'text',
            content: message
        })
    });
    
    const data = await response.json();
    return data.data; // Returns message object
}
```

### Flutter/Dart Example
```dart
class ChatApiService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';
  String? _token;
  
  Future<String> login(String userCode, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/user/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_code': userCode,
        'password': password,
      }),
    );
    
    final data = jsonDecode(response.body);
    _token = data['access_token'];
    return _token!;
  }
  
  Future<List<ChatGroup>> getChatGroups() async {
    final response = await http.get(
      Uri.parse('$baseUrl/chat/groups'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
    );
    
    final data = jsonDecode(response.body);
    return (data['data'] as List)
        .map((group) => ChatGroup.fromJson(group))
        .toList();
  }
}
```

## Notes for Developers

1. **Token Expiry**: JWT tokens expire after 1 hour. Implement token refresh logic.
2. **Error Handling**: Always check the `success` field in responses.
3. **Rate Limiting**: No rate limiting implemented currently, but consider it for production.
4. **Real-time Updates**: Consider implementing WebSocket connections for real-time message updates.
5. **File Uploads**: File and image message types will require multipart/form-data requests.
6. **Pagination**: Message lists support pagination - check `has_more_pages` field.

## Postman Collection

Import this URL in Postman for ready-to-use requests:
- Base URL: `http://127.0.0.1:8000/api`
- Collection includes all endpoints with sample requests

## Support

For technical support or questions about the API implementation, contact the backend developer.

---

**Last Updated:** October 2, 2025  
**API Version:** 1.0  
**Laravel Version:** 10+