import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DataMigration {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> seedDatabase() async {
    debugPrint('🌱 Starting Database Seeding...');

    try {
      // 1. Check if Stadiums exist
      final stadiumQuery = await _firestore.collection('stadiums').limit(1).get();
      if (stadiumQuery.docs.isEmpty) {
        debugPrint('🏟️ Seeding Stadiums...');
        await _seedStadiums();
      } else {
        debugPrint('✅ Stadiums already seeded.');
      }

      // 2. Check if Teams exist
      final teamQuery = await _firestore.collection('teams').limit(1).get();
      if (teamQuery.docs.isEmpty) {
        debugPrint('⚽ Seeding Teams...');
        await _seedTeams();
      } else {
        debugPrint('✅ Teams already seeded.');
      }

      debugPrint('🎉 Database Seeding Complete!');
    } catch (e) {
      debugPrint('❌ Error during seeding: $e');
    }
  }

  Future<void> _seedStadiums() async {
    final List<Map<String, dynamic>> stadiums = [
      {
        'name': 'Cairo International Stadium',
        'location': 'Nasr City, Cairo',
        'pricePerHour': 1500.0,
        'rating': 4.8,
        'imageUrl': 'https://images.unsplash.com/photo-1522778119026-d647f0565c6a?auto=format&fit=crop&w=800&q=80',
        'description': 'The historical home of Egyptian football.',
        'features': ['Parking', 'Lighting', 'Shower'],
        'pitchType': 'Natural Grass',
        'seatsCapacity': 75000,
        'area': 'Cairo',
        'type': 'Football',
        'size': '11 VS 11',
      },
      {
        'name': 'Santiago Bernabéu',
        'location': 'Madrid, Spain',
        'pricePerHour': 5000.0,
        'rating': 5.0,
        'imageUrl': 'https://images.unsplash.com/photo-1577223625816-7546f13df25d?auto=format&fit=crop&w=800&q=80',
        'description': 'A world-class stadium with futuristic design.',
        'features': ['Parking', 'Lighting', 'Shower', 'WiFi'],
        'pitchType': 'Hybrid Grass',
        'seatsCapacity': 81044,
        'area': 'Madrid',
        'type': 'Football',
        'size': '11 VS 11',
      },
      {
        'name': 'Anfield',
        'location': 'Liverpool, UK',
        'pricePerHour': 4000.0,
        'rating': 4.9,
        'imageUrl': 'https://images.unsplash.com/photo-1459865264687-595d652de67e?auto=format&fit=crop&w=800&q=80',
        'description': 'You Never Walk Alone. Iconic atmosphere.',
        'features': ['Parking', 'Lighting', 'Shower'],
        'pitchType': 'Natural Grass',
        'seatsCapacity': 53394,
        'area': 'Liverpool',
        'type': 'Football',
        'size': '11 VS 11',
      },
      {
        'name': 'Lusail Stadium',
        'location': 'Lusail, Qatar',
        'pricePerHour': 5500.0,
        'rating': 5.0,
        'imageUrl': 'https://images.unsplash.com/photo-1540747913346-19e32dc3e97e?auto=format&fit=crop&w=800&q=80',
        'description': 'The golden stadium that hosted the World Cup final.',
        'features': ['Parking', 'Lighting', 'Shower', 'WiFi'],
        'pitchType': 'Natural Grass',
        'seatsCapacity': 80000,
        'area': 'Lusail',
        'type': 'Football',
        'size': '11 VS 11',
      },
      {
        'name': 'Borg El Arab Stadium',
        'location': 'Alexandria, Egypt',
        'pricePerHour': 1200.0,
        'rating': 4.4,
        'imageUrl': 'https://images.unsplash.com/photo-1540747913346-19e32dc3e97e?auto=format&fit=crop&w=800&q=80',
        'description': 'The largest stadium in Egypt.',
        'features': ['Parking', 'Lighting', 'Shower'],
        'pitchType': 'Natural Grass',
        'seatsCapacity': 86000,
        'area': 'Alexandria',
        'type': 'Football',
        'size': '11 VS 11',
      },
      {
        'name': 'Al Salam Stadium',
        'location': 'Cairo, Egypt',
        'pricePerHour': 900.0,
        'rating': 4.2,
        'imageUrl': 'https://images.unsplash.com/photo-1510051640316-cee39563ddab?auto=format&fit=crop&w=800&q=80',
        'description': 'Modern stadium with great facilities.',
        'features': ['Parking', 'Lighting'],
        'pitchType': 'Natural Grass',
        'seatsCapacity': 30000,
        'area': 'Cairo',
        'type': 'Football',
        'size': '11 VS 11',
      },
      {
        'name': 'Stamford Bridge',
        'location': 'London, UK',
        'pricePerHour': 3200.0,
        'rating': 4.5,
        'imageUrl': 'https://images.unsplash.com/photo-1516211697149-d8677ccecbbd?auto=format&fit=crop&w=800&q=80',
        'description': 'The historical home of Chelsea.',
        'features': ['Parking', 'Lighting', 'WiFi'],
        'pitchType': 'Natural Grass',
        'seatsCapacity': 40834,
        'area': 'London',
        'type': 'Football',
        'size': '11 VS 11',
      },
      {
        'name': 'San Siro',
        'location': 'Milan, Italy',
        'pricePerHour': 3500.0,
        'rating': 4.6,
        'imageUrl': 'https://images.unsplash.com/photo-1522778119026-d647f0565c6a?auto=format&fit=crop&w=800&q=80',
        'description': 'A historic monument of Italian football.',
        'features': ['Parking', 'Lighting'],
        'pitchType': 'Hybrid Grass',
        'seatsCapacity': 80018,
        'area': 'Milan',
        'type': 'Football',
        'size': '11 VS 11',
      },
       {
        'name': 'Camp Nou',
        'location': 'Barcelona, Spain',
        'pricePerHour': 4800.0,
        'rating': 4.9,
        'imageUrl': 'https://images.unsplash.com/photo-1550966871-3ed3c47e2ce2?auto=format&fit=crop&w=800&q=80',
        'description': 'The largest stadium in Europe.',
        'features': ['Parking', 'Lighting', 'WiFi'],
        'pitchType': 'Natural Grass',
        'seatsCapacity': 99354,
        'area': 'Barcelona',
        'type': 'Football',
        'size': '11 VS 11',
      },
       {
        'name': 'Allianz Arena',
        'location': 'Munich, Germany',
        'pricePerHour': 4200.0,
        'rating': 4.7,
        'imageUrl': 'https://images.unsplash.com/photo-1625941544336-d8f9916ab490?auto=format&fit=crop&w=800&q=80',
        'description': 'Known for its exterior of inflated ETFE plastic panels.',
        'features': ['Parking', 'Lighting', 'Shower'],
        'pitchType': 'Natural Grass',
        'seatsCapacity': 75024,
        'area': 'Munich',
        'type': 'Football',
        'size': '11 VS 11',
      },
       {
        'name': 'Old Trafford',
        'location': 'Manchester, UK',
        'pricePerHour': 3800.0,
        'rating': 4.5,
        'imageUrl': 'https://images.unsplash.com/photo-1516283576620-6d43232c744d?auto=format&fit=crop&w=800&q=80',
        'description': 'The Theatre of Dreams.',
        'features': ['Parking', 'Lighting', 'Shower'],
        'pitchType': 'Natural Grass',
        'seatsCapacity': 74310,
        'area': 'Manchester',
        'type': 'Football',
        'size': '11 VS 11',
      },
      {
        'name': 'Wembley Stadium',
        'location': 'London, UK',
        'pricePerHour': 6000.0,
        'rating': 5.0,
        'imageUrl': 'https://images.unsplash.com/photo-1556056504-5c7696c4c28d?auto=format&fit=crop&w=800&q=80',
        'description': 'The Home of Football.',
        'features': ['Parking', 'Lighting', 'Shower', 'WiFi'],
        'pitchType': 'Natural Grass',
        'seatsCapacity': 90000,
        'area': 'London',
        'type': 'Football',
        'size': '11 VS 11',
      },
      {
        'name': 'Petro Sport Stadium',
        'location': 'New Cairo, Egypt',
        'pricePerHour': 800.0,
        'rating': 4.0,
        'imageUrl': 'https://images.unsplash.com/photo-1575361204480-aadea25e6e68?auto=format&fit=crop&w=800&q=80',
        'description': 'Known for its intense atmosphere.',
        'features': ['Parking', 'Lighting', 'Shower'],
        'pitchType': 'Natural Grass',
        'seatsCapacity': 16000,
        'area': 'Cairo',
        'type': 'Football',
        'size': '11 VS 11',
      },
      {
        'name': 'Maracanã',
        'location': 'Rio de Janeiro, Brazil',
        'pricePerHour': 4500.0,
        'rating': 4.8,
        'imageUrl': 'https://images.unsplash.com/photo-1518091043644-c1d4457512c6?auto=format&fit=crop&w=800&q=80',
        'description': 'Temple of Brazilian football.',
        'features': ['Parking', 'Lighting', 'Shower'],
        'pitchType': 'Natural Grass',
        'seatsCapacity': 78838,
        'area': 'Rio',
        'type': 'Football',
        'size': '11 VS 11',
      },
      {
        'name': 'La Bombonera',
        'location': 'Buenos Aires, Argentina',
        'pricePerHour': 3200.0,
        'rating': 4.7,
        'imageUrl': 'https://images.unsplash.com/photo-1489944440615-453fc2b6a9a9?auto=format&fit=crop&w=800&q=80',
        'description': 'Unique structure and incredible noise.',
        'features': ['Parking', 'Lighting'],
        'pitchType': 'Natural Grass',
        'seatsCapacity': 54000,
        'area': 'Buenos Aires',
        'type': 'Football',
        'size': '11 VS 11',
      },
      {
        'name': 'Signal Iduna Park',
        'location': 'Dortmund, Germany',
        'pricePerHour': 3800.0,
        'rating': 4.9,
        'imageUrl': 'https://images.unsplash.com/photo-1431324155629-1a6deb1dec8d?auto=format&fit=crop&w=800&q=80',
        'description': 'Home of the Yellow Wall.',
        'features': ['Parking', 'Lighting', 'Shower'],
        'pitchType': 'Hybrid Grass',
        'seatsCapacity': 81365,
        'area': 'Dortmund',
        'type': 'Football',
        'size': '11 VS 11',
      },
      {
        'name': 'Johan Cruyff Arena',
        'location': 'Amsterdam, Netherlands',
        'pricePerHour': 3600.0,
        'rating': 4.6,
        'imageUrl': 'https://images.unsplash.com/photo-1543351611-58f69d7c1781?auto=format&fit=crop&w=800&q=80',
        'description': 'Modern arena with retractable roof.',
        'features': ['Parking', 'Lighting', 'WiFi'],
        'pitchType': 'Hybrid Grass',
        'seatsCapacity': 55500,
        'area': 'Amsterdam',
        'type': 'Football',
        'size': '11 VS 11',
      },
      {
        'name': 'Emirates Stadium',
        'location': 'London, UK',
        'pricePerHour': 4400.0,
        'rating': 4.8,
        'imageUrl': 'https://images.unsplash.com/photo-1522778119026-d647f0565c6a?auto=format&fit=crop&w=800&q=80',
        'description': 'A masterpiece of modern stadium architecture.',
        'features': ['Parking', 'Lighting', 'WiFi', 'Shower'],
        'pitchType': 'Natural Grass',
        'seatsCapacity': 60704,
        'area': 'London',
        'type': 'Football',
        'size': '11 VS 11',
      },
      {
        'name': 'Stade de France',
        'location': 'Paris, France',
        'pricePerHour': 4100.0,
        'rating': 4.5,
        'imageUrl': 'https://images.unsplash.com/photo-1556056504-5c7696c4c28d?auto=format&fit=crop&w=800&q=80',
        'description': 'The national stadium of France.',
        'features': ['Parking', 'Lighting', 'Shower'],
        'pitchType': 'Natural Grass',
        'seatsCapacity': 80698,
        'area': 'Paris',
        'type': 'Football',
        'size': '11 VS 11',
      },
      {
        'name': 'Etihad Stadium',
        'location': 'Manchester, UK',
        'pricePerHour': 4300.0,
        'rating': 4.7,
        'imageUrl': 'https://images.unsplash.com/photo-1625941544336-d8f9916ab490?auto=format&fit=crop&w=800&q=80',
        'description': 'Home of the champions.',
        'features': ['Parking', 'Lighting', 'WiFi'],
        'pitchType': 'Natural Grass',
        'seatsCapacity': 53400,
        'area': 'Manchester',
        'type': 'Football',
        'size': '11 VS 11',
      },
      {
        'name': 'Juventus Stadium',
        'location': 'Turin, Italy',
        'pricePerHour': 3900.0,
        'rating': 4.9,
        'imageUrl': 'https://images.unsplash.com/photo-1459865264687-595d652de67e?auto=format&fit=crop&w=800&q=80',
        'description': 'A modern and atmospheric rectangular stadium.',
        'features': ['Parking', 'Lighting', 'Shower'],
        'pitchType': 'Natural Grass',
        'seatsCapacity': 41507,
        'area': 'Turin',
        'type': 'Football',
        'size': '11 VS 11',
      },
    ];

    final batch = _firestore.batch();

    for (var stadium in stadiums) {
      final docRef = _firestore.collection('stadiums').doc();
      batch.set(docRef, {
        ...stadium,
        'id': docRef.id,
        'ownerId': 'seeded_owner', // Mock owner
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> _seedTeams() async {
     final List<Map<String, dynamic>> teams = [
      {
        'name': 'Al Ahly SC',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/en/thumb/8/8c/Al_Ahly_SC_logo.svg/1200px-Al_Ahly_SC_logo.svg.png',
        'points': 85,
        'trend': 'up',
        'playersCount': 11,
      },
      {
        'name': 'Zamalek SC',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/en/thumb/0/04/ZamalekSC.png/180px-ZamalekSC.png',
        'points': 78,
        'trend': 'up',
        'playersCount': 11,
      },
      {
        'name': 'Liverpool FC',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/en/thumb/0/0c/Liverpool_FC.svg/1200px-Liverpool_FC.svg.png',
        'points': 92,
        'trend': 'up',
        'playersCount': 11,
      },
      {
        'name': 'Real Madrid',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/en/thumb/5/56/Real_Madrid_CF.svg/1200px-Real_Madrid_CF.svg.png',
        'points': 95,
        'trend': 'same',
        'playersCount': 11,
      },
      {
        'name': 'Manchester City',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/en/thumb/e/eb/Manchester_City_FC_badge.svg/1200px-Manchester_City_FC_badge.svg.png',
        'points': 90,
        'trend': 'down',
        'playersCount': 11,
      },
      {
        'name': 'Bayern Munich',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/FC_Bayern_M%C3%BCnchen_logo_%282017%29.svg/1200px-FC_Bayern_M%C3%BCnchen_logo_%282017%29.svg.png',
        'points': 88,
        'trend': 'up',
        'playersCount': 11,
      },
      {
        'name': 'Paris Saint-Germain',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/en/thumb/a/a7/Paris_Saint-Germain_F.C..svg/1200px-Paris_Saint-Germain_F.C..svg.png',
        'points': 82,
        'trend': 'down',
        'playersCount': 11,
      },
      {
        'name': 'FC Barcelona',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/en/thumb/4/47/FC_Barcelona_%28crest%29.svg/1200px-FC_Barcelona_%28crest%29.svg.png',
        'points': 80,
        'trend': 'up',
        'playersCount': 11,
      },
       {
        'name': 'Juventus',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/bc/Juventus_FC_2017_icon_%28black%29.svg/1200px-Juventus_FC_2017_icon_%28black%29.svg.png',
        'points': 75,
        'trend': 'same',
        'playersCount': 11,
      },
       {
        'name': 'Chelsea FC',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/en/thumb/c/cc/Chelsea_FC.svg/1200px-Chelsea_FC.svg.png',
        'points': 70,
        'trend': 'down',
        'playersCount': 11,
      },
       {
        'name': 'Arsenal FC',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/en/thumb/5/53/Arsenal_FC.svg/1200px-Arsenal_FC.svg.png',
        'points': 84,
        'trend': 'up',
        'playersCount': 11,
      },
       {
        'name': 'AC Milan',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/Logo_of_AC_Milan.svg/1200px-Logo_of_AC_Milan.svg.png',
        'points': 72,
        'trend': 'up',
        'playersCount': 11,
      },
       {
        'name': 'Inter Milan',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/FC_Internazionale_Milano_2021.svg/1200px-FC_Internazionale_Milano_2021.svg.png',
        'points': 76,
        'trend': 'same',
        'playersCount': 11,
      },
       {
        'name': 'Pyramids FC',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/en/thumb/0/06/Pyramids_FC_logo.png/180px-Pyramids_FC_logo.png',
        'points': 68,
        'trend': 'down',
        'playersCount': 11,
      },
       {
        'name': 'Al Ittihad',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/en/thumb/e/e4/Al-Ittihad_Aleksandrie_Club_Logo.png/180px-Al-Ittihad_Aleksandrie_Club_Logo.png',
        'points': 60,
        'trend': 'same',
        'playersCount': 11,
      },
    ];

    final batch = _firestore.batch();

    for (var team in teams) {
      final docRef = _firestore.collection('teams').doc();
      batch.set(docRef, {
        ...team,
        'id': docRef.id,
        'captainId': 'seeded_captain', // Mock captain
        'createdAt': FieldValue.serverTimestamp(),
        'members': [
           'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?auto=format&fit=crop&w=100&q=80',
           'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=100&q=80',
           'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=100&q=80',
           'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=100&q=80',
           'https://images.unsplash.com/photo-1527980965255-d3b416303d12?auto=format&fit=crop&w=100&q=80',
        ],
      });
    }

    await batch.commit();
  }
}
