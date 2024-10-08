local read_config = require('_extensions.pvandyken.abbr.config')
local utils = require('_extensions.pvandyken.abbr.utils')



return {
    ---@param meta Meta
    ["abbr_table"] = function(args, _, meta)
        if meta.abbr_file == nil then
            quarto.log.warning("abbr_file not defined")
            return nil
        end
        local file_name = pandoc.utils.stringify(meta.abbr_file)
        local config = read_config(file_name).abbreviations
        local abbrs = utils.sort_abbreviations(meta.ABBR_TABLE)
        local caption = "Table of Abbreviations"
        local alignments = { pandoc.AlignLeft, pandoc.AlignLeft }
        local widths = { 0, 0 }
        local headers = { { pandoc.Plain({ pandoc.Str "Abbreviation" }) },
            { pandoc.Plain({ pandoc.Str "Definition" }) } }
        local rows = pandoc.List({})
        for _, key in pairs(abbrs) do
            settings = config[key]
            if settings.expand ~= "always" then
                rows:insert({ { pandoc.Plain(settings.abbr) }, { utils.capitalize(settings.expanded) } })
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
