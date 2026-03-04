# EnterpriseVoxelCAD — Architecture Overview

---

## Virtual Block Engine (Schema v2)

The Virtual Block Engine enables logical grouping of voxels into manipulatable units called "virtual blocks". This abstraction layer sits on top of the raw voxel storage and provides:

### Architecture

```
+---------------------------+
|  VoxelManager (API)       |
|  - create_virtual_block() |
|  - refine_virtual_block() |
|  - delete_virtual_block() |
+---------------------------+
            |
            v
+---------------------------+
|  structure_tags table     |
|  - chunk_id               |
|  - voxel_index            |
|  - virtual_block_id       |
|  - structure_level        |
+---------------------------+
            |
            v
+---------------------------+
|  voxel_chunks (BLOB)      |
|  - Raw voxel storage      |
+---------------------------+
```

### Key Design Decisions

1. **Non-destructive to existing schema**: Virtual blocks are implemented via a separate `structure_tags` table that references `voxel_chunks.id` and `voxel_index`. The original BLOB storage is unchanged.

2. **In-memory tracking**: `VoxelManager` maintains `_virtual_blocks: Dictionary` mapping `virtual_block_id -> Array[Vector3i]` for fast lookup during editing sessions.

3. **Database persistence**: `structure_tags` table persists the mapping to disk, allowing virtual blocks to be restored when a project is loaded.

4. **Async structural analysis**: Virtual block operations do NOT trigger immediate full structural analysis. Instead:
   - Local floating checks are performed asynchronously via `StructuralAnalyzer.check_floating_async(position)`
   - Full load case analysis is triggered by explicit user action or tool-layer events

### Integration with Semantic Command Engine

The Semantic Command Engine (schema v2) provides fuzzy resolution for virtual block commands:

| Canonical Name | Aliases | Description |
|----------------|---------|-------------|
| `create_virtual_block` | `cvb,cv,virtblock,vblock` | Create a new virtual block from positions |
| `refine_virtual_block` | `rvb,refinevb,editvb` | Add/remove voxels from existing virtual block |
| `delete_virtual_block` | `dvb,delvb,removevb` | Delete a virtual block and all its voxels |

`CommandParser.resolve_command(input)` uses:
1. Exact match on canonical names
2. Alias lookup from `semantic_commands` table
3. Levenshtein distance fuzzy matching (max 2 edit distance)

### Data Flow

```
User Input (e.g., "cvb")
        |
        v
CommandParser.resolve_command("cvb")
        |
        v
Returns: "create_virtual_block"
        |
        v
CommandParser.execute_command("create_virtual_block", params)
        |
        v
VoxelManager.create_virtual_block(positions, material_id, layer_id)
        |
        +--> Creates voxels via create_voxel()
        +--> Inserts structure_tags for each voxel
        +--> Emits virtual_block_created signal
        |
        v
TelemetryService.record_event("virtual_block_created", ...)
```

### Testing

- `tests/test_virtual_block.gd`: Unit tests for VoxelManager virtual block API
- `tests/test_semantic_commands.gd`: Unit tests for CommandParser fuzzy resolution
- Integration tests verify end-to-end flow from command input to voxel creation

## Four-Layer Architecture

```
+--------------------------------------------------+
|  Layer 1: UI Layer                               |
|  (Godot Scenes, GDScript UI nodes, menus)        |
+--------------------------------------------------+
           |
           v
+--------------------------------------------------+
|  Layer 2: Logic Layer                            |
|  (GDScript core modules: VoxelManager,           |
|   LayerSystem, StructuralAnalyzer,               |
|   CommandParser, TelemetryService,               |
|   EngineRegistry, Database)                      |
+--------------------------------------------------+
           |
           v
+--------------------------------------------------+
|  Layer 3: GDExtension Layer                      |
|  (C++17 native modules: voxel_mesher,            |
|   subdivision, chunk_memory)                     |
+--------------------------------------------------+
           |
           v
+--------------------------------------------------+
|  Layer 4: Data Layer                             |
|  (SQLite + WAL, future SQLCipher encryption,     |
|   .env-based secrets, external DB paths)         |
+--------------------------------------------------+
```

---

## Layer 1: UI Layer

- Built with Godot 4 scenes (`.tscn`).
- Main scene: `scenes/main.tscn` — multi-viewport editor shell.
- Communicates with Logic Layer **only** via signals and public GDScript APIs.
- Must never access the database directly.

## Layer 2: Logic Layer

| Module | File | Responsibility |
|---|---|---|
| `VoxelManager` | `src/scripts/VoxelManager.gd` | CRUD for voxels, chunk allocation, mesh dispatch |
| `LayerSystem` | `src/scripts/LayerSystem.gd` | Layer create/visibility/mask management |
| `StructuralAnalyzer` | `src/scripts/StructuralAnalyzer.gd` | Floating detection, load-case execution |
| `CommandParser` | `src/scripts/CommandParser.gd` | Command registration and dispatch |
| `TelemetryService` | `src/scripts/TelemetryService.gd` | Metrics and event recording |
| `EngineRegistry` | `src/scripts/EngineRegistry.gd` | Engine plug-in registration |
| `Database` | `src/scripts/Database.gd` | SQLite access facade |

**Rule:** All modules in this layer are **public API**. Signatures are frozen after AI-0 publishes them.

## Layer 3: GDExtension Layer (C++17)

| Module | File | Responsibility |
|---|---|---|
| `VoxelMesher` | `src/gdextension/voxel_mesher.cpp` | Greedy meshing, LOD generation |
| `Subdivision` | `src/gdextension/subdivision.cpp` | Catmull-Clark subdivision |
| `ChunkMemory` | `src/gdextension/chunk_memory.cpp` | Chunk memory pool management |

All C++ classes are registered in `register_types.cpp` and exposed to GDScript via the GDExtension API.

## Layer 4: Data Layer

- SQLite database in **WAL mode** for concurrent read access.
- Database path is configured via `.env` (never hardcoded).
- SQLCipher hook is pre-wired in `Database.gd`; enable by setting `DB_ENCRYPT=true` in `.env`.
- Migration scripts live in `tools/db/schema_vN.sql`.

---

## Inter-Layer Communication Rules

1. UI → Logic: Godot signals or direct method calls on autoloaded singletons.
2. Logic → GDExtension: Direct method calls on registered GDExtension objects.
3. Logic → Data: **Only through** `Database.gd`. No raw SQL elsewhere.
4. GDExtension → Data: Not permitted. Must route through Logic layer.

---

## Engine Plug-in Architecture

Each of the nine planned engines registers itself via `EngineRegistry`:

```
EngineRegistry
  ├── VoxelEngine (virtual voxel / manifold surface)
  ├── MeshEngine  (greedy meshing, Catmull-Clark)
  ├── SemanticEngine (NLP command layer)
  ├── LoadEngine  (structural / FEA analysis)
  ├── MultiplayerEngine (collaborative editing)
  ├── AgentEngine (AI agents)
  ├── LayerEngine (advanced layer graphs)
  ├── TextureEngine (PBR / procedural textures)
  └── LODEngine   (level-of-detail streaming)
```

Each engine:
- Implements a standard `init()` / `shutdown()` lifecycle.
- Binds to one or more core module APIs (see `engine_extension_points.md`).
- Must **not** modify any public interface defined by AI-0.
