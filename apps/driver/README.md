# MSI Parcel Driver — v0.4

Fast. Reliable. Nearer to You.

Android app for MSI Parcel delivery drivers (Flutter).

## What the driver can do
1. **Sign in with mobile number**: SMS code (Firebase Phone Auth).
2. **Register**: full name, Iqama/ID number, city, vehicle, plate number, plus 3 photos (license, vehicle, selfie).
3. **Wait for approval**: the screen updates itself when the office approves or rejects. A rejected driver can fix the details and send again.
4. **Go online/offline**: while online, the GPS location is sent live so customers and admin can track.
5. **Deliveries**: Accept → Picked up → Out for delivery → enter the receiver's 4-digit code → Delivered.
6. **COD**: shows how much cash to collect; the driver confirms collection; the Earnings tab shows the cash they still need to hand over.
7. **Call / Map** buttons for sender and receiver.

## Demo mode vs live mode
- While `lib/firebase_options.dart` is the placeholder, the app runs in **demo mode**: everything works on the phone with sample data. The SMS code is `123456`, and a button simulates office approval.
- After `flutterfire configure` creates the real `firebase_options.dart`, the GitHub build switches to **live mode** automatically (`--dart-define=USE_FIREBASE=true`).

## Firebase setup (one time)
1. Create a Firebase project "msi-parcel" and upgrade it to the **Blaze** plan (needed for SMS and Cloud Functions; small usage is free).
2. Add an Android app with package `com.msibusinesscare.msi_parcel_driver` and these fingerprints (from `ci/debug.keystore`, used by every CI build):
   - SHA-1: `D0:73:6C:1F:61:AB:8E:CC:DE:36:B8:AC:71:74:81:F0:CF:11:A4:4B`
   - SHA-256: `6C:86:DC:CA:FD:8F:92:C8:F3:5D:91:E2:C0:49:B7:3D:A4:B4:64:5E:11:7B:52:76:3C:2A:98:ED:DF:7A:A7:8B`
3. Enable **Authentication → Phone**, **Firestore**, **Storage**.
4. Run `flutterfire configure` to make `lib/firebase_options.dart`.
5. Deploy rules and functions: `firebase deploy --only firestore:rules,storage,functions`.
6. Add at least one city: Firestore `service_zones/jeddah` = `{ name: "Jeddah", active: true }`.
7. Make the owner an admin: Firestore `users/<your uid>` = `{ role: "admin" }`.

> `ci/debug.keystore` is fine for private testing. Before publishing to Google Play, create a separate private release key and keep it out of the repository.

## Data (Firestore)
| Collection | Purpose |
|---|---|
| `users/{uid}` | role: driver / customer / admin |
| `drivers/{uid}` | profile, `status` pending/approved/rejected/suspended, `online`, `location`, `documents` |
| `orders/{id}` | `driverId`, `customerId`, `status`, addresses, receiver, `codAmount`, `deliveryFee` |
| `orders/{id}/private/otp` | delivery code: customer + admin only, never the driver |
| `order_events` | audit trail of every status change |
| `service_zones` | cities (not hardcoded to Jeddah) |
| `pricing_rules` | prices (Admin) |
| `cod_transactions` | cash collected per order |

Security: `firebase/firestore.rules` and `firebase/storage.rules`. Drivers can only see orders assigned to them, can only move a status forward by one step, and cannot mark an order delivered themselves. The `completeDelivery` Cloud Function checks the code on the server (5 tries max).

## Build
GitHub Actions (`.github/workflows/build-apk.yml`) builds `MSI-Parcel-Driver.apk` on every push to `main`. Download it from the run's **Artifacts** section.
