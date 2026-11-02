# Derleng App — Implementation Tasks

Travel app: users search a place, see it on a map, and get directions.

**Stack:** Flutter (Dart) · Firebase Auth · Laravel API (proxy for Google APIs) · Google Maps

---

## Task 0 — Prerequisites

- [ ] Google Cloud project: enable **Maps SDK for Android/iOS**, **Places API**, **Directions API**
- [ ] Create Firebase project, add Android/iOS apps, run `flutterfire configure`
- [ ] Laravel API running (keep Google API key **server-side only**; the app only holds the Maps SDK key)

## Task 1 — Project Setup

```bash
flutter create derleng
cd derleng
flutter pub add firebase_core firebase_auth google_sign_in \
  google_maps_flutter geolocator permission_handler \
  dio flutter_riverpod flutter_polyline_points url_launcher
```

Folder structure:

```
lib/
├── main.dart
├── core/            # dio client, constants, theme
├── features/
│   ├── auth/        # login, auth repository
│   ├── search/      # place search, suggestions
│   └── map/         # map screen, directions
└── models/          # Place, RouteInfo
```

- [ ] Android: add Maps key to `AndroidManifest.xml`

```xml
<meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_MAPS_SDK_KEY"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

- [ ] iOS: add `NSLocationWhenInUseUsageDescription` to `Info.plist` and the key in `AppDelegate.swift`

## Task 2 — App Entry

```dart
// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'features/auth/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: DerlengApp()));
}

class DerlengApp extends StatelessWidget {
  const DerlengApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Derleng',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: const AuthGate(),
      );
}
```

## Task 3 — Authentication (Firebase)

- [ ] Email/password + Google sign-in enabled in Firebase console
- [ ] `AuthGate` routes by auth state

```dart
// lib/features/auth/auth_gate.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../map/map_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snap.hasData ? const MapScreen() : const LoginScreen();
        },
      );
}
```

```dart
// lib/features/auth/login_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  Future<void> _submit({required bool register}) async {
    setState(() => _loading = true);
    try {
      final auth = FirebaseAuth.instance;
      register
          ? await auth.createUserWithEmailAndPassword(
              email: _email.text.trim(), password: _password.text)
          : await auth.signInWithEmailAndPassword(
              email: _email.text.trim(), password: _password.text);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message ?? 'Auth error')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Derleng', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 32),
              TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : () => _submit(register: false),
                child: const Text('Sign in'),
              ),
              TextButton(
                onPressed: _loading ? null : () => _submit(register: true),
                child: const Text('Create account'),
              ),
            ]),
          ),
        ),
      );
}
```

## Task 4 — Models & API Client

```dart
// lib/models/place.dart
class Place {
  final String id, name, address;
  final double lat, lng;
  const Place({required this.id, required this.name, required this.address, required this.lat, required this.lng});

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        id: j['id'],
        name: j['name'],
        address: j['address'] ?? '',
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
      );
}
```

```dart
// lib/core/api_client.dart
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

final dio = Dio(BaseOptions(baseUrl: 'https://your-domain.com/api'))
  ..interceptors.add(InterceptorsWrapper(onRequest: (o, h) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token != null) o.headers['Authorization'] = 'Bearer $token';
    h.next(o);
  }));
```

## Task 5 — Laravel Backend (proxy + token verification)

- [ ] `composer require kreait/laravel-firebase` (verify Firebase ID tokens in middleware)
- [ ] Add `GOOGLE_MAPS_KEY` to `.env`

```php
// routes/api.php
Route::middleware('firebase.auth')->group(function () {
    Route::get('/places/search', [PlaceController::class, 'search']);
    Route::get('/directions',    [PlaceController::class, 'directions']);
});
```

```php
// app/Http/Controllers/PlaceController.php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class PlaceController extends Controller
{
    public function search(Request $r)
    {
        $r->validate(['q' => 'required|string|min:2']);

        $res = Http::withHeaders([
            'X-Goog-Api-Key'   => config('services.google.maps_key'),
            'X-Goog-FieldMask' => 'places.id,places.displayName,places.formattedAddress,places.location',
        ])->post('https://places.googleapis.com/v1/places:searchText', [
            'textQuery' => $r->q,
        ])->throw()->json('places', []);

        return collect($res)->map(fn ($p) => [
            'id'      => $p['id'],
            'name'    => $p['displayName']['text'] ?? '',
            'address' => $p['formattedAddress'] ?? '',
            'lat'     => $p['location']['latitude'],
            'lng'     => $p['location']['longitude'],
        ]);
    }

    public function directions(Request $r)
    {
        $r->validate([
            'origin'      => 'required|string',   // "lat,lng"
            'destination' => 'required|string',
            'mode'        => 'in:driving,walking,transit,bicycling',
        ]);

        $res = Http::get('https://maps.googleapis.com/maps/api/directions/json', [
            'origin'      => $r->origin,
            'destination' => $r->destination,
            'mode'        => $r->mode ?? 'driving',
            'key'         => config('services.google.maps_key'),
        ])->throw()->json();

        $leg = $res['routes'][0]['legs'][0] ?? null;
        abort_if(!$leg, 404, 'No route found');

        return [
            'polyline' => $res['routes'][0]['overview_polyline']['points'],
            'distance' => $leg['distance']['text'],
            'duration' => $leg['duration']['text'],
        ];
    }
}
```

## Task 6 — Location Service

```dart
// lib/features/map/location_service.dart
import 'package:geolocator/geolocator.dart';

