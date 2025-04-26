class ServicePerson {
  final String id;
  final String name;
  final String phone;
  final String zone;
  final String experience;
  final double rating;
  final Map<String, bool> services;
  final String? profile;

  ServicePerson({
    required this.id,
    required this.name,
    required this.phone,
    required this.zone,
    required this.experience,
    required this.rating,
    required this.services,
    this.profile,
  });

  factory ServicePerson.fromMap(String id, Map<dynamic, dynamic> data) {
    return ServicePerson(
      id: id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      zone: data['zone'] ?? '',
      experience: data['experience'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      services: Map<String, bool>.from(data['services'] ?? {}),
      profile: data['profile'],
    );
  }
}
