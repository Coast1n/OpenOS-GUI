-- Installed OpenOS example: lua /home/OpenOS-GUI/examples/basic.lua
local gui = require("ocgui")
local app = gui.application {theme = {container = {background = 0x101820}, label = {background = 0x101820}}}
local status = app.root:add(gui.label {x = 3, y = 2, width = 44, text = "OpenOS GUI：点击或 Tab/Enter 更新计数"})
local count = 0
local update = app.root:add(gui.button {x = 3, y = 5, width = 16, height = 2, text = "更新计数"})
local quit = app.root:add(gui.button {x = 23, y = 5, width = 16, height = 2, text = "退出"})
update:on("click", function()
  count = count + 1
  status:setText("已激活 " .. count .. " 次")
end)
quit:on("click", function() app:stop() end)
local ok, err = app:run()
if not ok then error(err.code .. ": " .. err.message, 0) end
