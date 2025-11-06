# Mobile App Integration Guide

This guide explains how a mobile client (rider or driver) integrates with the Taxi Service backend. The API is RESTful, uses JSON payloads, and exposes both public and authenticated routes under the `/api/v1` namespace.

---

## 1. Base URLs & Tooling
- **Local development**: `http://localhost:8080/api/v1`
- **Production (from Swagger)**: `https://64.225.107.130/api/v1`
- **Swagger UI**: `GET /swagger/index.html`
- **Health check**: `GET /health`
- **Static assets (avatars, licenses, etc.)**: `GET /uploads/<relative_path>`

All examples below assume the `/api/v1` prefix.

---

## 2. Authentication & Session Management
The API issues JWT access tokens. Supply them in the `Authorization` header:

```
Authorization: Bearer <token>
```

- Tokens are created on registration/login and validated on every protected route.
- Claims contain `user_id` and `role`. Tokens expire after `JWT_EXPIRATION_HOURS` (default 720 hours).
- Roles (`models.UserRole`): `user`, `driver`, `admin`, `superadmin`.

### 2.1 Register
`POST /auth/register`

```json
{
  "phone_number": "+998901234567",
  "name": "John Doe",
  "password": "password123",
  "confirm_password": "password123"
}
```

Response `201 Created`:

```json
{
  "token": "<jwt>",
  "user": {
    "id": 15,
    "phone_number": "+998901234567",
    "name": "John Doe",
    "role": "user",
    "language": "uz_latin",
    "avatar": null,
    "is_blocked": false,
    "created_at": "...",
    "updated_at": "..."
  }
}
```

Password confirmation must match. Duplicate phone numbers return `409 Conflict`.

### 2.2 Login
`POST /auth/login`

```json
{
  "phone_number": "+998901234567",
  "password": "password123"
}
```

Response `200 OK` mirrors the register response. Blocked users receive `403 Forbidden`.

### 2.3 Session Lifecycle
1. Register (or login) to obtain JWT.
2. Persist JWT securely on the device.
3. Attach `Authorization` header on every protected request.
4. Handle `401` by refreshing credentials (no refresh token exists yet; re-login is required).

---

## 3. Response & Error Conventions
- Success responses return the created or requested resource directly (no `data` wrapper).
- Error payloads always include an `error` key with a string message, e.g. `{"error": "Invalid credentials"}`.
- Validation errors return `400 Bad Request` with either Go validator messages or custom descriptions.

---

## 4. Domain Reference

| Concept            | Values                                                                 |
|--------------------|------------------------------------------------------------------------|
| User roles         | `user`, `driver`, `admin`, `superadmin`                                |
| Languages          | `uz_latin`, `uz_cyrillic`, `ru`                                        |
| Order types        | `taxi`, `delivery`                                                     |
| Order statuses     | `pending`, `accepted`, `in_progress`, `completed`, `cancelled`         |
| Driver status      | `pending`, `approved`, `rejected` (see `drivers.status`)               |
| Delivery types     | `document`, `box`, `luggage`, `valuable`, `other`                      |

Time fields are ISO-8601 timestamps unless otherwise noted. `scheduled_date` expects `DD.MM.YYYY` in requests.

---

## 5. Access Control Overview

| Route Group                  | Roles                                                                    |
|------------------------------|--------------------------------------------------------------------------|
| `/auth`, `/orders`, `/ratings`, `/notifications`, `/feedback` | Any authenticated user (role checked per handler)                  |
| `/driver` (apply)            | Any authenticated user                                                   |
| `/driver` (profile/orders/actions) | `driver`, `admin`, or `superadmin` (enforced via middleware)         |
| `/admin`                     | `admin` or `superadmin`; certain actions require `superadmin` specifically |
| Public (`/health`, `/regions`, `/districts`, auth register/login) | No authentication required |

---

## 6. Rider App Workflow (User Role)
1. Register or login.
2. Fetch regions/districts to populate pickers.
3. Create taxi or delivery order using `/orders/taxi` or `/orders/delivery`.
4. Track orders via `/orders/my` or `/orders/{id}`.
5. Cancel pending/accepted orders with `/orders/{id}/cancel`.
6. Rate driver after completion using `/ratings`.
7. Read notifications (`/notifications`) and submit optional feedback (`/feedback`).

---

## 7. Driver App Workflow (Driver Role)
1. Register/login as user.
2. Submit application via `/driver/apply` (multipart with license image).
3. Wait for admin approval. Once approved, role changes to `driver`.
4. Maintain profile (`/driver/profile` GET/PUT).
5. Discover available jobs (`/driver/orders/new` with optional filters).
6. Accept orders (`/driver/orders/{id}/accept`) if balance covers service fee.
7. Manage assignments via `/driver/orders` and mark completion with `/driver/orders/{id}/complete`.
8. Review performance using `/driver/statistics`.

---

## 8. Endpoint Reference

### 8.1 Public Utilities

