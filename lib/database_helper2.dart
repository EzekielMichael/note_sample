import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper2 {
  static final DatabaseHelper2 instance = DatabaseHelper2._init();
  static Database? _database;

  DatabaseHelper2._init();

  factory DatabaseHelper2() => instance;

  DatabaseHelper2._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('notes.db');
    // Debug: Print the schema of the Image table
    final result = await _database!.rawQuery('PRAGMA table_info(Image);');
    print('Image table schema: $result');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5, // Incremented to force upgrade
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE Note (
        noteId INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        time TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE Image (
        imageId INTEGER PRIMARY KEY AUTOINCREMENT,
        noteId INTEGER NOT NULL,
        mediaPath TEXT NOT NULL,
        FOREIGN KEY (noteId) REFERENCES Note (noteId) ON DELETE CASCADE
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      // Check if the Image table exists
      final tableExists = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='Image'");
      if (tableExists.isNotEmpty) {
        // Rename the old table and create a new one
        await db.execute('ALTER TABLE Image RENAME TO Image_old');
        await db.execute('''
          CREATE TABLE Image (
            imageId INTEGER PRIMARY KEY AUTOINCREMENT,
            noteId INTEGER NOT NULL,
            mediaPath TEXT NOT NULL,
            FOREIGN KEY (noteId) REFERENCES Note (noteId) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE TABLE events(id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'title TEXT, description TEXT, date TEXT, time TEXT)',
        );
        // Migrate data if the old column exists
        try {
          await db.execute('''
            INSERT INTO Image (imageId, noteId, mediaPath)
            SELECT imageId, noteId, imagePath FROM Image_old 
            WHERE imagePath IS NOT NULL
          ''');
        } catch (e) {
          print('Migration failed: $e');
        }
        await db.execute('DROP TABLE Image_old');
      } else {
        // If the table doesn’t exist, create it fresh
        await db.execute('''
          CREATE TABLE Image (
            imageId INTEGER PRIMARY KEY AUTOINCREMENT,
            noteId INTEGER NOT NULL,
            mediaPath TEXT NOT NULL,
            FOREIGN KEY (noteId) REFERENCES Note (noteId) ON DELETE CASCADE
          )
        ''');
      }
    }
  }

  // ========== Events CRUD ==========
  Future<List<Map<String, dynamic>>> getEvents() async {
    final db = await database;
    return await db.query('events');
  }

  Future<int> insertEvent(Map<String, dynamic> event) async {
    if (event['title'] == null || event['title'].toString().isEmpty) {
      throw ArgumentError('Event title cannot be empty');
    }

    final db = await database;
    return await db.insert('events', event);
  }

  Future<int> updateEvent(int id, Map<String, dynamic> event) async {
    final db = await database;
    return await db.update(
      'events',
      event,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteEvent(int id) async {
    final db = await database;
    return await db.delete(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  //Notes Methods
  Future<int> insertNote(Map<String, dynamic> note) async {
    final db = await database;
    return await db.insert('Note', note);
  }

  Future<int> insertImage(Map<String, dynamic> image) async {
    final db = await database;
    try {
      return await db.insert('Image', image);
    } catch (e) {
      print('Insert image failed: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getNoteWithImages(int noteId) async {
    final db = await database;

    final noteResult = await db.query('Note', where: 'noteId = ?', whereArgs: [noteId]);
    if (noteResult.isEmpty) return {};

    final imagesResult = await db.query('Image', where: 'noteId = ?', whereArgs: [noteId]);

    return {'note': noteResult.first, 'images': imagesResult};
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}