Future<Position> getCurrentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw Exception('Location services are disabled');
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
    throw Exception('Location permission denied');
  }
  return Geolocator.getCurrentPosition();
}
```

## Task 7 — Map Screen (search + marker + route)

```dart
// lib/features/map/map_screen.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../models/place.dart';
import 'location_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _search = TextEditingController();
  GoogleMapController? _map;
  Timer? _debounce;

  LatLng? _me;
  Place? _selected;
  List<Place> _results = [];
  Set<Polyline> _polylines = {};
  String? _info; // "12 km · 25 min"

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    try {
      final p = await getCurrentPosition();
      setState(() => _me = LatLng(p.latitude, p.longitude));
      _map?.animateCamera(CameraUpdate.newLatLngZoom(_me!, 14));
    } catch (e) {
      _toast(e.toString());
    }
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final res = await dio.get('/places/search', queryParameters: {'q': q});
        setState(() => _results =
            (res.data as List).map((e) => Place.fromJson(e)).toList());
      } catch (_) {
        _toast('Search failed');
      }
    });
  }

  void _selectPlace(Place p) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selected = p;
      _results = [];
      _polylines = {};
      _info = null;
      _search.text = p.name;
    });
    _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(p.lat, p.lng), 15));
  }

  Future<void> _showRoute(String mode) async {
    if (_me == null || _selected == null) return;
    try {
      final res = await dio.get('/directions', queryParameters: {
        'origin': '${_me!.latitude},${_me!.longitude}',
        'destination': '${_selected!.lat},${_selected!.lng}',
        'mode': mode,
      });
      final points = PolylinePoints.decodePolyline(res.data['polyline'])
          .map((e) => LatLng(e.latitude, e.longitude))
          .toList();
      setState(() {
        _info = '${res.data['distance']} · ${res.data['duration']}';
        _polylines = {
          Polyline(
              polylineId: const PolylineId('route'),
              points: points,
              width: 5,
              color: Colors.teal),
        };
      });
      final bounds = _bounds(points);
      _map?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    } catch (_) {
      _toast('Could not get directions');
    }
  }

  Future<void> _startNavigation() async {
    final p = _selected;
    if (p == null) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${p.lat},${p.lng}&travelmode=driving');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _toast('Cannot open Maps');
    }
  }

  LatLngBounds _bounds(List<LatLng> pts) {
    double minLat = pts.first.latitude, maxLat = minLat;
    double minLng = pts.first.longitude, maxLng = minLng;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
        southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition:
              const CameraPosition(target: LatLng(11.5564, 104.9282), zoom: 12),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          polylines: _polylines,
          markers: {
            if (_selected != null)
              Marker(
                markerId: const MarkerId('dest'),
                position: LatLng(_selected!.lat, _selected!.lng),
                infoWindow: InfoWindow(title: _selected!.name),
              ),
          },
          onMapCreated: (c) => _map = c,
        ),
        // Search bar + results
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: TextField(
                  controller: _search,
                  onChanged: _onQueryChanged,
                  decoration: InputDecoration(
                    hintText: 'Where do you want to go?',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () => FirebaseAuth.instance.signOut(),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ),
              if (_results.isNotEmpty)
                Flexible(
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(_results[i].name),
                        subtitle: Text(_results[i].address,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => _selectPlace(_results[i]),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        // Bottom directions panel
        if (_selected != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_selected!.name, style: Theme.of(context).textTheme.titleMedium),
                  Text(_selected!.address),
                  if (_info != null) ...[
                    const SizedBox(height: 8),
                    Text(_info!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                  const SizedBox(height: 12),
                  Row(children: [
                    IconButton(icon: const Icon(Icons.directions_car), onPressed: () => _showRoute('driving')),
                    IconButton(icon: const Icon(Icons.directions_walk), onPressed: () => _showRoute('walking')),
                    IconButton(icon: const Icon(Icons.directions_transit), onPressed: () => _showRoute('transit')),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _startNavigation,
                      icon: const Icon(Icons.navigation),
                      label: const Text('Start'),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
      ]),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: _selected != null ? 170 : 0),
        child: FloatingActionButton.small(
          onPressed: _locate,
          child: const Icon(Icons.my_location),
        ),
      ),
    );
  }
}
```

## Task 8 — Next Features (backlog)

- [ ] Save favorite places (Laravel `favorites` table, keyed by Firebase UID)
- [ ] Search history
- [ ] Nearby categories (restaurants, hotels, attractions) via Places Nearby Search
- [ ] Live turn-by-turn tracking with `Geolocator.getPositionStream`
- [ ] Offline cache for saved places
- [ ] Khmer / English localization (`flutter_localizations`, `intl`)
- [ ] Dark map style

## Task 9 — Testing & Release

- [ ] Test on real Android + iOS devices (location permission flows)
- [ ] Restrict API keys (Maps SDK key by app ID/bundle ID; server key by IP)
- [ ] Add rate limiting on Laravel `/places/search` and `/directions`
- [ ] `flutter build appbundle --release` / `flutter build ipa`
- [ ] Crashlytics + Analytics via Firebase

===============================================================

more feature ideas:

- add buttom navigate bar with directions Home and the home tap has a new trend or viral place from user post almost there, it aslo have image, video for display user can view or save to favourite place.
- Add buttom Navigation bar Home and fetch display post from User post the place and the most viral place on trending .
