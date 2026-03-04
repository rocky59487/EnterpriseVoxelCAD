-- EnterpriseVoxelCAD Database Schema v1
-- Migration: schema_v1.sql
-- Engine: SQLite 3 with WAL mode + optional SQLCipher encryption
--
-- Usage:
--   sqlite3 project.db < tools/db/schema_v1.sql
--
-- WAL mode and foreign keys are enabled at runtime by the application:
--   PRAGMA journal_mode=WAL;
--   PRAGMA foreign_keys=ON;
--   PRAGMA key='<value_of_EVCAD_DB_KEY>';

-- ---------------------------------------------------------------------------
-- Migration tracking
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS schema_migrations (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  version    TEXT    NOT NULL UNIQUE,
  applied_at INTEGER NOT NULL  -- Unix epoch seconds (UTC)
);

INSERT OR IGNORE INTO schema_migrations (version, applied_at)
VALUES ('v1', strftime('%s', 'now'));

-- ---------------------------------------------------------------------------
-- Projects
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS projects (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT    NOT NULL,
  description TEXT    DEFAULT '',
  created_at  INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  updated_at  INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  owner       TEXT    NOT NULL DEFAULT 'default'
);

CREATE INDEX IF NOT EXISTS idx_projects_owner ON projects(owner);

-- ---------------------------------------------------------------------------
-- Materials
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS materials (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id  INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name        TEXT    NOT NULL,
  color_r     REAL    NOT NULL DEFAULT 1.0,  -- 0.0 .. 1.0
  color_g     REAL    NOT NULL DEFAULT 1.0,
  color_b     REAL    NOT NULL DEFAULT 1.0,
  color_a     REAL    NOT NULL DEFAULT 1.0,
  metallic    REAL    NOT NULL DEFAULT 0.0,
  roughness   REAL    NOT NULL DEFAULT 0.5,
  created_at  INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_materials_project ON materials(project_id);

-- ---------------------------------------------------------------------------
-- Layers
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS layers (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id  INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name        TEXT    NOT NULL,
  color_r     REAL    NOT NULL DEFAULT 1.0,
  color_g     REAL    NOT NULL DEFAULT 1.0,
  color_b     REAL    NOT NULL DEFAULT 1.0,
  visible     INTEGER NOT NULL DEFAULT 1,  -- 0 = hidden, 1 = visible
  locked      INTEGER NOT NULL DEFAULT 0,  -- 0 = editable, 1 = locked
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_at  INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_layers_project ON layers(project_id);

-- ---------------------------------------------------------------------------
-- Voxel Chunks
-- (Chunk coordinates are in chunk-space; each chunk = 16x16x16 voxels)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS voxel_chunks (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id  INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  layer_id    INTEGER NOT NULL REFERENCES layers(id)   ON DELETE CASCADE,
  chunk_x     INTEGER NOT NULL,
  chunk_y     INTEGER NOT NULL,
  chunk_z     INTEGER NOT NULL,
  -- Compressed voxel payload (run-length encoded or zstd-compressed blob)
  payload     BLOB    NOT NULL DEFAULT X'',
  updated_at  INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  UNIQUE (project_id, layer_id, chunk_x, chunk_y, chunk_z)
);

CREATE INDEX IF NOT EXISTS idx_chunks_project_layer
  ON voxel_chunks(project_id, layer_id);

CREATE INDEX IF NOT EXISTS idx_chunks_coords
  ON voxel_chunks(project_id, chunk_x, chunk_y, chunk_z);

-- ---------------------------------------------------------------------------
-- Load Cases (structural analysis scenarios)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS load_cases (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id   INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name         TEXT    NOT NULL,
  description  TEXT    DEFAULT '',
  force_x      REAL    NOT NULL DEFAULT 0.0,  -- N (Newtons)
  force_y      REAL    NOT NULL DEFAULT 0.0,
  force_z      REAL    NOT NULL DEFAULT 0.0,
  created_at   INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_load_cases_project ON load_cases(project_id);
