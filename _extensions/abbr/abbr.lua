local read_config = require('_extensions.pvandyken.abbr.config')
local utils = require('_extensions.pvandyken.abbr.utils')
local has_entries = utils.has_entries
local get_count = utils.get_count


-- Globals

---Path to config file
---@type string
local CONFIG_FILE = nil

---List of abbreviations found in the current context
---@type string[]
local ABBRS = {}

---List of abbreviations that should not be expanded in the current context
---@type table<string,boolean>
local DONT_EXPAND = {}

---List of all abbreviations found in all contexts. Used for reporting
---configured but unused variables
---@type table<string,boolean>
local FOUND_ABBRS = {}

---List of all abbreviations expanded at least once in all contexts. Used when
---generating abbreviation table
---@type table<string,boolean>
local ABBR_TABLE = {}

---Array tracking missing abbreviations so that we only report each one once
---@type string[]
local REPORTED_MISSING = {}

---Normalized abbreviation configuration table
---@type table<string,Abbreviations>
local CONFIG = {}

---@type AbbrConfig
local ABBR_CONFIG = {}

---Flag marking a word as the first in a sentence or block. Used for
---capitalization detection
---@type boolean
local FIRST_WORD = true

---Flag marking word as the first in the block. Used for capitalization
---detection (unlike FIRST_WORD, this flag is not ambiguous about periods)
local FIRST_WORD_IN_BLOCK = true

---Flag indicating a vague capital was found and that context should be printed
---@type boolean
local FOUND_VAGUE_CAPITAL = false

---Flag indicating the integration with latex acronym package
---@type boolean
local LATEX_MODE = false


-- Function to format value
---@param val pandoc.Inlines
---@param plural boolean
---@param capitalize boolean
---@param define string | nil
---@return pandoc.List
local function format(val, plural, capitalize, define)
    local i = 0
    local total = 0
    val:walk({ Str = function(_) total = total + 1 end })
    local formatted = val:walk({
        Str = function(str)
            s = str.text
            i = i + 1
            if i == 1 and capitalize then
                s = s:gsub("^%l", string.upper)
            end
            if plural and i == total then
                return pandoc.Str(s .. "s")
            end
            return pandoc.Str(s)
        end
    })
    if define ~= nil then
        local closer = plural and "s)" or ")"
        formatted:extend(pandoc.List({ pandoc.Space(), pandoc.Str("(" .. define .. closer) }))
    end
    return formatted
end

---Format acronym for latex as general
---@param abbr string
---@param plural boolean
---@param capitalize boolean
---@param define boolean
---@return pandoc.List
local function format_latex(abbr, plural, capitalize, define)
    local l1 = capitalize and "A" or "a"
    local lp = plural and "p" or ""
    local lf = define and "f" or ""
    return pandoc.List({ pandoc.RawInline("latex", "\\" .. l1 .. "c" .. lf .. lp .. "{" .. abbr .. "}") })
end



