-- Define types and aliases
local AbbrSettingsRaw = { expanded = "", expand = "" }
local AbbrConfigRaw = {}

local AbbrSettings = { expanded = "", expand = "" }
local AbbrConfig = {}

---@class AbbrSettings
---@field expanded pandoc.Inlines
---@field expand "always" | "auto" | "never"

-- Function to read the configuration file
---@param file_name string
---@return table<string,AbbrSettings>
local function read_config(file_name)
    local f = assert(io.open(file_name, "r"))
    local config_raw = pandoc.read(f:read("*all"), "markdown")
    f:close()

    local function parse_settings(key, settings)
        if settings.expanded == nil then
            return { expanded = settings, expand = "auto" }
        else
            local expand = nil
            if settings.expand then
                expand = pandoc.utils.stringify(settings.expand)
                if not (expand == "auto" or expand == "always" or expand == "never") then
                    quarto.log.error(
                        "The expand field for abbr '" .. key .. "' must be set to one of " ..
                        "'auto', 'always', or 'never'; got '" .. expand .. "'. " ..
                        "Treating it as auto"
                    )
                    expand = nil
                end
            end
            return {
                expanded = settings.expanded,
                expand = expand or "auto"
            }
        end
    end

    local config = {}
    for key, val in pairs(config_raw.meta) do
        config[key] = parse_settings(key, val)
    end

    return config
end

return read_config
