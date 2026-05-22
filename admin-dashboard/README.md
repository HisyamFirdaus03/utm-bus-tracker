# UTM BusTracker — Admin Dashboard

React + Vite + MUI admin UI for managing routes, buses, and schedules. Talks to the same Django backend the mobile app uses; auth via Firebase Auth (admin role gate).

## First-time setup

1. **Register a Web app in Firebase Console**
   - Firebase Console → Project Settings → General → Your apps → "Add app" → Web (`</>`)
   - Name it e.g. "admin-dashboard"; you can skip Hosting setup
   - Copy the `firebaseConfig` snippet

2. **Create `.env.local`** at `admin-dashboard/.env.local`:
   ```env
   VITE_FIREBASE_API_KEY=...
   VITE_FIREBASE_AUTH_DOMAIN=utm-bustracker.firebaseapp.com
   VITE_FIREBASE_PROJECT_ID=utm-bustracker
   VITE_FIREBASE_STORAGE_BUCKET=utm-bustracker.appspot.com
   VITE_FIREBASE_MESSAGING_SENDER_ID=...
   VITE_FIREBASE_APP_ID=...
   VITE_API_BASE_URL=http://localhost:8000
   ```
   See `.env.example` for the full list of keys.

3. **Create an admin user** (one-off, from the backend):
   ```bash
   cd ../backend && source venv/bin/activate
   python manage.py seed_admin --email admin@utm.my --password admin123 --name "Test Admin"
   ```
   This sets `role=admin` as a Firebase custom claim. After running, the admin must sign in fresh — existing ID tokens won't have the claim until refreshed.

4. **Run the dev server**:
   ```bash
   npm install
   npm run dev
   ```
   Defaults to `http://localhost:5173`. The Django settings include `localhost:5173` in `CORS_ALLOWED_ORIGINS` by default.

## Structure

```
src/
├── api/              # axios client + per-resource modules + shared types
├── auth/             # Firebase Auth context + admin route gate
├── layout/           # AdminLayout (drawer + topbar)
├── pages/            # Dashboard, Routes, Buses, Schedules, Login
├── theme.ts          # MUI theme (UTM crimson)
├── firebase.ts       # Firebase init (reads from import.meta.env)
└── App.tsx           # router with protected admin tree
```

## Backend endpoints used

All admin writes require `role=admin` on the Firebase ID token — backend views return 403 otherwise.

| Method | Path | Used by |
|---|---|---|
| `GET` | `/api/routes/` | Dashboard, Routes, Buses, Schedules |
| `POST` | `/api/routes/create/` | Routes (Add) |
| `PATCH` | `/api/routes/<id>/update/` | Routes (Edit), Schedules (Save) |
| `DELETE` | `/api/routes/<id>/delete/` | Routes (Delete) |
| `GET` | `/api/routes/stops/` | Dashboard, Routes (stop picker) |
| `GET` | `/api/buses/` | Dashboard, Buses |
| `POST` | `/api/buses/create/` | Buses (Add) |
| `PATCH` | `/api/buses/<id>/update/` | Buses (Edit) |
| `DELETE` | `/api/buses/<id>/delete/` | Buses (Delete) |

## Notes

- The Schedules page is a convenience view — schedules are stored embedded on each route doc (`route.schedule = {departure_time, arrival_time, frequencies}`), so saving here just patches the route via `PATCH /api/routes/<id>/update/`.
- Driver assignment on the Buses page expects a raw Firebase UID. A future improvement is to fetch a user list and present a dropdown; for now, get the UID from the `users` Firestore collection or from `seed_driver`'s output.
- UC12 (admin feedback response) is **not implemented** — `admin_response` field is already on the backend `feedbacks` doc; needs `PATCH /api/feedbacks/<id>/respond/` + a Feedback page.
