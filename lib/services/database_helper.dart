import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'search_history.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE search_history(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            query TEXT NOT NULL,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      },
    );
  }

  Future<void> insertSearch(String query) async {
    final db = await database;
    final normalizedQuery = query.trim().toLowerCase();
    
    // Delete existing duplicate entries
    await db.delete(
      'search_history',
      where: 'LOWER(query) = ?',
      whereArgs: [normalizedQuery],
    );
    
    // Insert new entry
    await db.insert(
      'search_history',
      {
        'query': query,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<List<String>> getSearchHistory() async {
    final db = await database;
    
    // Get unique searches with most recent timestamp
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT query, MAX(timestamp) as timestamp
      FROM search_history
      GROUP BY LOWER(query)
      ORDER BY timestamp DESC
      LIMIT 10
    ''');
    
    return maps.map((map) => map['query'] as String).toList();
  }

  Future<void> clearSearchHistory() async {
    final db = await database;
    await db.delete('search_history');
  }
}
