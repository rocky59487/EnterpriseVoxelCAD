A. 前置檢查（若未完成先補齊）
請先自我確認以下項目都已達成，否則先完成再往下：

專案結構、Godot 專案、SQLite Schema、核心 GDScript 模組（VoxelManager/LayerSystem/StructuralAnalyzer/CommandParser/TelemetryService）與 C++ GDExtension 骨架、CI/CD workflow 都存在且能跑通基本 build + 測試。
​

B. 任務 1：在資料層支援「虛塊」（Virtual Blocks）
B1. 擴充資料結構（不破壞原有格式）
在 chunks BLOB 格式上擴充邏輯，維持原本「16-bit 材質 ID + 圖層遮罩」的概念，但增加虛塊標記與群組概念，可透過以下方式其一實現：
​

方案 A：使用額外的 structure_tags 表來記錄哪些 Voxel 屬於哪個虛塊（virtual_block_id），不改動 BLOB 結構。

方案 B：若已有預留 bit，可在現有 16-bit 中保留 1–2 bit 標記「虛塊/實體」，再用 structure_tags 表記錄群組 ID。

在 tools/db/schema_v1.sql 中，補上 structure_tags 表的具體欄位（若尚未詳細定義）：
​

id INTEGER PRIMARY KEY

project_id INTEGER

chunk_id TEXT

voxel_index INTEGER（對應一維 index）
​

virtual_block_id INTEGER

日後可擴充欄位：structure_level（主結構、副結構、裝飾）

更新 database_schema.md，說明虛塊的儲存策略與 structure_tags 的用途。
​

C. 任務 2：在 VoxelManager 中實作「虛塊」操作 API
C1. 新增公開 API（公共介面，禁止日後破壞）
在 VoxelManager.gd 中，新增並實作以下方法（在不破壞既有介面前提下）：
​

func create_virtual_block(positions: Array[Vector3i], material_id: int, layer_id: int) -> int

依照輸入位置陣列批次建立 Voxel。

在 structure_tags 中為這批 Voxel 建立新的 virtual_block_id 記錄。

回傳 virtual_block_id。

func refine_virtual_block(virtual_block_id: int, operations: Array[Dictionary]) -> void

operations 內可包含：{ "op": "delete", "position": Vector3i }、{ "op": "add", "position": Vector3i } 等。

依操作更新 Voxel 與對應 structure_tags。

func delete_virtual_block(virtual_block_id: int) -> void

將此虛塊中所有 Voxel 清空，並清除 structure_tags 中相關紀錄。

在 delete_voxel 裡，若該 Voxel 有 virtual_block_id，需同步更新 structure_tags。
​

C2. 非同步結構分析鉤子
在 create_virtual_block / refine_virtual_block / delete_virtual_block 完成後，不要立即跑完整力傳導，而是：

僅在「使用者編輯行為完成（之後會由工具層事件決定）」時，由更上層呼叫 StructuralAnalyzer.run_full_load_case(...)。
​

保留 StructuralAnalyzer.check_floating_async(position) 的呼叫，用於局部浮空檢查。
​

D. 任務 3：建立「虛塊編輯工具」UI 和操作流
D1. 工具模式與 UI 要求
在 Godot 專案中：

新增一組 GDScript 工具腳本（例如放在 src/scripts/tools/VirtualBlockTool.gd）：

模式 1：AI 生成虛塊（之後代理人引擎會用，暫時可用假資料或隨機體）。

模式 2：描圖筆（沿虛塊輪廓添加/刪除 Voxel）。

模式 3：整塊刪除。

在主 UI（main.tscn 對應腳本）中加入簡單的工具列或快捷鍵：

V → 進入虛塊編輯模式。

滑鼠左鍵：新增 Voxel 到當前虛塊（呼叫 refine_virtual_block with op=add）。

滑鼠右鍵：從虛塊刪除 Voxel（op=delete）。

每次結束一組操作後（例如使用者放開滑鼠鍵）：

不要直接計算整體負載，只是：

更新畫面 Mesh。

紀錄到 undo_stack。
​

D2. 視覺區分
虛塊 Voxel 與普通 Voxel 必須在視覺上有差異（例：半透明、不同顏色），以便日後 AI、人類與代理人都能區分。

可將顏色/材質方案寫在 materials 表與 Material Registry 初始化邏輯中。
​

E. 任務 4：語意引擎基礎（模糊指令支援）
此階段只做「最小可用語意層」，之後再強化。

E1. 資料表實作
在 schema_v1.sql 具體定義 semantic_commands 表：
​

id INTEGER PRIMARY KEY

canonical_name TEXT NOT NULL（例："create_virtual_block"）

aliases TEXT（以分隔符存放多個 alias："cvb,cv,virtblock"）

phonetic_key TEXT（預留給發音/拼音用）

初始化腳本中，插入幾個基本指令：

create_virtual_block（對應虛塊建立）

refine_virtual_block

delete_virtual_block

E2. CommandParser 擴充
在 CommandParser.gd 中追加邏輯：
​

建立一個方法：

func resolve_command(input: String) -> String

