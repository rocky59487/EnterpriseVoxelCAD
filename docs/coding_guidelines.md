# EnterpriseVoxelCAD — Coding Guidelines

> **This document is authoritative.** All contributors (human or AI) must follow these guidelines without exception.

---

## 1. GDScript Conventions

### 1.1 Naming

| Construct | Convention | Example |
|---|---|---|
| Variables & Functions | `snake_case` | `chunk_size`, `create_voxel()` |
| Constants | `SCREAMING_SNAKE_CASE` | `MAX_CHUNK_SIZE`, `DEFAULT_LOD` |
| Classes | `PascalCase` via `class_name` | `class_name VoxelManager` |
| Signals | `snake_case` | `voxel_created`, `layer_changed` |
| Enum values | `SCREAMING_SNAKE_CASE` | `LayerType.AI_GENERATED` |

### 1.2 Type Hints

All variables, function parameters, and return values **must** carry explicit type hints.

```gdscript
# CORRECT
var chunk_size: int = 32
func create_voxel(position: Vector3i, material_id: int) -> void:
    pass

# WRONG — no type hints
var chunk_size = 32
func create_voxel(position, material_id):
    pass
```

### 1.3 Class Declaration

Every file that defines a reusable type **must** begin with `class_name`:

```gdscript
class_name VoxelManager
extends Node
```

### 1.4 Public API Protection

Files marked `## PUBLIC INTERFACE — DO NOT MODIFY SIGNATURES` must not have their public method signatures changed.
Only the **Infrastructure AI (AI-0)** may alter public interfaces, and only with a documented rationale.

### 1.5 Static Analysis

- Use `gdtoolkit` (`gdlint`) for style checking in CI.
- Max line length: 120 characters.
- No `match` without a default `_:` branch.

---

## 2. C++ (GDExtension) Conventions

### 2.1 Standard

- C++17 (`-std=c++17`).
- Compiler flags: `-Wall -Wextra -Werror` (warnings are errors in CI).

### 2.2 Naming

| Construct | Convention | Example |
|---|---|---|
| Classes | `PascalCase` | `VoxelMesher` |
| Methods | `snake_case` | `generate_greedy_mesh()` |
| Member variables | `m_snake_case` | `m_chunk_data` |
| Constants / Macros | `SCREAMING_SNAKE_CASE` | `MAX_VOXEL_COUNT` |
| Namespaces | `snake_case` | `evc::meshing` |

### 2.3 Formatting (`.clang-format`)

```yaml
BasedOnStyle: LLVM
IndentWidth: 4
UseTab: ForIndentation
PointerAlignment: Right
ColumnLimit: 120
BraceWrapping:
  AfterClass: true
  AfterFunction: true
AllowShortFunctionsOnASingleLine: None
```

The `.clang-format` file at the project root enforces these settings.
Run `clang-format -i` before committing.

### 2.4 Header Guards

Use `#pragma once` in every header file.

### 2.5 Memory Management

- Prefer RAII; avoid raw `new`/`delete`.
- Use `std::unique_ptr` / `std::shared_ptr` where appropriate.
- Godot object lifetime is managed by Godot's ref-counting — do not double-free.

---

## 3. SQL / Database Conventions

- All schema changes go through numbered migration scripts (`tools/db/schema_vN.sql`).
- Table names: `snake_case`, plural (`chunks`, `layers`).
- Column names: `snake_case` (`modified_at`, `project_id`).
- Every table must have a `created_at DATETIME DEFAULT CURRENT_TIMESTAMP` column.
- Foreign keys must be declared explicitly.
- Never execute raw SQL outside `Database.gd`.

---

## 4. Git Workflow

- `main` branch is protected; all changes via Pull Requests.
- PR must pass CI (build + tests + lint) before merge.
- Commit messages: `type(scope): description` (Conventional Commits).
  - Types: `feat`, `fix`, `docs`, `refactor`, `test`, `ci`, `chore`.
- Branch naming: `feat/engine-name-feature`, `fix/bug-description`.

---

## 5. Documentation

- Every public class and function must have a doc-comment.
- GDScript: `##` doc-comments above the declaration.
- C++: Doxygen `/** */` style.
- Keep `docs/` updated when interfaces change.
