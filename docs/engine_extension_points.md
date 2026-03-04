# EnterpriseVoxelCAD - Engine Extension Points

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