先精準匹配已註冊指令。

若失敗，查詢 semantic_commands：

以別名或相似度（可以用簡易編碼：開頭字母相同、Levenshtein 距離小於 N 等）找最接近的 canonical_name。

若找到可信結果，回傳 canonical name；否則回傳空字串。

修改 execute_command(input: String)：

先用 resolve_command 將模糊輸入轉成 canonical name。

根據 canonical name 尋找對應 callback 並執行。

在初始化階段，將虛素引擎相關指令註冊進 CommandParser：

例如："create_virtual_block" 對應一個 wrapper callback，會解析參數（如選取區域），然後呼叫 VoxelManager.create_virtual_block(...)。

F. 任務 5：最小整合測試
F1. 單元測試擴充
​
在 tests/unit/ 中新增／擴充測試：

test_virtual_block.gd：

測試 create_virtual_block 是否真正創建多個 Voxel，且 structure_tags 有正確記錄。

測試 refine_virtual_block 的 add/delete 是否同步更新 DB。

test_semantic_commands.gd：

插入幾筆 semantic_commands 資料。

測試多種輸入（"cvb", "virtblock", 拼錯一兩個字）仍能正確解析到 create_virtual_block。

F2. 簡易流程測試
撰寫一個整合測試腳本（可放在 tests/integration/test_virtual_block_flow.gd）：

步驟：

建立一個新專案 TestVirtualBlockProject。

使用 CommandParser 輸入近似指令（例如："cvb" + 參數）呼叫 create_virtual_block。

驗證：

對應 Chunk 中存在該虛塊的 Voxel。

structure_tags 有記錄。

畫面 Mesh 可被成功生成，不崩潰。

G. 任務 6：文檔更新與提交規則
G1. 文檔
更新 architecture_overview.md：

補充一段描述「虛素引擎」如何建立在 VoxelManager + structure_tags 之上。
​

更新 engine_extension_points.md：

標示語意引擎已實作基本模糊指令解析，將來代理人引擎可以直接呼叫 canonical 指令。

G2. Git 提交與 PR 規則
使用單一 feature branch，例如：feature/engine-virtual-semantic-v1。

在本 branch 上完成上述所有任務，確保：

本地與 CI 上所有測試通過。
​

提交訊息建議格式：

feat(engine): add virtual block support to VoxelManager

feat(engine): add basic semantic command resolution

-- EnterpriseVoxelCAD Database Schema v2
-- Migration: schema_v2.sql
-- Purpose: Add virtual block support and semantic command engine
-- Prerequisite: schema_v1.sql must be applied first
--
-- Usage:
--   sqlite3 project.db < tools/db/schema_v2.sql
--
-- This migration adds:
-- 1. structure_tags table for virtual block grouping
-- 2. semantic_commands table for fuzzy command resolution

-- ---------------------------------------------------------------------------
-- Migration tracking
-- ---------------------------------------------------------------------------
INSERT OR IGNORE INTO schema_migrations (version, applied_at)
VALUES ('v2', strftime('%s', 'now'));

-- ---------------------------------------------------------------------------
-- Structure Tags (Virtual Block Grouping)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS structure_tags (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id       INTEGER NOT NULL,
  chunk_id         INTEGER NOT NULL REFERENCES voxel_chunks(id) ON DELETE CASCADE,
  voxel_index      INTEGER NOT NULL,
  virtual_block_id INTEGER NOT NULL,
  structure_level  INTEGER NOT NULL DEFAULT 0,
  created_at       INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  UNIQUE (chunk_id, voxel_index)
);

CREATE INDEX IF NOT EXISTS idx_structure_tags_project ON structure_tags(project_id);
CREATE INDEX IF NOT EXISTS idx_structure_tags_virtual_block ON structure_tags(virtual_block_id);
CREATE INDEX IF NOT EXISTS idx_structure_tags_chunk ON structure_tags(chunk_id);

-- ---------------------------------------------------------------------------
-- Semantic Commands (Fuzzy Command Resolution)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS semantic_commands (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  canonical_name TEXT    NOT NULL UNIQUE,
  aliases        TEXT    NOT NULL DEFAULT '',
  phonetic_key   TEXT    DEFAULT '',
  enabled        INTEGER NOT NULL DEFAULT 1,
  created_at     INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_semantic_commands_enabled ON semantic_commands(enabled);

-- Seed semantic_commands with default engine commands
INSERT INTO semantic_commands (canonical_name, aliases, enabled)
VALUES
  ('create_virtual_block', 'cvb,cv,virtblock,vblock,createvb', 1),
  ('refine_virtual_block', 'rvb,refinevb,editvb,modifyvb', 1),
  ('delete_virtual_block', 'dvb,delvb,removevb,deletevb', 1),
  ('create_voxel', 'cv,setvoxel,placevoxel', 1),
  ('delete_voxel', 'dv,removevoxel,clearvoxel', 1),
  ('list_layers', 'll,showlayers,la', 1),
  ('set_layer_visibility', 'slv,togglelayer,hidelayer', 1),
  ('run_load_case', 'rlc,analyze,structural', 1);
