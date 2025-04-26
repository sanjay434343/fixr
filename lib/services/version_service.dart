import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionService {
  final DatabaseReference _appVersionRef = FirebaseDatabase.instance.ref('appversion/v1');

  static final VersionService _instance = VersionService._internal();
  
  factory VersionService(FirebaseRemoteConfig instance) {
    return _instance;
  }

  VersionService._internal();

  Future<UpdateInfo> checkForUpdate() async {
    try {
      // Wait for package info plugin to initialize
      await PackageInfo.fromPlatform().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw 'Package info timeout',
      );

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final snapshot = await _appVersionRef.get();
      if (!snapshot.exists) {
        throw 'Version info not available';
      }

      final versionData = Map<String, dynamic>.from(snapshot.value as Map);
      final latestVersion = versionData['version']?.toString() ?? currentVersion;
      final updateUrl = versionData['url']?.toString() ?? '';

      final needsUpdate = _compareVersions(currentVersion, latestVersion) < 0;

      return UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        needsUpdate: needsUpdate,
        forceUpdate: needsUpdate,
        updateUrl: updateUrl,
        updateMessage: 'A new version ($latestVersion) is available.',
      );
    } catch (e) {
      print('Version check error details: $e');
      rethrow;
    }
  }

  int _compareVersions(String v1, String v2) {
    try {
      final List<int> version1 = v1.split('.')
          .take(3)
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
      final List<int> version2 = v2.split('.')
          .take(3)
          .map((e) => int.tryParse(e) ?? 0)
          .toList();

      // Pad with zeros if needed
      while (version1.length < 3) {
        version1.add(0);
      }
      while (version2.length < 3) {
        version2.add(0);
      }

      for (var i = 0; i < 3; i++) {
        if (version1[i] > version2[i]) return 1;
        if (version1[i] < version2[i]) return -1;
      }
      return 0;
    } catch (e) {
      print('Version comparison error: $e');
      return 0;
    }
  }
}

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final bool needsUpdate;
  final bool forceUpdate;
  final String updateUrl;
  final String updateMessage;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.needsUpdate,
    required this.forceUpdate,
    required this.updateUrl,
    required this.updateMessage,
  });
}
