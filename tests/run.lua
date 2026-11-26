-- Ejecuta todas las pruebas offline: luajit tests/run.lua (desde la raíz del repositorio).
package.path = "./tests/lib/?.lua;" .. package.path
local Harness = require("harness")

local TEST_FILES = {
  "tests/test_init.lua",
  "tests/test_events.lua",
  "tests/test_combat_queue.lua",
  "tests/test_database.lua",
  "tests/test_spells.lua",
  "tests/test_druid.lua",
  "tests/test_profiles.lua",
  "tests/test_serializer.lua",
  "tests/test_media_curves.lua",
  "tests/test_click_cast.lua",
  "tests/test_prediction.lua",
  "tests/test_containers.lua",
  "tests/test_missing_buffs.lua",
  "tests/test_unit_button.lua",
  "tests/test_headers.lua",
  "tests/test_preview.lua",
  "tests/test_config.lua",
  "tests/test_tab_clicks.lua",
  "tests/test_tab_frames.lua",
  "tests/test_tab_lists.lua",
  "tests/test_diagnostics_commands.lua",
  "tests/test_bootstrap.lua",
  "tests/test_load_all.lua",
  "tests/test_minimap_button.lua",
}

for _, path in ipairs(TEST_FILES) do
  local chunk, loadError = loadfile(path)
  if not chunk then
    Harness.failed = Harness.failed + 1
    Harness.failures[#Harness.failures + 1] = path .. "\n" .. tostring(loadError)
  else
    Harness.describe(path, chunk)
  end
end

if not Harness.Report() then
  os.exit(1)
end
