import 'package:firebase_database/firebase_database.dart';

class SearchService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  Future<List<Map<String, dynamic>>> searchServices(String query) async {
    try {
      DataSnapshot snapshot = await _database.ref().child('services').get();
      
      if (!snapshot.exists) {
        return [];
      }

      Map<dynamic, dynamic> servicesMap = snapshot.value as Map;
      List<Map<String, dynamic>> searchResults = [];

      servicesMap.forEach((key, value) {
        Map<String, dynamic> service = Map<String, dynamic>.from(value);
        if (service['title'].toString().toLowerCase().contains(query.toLowerCase()) ||
            service['description'].toString().toLowerCase().contains(query.toLowerCase())) {
          service['id'] = key;
          searchResults.add(service);
        }
      });

      return searchResults;
    } catch (e) {
      throw Exception('Failed to search services: $e');
    }
  }
}
