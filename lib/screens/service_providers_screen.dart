import 'package:flutter/material.dart';

class ServiceProvidersScreen extends StatefulWidget {
  final String? category;
  final String? searchQuery;

  const ServiceProvidersScreen({
    super.key, 
    this.category,
    this.searchQuery,
  });

  @override
  State<ServiceProvidersScreen> createState() => _ServiceProvidersScreenState();
}

class _ServiceProvidersScreenState extends State<ServiceProvidersScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category ?? 'Service Providers'),
      ),
      body: Center(
        child: Text(
          'Showing ${widget.category ?? 'all'} providers\n'
          'Search query: ${widget.searchQuery ?? 'none'}'
        ),
      ),
    );
  }
}
