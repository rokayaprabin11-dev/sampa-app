import 'package:flutter/foundation.dart';
import 'package:path/path.dart' show join;
import 'package:sqflite/sqflite.dart';

// v10: production cache migration.  This version is deliberately additive:
// cached content may be discarded, but pending actions and user preferences
// must survive an app update.
const int _kDbVersion = 10;
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
        try {
          await db.execute('PRAGMA journal_mode = WAL');
        } catch (_) {}
      },
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Never rebuild the database during a production upgrade.  In particular,
    // doing so loses queued offline actions before they can be synchronized.
    if (oldVersion < 10) {
      await _migrateToV10(db);
    }
  }

  Future<void> _migrateToV10(Database db) async {
    // These columns are optional cache enrichment.  Older installs keep their
    // existing rows and simply receive null/default values until refreshed.
    for (final statement in [
      'ALTER TABLE local_heritage_sites ADD COLUMN history_en TEXT',
      'ALTER TABLE local_heritage_sites ADD COLUMN history_ne TEXT',
      'ALTER TABLE local_heritage_sites ADD COLUMN municipality TEXT',
      'ALTER TABLE local_heritage_sites ADD COLUMN opening_hours TEXT',
      'ALTER TABLE local_heritage_sites ADD COLUMN entry_fee TEXT',
      'ALTER TABLE local_events ADD COLUMN rsvp_status TEXT',
      'ALTER TABLE local_events ADD COLUMN updated_at INTEGER',
      'ALTER TABLE local_user_profile ADD COLUMN notification_preferences TEXT',
      'ALTER TABLE local_user_profile ADD COLUMN last_updated INTEGER',
    ]) {
      try {
        await db.execute(statement);
      } catch (_) {
        // The column may already exist on a partially migrated install.
      }
    }
    await _createProductionTables(db);
    await _createIndexes(db);
    // Retire unused legacy caches.  None are read by the current app; keeping
    // them duplicates server data and can retain sensitive/nonessential data.
    for (final table in [
      'local_site_media',
      'local_reviews_draft',
      'local_recently_viewed',
      'local_search_history',
      'cache_users',
      'cache_districts',
      'cache_sites',
      'cache_sites_fts',
      'cache_site_media',
      'cache_events',
      'cache_site_reviews',
      'cache_guides',
      'cache_bookings',
      'cache_notifications',
      'cache_offline_downloads',
    ]) {
      await db.execute('DROP TABLE IF EXISTS $table');
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
      history_en      TEXT,
      history_ne      TEXT,
      latitude        REAL    NOT NULL,
      longitude       REAL    NOT NULL,
      district        TEXT    NOT NULL,
      province        TEXT,
      municipality    TEXT,
      opening_hours   TEXT,
      entry_fee       TEXT,
        is_unesco       INTEGER NOT NULL DEFAULT 0,
        cover_image_url TEXT,
        rating_avg      REAL    NOT NULL DEFAULT 0.0,
        review_count    INTEGER NOT NULL DEFAULT 0,
        is_bookmarked   INTEGER NOT NULL DEFAULT 0,
        is_featured     INTEGER NOT NULL DEFAULT 0,
        geofence_radius_m INTEGER NOT NULL DEFAULT 500,
        cached_at       INTEGER NOT NULL,
        updated_at      INTEGER,
        is_dirty        INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _createIndexes(db);

    // FTS5 is compiled into standard SQLite but some Android vendors (MIUI, etc.)
    // ship a stripped SQLite without it.  Fall back to FTS4, then skip.
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE local_heritage_sites_fts USING fts5(
          id, name_en, name_ne, district, category,
          tokenize = "unicode61"
        )
      ''');
    } catch (_) {
      try {
        await db.execute('''
          CREATE VIRTUAL TABLE local_heritage_sites_fts USING fts4(
            id, name_en, name_ne, district, category
          )
        ''');
      } catch (_) {
        // FTS not available — local search falls back to LIKE queries.
      }
    }

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
        start_time      TEXT,
        end_time        TEXT,
        is_recurring    INTEGER NOT NULL DEFAULT 0,
        district        TEXT,
        cover_image_url TEXT,
        rsvp_status     TEXT,
        cached_at       INTEGER NOT NULL,
        updated_at      INTEGER
      )
    ''');

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
    await db
        .execute('CREATE INDEX idx_lb_sync   ON local_bookmarks (is_synced)');

    await db.execute('''
      CREATE TABLE local_user_profile (
        firebase_uid   TEXT PRIMARY KEY,
        full_name      TEXT NOT NULL,
        email          TEXT NOT NULL,
        phone          TEXT,
        avatar_url     TEXT,
        preferred_lang TEXT NOT NULL DEFAULT 'en',
        theme          TEXT NOT NULL DEFAULT 'system',
        notification_preferences TEXT,
        cached_at      INTEGER NOT NULL,
        last_updated   INTEGER
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
    // ------------------------------------------------------------------
    // 4. Notification history — saved on FCM receive for offline access
    // ------------------------------------------------------------------
    await db.execute('''
      CREATE TABLE local_notifications (
        id          TEXT    PRIMARY KEY,
        title       TEXT    NOT NULL,
        body        TEXT    NOT NULL,
        type        TEXT    NOT NULL DEFAULT 'system',
        data        TEXT    NOT NULL DEFAULT '{}',
        is_read     INTEGER NOT NULL DEFAULT 0,
        received_at INTEGER NOT NULL
      )
    ''');
    await _createProductionTables(db);
    await _createIndexes(db);
  }

  Future<void> _createProductionTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_metadata (
        table_name   TEXT PRIMARY KEY,
        last_sync_at INTEGER NOT NULL,
        version      INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_heritage_categories (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        icon       TEXT,
        updated_at INTEGER,
        cached_at  INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_help_articles (
        id         TEXT PRIMARY KEY,
        title      TEXT NOT NULL,
        body       TEXT NOT NULL,
        kind       TEXT NOT NULL DEFAULT 'article',
        updated_at INTEGER,
        cached_at  INTEGER NOT NULL
      )
    ''');
    // Sync actions are transient.  A successful worker update removes the row
    // in SQLite itself, preventing completed operations from accumulating even
    // if the process is terminated before its Dart cleanup runs.
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS delete_completed_sync_actions
      AFTER UPDATE OF status ON sync_queue
      WHEN NEW.status = 'done'
      BEGIN
        DELETE FROM sync_queue WHERE id = NEW.id;
      END
    ''');
    await _createFtsTables(db);
  }

  Future<void> _createIndexes(Database db) async {
    for (final statement in [
      'CREATE INDEX IF NOT EXISTS idx_lhs_district ON local_heritage_sites (district)',
      'CREATE INDEX IF NOT EXISTS idx_lhs_name_en ON local_heritage_sites (name_en)',
      'CREATE INDEX IF NOT EXISTS idx_lhs_rating ON local_heritage_sites (rating_avg DESC)',
      'CREATE INDEX IF NOT EXISTS idx_lhs_featured ON local_heritage_sites (is_featured)',
      'CREATE INDEX IF NOT EXISTS idx_lhs_cached ON local_heritage_sites (cached_at)',
      'CREATE INDEX IF NOT EXISTS idx_lhs_coordinates ON local_heritage_sites (latitude, longitude)',
      'CREATE INDEX IF NOT EXISTS idx_le_site ON local_events (site_id)',
      'CREATE INDEX IF NOT EXISTS idx_le_date ON local_events (event_date_ad)',
      'CREATE INDEX IF NOT EXISTS idx_le_cached ON local_events (cached_at)',
      'CREATE INDEX IF NOT EXISTS idx_sq_status ON sync_queue (status, created_at ASC)',
      'CREATE INDEX IF NOT EXISTS idx_ln_received ON local_notifications (received_at DESC)',
      'CREATE INDEX IF NOT EXISTS idx_ln_read ON local_notifications (is_read)',
    ]) {
      try {
        await db.execute(statement);
      } catch (_) {
        // Older, incomplete development databases are repaired on next sync.
      }
    }
  }

  Future<void> _createFtsTables(Database db) async {
    // Keep the existing heritage index.  Event/help indexes are populated only
    // by their local writers, so no server payload or UI contract changes.
    for (final spec in [
      ('local_events_fts', 'id, title_en, title_ne'),
      ('local_help_articles_fts', 'id, title, body'),
    ]) {
      try {
        await db.execute(
            'CREATE VIRTUAL TABLE IF NOT EXISTS ${spec.$1} USING fts5(${spec.$2}, tokenize = "unicode61")');
      } catch (_) {
        try {
          await db.execute(
              'CREATE VIRTUAL TABLE IF NOT EXISTS ${spec.$1} USING fts4(${spec.$2})');
        } catch (_) {}
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  /// Wipes all cached server content. User-created data (bookmarks, drafts) is
  /// preserved so the sync queue can still upload pending changes.
  Future<void> clearContentCache() async {
    final db = await database;
    final batch = db.batch();
    for (final t in [
      'local_heritage_sites',
      'local_heritage_sites_fts',
      'local_events',
      'local_events_fts',
      'local_heritage_categories',
      'local_help_articles',
      'local_help_articles_fts',
      'cache_metadata',
    ]) {
      batch.delete(t);
    }
    await batch.commit(noResult: true);
  }

  /// Clears all user-specific data (sign-out).
  Future<void> clearUserData() async {
    final db = await database;
    final batch = db.batch();
    for (final t in [
      'local_bookmarks',
      'local_user_profile',
      'sync_queue',
      'local_notifications',
    ]) {
      batch.delete(t);
    }
    await batch.commit(noResult: true);
  }

  Future<void> vacuumAndCheckpoint() async {
    if (kIsWeb) return;
    final db = await database;
    await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    await db.execute('VACUUM');
  }

  /// Low-cost retention work for a background sync or app-idle callback.
  /// It never touches pending user actions.  Help articles use an ID primary
  /// key, so a newer server version replaces the older row rather than growing
  /// history indefinitely.
  Future<void> runCacheMaintenance() async {
    if (kIsWeb) return;
    final db = await database;
    final now = DateTime.now();
    final notificationCutoff =
        now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    final helpCutoff =
        now.subtract(const Duration(days: 180)).millisecondsSinceEpoch ~/ 1000;
    await db.transaction((txn) async {
      await txn.delete('sync_queue', where: "status = 'done'");
      await txn.delete(
        'local_notifications',
        where: 'received_at < ?',
        whereArgs: [notificationCutoff],
      );
      await txn.delete(
        'local_help_articles',
        where: 'cached_at < ?',
        whereArgs: [helpCutoff],
      );
    });
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
