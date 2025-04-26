import 'package:fixr/models/service_model.dart';
import 'package:fixr/screens/service_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/service_card.dart';

class CategoryServicesScreen extends StatefulWidget {
  final String category;

  const CategoryServicesScreen({super.key, required this.category});

  @override
  State<CategoryServicesScreen> createState() => _CategoryServicesScreenState();
}

class _CategoryServicesScreenState extends State<CategoryServicesScreen> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  bool _isLoading = true;
  List<ServiceModel> _services = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCategoryServices();
  }

  Future<void> _fetchCategoryServices() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final categoryPath = widget.category.toLowerCase();
      final snapshot = await _database.ref().child('services').child(categoryPath).get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final service = ServiceModel(
          id: categoryPath,
          title: data['title']?.toString() ?? '',
          description: data['description']?.toString() ?? '',
          price: (data['price'] ?? 0).toInt(),
          rating: (data['rating'] ?? 0).toDouble(),
          reviews: (data['reviews'] ?? 0).toInt(),
          image: data['image']?.toString() ?? '',
          duration: data['duration']?.toString() ?? '',
          availability: data['availability']?.toString() ?? 'Unavailable',
          category: categoryPath,
          serviceCharge: (data['serviceCharge'] ?? 0).toInt(),
          travelCharge: (data['travelCharge'] ?? 0).toInt(),
        );
        
        setState(() {
          _services = [service];
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildServicesList() {
    if (_services.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.handyman_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No services available in this category',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _services.length,
      itemBuilder: (context, index) {
        final service = _services[index];
        return ServiceCard(
          service: service,
          isFavorite: false,
          onFavoriteChanged: (_) {},
          heroTagSource: 'category',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceDetailScreen(
                service: service,
                isFavorite: false,
                onFavoriteChanged: (_) {},
                heroTagSource: 'category',
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.primaryColor,
        elevation: 0,
        title: Text(
          '${widget.category[0].toUpperCase()}${widget.category.substring(1)} Services',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.primaryColor,
                theme.primaryColor.withOpacity(0.8),
              ],
            ),
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.scaffoldBackgroundColor,
              theme.cardColor,
            ],
          ),
        ),
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                ),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                        const SizedBox(height: 16),
                        Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchCategoryServices,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _buildServicesList(),
      ),
    );
  }
}
