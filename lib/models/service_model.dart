class ServiceModel {
  final String id;
  final String title;
  final String description;
  final int price;
  final double rating;
  final String image;
  final String duration;
  final int reviews;
  final String availability;
  final String category;
  final int serviceCharge;
  final int travelCharge;

  ServiceModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.rating,
    required this.image,
    required this.duration,
    required this.reviews,
    required this.availability,
    required this.category,
    required this.serviceCharge,
    required this.travelCharge,
  });

  factory ServiceModel.fromMap(String id, Map<dynamic, dynamic> data) {
    return ServiceModel(
      id: id,
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      price: (data['price'] ?? 0).toInt(),
      rating: (data['rating'] ?? 0.0).toDouble(),
      image: data['image']?.toString() ?? '',
      duration: data['duration']?.toString() ?? '',
      reviews: (data['reviews'] ?? 0).toInt(),
      availability: data['availability']?.toString() ?? 'Unavailable',
      category: data['category']?.toString() ?? id,
      serviceCharge: (data['serviceCharge'] ?? 0).toInt(),
      travelCharge: (data['travelCharge'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'price': price,
      'rating': rating,
      'image': image,
      'duration': duration,
      'reviews': reviews,
      'availability': availability,
      'category': category,
    };
  }

  int get totalCharge => serviceCharge + travelCharge;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  String get name => title;
}
