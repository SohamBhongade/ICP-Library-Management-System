import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p; // Use 'as p' to avoid name conflicts
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('icp_library_pro.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // 1. Get the safe AppData directory
    final Directory appSupportDir = await getApplicationSupportDirectory();

    // 2. Create a subfolder for your app
    final String dbDirectoryPath = p.join(
      appSupportDir.path,
      'ICP_Library_Data',
    );
    final Directory dbDirectory = Directory(dbDirectoryPath);

    if (!await dbDirectory.exists()) {
      await dbDirectory.create(recursive: true);
    }

    // 3. Join the safe path with your filename using 'p.join'
    final dbPath = p.join(dbDirectoryPath, filePath);

    return await openDatabase(dbPath, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT, acc_no TEXT UNIQUE, author TEXT, title TEXT,
        publisher TEXT, year TEXT, pages TEXT, cost TEXT,
        isbn TEXT, call_no TEXT, bill_info TEXT, source TEXT, remarks TEXT,
        status TEXT DEFAULT 'Available'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY, 
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        enrollment TEXT UNIQUE,
        mobile TEXT,
        student_class TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS issues (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER, book_title TEXT, acc_no TEXT,
        student_name TEXT, issue_date TEXT, due_date TEXT,
        status TEXT DEFAULT 'ISSUED'
      )
    ''');
  }

  // --- REFRESH / SETTINGS METHODS ---

  Future<void> saveExcelPath(String path) async {
    final db = await database;
    await db.insert('settings', {
      'key': 'excel_path',
      'value': path,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getExcelPath() async {
    final db = await database;
    final maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['excel_path'],
    );
    if (maps.isNotEmpty) return maps.first['value'] as String?;
    return null;
  }

  // --- BOOK METHODS ---

  Future<List<Map<String, dynamic>>> getBooks() async {
    final db = await database;
    return await db.query('books', orderBy: 'acc_no ASC');
  }

  Future<int> insertBook(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('books', data);
  }

  Future<int> updateBook(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('books', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteBook(int id) async {
    final db = await database;
    return await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  // --- ISSUE & UTILITY METHODS ---

  Future<void> deleteAllIssues() async {
    final db = await database;
    await db.delete('issues');
    await db.update('books', {'status': 'Available'});
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('books');
    await db.delete('students');
    await db.delete('issues');
    await db.delete('settings');
  }
}
