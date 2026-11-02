# Derleng — Flutter travel app

Derleng lets you discover trending places, search for one, see it on a map,
preview the route for driving, walking, transit or cycling, save favourites, and
hand navigation over to Google Maps.

The app ships with a complete **demo mode** (sample Phnom Penh data, fake auth,
on-device favourites) and is wired for a **Laravel backend** that proxies Google
Places and Directions. Switching between the two is a runtime toggle in the
Profile tab or a compile-time flag.

## Features

- **Auth** — email/password sign-in, registration, forgot-password dialog,
  Google button, session persistence. Demo and API implementations share one
  `AuthRepository` interface.
- **Home** — trending feed of community posts with photo/video covers, viral
  ranking, like and save actions, and a "Viral right now" carousel that opens
  the place directly on the map.
- **Explore** — debounced search with recent searches, nearby category chips
  (restaurants, cafés, hotels, attractions, parks, markets), interactive map,
  place sheet with rating/address, travel-mode switcher, live route summary,
  favourite toggle, "Start navigation" via Google Maps.
- **Map** — native `google_maps_flutter` when an API key is configured, otherwise
  a built-in interactive `MapCanvas` (roads, water, route line, markers) so the
  app runs without any Google key.
- **Saved** — local-first favourites with undo, synced to the API when live.
- **Profile** — demo-data switch, theme picker, editable API base URL,
  connection test, backend integration notes, sign out.
- **Theming** — Material 3 light/dark theme.

## Requirements

- Flutter 3.47+ / Dart 3.13+
- Android Studio (Android) or Xcode (iOS); Chrome/Edge or Windows for a quick
  preview

## Quick start

```bash
flutter pub get
flutter run
```

The app starts in demo mode:

| Field    | Value                     |
| -------- | ------------------------- |
| Email    | `sokha.chan@derleng.app`  |
| Password | `derleng123`              |

Or tap **Use demo account** on the sign-in screen. Any valid email with a
password of 6+ characters also works.

Demo mode is a self-contained Phnom Penh sample: "near me", nearby categories and
routes are anchored to the city center so distances stay meaningful even when the
device GPS reports another location.

Preview targets:

```bash
flutter run -d chrome     # web
flutter run -d windows    # Windows desktop
flutter run               # connected Android/iOS device
```

## Connecting the Laravel API

1. Start the backend (default `http://localhost:8000/api`).
2. Run the app with demo mode disabled:

   ```bash
   # Android emulator (10.0.2.2 reaches the host machine)
   flutter run --dart-define=DEMO_MODE=false \
     --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
   ```

   ```bash
   # iOS simulator / desktop / web
   flutter run --dart-define=DEMO_MODE=false \
     --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
   ```

   On a physical device use your machine's LAN IP, e.g.
   `http://192.168.1.20:8000/api`.

3. Or change it at runtime: **Profile → Demo data** off, edit **API base URL**,
   then **Test connection** (calls `GET /health`). Settings persist in
   `SharedPreferences`.

Android debug builds allow cleartext HTTP to a local server. Use HTTPS in
release builds.

## API contract

The client sends `Accept: application/json` and, when signed in,
`Authorization: Bearer <token>` on every request. Laravel's `{ "data": ... }`
envelope is supported as well as a bare payload. Validation errors
(`errors: { field: [message] }`) are surfaced in the UI.

| Method | Endpoint               | Purpose                              |
| ------ | ---------------------- | ------------------------------------ |
| GET    | `/health`              | Connection test (any status < 500)   |
| POST   | `/auth/login`          | Email/password sign-in               |
| POST   | `/auth/register`       | Create an account                    |
| POST   | `/auth/forgot-password`| Send a reset link                    |
| POST   | `/auth/logout`         | Revoke the current token             |
| GET    | `/places/search?q=`    | Text search (min. 2 characters)      |
| GET    | `/places/nearby`       | Nearby places by category            |
| GET    | `/feed?sort=trending`  | Trending community posts             |
| GET    | `/directions`          | Route between two points             |
| GET    | `/favorites`           | List saved places                    |
| POST   | `/favorites`           | Save a place                         |
| DELETE | `/favorites/{id}`      | Remove a saved place                 |