---For each string, find abbreviations within the string and format based on
---document context
---@param str string
local function format_abbr(str)
    ---@type pandoc.List
    local subs = pandoc.List({})
    local starts = {}
    local stops = {}

    local i = 0
    for flag, id in str:gmatch("&([-+]?)([a-zA-Z0-9]+)") do
        ---@cast id string
        i = i + 1
        local plural = false

        if not CONFIG[id] then
            if id:sub(-1) == "s" and CONFIG[id:sub(1, -2)] then
                id = id:sub(1, -2)
                plural = true
            else
                goto continue
            end
        end


        local abbr = CONFIG[id].abbr
        local always_expand = CONFIG[id].expand == "always" or get_count(ABBRS, id) < ABBR_CONFIG.min_occurances
        if DONT_EXPAND[id] then
            subs:insert(plural and (abbr .. "s") or abbr)
        else
            local capitalize
            if flag == "+" then
                capitalize = true
            elseif flag == "-" then
                capitalize = false
            else
                capitalize = FIRST_WORD
                if capitalize and not FIRST_WORD_IN_BLOCK then
                    quarto.log.warning(
                        "Vague capitalization: &" .. flag .. id ..
                        ". Use either &+" .. id .. " or &-" .. id ..
                        " to clarify upper or lower case"
                    )
                    FOUND_VAGUE_CAPITAL = true
                end
            end
            if LATEX_MODE and not always_expand then
                subs:insert(format_latex(id, plural, capitalize, CONFIG[id].define == "always"))
            else
                local define = CONFIG[id].define == "always" or not always_expand

                local val = format(CONFIG[id].expanded, plural, capitalize,
                    define and pandoc.utils.stringify(abbr) or nil)
                -- quarto.log.warning(val)
                subs:insert(val)
                if not always_expand then
                    DONT_EXPAND[id] = true
                end
            end
        end

        ---@type integer | nil
        local init = 1
        if starts[-1] ~= nil then
            init = starts[-1] + 2
        end
        local start, stop = str:find("&" .. flag .. id .. (plural and "s" or ""), init, true)
        table.insert(starts, start - 1)
        table.insert(stops, stop + 1)
        ::continue::
    end

    local subbed = pandoc.List({})
    local pos = 1

    for j, start in ipairs(starts) do
        ---@type string | pandoc.List
        local sub = subs[j]
        subbed:insert(pandoc.Str(str:sub(pos, start)))
        if type(sub) == "string" then
            subbed:insert(pandoc.Str(sub))
        else
            subbed:extend(sub)
        end
        pos = stops[j]
    end

    subbed:insert(str:sub(pos))

    return subbed
end

-- Function to provide context for error messages
---@param block pandoc.Para | pandoc.Header
local function context(block, centre, range)
    local surrounding = pandoc.List({})
    local i = 0
    block:walk({
        Str = function(s)
            i = i + 1
            if centre - i == 0 then
                surrounding:insert("-->" .. s.text .. "<--")
            elseif math.abs(centre - i) < range then
                surrounding:insert(s.text)
            end
        end
    })
    quarto.log.warning("::: " .. table.concat(surrounding, " "))
end

---@param p pandoc.Para | pandoc.Header
local function collect_abbr(p)
    local i = 0
    p:walk({
        Str = function(s)
            i = i + 1
            for flag, abbr in s.text:gmatch("&([-+]?)([a-zA-Z0-9]+)") do
                if CONFIG[abbr] then
                    table.insert(ABBRS, abbr)
                elseif CONFIG[abbr:sub(1, -2)] and abbr:sub(-1) == "s" then
                    table.insert(ABBRS, abbr:sub(1, -2))
                elseif not utils.contains(REPORTED_MISSING, abbr) then
                    quarto.log.warning("Unrecognized abbr: &" .. flag .. abbr)
                    context(p, i, 10)
                    table.insert(REPORTED_MISSING, abbr)
                end
            end
        end
    })
end

---@param p pandoc.Para | pandoc.Header
local function process_abbr(p)
    FIRST_WORD = true
    FIRST_WORD_IN_BLOCK = true
    local i = 0
    return p:walk({
        Str = function(s)
            i = i + 1
            if s.text:match("&") then
                new = format_abbr(s.text)
                if FOUND_VAGUE_CAPITAL then
                    context(p, i, 10)
                    FOUND_VAGUE_CAPITAL = false
                end
            else
                new = s
            end
            if s.text:sub(-1, -1) == "." then
                FIRST_WORD = true
            else
                FIRST_WORD = false
            end
            return new
        end
    })
end


---Initialize global variables for a new abbreviation formatting context
local function init()
    if CONFIG_FILE == nil then
        return false
    end
    if not has_entries(CONFIG) then
        ABBR_CONFIG = read_config(CONFIG_FILE)
        CONFIG = ABBR_CONFIG.abbreviations
    end

    ABBRS = {}
    DONT_EXPAND = {}
    for abbr, settings in pairs(CONFIG) do
        if settings.expand == "never" then
            DONT_EXPAND[abbr] = true
        end
    end
    return true
end

local Meta = function(meta)
    file_name = meta.abbr_file
    if file_name == nil or type(file_name) == "number" then
        quarto.log.warning("abbr_file must be defined as a string")
    end
    CONFIG_FILE = pandoc.utils.stringify(file_name)
    if quarto.doc.is_format("latex") and meta.abbr_with_acronym then
        LATEX_MODE = true
    end
