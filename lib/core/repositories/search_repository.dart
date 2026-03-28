import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models.dart';

class SearchRepository {
  final FirebaseFirestore _firestore;

  SearchRepository({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<Map<String, List<dynamic>>> globalUnifiedSearch(String query) async {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return {'stadiums': [], 'teams': [], 'championships': []};

    try {
      final stadiumSnap = await _firestore.collection('stadiums')
          .where('name_lowercase', isGreaterThanOrEqualTo: term)
          .where('name_lowercase', isLessThanOrEqualTo: '$term\uf8ff')
          .limit(5)
          .get();
      
      final stadiums = stadiumSnap.docs.map((d) => Stadium.fromFirestore(d.data(), d.id)).toList();

      final teamSnap = await _firestore.collection('teams')
          .where('name_lowercase', isGreaterThanOrEqualTo: term)
          .where('name_lowercase', isLessThanOrEqualTo: '$term\uf8ff')
          .limit(5)
          .get();
      
      final teams = teamSnap.docs.map((d) => Team.fromFirestore(d.data(), d.id)).toList();

      final champSnap = await _firestore.collection('championships')
          .where('name_lowercase', isGreaterThanOrEqualTo: term)
          .where('name_lowercase', isLessThanOrEqualTo: '$term\uf8ff')
          .limit(5)
          .get();
      
      final championships = champSnap.docs.map((d) => Championship.fromFirestore(d.data(), d.id)).toList();

      return {
        'stadiums': stadiums,
        'teams': teams,
        'championships': championships,
      };
    } catch (e) {
      return {'stadiums': [], 'teams': [], 'championships': []};
    }
  }
}