| Method | Path                      | Description                                  |
|--------|---------------------------|----------------------------------------------|
| GET    | `/health`                 | Service liveness check                       |
| GET    | `/regions`                | List all regions (sorted by Uzbek Latin name)|
| GET    | `/regions/{id}`           | Fetch a single region                        |
| GET    | `/regions/{id}/districts` | Districts within a region                    |
| GET    | `/districts/{id}`         | Fetch a single district                      |
| POST   | `/auth/register`          | Create new user and receive JWT              |
| POST   | `/auth/login`             | Authenticate existing user                   |

### 8.2 Profile & Account (Authorization required)

| Method | Path               | Notes                                                       |
|--------|--------------------|-------------------------------------------------------------|
| GET    | `/auth/profile`    | Returns full user object                                    |
| PUT    | `/auth/profile`    | Body `{ "name": "...", "language": "ru" }`                  |
| POST   | `/auth/change-password` | Body `{ "old_password": "...", "new_password": "...", "confirm_new_password": "..." }` |
| POST   | `/auth/avatar`     | `multipart/form-data` with `avatar` file (max 10MB, jpg/png/gif) |

Avatar responses include the relative path (e.g. `avatars/<file>.jpg`). Retrieve via `/uploads/avatars/<file>.jpg`.

### 8.3 Orders (User + Driver roles)

#### Create Taxi Order
`POST /orders/taxi`

```json
{
  "customer_name": "John Doe",
  "customer_phone": "+998901234567",
  "from_region_id": 1,
  "from_district_id": 5,
  "to_region_id": 2,
  "to_district_id": 12,
  "passenger_count": 2,
  "scheduled_date": "15.11.2025",
  "time_range_start": "09:00",
  "time_range_end": "11:00",
  "notes": "Call before arrival"
}
```

Optional fields: `from_latitude`, `from_longitude`, `from_address`, `to_latitude`, `to_longitude`, `to_address`.

The backend calculates pricing using region pricing + passenger discounts. Rejections include misconfigured pricing (`400`) or identical regions.

#### Create Delivery Order
`POST /orders/delivery` with additional fields:

```json
{
  "recipient_phone": "+998907654321",
  "delivery_type": "document"
}
```

#### Order Management

| Method | Path                    | Description                                                       |
|--------|------------------------|-------------------------------------------------------------------|
| GET    | `/orders/my`           | Query params: `status`, `type`                                    |
| GET    | `/orders/{id}`         | Returns full order (users see their orders, drivers/admins see all) |
| POST   | `/orders/{id}/cancel`  | Body `{ "reason": "..." }`; valid while status is `pending` or `accepted` |

Cancelling an accepted order refunds the driver's service fee and records a transaction.

### 8.4 Ratings

| Method | Path                    | Description                                   |
|--------|------------------------|-----------------------------------------------|
| POST   | `/ratings`             | Body `{ "order_id": 12, "rating": 5, "comment": "Great ride" }` |
| GET    | `/ratings/driver/{id}` | List all ratings for a driver                 |

Only completed orders can be rated once.

### 8.5 Notifications

| Method | Path                         | Description                               |
|--------|------------------------------|-------------------------------------------|
| GET    | `/notifications`             | Optional query `unread=true`               |
| POST   | `/notifications/{id}/read`   | Marks notification as read                |

Notifications include titles, messages, type (e.g. `new_order`), and optional `related_id`.

### 8.6 Feedback

| Method | Path        | Description                         |
|--------|-------------|-------------------------------------|
| POST   | `/feedback` | Body `{ "message": "Add cashback" }`|

Feedback is stored for admins and can be viewed via `/admin/feedback`.

### 8.7 Driver-Specific

| Method | Path                                 | Notes                                                                                |
|--------|--------------------------------------|--------------------------------------------------------------------------------------|
| POST   | `/driver/apply`                      | `multipart/form-data` with `full_name`, `car_model`, `car_number`, `license_image`   |
| GET    | `/driver/profile`                    | Requires driver/admin role                                                          |
| PUT    | `/driver/profile`                    | Update `full_name`, `car_model`, `car_number`                                       |
| GET    | `/driver/orders/new`                 | Filters: `type`, `from_region`, `to_region`; lists pending orders with active deadline |
| POST   | `/driver/orders/{id}/accept`         | Deducts service fee from driver balance if balance >= fee                            |
| POST   | `/driver/orders/{id}/complete`       | Marks accepted order as completed                                                    |
| GET    | `/driver/orders`                     | Lists driver’s orders (`status` filter optional)                                     |
| GET    | `/driver/statistics`                 | Optional `period` (`daily`, `monthly`, `yearly`)                                     |

Accepting an order requires the driver's `balance` to cover the order's `service_fee`. Transactions are created automatically for debits/credits.

### 8.8 Admin & Superadmin (Staff Apps)
These routes are guarded by role middleware. Only include them if the mobile app targets back-office functionality.

