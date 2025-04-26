import 'package:flutter/material.dart';
import '../models/service_model.dart';
import '../services/services_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_loader.dart';
import '../widgets/service_card.dart';
import 'service_detail_screen.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final ServicesRepository _servicesRepo = ServicesRepository();
  List<ServiceModel> _services = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      if (!mounted) return;  // Add check before first setState
      setState(() => _isLoading = true);
      
      final services = await _servicesRepo.getServices();
      
      if (!mounted) return;  // Add check before second setState
      setState(() {
        _services = services;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading services: $e');
      if (!mounted) return;  // Add check before error setState
      setState(() => _isLoading = false);
    }
  }

  Widget _buildCategoryChips() {
    final categories = ['All', 'Plumbing', 'Cleaning', 'Electrical', 'Painting', 'Carpentry', 'Gardening'];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: categories.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(category),
              onSelected: (selected) {
                setState(() => _selectedCategory = category);
              },
              selectedColor: AppTheme.primaryColor.withOpacity(0.2),
              checkmarkColor: AppTheme.primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.primaryColor : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildServicesList() {
    final filteredServices = _selectedCategory == 'All'
        ? _services
        : _services.where((service) => 
            service.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();

    if (filteredServices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.handyman_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No services available',
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
      itemCount: filteredServices.length,
      itemBuilder: (context, index) {
        final service = filteredServices[index];
        return ServiceCard(
          service: service,
          isFavorite: false,
          onFavoriteChanged: (_) {},
          heroTagSource: 'services',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceDetailScreen(
                service: service,
                isFavorite: false,
                onFavoriteChanged: (_) {},
                heroTagSource: 'services',
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 16),
          _buildCategoryChips(),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const CustomLoader()
                : RefreshIndicator(
                    onRefresh: _loadServices,
                    color: AppTheme.primaryColor,
                    child: _buildServicesList(),
                  ),
          ),
        ],
      ),
    );
  }
}
