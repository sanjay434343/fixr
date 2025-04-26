import 'package:flutter/material.dart';

class ProviderProfileScreen extends StatelessWidget {
  final String? providerName;
  
  const ProviderProfileScreen({super.key, this.providerName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(providerName ?? 'Provider Profile')),
      body: Center(child: Text('Provider Profile: ${providerName ?? "Unknown"}')),
    );
  }
}