| Method | Path                                       | Role            | Purpose                                                |
|--------|--------------------------------------------|-----------------|--------------------------------------------------------|
| GET    | `/admin/driver-applications`               | admin+          | List applications (`status` filter)                    |
| POST   | `/admin/driver-applications/{id}/review`   | admin+          | Body `{ "status": "approved"|"rejected", "rejection_reason": "..." }` |
| GET    | `/admin/drivers`                           | admin+          | Optional `status` filter                               |
| POST   | `/admin/drivers/{id}/add-balance`          | admin+          | Body `{ "amount": 50000 }`                             |
| POST   | `/admin/users/{id}/block`                  | admin+          | Body `{ "is_blocked": true }`                          |
| POST   | `/admin/pricing`                           | admin+          | Manage inter-region pricing                           |
| GET    | `/admin/pricing`                           | admin+          | List pricing entries                                   |
| GET    | `/admin/orders`                            | admin+          | Filters: `status`, `type`, `from_date`, `to_date`     |
| GET    | `/admin/statistics`                        | admin+          | Platform metrics                                       |
| GET    | `/admin/feedback`                          | admin+          | Read user feedback                                     |
| POST   | `/admin/regions`                           | admin+          | Create region                                          |
| PUT    | `/admin/regions/{id}`                      | admin+          | Update region (partial)                                |
| DELETE | `/admin/regions/{id}`                      | admin+          | Delete region                                          |
| POST   | `/admin/districts`                         | admin+          | Create district                                        |
| PUT    | `/admin/districts/{id}`                    | admin+          | Update district (partial)                              |
| DELETE | `/admin/districts/{id}`                    | admin+          | Delete district                                        |
| POST   | `/admin/create-admin`                      | superadmin only | Create new admin user                                  |
| POST   | `/admin/users/{id}/reset-password`         | superadmin only | Body `{ "new_password": "..." }`                       |

---

## 9. File Uploads
- Upload directory defaults to `./uploads` (configurable via `UPLOAD_DIR`).
- Accepted image extensions: `.jpg`, `.jpeg`, `.png`, `.gif`.
- `license_image` and `avatar` uploads store the relative path, which the API returns. Serve them via `/uploads/<relative_path>`.
- Max upload size defaults to 10 MB (`MAX_UPLOAD_SIZE`).

To upload from mobile:
1. Build a multipart request with the file part (`Content-Type: image/jpeg` etc.).
2. Include other form fields as simple text fields.

---

## 10. Pricing & Discounts
- Pricing is managed by admins via `/admin/pricing`.
- Taxi price calculation (`CreateTaxiOrder`):
  1. `base_price + (price_per_person × passenger_count)`
  2. Apply discount from the `discounts` table (per passenger count).
  3. Service fee = percentage of the discounted amount.
  4. Final price = discounted price + service fee.
- Delivery orders reuse the same base pricing with a passenger count of 1.

If pricing is missing for a route, the API returns `400` with `pricing not configured for this route`.

---

## 11. Status & Notification Flow (Driver Orders)
1. **pending** — order created and visible to drivers. Drivers can accept until `accept_deadline` (~5 minutes).
2. **accepted** — assigned to a driver; service fee is deducted and a transaction recorded.
3. **in_progress** — reserved for mid-trip state (not yet exposed).
4. **completed** — driver marks order complete; user can rate driver.
5. **cancelled** — user cancels pending/accepted order. If accepted, driver fee is refunded.

Notifications (`notifications` table) are generated for key events (new orders, application review, etc.) and should be polled periodically by the mobile app.

---

## 12. Environment Configuration Highlights
- `SERVER_HOST`, `SERVER_PORT` determine binding address.
- `JWT_SECRET` must match between backend and any service validating tokens.
- `CORS_ALLOWED_ORIGINS` controls frontend/mobile origins permissible for browsers; native apps can ignore.
- Database credentials (`DB_*`) must be set before startup.

---

## 13. Suggested Integration Checklist
1. **Setup**: Configure base URL per environment, implement HTTP client with JWT header support.
2. **Onboarding**: Implement forms for register/login, handle validation errors surfaced by API.
3. **Localization**: Store and send `language` preference; backend defaults to `uz_latin`.
4. **Location Data**: Cache region/district lists client-side; refresh periodically.
5. **Orders**: Validate input (dates, passenger counts, delivery type) before submission. Display calculated prices returned from API.
6. **Driver Mode**: Gate driver-only screens by role, fetch latest balance/stats on screen entry.
7. **Notifications**: Poll `/notifications` (or set up push once backend supports it); mark read after user interaction.
8. **Error Handling**: Surface `error` messages and watch for `401` / `403` to trigger logout or re-authentication.
9. **File Uploads**: Compress images before upload to stay under 10 MB limit.

---

With this document embedded in your mobile project, an AI or developer can map UI flows to backend capabilities, build test scripts, or wire data bindings with minimal additional context.