end
local Pandoc = function(docs)
    if not init() then
        return docs
    end

    -- quarto.log.warning(CONFIG)

    docs:walk({
        Para = collect_abbr,
        Header = collect_abbr,
        BlockQuote = collect_abbr,
        OrderedList = collect_abbr,
        BulletList = collect_abbr,
        LineBlock = collect_abbr,
    })

    for _, abbr in pairs(ABBRS) do
        FOUND_ABBRS[abbr] = true
        if DONT_EXPAND[abbr] ~= true and get_count(ABBRS, abbr) >= ABBR_CONFIG.min_occurances then
            ABBR_TABLE[abbr] = true
        end
    end

    return docs:walk({
        Para = process_abbr,
        Header = process_abbr,
        BlockQuote = process_abbr,
        OrderedList = process_abbr,
        BulletList = process_abbr,
        LineBlock = process_abbr,
    })
    --   quarto.log.warning(docs.blocks)
end

local Table = function(table)
    if not init() then return table end

    -- quarto.log.warning(CONFIG)

    collect_abbr(table.caption.long)

    for _, abbr in pairs(ABBRS) do
        FOUND_ABBRS[abbr] = true
        if DONT_EXPAND[abbr] ~= true and get_count(ABBRS, abbr) >= ABBR_CONFIG.min_occurances then
            ABBR_TABLE[abbr] = true
        end
    end

    table.caption.long = process_abbr(table.caption.long)
    return table
    --   quarto.log.warning(docs.blocks)
end

---@param meta pandoc.Meta
local Check = function(meta)
    if not has_entries(CONFIG) then
        return meta
    end
    for key, _ in pairs(CONFIG) do
        if not FOUND_ABBRS[key] then
            quarto.log.warning(key .. " found in abbr_config but not in document")
        end
    end
    meta.ABBR_TABLE = ABBR_TABLE
    return meta
end

---Create a list of abbreviations for latex mode
---@param meta pandoc.Meta
local ListOfAbbr = function(meta)
    if not LATEX_MODE then
        return meta
    end
    if not init() then
        return meta
    end
    quarto.doc.use_latex_package("acronym")
    quarto.doc.use_latex_package("titlecaps")
    quarto.doc.include_text('in-header', '\\makeatletter\n')
    quarto.doc.include_text('in-header',
        '\\expandafter\\patchcmd\\csname AC@\\AC@prefix{}@acro\\endcsname{{#3}}{{\\titlecap #3}}{}{}\n')
    quarto.doc.include_text('in-header',
        '\\expandafter\\patchcmd\\csname AC@\\AC@prefix{}@acro\\endcsname{{#3}}{{\\titlecap #3}}{}{}\n')
    quarto.doc.include_text('in-header', '\\AddToHook{env/acronym/begin}{\\def\\AC@hyperref[#1]#2{#2}}\n')
    quarto.doc.include_text('in-header', '\\makeatother\n')

    local abbrs = utils.sort_abbreviations(ABBR_TABLE)

    local longest = utils.findLongestString(abbrs)
    local rows = pandoc.List({ pandoc.RawBlock("latex", "\\begin{acronym}[" .. longest .. "]\n\n") })
    for _, key in pairs(abbrs) do
        settings = CONFIG[key]
        if settings.expand ~= "always" then
            local row = ({
                pandoc.RawInline("latex", "\\acro{" .. key .. "}["),
                settings.abbr,
                pandoc.RawInline("latex", "]{"),
                settings.expanded,
                pandoc.RawInline("latex", "}"),
            })
            rows:insert(row)
            rows:insert(pandoc.RawBlock("latex", "\n\n"))
        end
    end
    rows:insert(pandoc.RawBlock("latex", "\\end{acronym}\n\n"))

    meta.abbr_toa = rows
    return meta
end

return {
    { Meta = Meta },
    { Table = Table },
    { Pandoc = Pandoc },
    { Meta = Check },
    { Meta = ListOfAbbr }
}
