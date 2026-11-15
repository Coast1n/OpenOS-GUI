-- Public constructors. Loading does not acquire devices or start a loop.
local application = require("ocgui.application")
local container = require("ocgui.container")
local label = require("ocgui.label")
local button = require("ocgui.button")

return {
  version = "0.1.0-dev",
  application = function(options) return application.new(options) end,
  container = container.new,
  label = label.new,
  button = button.new
}
