import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models.dart';

class LeagueRepository {
  final FirebaseFirestore _firestore;

  LeagueRepository({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<VSP1v1Player>> get1v1Standings() {
    return _firestore
        .collection('vsp_1VS1_players')
        .orderBy('totalPoints', descending: true)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return [];
          
          List<VSP1v1Player> players = [];
          for (int i = 0; i < snapshot.docs.length; i++) {
            var data = snapshot.docs[i].data();
            data['rank'] = i + 1; 
            players.add(VSP1v1Player.fromFirestore(data, snapshot.docs[i].id));
          }
          return players;
        });
  }
}
