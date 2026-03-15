# FootyTrack - 野球记

A cross-platform football (soccer) training tracker that captures GPS, heart rate, and motion data from wearable devices, syncs to a cloud backend, and delivers detailed performance analytics.

## Features

- **Real-time Tracking** — GPS trajectory, speed, heart rate, distance via Apple Watch / WearOS
- **Performance Analytics** — Sprint detection, speed zones, calorie estimation, fatigue analysis
- **Heatmap** — Spatial activity heatmap overlaid on real maps (MapKit / Google Maps)
- **Slack Index (摸鱼指数)** — Gamification metric (0-100) measuring on-field effort
- **Cloud Sync** — Local-first architecture with cloud backup and multi-device restore
- **Team System** — Create/join teams via invite codes, view team member stats
- **Badge System** — Auto-awarded achievements based on performance thresholds
- **Multi-Auth** — Username/password, SMS verification, WeChat OAuth

## Architecture Overview

```
┌─────────────┐    ┌─────────────┐
│  Apple Watch │    │   WearOS    │
│   (SwiftUI) │    │  (Compose)  │
└──────┬──────┘    └──────┬──────┘
       │ WatchConnectivity │ Wearable DataLayer
       ▼                   ▼
┌─────────────┐    ┌─────────────┐
│   iOS App   │    │ Android App │
│  (SwiftUI)  │    │  (Compose)  │
└──────┬──────┘    └──────┬──────┘
       │  REST API (JWT)  │
       └────────┬─────────┘
                ▼
        ┌──────────────┐
        │  Ktor Server │
        │ (PostgreSQL) │
        └──────────────┘
```

## Tech Stack

| Layer | iOS | Android | WearOS | Server |
|---|---|---|---|---|
| UI | SwiftUI | Jetpack Compose | Jetpack Compose | — |
| Database | SwiftData | Room | — | PostgreSQL (Exposed) |
| HTTP | URLSession | Retrofit + OkHttp | — | Ktor |
| Auth | UserDefaults | DataStore | — | JWT + BCrypt |
| Sensors | CoreLocation, HealthKit | FusedLocation, Health Services | FusedLocation, Health Services | — |
| Watch Sync | WatchConnectivity | Wearable DataLayer | Wearable DataLayer | — |
| Shared Logic | KMP Framework | KMP Library | KMP Library | — |

## Project Structure

```
football-tracker/
├── ios-app/                        # iOS + watchOS
│   ├── FootballTracker/            #   iPhone app (SwiftUI + SwiftData)
│   │   ├── Views/                  #     Home, Detail, Stats, Profile, Settings...
│   │   ├── Data/SessionStore.swift #     SwiftData models + analysis
│   │   ├── Auth/                   #     AuthManager, CloudSync
│   │   ├── Network/               #     ApiClient, ApiModels
│   │   ├── Sync/WatchSync.swift    #     Watch data receiver + geocoding
│   │   └── Components/            #     HeatmapOverlay, SpeedChart
│   └── FootballTrackerWatch/       #   watchOS app
│       ├── Tracking/               #     GPS + HealthKit + workout session
│       └── Sync/                   #     Phone data transfer
│
├── android-app/                    # Android phone app
│   ├── ui/screens/                 #   12+ Compose screens
│   ├── ui/components/              #   HeatmapOverlay, SpeedChart, StatCard
│   ├── auth/                       #   AuthRepository (SMS, WeChat, password)
│   ├── data/db/                    #   Room entities + DAOs
│   ├── data/repository/            #   SessionRepo, CloudSessionSync
│   └── network/                    #   Retrofit ApiClient
│
├── wearos-app/                     # WearOS watch app
│   ├── tracking/                   #   GpsTracker (foreground service), HeartRateTracker
│   ├── sync/                       #   DataLayerSync (Wearable API)
│   └── ui/                         #   TrackingScreen, SummaryScreen
│
├── shared/                         # Kotlin Multiplatform (KMP)
│   └── src/commonMain/kotlin/
│       ├── model/                  #   TrackPoint, Session, SessionStats
│       ├── analysis/               #   SessionAnalyzer, algorithms
│       └── util/GeoUtils.kt       #   Haversine distance
│
└── server/                         # Ktor backend
    ├── routes/                     #   Auth, User, Session, Team, Badge APIs
    ├── service/                    #   Business logic + external integrations
    ├── auth/                       #   JwtService, SmsCodeStore
    ├── db/tables/                  #   Exposed table definitions
    ├── plugins/                    #   CORS, serialization, auth, routing
    ├── Dockerfile
    └── docker-compose.yml
```

## Shared Analysis Algorithms (KMP)

All performance analysis lives in the `:shared` Kotlin Multiplatform module, compiled to a Swift framework for iOS and a Kotlin library for Android/WearOS. This ensures consistent results across all platforms.

| Algorithm | Description |
|---|---|
| **Distance** | Haversine formula, cumulative between consecutive GPS points |
| **Speed** | m/s to km/h conversion; avg, max, zone distribution |
| **Sprints** | Continuous segments where speed >= 18 km/h |
| **Calories** | Keytel formula (HR-based) with MET fallback by speed zone |
| **Slack Index** | Weighted: 35% standing + 25% low speed + 20% coverage + 20% low HR |
| **Fatigue** | 5-minute segment analysis (distance, avg speed, avg HR) |
| **Heatmap** | 50x30 grid, normalized by max cell count |

## Server API

### Auth

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/auth/register` | Username/password registration |
| POST | `/api/auth/login` | Username/password login |
| POST | `/api/auth/sms/send` | Send SMS verification code |
| POST | `/api/auth/sms/verify` | Verify SMS code, return JWT |
| POST | `/api/auth/wechat` | WeChat OAuth exchange |

### User & Sessions (JWT required)

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/user/profile` | Fetch user profile |
| PUT | `/api/user/profile` | Update nickname, weight, age |
| POST | `/api/sessions/sync` | Batch upload sessions |
| GET | `/api/sessions` | Fetch user sessions |

### Teams & Badges (JWT required)

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/teams` | Create team |
| GET | `/api/teams` | List user's teams |
| POST | `/api/teams/join` | Join team by invite code |
| GET | `/api/badges/earned` | User's earned badges |
| POST | `/api/badges/check` | Check & award new badges |

## Data Flow

```
Watch Sensors (GPS + HR)
        │
        ▼ WatchConnectivity / Wearable DataLayer
Phone App receives raw arrays
        │
        ▼ KMP SessionAnalyzer
Compute stats (distance, speed, calories, slack, heatmap, fatigue)
        │
        ├──▶ Save to local DB (SwiftData / Room)
        │
        └──▶ Sync to cloud (REST API + JWT)
                │
                ▼
        PostgreSQL (Exposed ORM)
```

## Build & Run

### iOS

```bash
xcodebuild -project ios-app/FootballTracker.xcodeproj \
  -scheme FootballTracker \
  -destination 'generic/platform=iOS' build
```

### Android

```bash
./gradlew :android-app:assembleDebug
```

### WearOS

```bash
./gradlew :wearos-app:assembleDebug
```

### Server

```bash
cd server
docker-compose up -d
```

Or manually:

```bash
./gradlew :server:buildFatJar
java -jar server/build/libs/football-tracker-server.jar
```

## License

Private project. All rights reserved.
