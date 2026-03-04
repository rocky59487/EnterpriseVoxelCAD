# EnterpriseVoxelCAD — Database Schema

All tables live in a single SQLite database file. Path is configured via `.env` (`DB_PATH`).  
WAL mode is always enabled for concurrent read access.  
SQLCipher encryption can be activated via `DB_ENCRYPT=true` in `.env`.

---

## Core Tables

### `projects`
Stores top-level project metadata.

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PRIMARY KEY | Auto-increment |
| `name` | TEXT NOT NULL | Project display name |
| `description` | TEXT | Optional description |
| `created_at` | DATETIME DEFAULT CURRENT_TIMESTAMP | |
| `updated_at` | DATETIME DEFAULT CURRENT_TIMESTAMP | Updated on save |

---

### `materials`
Material library shared across projects.

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PRIMARY KEY | |
| `name` | TEXT NOT NULL | Material name |
| `color_hex` | TEXT | Hex color string |
| `density_kg_m3` | REAL | Density in kg/m³ |
| `structural_score` | REAL | Normalized 0.0–1.0 |
| `is_structural` | INTEGER DEFAULT 0 | Boolean flag |
| `created_at` | DATETIME DEFAULT CURRENT_TIMESTAMP | |

---

### `chunks`
Compressed voxel data, one row per 32³32³32 chunk.

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PRIMARY KEY | |
| `project_id` | INTEGER NOT NULL | FK → projects.id |
| `chunk_x` | INTEGER NOT NULL | Chunk X coordinate |
| `chunk_y` | INTEGER NOT NULL | Chunk Y coordinate |
| `chunk_z` | INTEGER NOT NULL | Chunk Z coordinate |
| `data` | BLOB | Compressed voxel data |
| `modified_at` | DATETIME DEFAULT CURRENT_TIMESTAMP | |
| `created_at` | DATETIME DEFAULT CURRENT_TIMESTAMP | |
| UNIQUE(project_id, chunk_x, chunk_y, chunk_z) | | Prevents duplicate chunks |

**WAL Mode Note:** Enabled at connection time to allow concurrent reads during chunk streaming.

---

### `layers`
Editor layers for organizing voxels by source or type.

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PRIMARY KEY | |
| `project_id` | INTEGER NOT NULL | FK → projects.id |
| `layer_name` | TEXT NOT NULL | Display name |
| `layer_mask` | INTEGER DEFAULT 0 | Bitmask for filtering |
| `visible` | INTEGER DEFAULT 1 | Boolean |
| `locked` | INTEGER DEFAULT 0 | Boolean |
| `source_type` | TEXT DEFAULT 'human' | 'human' / 'ai' / 'import' |
| `created_at` | DATETIME DEFAULT CURRENT_TIMESTAMP | |

---

### `undo_stack`
Operation history for undo/redo. Operations are stored as JSON.

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PRIMARY KEY | |
| `project_id` | INTEGER NOT NULL | FK → projects.id |
| `operation` | TEXT NOT NULL | JSON-serialized operation |
| `timestamp` | DATETIME DEFAULT CURRENT_TIMESTAMP | |
| `is_undone` | INTEGER DEFAULT 0 | Boolean |

---

## Engine-Reserved Tables (Stub, to be expanded by respective AI engines)

### `semantic_commands` — Semantic Engine
| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PRIMARY KEY | |
| `project_id` | INTEGER | FK → projects.id |
| `raw_input` | TEXT | Original user input |
| `parsed_command` | TEXT | JSON parsed result |
| `executed_at` | DATETIME | |
| `created_at` | DATETIME DEFAULT CURRENT_TIMESTAMP | |

### `load_cases` — Load Engine
| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PRIMARY KEY | |
| `project_id` | INTEGER | |
| `name` | TEXT | |
| `parameters` | TEXT | JSON load parameters |
| `created_at` | DATETIME DEFAULT CURRENT_TIMESTAMP | |

### `structural_results` — Load Engine
| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PRIMARY KEY | |
| `load_case_id` | INTEGER | FK → load_cases.id |
| `result_data` | TEXT | JSON analysis results |
| `created_at` | DATETIME DEFAULT CURRENT_TIMESTAMP | |

### `multiplayer_sessions` — Multiplayer Engine
| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PRIMARY KEY | |
| `project_id` | INTEGER | |
| `session_token` | TEXT | |
| `started_at` | DATETIME | |
| `ended_at` | DATETIME | |
| `created_at` | DATETIME DEFAULT CURRENT_TIMESTAMP | |

### `agents` — Agent Engine
| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PRIMARY KEY | |
| `name` | TEXT | |
| `agent_type` | TEXT | |
| `config` | TEXT | JSON config |
| `created_at` | DATETIME DEFAULT CURRENT_TIMESTAMP | |

### `agent_logs` — Agent Engine
| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PRIMARY KEY | |
| `agent_id` | INTEGER | FK → agents.id |
| `action` | TEXT | |
| `result` | TEXT | |
| `created_at` | DATETIME DEFAULT CURRENT_TIMESTAMP | |

### `structure_tags` — Layer + Load Engine
| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PRIMARY KEY | |
| `project_id` | INTEGER | |
| `layer_id` | INTEGER | |
| `tag_name` | TEXT | |
| `tag_value` | TEXT | |
| `created_at` | DATETIME DEFAULT CURRENT_TIMESTAMP | |

### `textures` — Texture Engine
| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PRIMARY KEY | |
| `material_id` | INTEGER | FK → materials.id |
| `texture_type` | TEXT | 'albedo' / 'normal' / 'roughness' |
| `data` | BLOB | Compressed texture data |
| `created_at` | DATETIME DEFAULT CURRENT_TIMESTAMP | |

### `lod_chunks` — LOD Engine
| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PRIMARY KEY | |
| `chunk_id` | INTEGER | FK → chunks.id |
| `lod_level` | INTEGER | 0 = full detail |
| `data` | BLOB | LOD-reduced mesh data |
| `created_at` | DATETIME DEFAULT CURRENT_TIMESTAMP | |

---

## Migration Convention

- Each schema version is a separate file: `tools/db/schema_v1.sql`, `schema_v2.sql`, etc.
- Migrations are applied in order; never modify an existing migration file.
- `Database.gd` tracks the applied version in a `_schema_version` table.
