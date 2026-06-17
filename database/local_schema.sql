-- =============================================================================
-- Sampada · सम्पदा — Local SQLite Schema (sqflite / on-device)
-- =============================================================================
-- This file documents the on-device SQLite schema.
-- The canonical implementation lives in lib/core/database/database_helper.dart.
--
-- Design principles
--   • UUID primary keys for cached server data  (TEXT id)
--   • AUTOINCREMENT integer PKs for local-first data (bookmarks, drafts, queue)
--   • All timestamps stored as INTEGER Unix seconds for easy sorting
--   • is_dirty / is_synced flags drive the sync queue
--   • No foreign-key enforcement (sqflite has it off by default for speed)
-- =============================================================================

-- Offline content cache -------------------------------------------------------

CREATE TABLE IF NOT EXISTS local_heritage_sites (
    id              TEXT    PRIMARY KEY,            -- UUID from server
    name_en         TEXT    NOT NULL,
    name_ne         TEXT    NOT NULL,
    category        TEXT    NOT NULL,               -- temple | stupa | palace | …
    short_desc_en   TEXT,
    short_desc_ne   TEXT,
    description_en  TEXT,
    description_ne  TEXT,
    latitude        REAL    NOT NULL,               -- for proximity sort
    longitude       REAL    NOT NULL,
    district        TEXT    NOT NULL,
    province        TEXT,
    is_unesco       INTEGER NOT NULL DEFAULT 0,     -- boolean
    cover_image_url TEXT,
    rating_avg      REAL    NOT NULL DEFAULT 0.0,
    review_count    INTEGER NOT NULL DEFAULT 0,
    is_bookmarked   INTEGER NOT NULL DEFAULT 0,     -- cached flag (fast UI)
    cached_at       INTEGER NOT NULL,               -- Unix timestamp
    is_dirty        INTEGER NOT NULL DEFAULT 0      -- 0 = clean | 1 = pending sync
);

CREATE INDEX IF NOT EXISTS idx_lhs_category  ON local_heritage_sites (category);
CREATE INDEX IF NOT EXISTS idx_lhs_district  ON local_heritage_sites (district);
CREATE INDEX IF NOT EXISTS idx_lhs_latitude  ON local_heritage_sites (latitude);
CREATE INDEX IF NOT EXISTS idx_lhs_longitude ON local_heritage_sites (longitude);
CREATE INDEX IF NOT EXISTS idx_lhs_rating    ON local_heritage_sites (rating_avg DESC);


