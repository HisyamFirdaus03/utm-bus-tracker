# Design Changes from SDD

Changes made during implementation that differ from the original SDD document.
Update the SDD document to reflect these changes after development is complete.

## 1. Flat User Model (no inheritance tables)

**SDD**: User → Student/Driver/Admin as separate entities with inheritance (3 sub-tables).

**Implementation**: Single `User` document with a `role` field (student/driver/admin) and optional role-specific fields (`matric_number`, `faculty`, `year`, `phone_no`, `assigned_bus_id`).

**Reason**: Matches the Flutter `AppUser` model already built. Simpler for Firestore (NoSQL — no joins). Avoids multi-collection lookups on every auth check.

## 2. Service Layer Pattern

**SDD**: Controller classes call models directly (e.g., `BusController → Bus`).

**Implementation**: Added a service layer between views and Firestore:
```
Views (HTTP) → Serializers (validation) → Services (business logic) → Firestore
```

**Reason**: Separates HTTP concerns from business logic. Makes it easy to swap Firestore for another database later without touching views or serializers. Improves testability.

## 3. BusStop as Separate Collection

**SDD**: BusStop referenced by BusRoute via FK.

**Implementation**: BusStop stored as a separate Firestore collection. BusRoute stores an ordered list of stop IDs. API returns stops nested inside the route response.

**Reason**: Stops can be reused across multiple routes. Supports independent querying for the demand prediction feature (UC07). Avoids data duplication.

## 4. Schedule Embedded in BusRoute

**SDD**: Schedule as a separate entity with 1:1 relationship to BusRoute.

**Implementation**: Schedule data (departure_time, arrival_time, frequencies) embedded as a nested object within the BusRoute Firestore document. API still exposes it as a nested JSON object.

**Reason**: Always accessed together with its route — embedding avoids an extra Firestore read per route query. Simpler data model for a 1:1 relationship in NoSQL.

## 5. Bus Model — Added Fields

**SDD**: Bus has `busName`, `plateNumber`, `capacity`, `currentLocation`, `status`, `driverId`, `routeId`.

**Implementation**: Kept all SDD fields. Added `speed` and `last_updated` fields to match the Flutter model (needed for real-time tracking UI). Location stored as separate `latitude`/`longitude` fields instead of a single `Location` object.

**Reason**: Flutter model already uses `speed` for display and `last_updated` for staleness checks. Separate lat/lng fields are simpler for Firestore queries and Google Distance Matrix API calls.

## 6. BusRoute — Added Fields

**SDD**: BusRoute has `routeId`, `routeName`, `stops`, `schedule`.

**Implementation**: Added `description`, `color` (hex string for map polyline), and `is_active` fields to match the Flutter `BusRoute` model.

**Reason**: `color` is needed for the map UI to distinguish routes visually. `description` provides user-facing route info. `is_active` supports soft-disable of routes without deletion.

## 7. Hybrid Driver-Input + GPS Validation for Next-Stop Tracking

**SDD**: Next-stop and ETA inferred entirely from the bus's GPS position (closest-stop heuristic).

**Implementation**: The driver app picks the **next stop** before starting location sharing, then writes that ID to RTDB on every heartbeat alongside the GPS coordinates (`/bus_locations/{busId}/next_stop_id`). The driver app auto-advances the next stop when the bus crosses the geofence (≤60 m haversine) of its current declared next stop, using the route's `order` field to pick the successor (wrapping for circular routes). Student-side code calls `pickNextStop(bus, route)` which prefers the driver-declared `next_stop_id` when present and valid, falling back to the existing `nextStopOnRoute()` polyline projection when absent (e.g., legacy heartbeats, simulator runs without `--next-stop`). The RTDB security rules added `next_stop_id` as an allowed string field on `/bus_locations/{busId}`.

**Reason**: Pure GPS inference produced visible bugs — "to KTR" when the bus was parked at KDSE, 27247-minute "ETAs" when projection picked the wrong segment on circular routes, fragile arrival detection. Real-world AVL systems combine driver input with GPS validation for exactly this reason: drivers know their own headsign with certainty, GPS confirms they're roughly where they say they are, and the system stays correct even when projection edge cases would otherwise fail. The fallback to `nextStopOnRoute` keeps the system functional for older drivers (or the `simulate_driver` command), so existing data paths don't break. `simulate_driver` was updated with a `--next-stop` flag and defaults to writing the successor in route order so the test path matches the production shape.
