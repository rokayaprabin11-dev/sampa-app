import 'package:flutter/foundation.dart';
import 'package:path/path.dart' show join;
import 'package:sqflite/sqflite.dart';

const int _kDbVersion = 4;
const String _kDbName = 'sampada.db';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (kIsWeb) throw UnsupportedError('SQLite is not supported on Web.');
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _kDbName);
    return openDatabase(
      path,
      version: _kDbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA journal_mode = WAL');
      },
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Drop and recreate — dev only. Replace with additive migrations before release.
    await _dropAllTables(db);
    await _onCreate(db, newVersion);
  }

  Future<void> _dropAllTables(Database db) async {
    const tables = [
      // v1–v3 legacy names
      'sync_metadata', 'cache_users', 'cache_districts', 'cache_sites',
      'cache_sites_fts', 'cache_site_media', 'cache_events',
      'cache_site_reviews', 'cache_bookmarks', 'cache_visit_history',
      'cache_guides', 'cache_bookings', 'cache_notifications',
      'cache_offline_downloads',
      // v4 names
      'local_heritage_sites', 'local_heritage_sites_fts', 'local_site_media',
      'local_events', 'local_bookmarks', 'local_reviews_draft',
      'local_user_profile', 'local_recently_viewed', 'local_search_history',
      'local_notifications', 'sync_queue',
    ];
    for (final t in tables) {
      await db.execute('DROP TABLE IF EXISTS $t');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // ------------------------------------------------------------------
    // 1. Offline content cache
    // ------------------------------------------------------------------
    await db.execute('''
      CREATE TABLE local_heritage_sites (
        id              TEXT    PRIMARY KEY,
        name_en         TEXT    NOT NULL,
        name_ne         TEXT    NOT NULL,
        category        TEXT    NOT NULL,
        short_desc_en   TEXT,
        short_desc_ne   TEXT,
        description_en  TEXT,
        description_ne  TEXT,
        latitude        REAL    NOT NULL,
        longitude       REAL    NOT NULL,
        district        TEXT    NOT NULL,
        province        TEXT,
        is_unesco       INTEGER NOT NULL DEFAULT 0,
        cover_image_url TEXT,
        rating_avg      REAL    NOT NULL DEFAULT 0.0,
        review_count    INTEGER NOT NULL DEFAULT 0,
        is_bookmarked   INTEGER NOT NULL DEFAULT 0,
        is_featured     INTEGER NOT NULL DEFAULT 0,
        geofence_radius_m INTEGER NOT NULL DEFAULT 500,
        cached_at       INTEGER NOT NULL,
        is_dirty        INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // FTS5 full-text search over English + Nepali name/description
    await db.execute('''
      CREATE VIRTUAL TABLE local_heritage_sites_fts USING fts5(
        id UNINDEXED,
        name_en,
        name_ne,
        description_en,
        district,
        tokenize="unicode61"
      )
    ''');

    // Keep FTS in sync with the main table
    for (final sql in [
      '''CREATE TRIGGER lhs_ai AFTER INSERT ON local_heritage_sites BEGIN
           INSERT INTO local_heritage_sites_fts(id,name_en,name_ne,description_en,district)
           VALUES (new.id,new.name_en,new.name_ne,new.description_en,new.district);
         END''',
      '''CREATE TRIGGER lhs_ad AFTER DELETE ON local_heritage_sites BEGIN
           DELETE FROM local_heritage_sites_fts WHERE id = old.id;
         END''',
      '''CREATE TRIGGER lhs_au AFTER UPDATE ON local_heritage_sites BEGIN
           DELETE FROM local_heritage_sites_fts WHERE id = old.id;
           INSERT INTO local_heritage_sites_fts(id,name_en,name_ne,description_en,district)
           VALUES (new.id,new.name_en,new.name_ne,new.description_en,new.district);
         END''',
    ]) {
      await db.execute(sql);
    }

    await db.execute('''
      CREATE TABLE local_site_media (
        id          TEXT    PRIMARY KEY,
        site_id     TEXT    NOT NULL,
        media_type  TEXT    NOT NULL DEFAULT 'image',
        url         TEXT    NOT NULL,
        title_en    TEXT,
        title_ne    TEXT,
        is_primary  INTEGER NOT NULL DEFAULT 0,
        sort_order  INTEGER NOT NULL DEFAULT 0,
        cached_at   INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_lsm_site ON local_site_media (site_id)');

    await db.execute('''
      CREATE TABLE local_events (
        id              TEXT    PRIMARY KEY,
        site_id         TEXT,
        title_en        TEXT    NOT NULL,
        title_ne        TEXT    NOT NULL,
        description_en  TEXT,
        description_ne  TEXT,
        event_type      TEXT,
        event_date_ad   TEXT    NOT NULL,
        event_date_bs   TEXT    NOT NULL,
        is_recurring    INTEGER NOT NULL DEFAULT 0,
        district        TEXT,
        cover_image_url TEXT,
        cached_at       INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_le_site   ON local_events (site_id)');
    await db.execute('CREATE INDEX idx_le_date   ON local_events (event_date_ad)');
    await db.execute('CREATE INDEX idx_le_dist   ON local_events (district)');

    // ------------------------------------------------------------------
    // 2. User data — local-first, synced to server
    // ------------------------------------------------------------------
    await db.execute('''
      CREATE TABLE local_bookmarks (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        site_id       TEXT    NOT NULL,
        user_id       TEXT    NOT NULL,
        bookmarked_at INTEGER NOT NULL,
        is_synced     INTEGER NOT NULL DEFAULT 0,
        UNIQUE (site_id, user_id)
      )
    ''');
    await db.execute('CREATE INDEX idx_lb_site   ON local_bookmarks (site_id)');
    await db.execute('CREATE INDEX idx_lb_user   ON local_bookmarks (user_id)');
    await db.execute('CREATE INDEX idx_lb_sync   ON local_bookmarks (is_synced)');

    await db.execute('''
      CREATE TABLE local_reviews_draft (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        site_id     TEXT    NOT NULL,
        guide_id    TEXT,
        rating      INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
        comment     TEXT,
        created_at  INTEGER NOT NULL,
        is_synced   INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_lrd_site  ON local_reviews_draft (site_id)');
    await db.execute('CREATE INDEX idx_lrd_sync  ON local_reviews_draft (is_synced)');

    await db.execute('''
      CREATE TABLE local_user_profile (
        firebase_uid   TEXT PRIMARY KEY,
        full_name      TEXT NOT NULL,
        email          TEXT NOT NULL,
        phone          TEXT,
        avatar_url     TEXT,
        preferred_lang TEXT NOT NULL DEFAULT 'en',
        theme          TEXT NOT NULL DEFAULT 'system',
        cached_at      INTEGER NOT NULL
      )
    ''');

    // ------------------------------------------------------------------
    // 3. Sync queue
    // ------------------------------------------------------------------
    await db.execute('''
      CREATE TABLE sync_queue (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        operation   TEXT    NOT NULL,
        entity      TEXT    NOT NULL,
        entity_id   TEXT,
        payload     TEXT    NOT NULL,
        created_at  INTEGER NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        status      TEXT    NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','failed','done'))
      )
    ''');
    await db.execute('CREATE INDEX idx_sq_status  ON sync_queue (status)');
    await db.execute('CREATE INDEX idx_sq_created ON sync_queue (created_at ASC)');

    // ------------------------------------------------------------------
    // 4. App state
    // ------------------------------------------------------------------
    await db.execute('''
      CREATE TABLE local_search_history (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        query       TEXT    NOT NULL,
        searched_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_lsh_time ON local_search_history (searched_at DESC)');

    await db.execute('''
      CREATE TABLE local_recently_viewed (
        site_id   TEXT    PRIMARY KEY,
        viewed_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE local_notifications (
        id        TEXT    PRIMARY KEY,
        type      TEXT    NOT NULL,
        title_en  TEXT    NOT NULL,
        title_ne  TEXT,
        message   TEXT    NOT NULL,
        site_id   TEXT,
        event_id  TEXT,
        is_read   INTEGER NOT NULL DEFAULT 0,
        sent_at   INTEGER NOT NULL,
        cached_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_ln_unread  ON local_notifications (is_read)');
    await db.execute('CREATE INDEX idx_ln_sent_at ON local_notifications (sent_at DESC)');
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  /// Wipes all cached server content. User-created data (bookmarks, drafts) is
  /// preserved so the sync queue can still upload pending changes.
  Future<void> clearContentCache() async {
    final db = await database;
    final batch = db.batch();
    for (final t in ['local_heritage_sites', 'local_site_media', 'local_events', 'local_notifications']) {
      batch.delete(t);
    }
    await batch.commit(noResult: true);
  }

  /// Clears all user-specific data (sign-out).
  Future<void> clearUserData() async {
    final db = await database;
    final batch = db.batch();
    for (final t in [
      'local_bookmarks', 'local_reviews_draft', 'local_user_profile',
      'local_recently_viewed', 'local_search_history', 'sync_queue',
    ]) {
      batch.delete(t);
    }
    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
