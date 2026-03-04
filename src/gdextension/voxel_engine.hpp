#pragma once
// VoxelEngine GDExtension - C++17
// Provides high-performance voxel mesh generation callable from GDScript.

#ifndef VOXEL_ENGINE_HPP
#define VOXEL_ENGINE_HPP

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector3i.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <unordered_map>
#include <vector>
#include <cstdint>

namespace EnterpriseVoxelCAD {

/// Chunk size constant (16x16x16 voxels per chunk)
constexpr int CHUNK_SIZE = 16;

/// Voxel data stored per position
struct VoxelData {
  int32_t material_id{0};
  uint8_t  layer_id{0};
  bool     active{false};
};

/// Key for chunk lookup: encodes chunk coordinates
struct ChunkKey {
  int32_t cx, cy, cz;
  bool operator==(const ChunkKey& o) const noexcept {
    return cx == o.cx && cy == o.cy && cz == o.cz;
  }
};

struct ChunkKeyHash {
  std::size_t operator()(const ChunkKey& k) const noexcept {
    std::size_t h = 17;
    h = h * 31 + std::hash<int32_t>{}(k.cx);
    h = h * 31 + std::hash<int32_t>{}(k.cy);
    h = h * 31 + std::hash<int32_t>{}(k.cz);
    return h;
  }
};

using VoxelMap = std::unordered_map<uint64_t, VoxelData>;
using ChunkMap = std::unordered_map<ChunkKey, VoxelMap, ChunkKeyHash>;

/// GDExtension node exposed to Godot
class VoxelEngine : public godot::Node {
  GDCLASS(VoxelEngine, godot::Node)

public:
  VoxelEngine()  = default;
  ~VoxelEngine() = default;

  // --- Public API (bound to GDScript) ---

  /// Place or update a voxel at world position.
  void      set_voxel(godot::Vector3i pos, int32_t material_id, int32_t layer_id);

  /// Remove voxel at world position. Returns true if removed.
  bool      remove_voxel(godot::Vector3i pos);

  /// Returns true if voxel exists at position.
  bool      has_voxel(godot::Vector3i pos) const;

  /// Returns Dictionary with keys: vertices (PackedVector3Array), indices (PackedInt32Array)
  godot::Dictionary generate_mesh_for_chunk(godot::Vector3i chunk_origin);

  /// Returns Array of Vector3i positions of all active voxels in chunk.
  godot::Array get_active_voxels_in_chunk(godot::Vector3i chunk_origin) const;

  /// Clears all voxel data.
  void      clear_all();

protected:
  static void _bind_methods();

private:
  ChunkMap _chunks;

  static ChunkKey   _world_to_chunk(godot::Vector3i pos);
  static uint64_t   _local_key(int lx, int ly, int lz);
  VoxelMap&         _get_or_create_chunk(const ChunkKey& key);
  const VoxelMap*   _find_chunk(const ChunkKey& key) const;
};

} // namespace EnterpriseVoxelCAD

#endif // VOXEL_ENGINE_HPP
