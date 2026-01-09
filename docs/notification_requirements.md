# Push Notification Requirements (FCM)

This document outlines the JSON payload structure required for the ITL Mobile App to correctly handle Push Notifications and navigate to specific screens (Deep Linking).

## Overview
The mobile application uses **Firebase Cloud Messaging (FCM)**. To trigger specific actions when a user taps on a notification, you must include a `data` object in your FCM payload.

## Payload Structure
Every notification request sent to FCM should include two parts:
1. `notification`: The visible title and body (handled by the system tray).
2. `data`: Custom key-value pairs processed by the app logic.

### Required Keys in `data`
| Key | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `type` | String | **YES** | Determines which screen to open. |
| `id` | String/Int | Optional | The ID of the specific item (e.g., Booking ID, Invoice ID). Currently routes to the *List* view, but useful for future Detail view routing. |

---

## Supported `type` Values

The mobile app currently supports the following values for the `type` key (case-insensitive):

| Type Value | Target Screen |
| :--- | :--- |
| `booking` OR `bookings` | **Bookings Dashboard** (List of bookings) |
| `report` OR `reports` | **Reports Dashboard** (List of reports) |
| `invoice` OR `invoices` | **Invoices List** |
| `expense` OR `expenses` | **Expenses List** |

---

## JSON Examples

### 1. New Booking Notification
```json
{
  "to": "DEVICE_FCM_TOKEN",
  "notification": {
    "title": "New Booking Received",
    "body": "You have received a new booking request #JOB-2024-001"
  },
  "data": {
    "type": "booking",
    "id": "1001",
    "job_no": "JOB-2024-001"
  },
  "priority": "high"
}
```

### 2. Report Status Update
```json
{
  "to": "DEVICE_FCM_TOKEN",
  "notification": {
    "title": "Report Completed",
    "body": "Report for Sample A is now available."
  },
  "data": {
    "type": "report",
    "id": "550"
  }
}
```

### 3. Invoice Generated
```json
{
  "to": "DEVICE_FCM_TOKEN",
  "notification": {
    "title": "Invoice Generated",
    "body": "Invoice #INV-999 has been created."
  },
  "data": {
    "type": "invoice",
    "id": "999"
  }
}
```

## Important Implementation Notes
*   **Android Channel ID**: The app listens to `high_importance_channel`. You do not strictly need to send this, but if your library supports it, it helps ensures popup behavior on some Android versions.
*   **Case Sensitivity**: The app converts the `type` to lowercase before checking, so `Booking`, `BOOKING`, and `booking` will all work.
*   **Empty Type**: If `type` is missing or unknown, the notification will still open the app, but it will land on the default Home/Dashboard screen.
