# Firestore Security Rules

Copy and paste the following rules into your **Firebase Console > Firestore Database > Rules** tab.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function: Check if user is signed in
    function isSignedIn() {
      return request.auth != null;
    }

    // Helper function: Check if current user is the owner of the document
    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }

    // --- USERS COLLECTION ---
    match /users/{userId} {
      // Users can only read and write their own profile
      allow read, write: if isOwner(userId);
    }

    // --- BOOKINGS COLLECTION ---
    match /bookings/{bookingId} {
      // Players can create a booking if they are the one creating it
      allow create: if isSignedIn() 
        && request.resource.data.createdByUserId == request.auth.uid;
        
      // Players can read their own bookings
      allow read: if isSignedIn() 
        && resource.data.createdByUserId == request.auth.uid;
        
      // Owners can read bookings for their stadiums
      // (Future check: && get(/databases/$(database)/documents/stadiums/$(resource.data.stadiumId)).data.ownerId == request.auth.uid)
      allow read: if isSignedIn() 
        && resource.data.ownerId == request.auth.uid;

      // Allow result submission (update) for both teams
      allow update: if isSignedIn() && (
        resource.data.createdByUserId == request.auth.uid || 
        resource.data.opponentTeamId != null // Add more specific logic based on player's team in future
      );
    }

    // --- STADIUMS COLLECTION ---
    match /stadiums/{stadiumId} {
      // Publicly readable, restricted write
      allow read: if true;
      allow write: if isSignedIn() && resource.data.ownerId == request.auth.uid;
    }

    // --- TEAMS COLLECTION ---
    match /teams/{teamId} {
      // Publicly readable
      allow read: if true;
      allow write: if isSignedIn();
    }
    
    // --- CHAMPIONSHIPS COLLECTION ---
    match /championships/{id} {
      allow read: if true;
    }
  }
}
```

