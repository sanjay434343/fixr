import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/service_model.dart';

class ServicesRepository {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<ServiceModel>> getServices() async {
    try {
      final snapshot = await _db.child('services').get();
      
      if (!snapshot.exists) {
        return [];
      }

      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      
      return data.entries.map((entry) {
        return ServiceModel.fromMap(entry.key, entry.value as Map<dynamic, dynamic>);
      }).toList();
    } on FirebaseException catch (e) {
      print('Firebase error: ${e.message}');
      if (e.code == 'permission-denied') {
        // Handle permission error
        print('Permission denied. Please check Firebase rules.');
      }
      rethrow;
    } catch (e) {
      print('Error fetching services: $e');
      return [];
    }
  }

  Future<List<ServiceModel>> getServicesByCategory(String category) async {
    final allServices = await getServices();
    return allServices.where((service) => 
      service.category.toLowerCase() == category.toLowerCase()
    ).toList();
  }

  Future<List<ServiceModel>> searchServices(String query) async {
    try {
      final allServices = await getServices();
      return allServices.where((service) =>
        service.title.toLowerCase().contains(query.toLowerCase()) ||
        service.description.toLowerCase().contains(query.toLowerCase())
      ).toList();
    } catch (e) {
      print('Error searching services: $e');
      return [];
    }
  }

  getTopRatedServices() {}
}
