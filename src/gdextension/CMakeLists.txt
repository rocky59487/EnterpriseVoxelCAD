cmake_minimum_required(VERSION 3.22)
project(EnterpriseVoxelCAD VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ---- godot-cpp submodule ----
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/godot-cpp/CMakeLists.txt")
  message(FATAL_ERROR
    "godot-cpp submodule not initialised. Run:\n"
    "  git submodule update --init --recursive")
endif()

set(GODOT_CPP_SYSTEM_HEADERS ON CACHE BOOL "" FORCE)
add_subdirectory(godot-cpp)

# ---- Shared library target ----
file(GLOB_RECURSE SOURCES CONFIGURE_DEPENDS *.cpp)
list(FILTER SOURCES EXCLUDE REGEX ".*godot-cpp.*")

add_library(enterprise_voxel_cad SHARED ${SOURCES})

target_include_directories(enterprise_voxel_cad PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(enterprise_voxel_cad PRIVATE godot::cpp)

target_compile_options(enterprise_voxel_cad PRIVATE
  $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall -Wextra -Wpedantic>
  $<$<CXX_COMPILER_ID:MSVC>:/W4>
)

# Strip debug symbols in Release
if(CMAKE_BUILD_TYPE STREQUAL "Release")
  if(UNIX)
    add_custom_command(TARGET enterprise_voxel_cad POST_BUILD
      COMMAND ${CMAKE_STRIP} $<TARGET_FILE:enterprise_voxel_cad>)
  endif()
endif()

# Output to builds/ directory
set_target_properties(enterprise_voxel_cad PROPERTIES
  LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/../../builds"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/../../builds"
)

message(STATUS "EnterpriseVoxelCAD GDExtension configured (C++17)")
message(STATUS "  Sources: ${SOURCES}")