CREATE TABLE IF NOT EXISTS local_events (
    id              TEXT    PRIMARY KEY,            -- UUID from server
    site_id         TEXT,                           -- → local_heritage_sites.id
    title_en        TEXT    NOT NULL,
    title_ne        TEXT    NOT NULL,
    description_en  TEXT,
    description_ne  TEXT,
    event_type      TEXT,
    event_date_ad   TEXT    NOT NULL,               -- ISO date "2026-06-13"
    event_date_bs   TEXT    NOT NULL,               -- Bikram Sambat "2083-02-30"
    is_recurring    INTEGER NOT NULL DEFAULT 0,
    district        TEXT,
    cover_image_url TEXT,
    cached_at       INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_le_site_id     ON local_events (site_id);
CREATE INDEX IF NOT EXISTS idx_le_date        ON local_events (event_date_ad);
CREATE INDEX IF NOT EXISTS idx_le_district    ON local_events (district);


CREATE TABLE IF NOT EXISTS local_site_media (
    id              TEXT    PRIMARY KEY,            -- UUID from server
    site_id         TEXT    NOT NULL,               -- → local_heritage_sites.id
    media_type      TEXT    NOT NULL DEFAULT 'image',
    url             TEXT    NOT NULL,
    title_en        TEXT,
    title_ne        TEXT,
    is_primary      INTEGER NOT NULL DEFAULT 0,
    sort_order      INTEGER NOT NULL DEFAULT 0,
    cached_at       INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_lsm_site_id ON local_site_media (site_id);


-- User data (local-first) -----------------------------------------------------

CREATE TABLE IF NOT EXISTS local_bookmarks (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    site_id         TEXT    NOT NULL,               -- → local_heritage_sites.id
    user_id         TEXT    NOT NULL,               -- Firebase UID
    bookmarked_at   INTEGER NOT NULL,               -- Unix timestamp
    is_synced       INTEGER NOT NULL DEFAULT 0,     -- 0 = queued | 1 = confirmed

    UNIQUE (site_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_lb_site_id  ON local_bookmarks (site_id);
CREATE INDEX IF NOT EXISTS idx_lb_user_id  ON local_bookmarks (user_id);
CREATE INDEX IF NOT EXISTS idx_lb_synced   ON local_bookmarks (is_synced);


CREATE TABLE IF NOT EXISTS local_reviews_draft (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    site_id         TEXT    NOT NULL,               -- → local_heritage_sites.id
    guide_id        TEXT,                           -- optional, for guide reviews
    rating          INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment         TEXT,
    created_at      INTEGER NOT NULL,               -- Unix timestamp
    is_synced       INTEGER NOT NULL DEFAULT 0      -- 0 = pending upload
);

CREATE INDEX IF NOT EXISTS idx_lrd_site_id ON local_reviews_draft (site_id);
CREATE INDEX IF NOT EXISTS idx_lrd_synced  ON local_reviews_draft (is_synced);


CREATE TABLE IF NOT EXISTS local_user_profile (
    firebase_uid    TEXT    PRIMARY KEY,
    full_name       TEXT    NOT NULL,
    email           TEXT    NOT NULL,
    phone           TEXT,
    avatar_url      TEXT,                           -- Cloudinary URL
    preferred_lang  TEXT    NOT NULL DEFAULT 'en',
    theme           TEXT    NOT NULL DEFAULT 'system',
    cached_at       INTEGER NOT NULL                -- Unix timestamp
);


-- Sync queue ------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS sync_queue (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    operation       TEXT    NOT NULL,               -- CREATE | UPDATE | DELETE
    entity          TEXT    NOT NULL,               -- bookmark | review | profile | …
    entity_id       TEXT,                           -- local row id for reference
    payload         TEXT    NOT NULL,               -- JSON blob of the change
    created_at      INTEGER NOT NULL,               -- Unix timestamp
    retry_count     INTEGER NOT NULL DEFAULT 0,     -- max 3 retries
    status          TEXT    NOT NULL DEFAULT 'pending'
                            CHECK (status IN ('pending','failed','done'))
);

CREATE INDEX IF NOT EXISTS idx_sq_operation ON sync_queue (operation);
CREATE INDEX IF NOT EXISTS idx_sq_status    ON sync_queue (status);
CREATE INDEX IF NOT EXISTS idx_sq_created   ON sync_queue (created_at ASC);


-- App state -------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS local_search_history (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    query           TEXT    NOT NULL,
    searched_at     INTEGER NOT NULL                -- Unix timestamp
);

CREATE INDEX IF NOT EXISTS idx_lsh_time ON local_search_history (searched_at DESC);


CREATE TABLE IF NOT EXISTS local_recently_viewed (
    site_id         TEXT    PRIMARY KEY,            -- → local_heritage_sites.id
    viewed_at       INTEGER NOT NULL                -- Unix timestamp (most recent)
);

CREATE INDEX IF NOT EXISTS idx_lrv_time ON local_recently_viewed (viewed_at DESC);


CREATE TABLE IF NOT EXISTS local_notifications (
    id              TEXT    PRIMARY KEY,            -- UUID from server
    type            TEXT    NOT NULL,
    title_en        TEXT    NOT NULL,
    title_ne        TEXT,
    message         TEXT    NOT NULL,
    site_id         TEXT,
    event_id        TEXT,
    is_read         INTEGER NOT NULL DEFAULT 0,
    sent_at         INTEGER NOT NULL,               -- Unix timestamp
    cached_at       INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ln_unread  ON local_notifications (is_read) WHERE is_read = 0;
CREATE INDEX IF NOT EXISTS idx_ln_sent_at ON local_notifications (sent_at DESC);