### Auth payloads

`POST /auth/login`

```json
{ "email": "user@example.com", "password": "secret123" }
```

`POST /auth/register`

```json
{
  "name": "Sokha Chan",
  "email": "user@example.com",
  "password": "secret123",
  "device_name": "derleng-app"
}
```

Both return:

```json
{
  "user": { "id": 1, "name": "Sokha Chan", "email": "user@example.com" },
  "token": "1|laravel-sanctum-token"
}
```

`access_token` is accepted as an alias for `token`. The stored token is attached
to later requests; a `401` signs the user out with a "session expired" message.

### Places

`GET /places/search?q=wat` returns a list (or `{ "data": [...] }`) of:

```json
{
  "id": "ChIJ...",
  "name": "Wat Phnom",
  "address": "Daun Penh, Phnom Penh",
  "location": { "lat": 11.5761, "lng": 104.9231 },
  "category": "attraction",
  "rating": 4.5,
  "rating_count": 1200
}
```

`category`, `rating` and `rating_count` are optional. Google-style field names
(`displayName`, `formattedAddress`, `place_id`, `lat`/`lng` at the top level) are
also understood.

### Nearby places

`GET /places/nearby?lat=11.5564&lng=104.9282&category=restaurant&radius=4000`

Returns the same place list shape as search. Supported categories:

| Category     | Google Places type(s) to proxy            |
| ------------ | ----------------------------------------- |
| `restaurant` | `restaurant`                              |
| `cafe`       | `cafe`                                    |
| `hotel`      | `lodging`                                 |
| `attraction` | `tourist_attraction` (+ landmark/temple)  |
| `park`       | `park`                                    |
| `market`     | `market` / `shopping_mall`                |

`radius` is in meters (default `4000`). The demo repository filters the bundled
Phnom Penh places by category and sorts them by distance from the map center.

### Trending feed

`GET /feed?sort=trending&limit=20` returns a list (or `{ "data": [...] }`) of
community posts, most viral first:

```json
{
  "id": "post-1",
  "author": { "name": "Sokha Chan", "avatar_url": "https://..." },
  "caption": "Sunrise over the Royal Palace",
  "place": {
    "id": "royal-palace",
    "name": "Royal Palace",
    "address": "Daun Penh, Phnom Penh",
    "location": { "lat": 11.5639, "lng": 104.9308 },
    "category": "landmark",
    "rating": 4.6
  },
  "image_url": "https://...",
  "video_url": null,
  "likes": 2840,
  "comments": 128,
  "saves": 412,
  "trending_score": 98,
  "created_at": "2026-10-31T05:40:00Z"
}
```

`image_url` and `video_url` are optional; when both are missing the card shows a
category-coloured placeholder. `media: { "type": "image|video", "url": "...",
"poster": "..." }` is accepted as an alternative shape, as are flat
`author_name` / `place` fields. Video posts show a play badge and open the video
URL in the platform browser.

Likes are optimistic and local until `POST /feed/{id}/like` is added. Saving a
post calls the same favourites endpoints as the rest of the app.

### Directions

`GET /directions?origin=11.55,104.92&destination=11.57,104.93&mode=driving`

`mode` is one of `driving`, `walking`, `transit`, `bicycling`. Response:

```json
{
  "polyline": "encoded-polyline",
  "distance": "1.2 km",
  "duration": "8 min",
  "distance_meters": 1200,
  "duration_seconds": 480,
  "mode": "driving"
}
```

`polyline` may be replaced by `points: [{ "lat": ..., "lng": ... }]` or
`[[lat, lng], ...]`. If the encoded line cannot be decoded the client draws a
straight segment, so the map is never left blank.

### Favourites

`GET /favorites` returns a list of place objects (same shape as search).
`POST /favorites` accepts a place object; `DELETE /favorites/{id}` removes it.
The local cache is the source of truth for the UI, so saving/removing works
offline and sync failures never block the user.

