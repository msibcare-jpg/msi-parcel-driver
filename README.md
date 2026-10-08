# MSI Parcel

Fast. Reliable. Nearer to You. — parcel pickup & delivery platform by MSI Business Care.

| Folder | What |
|---|---|
| `apps/customer` | Customer app (Flutter): sign in with mobile, book parcels, live tracking with delivery code, order history dashboard, wallet |
| `apps/driver` | Driver app (Flutter): self-registration with documents, approval, online/GPS, delivery steps with OTP, COD, history dashboard, wallet |
| `backend` | Firebase: Firestore & Storage security rules, Cloud Functions (delivery code, server-side pricing, OTP check, wallets) |
| `ci` | Shared Android signing key for test builds and launcher icons |

## Download the apps
Every build publishes both APKs on the **Releases** page: `/releases/latest`.

## Modes
Until Firebase is configured (`flutterfire configure` in each app), both apps run in **demo mode** with sample data. SMS code in demo: `123456`.

## Money model
- Driver earns `driverSharePct` (default 80%) of each delivery fee. COD cash they collect is owed to the office until settled.
- Customer wallet receives COD collected for them and pays delivery fees. Positive balance can be withdrawn.
