# EnterpriseVoxelCAD — Database Schema

---

## Virtual Block Tables (Schema v2)

### `structure_tags`

Stores associations between individual voxels and virtual blocks. Virtual blocks are logical groupings of voxels that can be manipulated as a single unit (e.g., "wall segment", "beam", "column").

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER PRIMARY KEY | Auto-increment |
| `project_id` | INTEGER NOT NULL | Foreign key to `projects` |
| `chunk_id` | INTEGER NOT NULL | Foreign key to `voxel_chunks` |
| `voxel_index` | INTEGER NOT NULL | Linear index within chunk (0..4095 for 16³) |
| `virtual_block_id` | INTEGER NOT NULL | Logical group identifier |
| `structure_level` | INTEGER DEFAULT 0 | 0=none, 1=primary, 2=secondary, 3=decorative |
| `created_at` | DATETIME DEFAULT CURRENT_TIMESTAMP | Creation timestamp |

**Indexes:**
- `idx_structure_tags_project` on `project_id`
- `idx_structure_tags_virtual_block` on `virtual_block_id`
- `idx_structure_tags_chunk` on `chunk_id`

**Constraints:**
- `UNIQUE (chunk_id, voxel_index)` — Each voxel can only belong to one virtual block at a time
- `FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE`
- `FOREIGN KEY (chunk_id) REFERENCES voxel_chunks(id) ON DELETE CASCADE`

**Usage:**
```sql
-- Find all voxels in a virtual block
SELECT vc.chunk_x, vc.chunk_y, vc.chunk_z, st.voxel_index
FROM structure_tags st
JOIN voxel_chunks vc ON st.chunk_id = vc.id
WHERE st.virtual_block_id = ?;

-- Find which virtual block a voxel belongs to
SELECT virtual_block_id, structure_level
FROM structure_tags
WHERE chunk_id = ? AND voxel_index = ?;
```

---

## Semantic Command Tables (Schema v2)

### `semantic_commands`

Stores canonical command names and their aliases for fuzzy command resolution. Allows users to type abbreviated or misspelled commands that still resolve correctly.

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER PRIMARY KEY | Auto-increment |
| `canonical_name` | TEXT NOT NULL UNIQUE | Official command name (e.g., `create_virtual_block`) |
| `aliases` | TEXT NOT NULL | Comma-separated list of aliases (e.g., `cvb,cv,virtblock`) |
| `phonetic_key` | TEXT | Reserved for future phonetic matching |
| `enabled` | INTEGER DEFAULT 1 | 0=disabled, 1=active |
| `created_at` | DATETIME DEFAULT CURRENT_TIMESTAMP | Creation timestamp |

**Indexes:**
- `idx_semantic_commands_enabled` on `enabled`

**Default Commands:**
| Canonical Name | Aliases | Purpose |
|----------------|---------|---------|
| `create_virtual_block` | `cvb,cv,virtblock,vblock,createvb` | Create a new virtual block |
| `refine_virtual_block` | `rvb,refinevb,editvb,modifyvb` | Modify an existing virtual block |
| `delete_virtual_block` | `dvb,delvb,removevb,deletevb` | Delete a virtual block |
| `create_voxel` | `cv,setvoxel,placevoxel` | Place a single voxel |
| `delete_voxel` | `dv,removevoxel,clearvoxel` | Remove a single voxel |
| `list_layers` | `ll,showlayers,la` | List all layers |
| `set_layer_visibility` | `slv,togglelayer,hidelayer` | Toggle layer visibility |
| `run_load_case` | `rlc,analyze,structural` | Run structural analysis |

**Usage:**
```sql
-- Resolve a fuzzy command input
SELECT canonical_name
FROM semantic_commands
WHERE enabled = 1
  AND (canonical_name = 'cvb' OR ',' || aliases || ',' LIKE '%,cvb,%');
```

---

## Virtual Block Workflow

1. **Create Virtual Block:**
   - `VoxelManager.create_virtual_block(positions, material_id, layer_id)` creates voxels
   - Returns a new `virtual_block_id`
   - Inserts records into `structure_tags` for each voxel

2. **Refine Virtual Block:**
   - `VoxelManager.refine_virtual_block(virtual_block_id, operations)` modifies voxels
   - Operations: `{ "op": "add", "position": Vector3i }` or `{ "op": "delete", "position": Vector3i }`
   - Updates `structure_tags` as voxels are added/removed

3. **Delete Virtual Block:**
   - `VoxelManager.delete_virtual_block(virtual_block_id)` removes all voxels
   - Deletes all `structure_tags` records for that `virtual_block_id`

4. **Semantic Command Resolution:**
   - `CommandParser.resolve_command(input)` resolves fuzzy input to canonical name
   - `CommandParser.execute_command(canonical_name, params)` executes the command
   - Example: User types "cvb" → resolves to "create_virtual_block" → executes callback

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
