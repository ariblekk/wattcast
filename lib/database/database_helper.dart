import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/meter.dart';
import '../models/watt_log.dart';

/// Helper SQLite berjendela tunggal (singleton).
///
/// Menampung:
/// - `meters`   : daftar meteran listrik yang dipantau.
/// - `watt_logs`: riwayat pencatatan (memiliki kolom `meter_id`).
/// - `settings` : pengaturan key-value.
///
/// Database disimpan 100% lokal di perangkat — tidak ada backend server.
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _dbName = 'wattcast.db';
  static const int _dbVersion = 3;
  static const String _table = 'watt_logs';
  static const String _metersTable = 'meters';
  static const String _settingsTable = 'settings';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _init();
    return _database!;
  }

  Future<Database> _init() async {
    // Di platform web, sqflite memakai factory FFI Web (SQLite-WASM)
    // sehingga database tetap tersimpan lokal (IndexedDB).
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }
    final String path =
        kIsWeb ? _dbName : join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_metersTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        number TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      INSERT INTO $_metersTable (name, number, created_at)
      VALUES ('Meteran Utama', '', '${DateTime.now().toIso8601String()}')
    ''');
    await db.execute('''
      CREATE TABLE $_table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meter_id INTEGER NOT NULL DEFAULT 1,
        timestamp TEXT NOT NULL,
        log_type TEXT NOT NULL,
        kwh_purchased REAL NOT NULL DEFAULT 0,
        remaining_kwh REAL NOT NULL,
        amount_paid REAL NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_watt_logs_meter_timestamp ON $_table (meter_id, timestamp DESC)',
    );
    await db.execute('''
      CREATE TABLE $_settingsTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_settingsTable (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_metersTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          number TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL
        )
      ''');
      // Pastikan ada meteran awal untuk menampung log lama.
      final List<Map<String, Object?>> count =
          await db.rawQuery('SELECT COUNT(*) AS c FROM $_metersTable');
      final int existing =
          (count.first['c'] as num?)?.toInt() ?? 0;
      if (existing == 0) {
        await db.rawInsert(
          "INSERT INTO $_metersTable (name, number, created_at) "
          "VALUES ('Meteran Utama', '', ?)",
          <Object?>[DateTime.now().toIso8601String()],
        );
      }
      // Tambahkan kolom meter_id ke log yang sudah ada, default meter pertama.
      await db.execute(
        "ALTER TABLE $_table ADD COLUMN meter_id INTEGER NOT NULL DEFAULT 1",
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_watt_logs_meter_timestamp '
        'ON $_table (meter_id, timestamp DESC)',
      );
    }
  }

  // ===== Meteran =====

  /// Mengembalikan seluruh meteran (urutan penambahan).
  Future<List<Meter>> getAllMeters() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows =
        await db.query(_metersTable, orderBy: 'id ASC');
    return rows.map(Meter.fromMap).toList();
  }

  Future<int> insertMeter(Meter meter) async {
    final Database db = await database;
    return db.insert(_metersTable, meter.toMap());
  }

  Future<int> updateMeter(Meter meter) async {
    final Database db = await database;
    return db.update(
      _metersTable,
      meter.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[meter.id],
    );
  }

  Future<int> deleteMeter(int id) async {
    final Database db = await database;
    return db.delete(_metersTable, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  // ===== Log =====

  /// Mengembalikan seluruh log; bila [meterId] diberikan, hanya milik meteran itu.
  Future<List<WattLog>> getAllLogs({int? meterId}) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: meterId == null ? null : 'meter_id = ?',
      whereArgs: meterId == null ? null : <Object?>[meterId],
      orderBy: 'timestamp DESC',
    );
    return rows.map(WattLog.fromMap).toList();
  }

  Future<WattLog?> getLatestLog({int? meterId}) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: meterId == null ? null : 'meter_id = ?',
      whereArgs: meterId == null ? null : <Object?>[meterId],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WattLog.fromMap(rows.first);
  }

  Future<int> insertLog(WattLog log) async {
    final Database db = await database;
    return db.insert(_table, log.toMap());
  }

  Future<int> updateLog(WattLog log) async {
    final Database db = await database;
    return db.update(
      _table,
      log.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[log.id],
    );
  }

  Future<int> deleteLog(int id) async {
    final Database db = await database;
    return db.delete(_table, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> deleteLogsForMeter(int meterId) async {
    final Database db = await database;
    await db.delete(
      _table,
      where: 'meter_id = ?',
      whereArgs: <Object?>[meterId],
    );
  }

  Future<void> clearAll() async {
    final Database db = await database;
    await db.delete(_table);
  }

  // ===== Settings (key-value) =====

  Future<String?> getSetting(String key) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      _settingsTable,
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final Database db = await database;
    await db.insert(
      _settingsTable,
      <String, Object?>{'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}