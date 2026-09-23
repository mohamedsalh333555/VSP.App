> **Current SSOT notice (2026-09-23):** `SYSTEM_SSOT.md` is the authoritative current architecture. Supabase Auth/PostgreSQL/Realtime/Storage/Edge Functions are the primary backend. Firebase is auxiliary only for FCM, Analytics, and Crashlytics; Firebase Auth and Firestore are not part of the active runtime.

# VSP (Vision Sports Performance) — Application Architecture & Guidelines

Single Source of Truth (SSOT) for tech stack, system architecture, module connections, database schema, screen routing map, and engineering rules for `vsp_application`.

---

## 1. Tech Stack & Environment

- **Framework**: Flutter SDK 3.32.8 (Dart 3.8.1)
- **Primary Backend, Auth & Realtime DB**: Supabase (`supabase_flutter` ^2.15.4)
- **Auxiliary Mobile Services**: Firebase Messaging, Analytics, and Crashlytics only; no Firebase Auth/Firestore
- **State Management**: Provider (`provider` ^6.1.1)
- **Design System Tokens**: Custom VSP Design Tokens (`VSPColors`, `VSPRadius`, `VSPSpacing`, `VSPShadow`)
- **Icons**: `lucide_icons_flutter`, `font_awesome_flutter`
- **Localization**: Multi-language support (`l10n`, `app_ar.arb`, `app_en.arb`)

---

## 2. Directory Structure & Layer Responsibilities

```text
lib/
├── main.dart                      # App entry point, Supabase + auxiliary Firebase initialization, Provider tree setup
├── firebase_options.dart          # Firebase project configuration
├── core/
│   ├── models/                    # Domain data models (UserModel, etc.)
│   ├── providers/                 # State management providers
│   │   ├── auth_provider.dart     # Authentication & user profile state
│   │   ├── booking_provider.dart  # Booking operations, schedule state, challenge submissions
│   │   ├── stadium_provider.dart  # Stadium listings, owner pitch management
│   │   └── language_provider.dart # App locale state (Arabic / English)
│   ├── repositories/              # Supabase & DB access abstraction layer
│   │   ├── booking_repository.dart    # Supabase booking RPCs, status updates, cancellation
│   │   ├── stadium_repository.dart    # Stadium fetching, verification status
│   │   ├── team_repository.dart       # Teams, rosters, Elo calculations
│   │   ├── tournament_repository.dart # Tournaments, bracket generation, championship state
│   │   ├── user_repository.dart       # User profiles, no-show tracking
│   │   ├── chat_repository.dart       # Realtime match chat streams
│   │   ├── notification_repository.dart # In-app notification delivery
│   │   └── [match, league, owner, report, search, app_settings]_repository.dart
│   ├── services/                  # Business logic & external service integrations
│   │   ├── database_service.dart      # Realtime match streams & public match queries
│   │   ├── notification_handler.dart  # Push notification triggers & payload formatting
│   │   ├── notification_service.dart  # Local FCM background listener & channels
│   │   ├── location_service.dart      # Geolocator & stadium distance math
│   │   ├── storage_service.dart       # Supabase image/document upload & deletion
│   │   ├── analytics_service.dart     # Event logging
│   │   └── [auth, logger, stats, support, owner_document, remote_config, sharing]_service.dart
│   ├── ui/                        # Design System Tokens
│   │   └── tokens/vsp_tokens.dart # Palette (Accent, Background, Surface), Radius, Spacing
│   ├── utils/                     # Utilities (PhoneUtils, VSPFeedback, etc.)
│   └── localization/              # Locale helpers
├── data/
│   └── models.dart                # Consolidated domain models export (Booking, Stadium, Team, etc.)
├── features/                      # Feature Modules (Screens & Widgets)
│   ├── auth/                      # Authentication Flow
│   │   └── screens/               # Splash, Welcome, Login, Signup, Verify Email, Onboarding
│   ├── player/                    # Player App Flow
│   │   ├── screens/               # Home, Stadium Details, Booking Type, Booking Confirmation, Bookings History, Chat, League, Profile
│   │   └── widgets/               # Player-specific UI components & modals
│   ├── owner/                     # Facility Owner App Flow
│   │   └── screens/               # Owner Main, Dashboard, Owner Bookings (Schedule Grid), Add Stadium Wizard, Tournament Dashboard, Subscription Plans
│   └── admin/                     # Super Admin Dashboard
│       └── screens/               # Admin Dashboard (Verification, Manual plan override, Elo approval)
├── shared/                        # Shared Reusable Widgets (PrimaryButton, VSPCard, VSPEmptyState, PublicMatchCard, etc.)
└── l10n/                          # Localization ARB files & generated localizations
```