## Google Maps

The app only mounts the native map when a key is present; otherwise it uses the
built-in `MapCanvas` fallback. To enable Google Maps:

**Android** — add the key to `android/local.properties` (already git-ignored):

```properties
MAPS_API_KEY=your-android-maps-sdk-key
```

The Gradle build injects it into `AndroidManifest.xml` as
`com.google.android.geo.API_KEY`. Also pass the key to Flutter so it renders the
native view:

```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=your-android-maps-sdk-key
```

**iOS** — `NSLocationWhenInUseUsageDescription` is already in
`ios/Runner/Info.plist`. Add the key in `ios/Runner/AppDelegate.swift`:

```swift
import GoogleMaps

// inside application(_:didFinishLaunchingWithOptions:), before super
GMSServices.provideAPIKey("your-ios-maps-sdk-key")
```

and run with `--dart-define=GOOGLE_MAPS_API_KEY=...` as above.

Keep the Places/Directions server key on Laravel only — the app never holds it.

## Configuration reference

| `--dart-define`       | Default                      | Notes                                  |
| --------------------- | ---------------------------- | -------------------------------------- |
| `API_BASE_URL`        | `http://10.0.2.2:8000/api`   | Laravel API root                       |
| `DEMO_MODE`           | `true`                       | `false` uses the live API              |
| `GOOGLE_MAPS_API_KEY` | empty                        | Enables the native Google map          |

Runtime overrides (theme, demo mode, base URL) live in
`lib/core/storage/settings_store.dart` and are editable from Profile.

## Project structure

```
lib/
├── main.dart                  # loads settings/session, injects providers
├── app.dart                   # MaterialApp, theme, AuthGate
├── core/
│   ├── config/app_config.dart # dart-define flags, defaults
│   ├── network/               # Dio client + error mapping
│   ├── storage/               # SharedPreferences stores
│   ├── theme/                 # light/dark Material 3 theme
│   ├── utils/                 # polyline decoder, formatters, validators
│   └── widgets/               # shared UI pieces
├── data/
│   ├── demo/demo_data.dart    # sample places, routes and feed posts
│   ├── repositories/          # auth, places, feed, favourites (API + demo)
│   ├── services/              # geolocator wrapper
│   └── providers.dart         # Riverpod wiring
├── features/
│   ├── auth/                  # login, register, auth gate/controller
│   ├── explore/               # map, search, place sheet, map canvas
│   ├── favorites/             # saved places
│   ├── home/                  # trending feed, post cards, feed controller
│   ├── profile/               # settings + backend guide
│   ├── settings/              # settings controller
│   └── shell/                 # bottom navigation shell
└── models/                    # Place, PlacePost, RouteInfo, AppUser, ...
```

## Auth: swapping in Firebase

`AuthRepository` (`lib/data/repositories/auth_repository.dart`) is the seam.
`DemoAuthRepository` is used in demo mode, `ApiAuthRepository` in live mode. To
use Firebase Auth instead:

1. Add `firebase_core`, `firebase_auth`, `google_sign_in` and run
   `flutterfire configure`.
2. Call `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
   in `main()`.
3. Implement `FirebaseAuthRepository implements AuthRepository`, mapping
   `FirebaseAuth.instance` calls to `AuthSession` and using
   `user.getIdToken()` as the bearer token.
4. Return it from `authRepositoryProvider` in `lib/data/providers.dart`.

The Laravel side then verifies Firebase ID tokens instead of Sanctum tokens
(see `derleng_tasks.md`, Task 5).

## Tests

```bash
flutter analyze   # no issues expected
flutter test      # widget + unit tests
```

## Roadmap (from `derleng_tasks.md`)

- Live turn-by-turn tracking with `Geolocator.getPositionStream`
- Post creation (photo/video upload) plus `POST /feed/{id}/like` and comments
- Khmer/English localization and dark map style
- Release signing, API key restrictions, rate limiting, Crashlytics
