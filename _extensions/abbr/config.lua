-- Define types and aliases
local AbbrSettingsRaw = { expanded = "", expand = "" }
local AbbrConfigRaw = {}

local AbbrSettings = { expanded = "", expand = "" }
local AbbrConfig = {}

---@class AbbrConfig
---@field min_occurances number
---@field abbreviations table<string,Abbreviations>


---@class Abbreviations
---@field expanded pandoc.Inlines
---@field expand "always" | "auto" | "never"
---@field define "always" | "auto"
---@field article pandoc.Inlines | nil
---@field abbr pandoc.Inlines | nil

-- Function to read the configuration file
---@param file_name string
---@return AbbrConfig
local function read_config(file_name)
    local f = assert(io.open(file_name, "r"))
    local config_raw = pandoc.read(f:read("*all"), "markdown")
    f:close()

    ---@param key string
    ---@param settings any
    local function parse_settings(key, settings)
        if settings.expanded == nil then
            return { expanded = settings, abbr = key, expand = "auto", define = "auto" }
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
            local define = nil
            if settings.define then
                define = pandoc.utils.stringify(settings.define)
                if not (define == "auto" or define == "always") then
                    quarto.log.error(
                        "The define field for abbr '" .. key .. "' must be set to one of " ..
                        "'auto' or 'always'; got '" .. define .. "'. " ..
                        "Treating it as auto."
                    )
                    define = nil
                end
            end
            if define == "always" and expand == "always" then
                quarto.log.warning(
                    "Abbr '" .. key .. "' has both 'define' and 'expand' set to " ..
                    "'always'. This currently causes the abbr to be defined every time " ..
                    "it appears in the text, not just the first, which is probably not " ..
                    "desired."
                )
            end
            return {
                expanded = settings.expanded,
                abbr = settings.abbr or key,
                expand = expand or "auto",
                define = define or "auto",
                article = settings.article,
            }
        end
    end

    local config = {}
    if config_raw.meta._min_occurances then
        config["min_occurances"] = tonumber(pandoc.utils.stringify(config_raw.meta._min_occurances))
        config_raw.meta._min_occurances = nil
    else
        config["min_occurances"] = 2
    end

    local abbreviations = {}
    for key, val in pairs(config_raw.meta) do
        abbreviations[key] = parse_settings(key, val)
    end

    config["abbreviations"] = abbreviations

    return config
end

return read_config