---

## 3. Core Architecture & Feature Connections

### 🔐 Auth & Identity Flow (`lib/features/auth`)

- **Flow**: `SplashScreen` ➔ `WelcomeScreen` ➔ `LoginScreen` / `SignupScreen` ➔ `VerifyEmailScreen` ➔ Role Router (`PlayerHomeScreen` vs `OwnerMainScreen`).
- **State**: Managed via `AuthProvider` (`auth_provider.dart`) wrapping `AuthService` (Supabase Auth) & `UserRepository` (Supabase `users` table).

### ⚽ Player Booking Flow (`lib/features/player`)

- **Flow**: `PlayerHomeScreen` ➔ `StadiumDetailsScreen` ➔ `BookingTypeScreen` (Individual/Team/Challenge) ➔ `BookingConfirmationScreen` ➔ `PaymentGatewayScreen` ➔ `BookingSuccessScreen`.
- **State**: Managed via `BookingProvider` (`booking_provider.dart`). Atomic booking creation executed on Postgres via RPC `create_booking_atomic` to guarantee 0 double-bookings under high concurrency.

### 🏟️ Owner Facility & Schedule Management (`lib/features/owner`)

- **Flow**: `OwnerMainScreen` ➔ `OwnerDashboardScreen` ➔ `OwnerBookingsScreen` (Time-slot schedule grid) ➔ `AddStadiumWizard` / `SubscriptionPlansScreen`.
- **Key Rules**:
  - Cancelled bookings (`status == 'cancelled'`) are filtered out of active time-slot grids.
  - Total Pitch Revenue ("إجمالي أرباح الملعب") only registers for completed bookings (`b.status == BookingStatus.completed || b.endTime.isBefore(now)`).
  - Owners in `free_trial` see remaining trial days on the dashboard banner with direct link to `SubscriptionPlansScreen` live countdown clock.

### 🏆 Tournaments & Challenges (`lib/core/repositories/tournament_repository.dart`)

- **Flow**: Challenge match creation ➔ Result submission ➔ Verification ➔ Automated Elo updates on Supabase.

---

## 4. Database Schema Overview (Supabase / PostgreSQL)

- **`users`**: `id`, `email`, `role`, `name`, `phone`, `is_blocked`, `no_show_count`, `subscription_plan`, `trial_ends_at`, `subscription_expires_at`, `verification_status`.
- **`stadiums`**: `id`, `owner_id`, `name`, `price_per_hour`, `opening_time`, `closing_time`, `features`, `is_verified`, `is_deleted_by_owner`.
- **`bookings`**: `id`, `stadium_id`, `created_by_user_id`, `owner_id`, `start_time`, `end_time`, `booking_type`, `total_price`, `status` (`pending`, `confirmed`, `completed`, `cancelled`), `is_paid`, `payment_status`, `payment_transaction_id`.
- **`teams`**: `id`, `name`, `captain_phone`, `member_uids`, `points`, `wins`, `draws`, `losses`.
- **`reviews`**: `id`, `stadium_id`, `user_id`, `rating`, `review_text`.

---

## 5. SDLC Development Guidelines

1. **Always Plan Before Coding**: Spec-driven development with Given/When/Then, edge case mapping, step-by-step small increments. Modify code only after the user explicitly requests execution.
2. **Scientific Debugging**: No guessing. Stack trace examination ➔ 3 ranked hypotheses ➔ empirical log/test proof ➔ root cause fix + regression test.
3. **Instant Live Sync**: Development is continuously synced via `flutter run` on attached emulators. Perform Hot Reload (`r`) / Hot Restart (`R`) to verify UI changes without full reinstalls.
4. **Clean Code Hygiene**: Verify repo-wide search before deleting unused code/imports. Ensure clean compilation (`flutter analyze`) after every step.
