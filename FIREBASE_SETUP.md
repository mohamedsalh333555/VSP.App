# Firebase Integration Guide for VSP Application

## âœ… Completed Steps

### 1. Dependencies Added
- âœ… firebase_core: ^3.8.1
- âœ… firebase_auth: ^5.3.3
- âœ… cloud_firestore: ^5.5.2
- âœ… firebase_storage: ^12.3.6
- âœ… image_picker: ^1.0.7

### 2. Services Layer Created
- âœ… `lib/core/services/auth_service.dart` - Authentication operations
- âœ… `lib/core/services/database_service.dart` - Firestore operations
- âœ… `lib/core/services/storage_service.dart` - Firebase Storage operations

### 3. Models Created
- âœ… `lib/core/models/stadium.dart` - Stadium model with Firestore serialization
- âœ… `lib/core/models/user_model.dart` - User model with role management

### 4. Providers Created
- âœ… `lib/core/providers/auth_provider.dart` - Global authentication state
- âœ… `lib/core/providers/stadium_provider.dart` - Stadium data management

### 5. Main.dart Updated
- âœ… Firebase initialization added
- âœ… Providers registered in MultiProvider

## ðŸ”§ Required Manual Steps

### Step 1: Install Dependencies
```bash
cd c:\Users\pc\.gemini\antigravity\scratch\vsp_application
flutter pub get
```

### Step 2: Configure Firebase Project

#### A. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add Project"
3. Name it "VSP Application"
4. Enable Google Analytics (optional)
5. Create project

#### B. Add Android App
1. Click "Add app" â†’ Android
2. Android package name: `com.example.vsp_application`
3. Download `google-services.json`
4. Place it in: `android/app/google-services.json`

#### C. Add iOS App
1. Click "Add app" â†’ iOS
2. iOS bundle ID: `com.example.vspApplication`
3. Download `GoogleService-Info.plist`
4. Place it in: `ios/Runner/GoogleService-Info.plist`

### Step 3: Update Android Configuration

Edit `android/build.gradle`:
```gradle
buildscript {
    dependencies {
        // Add this line
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

Edit `android/app/build.gradle`:
```gradle
// Add at the bottom of the file
apply plugin: 'com.google.gms.google-services'
```

### Step 4: Update iOS Configuration

Edit `ios/Runner/Info.plist` - Add before `</dict>`:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
        </array>
    </dict>
</array>
```

### Step 5: Enable Firebase Services

In Firebase Console:

#### Authentication
1. Go to Authentication â†’ Sign-in method
2. Enable "Email/Password"
3. Save

#### Firestore Database
1. Go to Firestore Database
2. Click "Create database"
3. Start in **Test mode** (for development)
4. Choose location (closest to your users)
5. Enable

#### Storage
1. Go to Storage
2. Click "Get started"
3. Start in **Test mode**
4. Done

### Step 6: Set Up Firestore Security Rules

Replace default rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    // Stadiums collection
    match /stadiums/{stadiumId} {
      allow read: if true;
      allow create: if request.auth != null && 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'owner';
      allow update, delete: if request.auth != null && 
                              resource.data.ownerId == request.auth.uid;
    }
    
    // Matches collection
    match /matches/{matchId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    
    // Championships collection
    match /championships/{championshipId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    
    // Bookings collection
    match /bookings/{bookingId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && 
                              resource.data.ownerId == request.auth.uid;
    }
  }
}
```

### Step 7: Set Up Storage Security Rules

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Owner documents
    match /owners/{ownerId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == ownerId;
    }
    
    // Stadium images
    match /stadiums/{stadiumId}/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    
    // User profiles
    match /users/{userId}/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth.uid == userId;
    }
  }
}
```

## ðŸ“Š Firestore Collections Structure

### users
```json
{
  "uid": "string",
  "email": "string",
  "role": "player|owner",
  "name": "string",
  "phone": "string",
  "profileImageUrl": "string",
  "createdAt": "timestamp"
}
```

### stadiums
```json
{
  "name": "string",
  "location": "string",
  "imageUrl": "string",
  "pricePerHour": "number",
  "seatsCapacity": "number",
  "ownerId": "string",
  "features": ["array"],
  "rating": "number",
  "reviewsCount": "number",
  "isAvailable": "boolean",
  "createdAt": "timestamp"
}
```

### matches
```json
{
  "stadiumId": "string",
  "dateTime": "timestamp",
  "duration": "number",
  "totalSlots": "number",
  "remainingSlots": "number",
  "joinedPlayers": ["array"],
  "pricePerPlayer": "number",
  "createdBy": "string"
}
```

### championships
```json
{
  "name": "string",
  "type": "cup|league",
  "sport": "football|basketball|volleyball|padel",
  "startDate": "timestamp",
  "endDate": "timestamp",
  "maxTeams": "number",
  "joinedTeams": ["array"],
  "entryFee": "number",
  "grandPrize": "number",
  "ownerId": "string"
}
```

### bookings
```json
{
  "stadiumId": "string",
  "ownerId": "string",
  "userId": "string",
  "dateTime": "timestamp",
  "duration": "number",
  "amount": "number",
  "paymentStatus": "pending|paid|cancelled",
  "playerName": "string",
  "playerPhone": "string",
  "createdAt": "timestamp"
}
```

## ðŸ”— Next Integration Steps

### 1. Connect Authentication Screens
Update signup/login screens to use AuthProvider:

```dart
// In signup screen
final authProvider = Provider.of<AuthProvider>(context, listen: false);
await authProvider.signUp(
  email: email,
  password: password,
  role: 'player', // or 'owner'
  userData: {'name': name, 'phone': phone},
);
```

### 2. Connect Stadium Screens
Use StadiumProvider in stadium lists:

```dart
// In player home screen
final stadiumProvider = Provider.of<StadiumProvider>(context);
final stadiums = stadiumProvider.stadiums;
```

### 3. Connect Owner Document Upload
Use StorageService in OwnerDocumentationWizard:

```dart
final storageService = StorageService();
String? url = await storageService.uploadOwnerDocument(
  file: selectedFile,
  ownerId: currentUserId,
  documentType: 'nationalIdFront',
);
```

### 4. Connect Match Join Logic
Update match cards to use DatabaseService:

```dart
final databaseService = DatabaseService();
await databaseService.joinMatch(matchId, userId);
```

## ðŸ§ª Testing

### Test Authentication
1. Run app
2. Sign up as Player
3. Check Firebase Console â†’ Authentication
4. Verify user created with email

### Test Firestore
1. Add test stadium data manually in Console
2. Run app
3. Verify stadiums appear in player home screen

### Test Storage
1. Upload owner document
2. Check Firebase Console â†’ Storage
3. Verify file uploaded with correct path

## ðŸ“ Important Notes

- **Test Mode**: Current rules allow all reads/writes. Update for production!
- **Indexes**: Firestore may require composite indexes for complex queries
- **Costs**: Monitor Firebase usage to avoid unexpected charges
- **Error Handling**: All services return success/error - handle appropriately
- **Offline**: Firestore has offline persistence enabled by default

## ðŸš€ Ready to Deploy

Once testing is complete:
1. Update Firestore rules to production mode
2. Update Storage rules to production mode
3. Enable App Check for security
4. Set up Firebase Analytics
5. Configure Crashlytics for error tracking

