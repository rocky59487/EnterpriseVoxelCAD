#include "voxel_engine.hpp"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

using namespace godot;
using namespace EnterpriseVoxelCAD;

// ---------------------------------------------------------------------------
// Static helpers
// ---------------------------------------------------------------------------

ChunkKey VoxelEngine::_world_to_chunk(Vector3i pos) {
  auto floordiv = [](int32_t a, int32_t b) -> int32_t {
    return a / b - (a % b != 0 && (a ^ b) < 0);
  };
  return {floordiv(pos.x, CHUNK_SIZE),
          floordiv(pos.y, CHUNK_SIZE),
          floordiv(pos.z, CHUNK_SIZE)};
}

uint64_t VoxelEngine::_local_key(int lx, int ly, int lz) {
  return static_cast<uint64_t>(lx)
       | (static_cast<uint64_t>(ly) << 16)
       | (static_cast<uint64_t>(lz) << 32);
}

VoxelMap& VoxelEngine::_get_or_create_chunk(const ChunkKey& key) {
  return _chunks[key];
}

const VoxelMap* VoxelEngine::_find_chunk(const ChunkKey& key) const {
  auto it = _chunks.find(key);
  if (it == _chunks.end()) return nullptr;
  return &it->second;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

void VoxelEngine::set_voxel(Vector3i pos, int32_t material_id, int32_t layer_id) {
  auto key  = _world_to_chunk(pos);
  auto& map = _get_or_create_chunk(key);
  int lx = pos.x - key.cx * CHUNK_SIZE;
  int ly = pos.y - key.cy * CHUNK_SIZE;
  int lz = pos.z - key.cz * CHUNK_SIZE;
  uint64_t k = _local_key(lx, ly, lz);
  map[k] = VoxelData{material_id, static_cast<uint8_t>(layer_id), true};
}

bool VoxelEngine::remove_voxel(Vector3i pos) {
  auto key = _world_to_chunk(pos);
  auto* map = _find_chunk(key);
  if (!map) return false;
  int lx = pos.x - key.cx * CHUNK_SIZE;
  int ly = pos.y - key.cy * CHUNK_SIZE;
  int lz = pos.z - key.cz * CHUNK_SIZE;
  return const_cast<VoxelMap*>(map)->erase(_local_key(lx, ly, lz)) > 0;
}

bool VoxelEngine::has_voxel(Vector3i pos) const {
  auto key = _world_to_chunk(pos);
  auto* map = _find_chunk(key);
  if (!map) return false;
  int lx = pos.x - key.cx * CHUNK_SIZE;
  int ly = pos.y - key.cy * CHUNK_SIZE;
  int lz = pos.z - key.cz * CHUNK_SIZE;
  return map->count(_local_key(lx, ly, lz)) > 0;
}

Dictionary VoxelEngine::generate_mesh_for_chunk(Vector3i chunk_origin) {
  // Naive cube mesher: emits 6 quads per exposed face (greedy TBD)
  Dictionary result;
  PackedVector3Array vertices;
  PackedInt32Array   indices;

  ChunkKey key{chunk_origin.x, chunk_origin.y, chunk_origin.z};
  auto* map = _find_chunk(key);
  if (!map) {
    result["vertices"] = vertices;
    result["indices"]  = indices;
    return result;
  }

  static const Vector3 face_normals[6] = {
    {0,0,1},{0,0,-1},{0,1,0},{0,-1,0},{1,0,0},{-1,0,0}
  };
  static const Vector3 face_verts[6][4] = {
    {{0,0,1},{1,0,1},{1,1,1},{0,1,1}},
    {{1,0,0},{0,0,0},{0,1,0},{1,1,0}},
    {{0,1,0},{1,1,0},{1,1,1},{0,1,1}},
    {{0,0,1},{1,0,1},{1,0,0},{0,0,0}},
    {{1,0,0},{1,1,0},{1,1,1},{1,0,1}},
    {{0,0,1},{0,1,1},{0,1,0},{0,0,0}}
  };

  int32_t base = 0;
  for (auto& [k, vdata] : *map) {
    if (!vdata.active) continue;
    int lx = static_cast<int>(k & 0xFFFF);
    int ly = static_cast<int>((k >> 16) & 0xFFFF);
    int lz = static_cast<int>((k >> 32) & 0xFFFF);
    Vector3 origin(chunk_origin.x * CHUNK_SIZE + lx,
                   chunk_origin.y * CHUNK_SIZE + ly,
                   chunk_origin.z * CHUNK_SIZE + lz);
    for (int f = 0; f < 6; ++f) {
      for (int v = 0; v < 4; ++v)
        vertices.push_back(origin + face_verts[f][v]);
      indices.push_back(base);   indices.push_back(base+1); indices.push_back(base+2);
      indices.push_back(base);   indices.push_back(base+2); indices.push_back(base+3);
      base += 4;
    }
  }

  result["vertices"] = vertices;
  result["indices"]  = indices;
  return result;
}

Array VoxelEngine::get_active_voxels_in_chunk(Vector3i chunk_origin) const {
  Array out;
  ChunkKey key{chunk_origin.x, chunk_origin.y, chunk_origin.z};
  auto* map = _find_chunk(key);
  if (!map) return out;
  for (auto& [k, vdata] : *map) {
    if (!vdata.active) continue;
    int lx = static_cast<int>(k & 0xFFFF);
    int ly = static_cast<int>((k >> 16) & 0xFFFF);
    int lz = static_cast<int>((k >> 32) & 0xFFFF);
    out.push_back(Vector3i(
      chunk_origin.x * CHUNK_SIZE + lx,
      chunk_origin.y * CHUNK_SIZE + ly,
      chunk_origin.z * CHUNK_SIZE + lz));
  }
  return out;
}

void VoxelEngine::clear_all() {
  _chunks.clear();
}

// ---------------------------------------------------------------------------
// GDExtension binding
// ---------------------------------------------------------------------------

void VoxelEngine::_bind_methods() {
  ClassDB::bind_method(D_METHOD("set_voxel", "pos", "material_id", "layer_id"),
                       &VoxelEngine::set_voxel);
  ClassDB::bind_method(D_METHOD("remove_voxel", "pos"), &VoxelEngine::remove_voxel);
  ClassDB::bind_method(D_METHOD("has_voxel",    "pos"), &VoxelEngine::has_voxel);
  ClassDB::bind_method(D_METHOD("generate_mesh_for_chunk", "chunk_origin"),
                       &VoxelEngine::generate_mesh_for_chunk);
  ClassDB::bind_method(D_METHOD("get_active_voxels_in_chunk", "chunk_origin"),
                       &VoxelEngine::get_active_voxels_in_chunk);
  ClassDB::bind_method(D_METHOD("clear_all"), &VoxelEngine::clear_all);
}
