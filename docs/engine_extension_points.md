# EnterpriseVoxelCAD - Engine Extension Points

---

## Semantic Command Engine (Schema v2)

The Semantic Command Engine provides fuzzy command resolution for agent-driven workflows.

### Extension Points

#### 1. Command Registration

```gdscript
# Register a command callback
CommandParser.register_command("my_custom_command", my_callback_func)

# Callback signature
func my_callback_func(params: Dictionary = {}) -> void:
    # Your implementation
    pass
```

#### 2. Custom Semantic Aliases

Add custom command aliases via database:

```sql
INSERT INTO semantic_commands (canonical_name, aliases, enabled)
VALUES ('my_custom_command', 'mcc,customcmd,mycmd', 1);
```

#### 3. Fuzzy Matching Configuration

The Levenshtein distance threshold is configurable in `CommandParser.resolve_command()`:

```gdscript
# Current implementation allows up to 2 character differences
if distance < best_distance and distance <= 2:
    best_distance = distance
    best_match = candidate
```

### Agent Engine Integration

The agent engine can use the semantic command layer to execute high-level instructions:

```
Agent Input: "Create a virtual block here"
        |
        v
Natural Language Processing (external)
        |
        v
Extracted command: "cvb" or "create_virtual_block"
        |
        v
CommandParser.resolve_and_execute("cvb", params)
        |
        v
VoxelManager.create_virtual_block(...)
```

### Registered Commands (Default)

| Canonical Name | Aliases | Callback Location |
|----------------|---------|-------------------|
| `create_virtual_block` | `cvb,cv,virtblock,vblock` | VoxelManager |
| `refine_virtual_block` | `rvb,refinevb,editvb` | VoxelManager |
| `delete_virtual_block` | `dvb,delvb,removevb` | VoxelManager |
| `create_voxel` | `cv,setvoxel,placevoxel` | VoxelManager |
| `delete_voxel` | `dv,removevoxel` | VoxelManager |
| `run_load_case` | `rlc,analyze` | StructuralAnalyzer |

### Testing

- `tests/test_semantic_commands.gd` covers:
  - Alias resolution
  - Fuzzy matching (Levenshtein distance)
  - Command execution with parameters
  - Error handling for unknown commands

This document defines the binding points for each of the nine planned engines.
All engines MUST register through EngineRegistry.gd and interact exclusively via defined public APIs.

Rule: Engines may add new methods to their own files but MUST NOT alter signatures in core modules defined by AI-0.

---

## 1. VoxelEngine
Binds to: VoxelManager.gd (create_voxel, delete_voxel, has_voxel, get_chunk), LayerSystem.gd, Database.gd
DB Tables: chunks, layers

## 2. MeshEngine
Binds to: VoxelManager.generate_mesh_for_chunk(), C++ VoxelMesher, C++ Subdivision
DB Tables: lod_chunks

## 3. SemanticEngine
Binds to: CommandParser.gd (register_command, execute_command)
DB Tables: semantic_commands

## 4. LoadEngine
Binds to: StructuralAnalyzer.gd (check_floating_async, run_full_load_case), Database.gd
DB Tables: load_cases, structural_results, structure_tags

## 5. MultiplayerEngine
Binds to: VoxelManager.gd (all mutation methods), LayerSystem.gd, TelemetryService.gd
DB Tables: multiplayer_sessions

## 6. AgentEngine
Binds to: CommandParser.gd, VoxelManager.gd, LayerSystem.gd, TelemetryService.gd
DB Tables: agents, agent_logs

## 7. LayerEngine
Binds to: LayerSystem.gd (all methods), Database.gd
DB Tables: layers, structure_tags

## 8. TextureEngine
Binds to: Database.gd (materials, textures), VoxelManager.gd (material_id)
DB Tables: textures, materials

## 9. LODEngine
Binds to: VoxelManager.generate_mesh_for_chunk(), C++ VoxelMesher, Database.gd
DB Tables: lod_chunks

---

## EngineRegistry Lifecycle

Game Start -> AutoLoad EngineRegistry._ready()
  -> Each engine calls register_engine(name, version, init_callable)
    -> EngineRegistry stores entry and calls init_callable()

Game End / Scene Change -> EngineRegistry.shutdown_all()
  -> Each engine receives shutdown signal

---

## Registration Example

  EngineRegistry.register_engine("SemanticEngine", "1.0", _init_semantic_engine)
  CommandParser.register_command("extrude", _handle_extrude)
  CommandParser.register_command("fill", _handle_fill)
