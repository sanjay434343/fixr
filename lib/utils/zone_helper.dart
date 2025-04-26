class ZoneHelper {
  static const Map<String, List<String>> _zoneKeywords = {
    'pollachi': ['pollachi', 'rasakkapalayam', 'kinathukadavu'],
    'coimbatore': ['coimbatore', 'gandhipuram', 'peelamedu', 'ukkadam'],
    'tirupur': ['tirupur', 'avinashi', 'mangalam'],
    'chennai': ['chennai', 'adyar', 'tambaram', 'velachery'],
    'madurai': ['madurai', 'thirumangalam', 'thirunagar'],
  };

  static List<String> splitAddress(String? address) {
    if (address == null || address.isEmpty) return [];
    
    // Split by common separators and clean up the words
    return address
        .toLowerCase()
        .replaceAll(RegExp(r'[,\.]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
  }

  static String extractZone(String? address) {
    if (address == null || address.isEmpty) return '';
    
    final words = splitAddress(address);
    
    for (final entry in _zoneKeywords.entries) {
      if (words.any((word) => entry.value.contains(word))) {
        return entry.key;
      }
    }
    
    return '';
  }

  static bool isNearby(String servicePersonZone, String? userAddress) {
    if (userAddress == null || userAddress.isEmpty) return false;

    final serviceZoneWords = splitAddress(servicePersonZone);
    final userAddressWords = splitAddress(userAddress);

    // Check if any word in the service person's zone matches any word in user's address
    return serviceZoneWords.any((zoneWord) => 
      userAddressWords.any((addressWord) => 
        addressWord.contains(zoneWord) || zoneWord.contains(addressWord)
      )
    );
  }

  static String extractMainLocation(String? address) {
    final words = splitAddress(address);
    return words.isNotEmpty ? words.last : '';
  }
}
