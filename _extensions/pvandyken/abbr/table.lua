local read_config = require('_extensions.pvandyken.abbr.config')
local utils = require('_extensions.pvandyken.abbr.utils')


---@param config table<string,any>
---@return string[]
local function sort_abbreviations(config)
    local abbrs = utils.keys(config)
    table.sort(abbrs, utils.icase_sort)
    return abbrs
end

---@param elems pandoc.Inlines
function capitalize(elems)
    local minor_words = {
        "and", "as", "but", "for", "if", "nor", "or", "so", "yet", "a", "an",
        "the", "at", "by", "in", "of", "off", "on", "per", "to", "up", "via",
        "de", "lest", "sans", "vis-à-vis", "vis-a-vis", "qua", "pro", "versus",
        "albeit", "ergo"
    }
    local i = 0
    return elems:walk({
        Str = function(s)
            i = i + 1
            if i ~= 1 and utils.contains(minor_words, s.text) then
                return s
            end
            return pandoc.Str(s.text:sub(1, 1):upper() .. s.text:sub(2))
        end
    })
end

return {
    ---@param meta Meta
    ["abbr_table"] = function(args, _, meta)
        if meta.abbr_file == nil then
            quarto.log.warning("abbr_file not defined")
            return nil
        end
        local file_name = pandoc.utils.stringify(meta.abbr_file)
        local config = read_config(file_name)
        local abbrs = sort_abbreviations(meta.ABBR_TABLE)
        local caption = "Table of Abbreviations"
        local alignments = { pandoc.AlignLeft, pandoc.AlignLeft }
        local widths = { 0, 0 }
        local headers = { { pandoc.Plain({ pandoc.Str "Abbreviation" }) },
            { pandoc.Plain({ pandoc.Str "Definition" }) } }
        local rows = pandoc.List({})
        for _, key in pairs(abbrs) do
            settings = config[key]
            if settings.expand ~= "always" then
                rows:insert({ { pandoc.Plain(key) }, { capitalize(settings.expanded) } })
            end
        end

        local table = pandoc.utils.from_simple_table(
            pandoc.SimpleTable(
                caption,
                alignments,
                widths,
                headers,
                rows
            )
        )
        table.identifier = "abbr-table"
        return table
    end
}
