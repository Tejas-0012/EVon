# EVon Backend (Node.js + Express.js + MongoDB)

This is the modernized backend API server for the **EVon Smart EV Charging Management System**, replacing the monolithic Flask backend.

---

## 🚀 Features

- **Decoupled REST API Architecture**: Clean separation between controllers, services, routes, and Mongoose models.
- **JWT Authentication & RBAC**: Multi-role support (`user`, `station_admin`, `super_admin`) with password hashing via `bcryptjs`.
- **Geospatial MongoDB Engine**: Fast station lookup via MongoDB's native `$near` and `2dsphere` index.
- **Atomic Slot Reservation**: Prevents double-booking race conditions when multiple users book the same time slot concurrently.
- **Automated Charging Calculator**: Calculates energy required (kWh), charging duration, and pricing based on battery capacity and State of Charge (SoC).
- **ML Integration**: Connects seamlessly with the Python ML microservice (running on port 8000) for Random Forest demand prediction and Keras LSTM load forecasting. Includes resilient heuristic fallbacks if the ML service is offline.
- **Seeder Script**: Out-of-the-box seeding for Bangalore charging stations, admin accounts, and time slots.

---

## 📋 Installation & Running

### 1. Install Node Dependencies
```bash
npm install
```

### 2. Configure Environment Variables
Copy `.env.example` to `.env` (already created):
```bash
PORT=5000
MONGODB_URI=mongodb://localhost:27017/evon_db
JWT_SECRET=evon_super_secret_jwt_key_2026_charge_on
JWT_EXPIRES_IN=7d
COST_PER_KWH=12.0
ML_SERVICE_URL=http://localhost:8000
```
*(You can also use your cloud MongoDB Atlas connection string in `MONGODB_URI`)*.

### 3. Seed Database
```bash
npm run seed
```

### 4. Run Development Server
```bash
npm run dev
# or production mode:
npm start
```

API Server will be live at: `http://localhost:5000`

---

## 🔑 Default Credentials

| Role | Email | Password |
| :--- | :--- | :--- |
| **Super Admin** | `superadmin@evon.com` | `admin123` |
| **Station Admin** | `station1@evon.com` | `station123` |
| **Demo User** | `user@evon.com` | `user123` |

---

## 📡 Key API Endpoints

- **Auth**: `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/me`, `PUT /api/auth/profile`
- **Stations**: `GET /api/stations`, `GET /api/stations/nearby?lat=...&lng=...`, `GET /api/stations/:id`
- **Slots**: `GET /api/stations/:id/slots?date=YYYY-MM-DD`, `PUT /api/slots/:slotId`
- **Bookings**: `POST /api/bookings/quote`, `POST /api/bookings`, `GET /api/bookings/my`, `PUT /api/bookings/:id/cancel`
- **Payments**: `POST /api/payments`, `GET /api/payments/booking/:bookingId`
- **Recommendations**: `GET /api/recommendations/route?origin=koramangala&destination=whitefield`
- **ML Services**: `GET /api/ml/status`, `GET /api/ml/demand/station/:stationId`, `GET /api/ml/load/forecast`
- **Analytics**: `GET /api/analytics/overview`, `GET /api/analytics/station/:stationId`
