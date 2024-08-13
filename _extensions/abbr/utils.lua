utils = {}

---@param tbl table<any,any>
function utils.has_entries(tbl)
    for _ in pairs(tbl) do return true end
    return false
end

---@param tab table<integer,string>
---@param val string
function utils.get_count(tab, val)
    local count = 0
    for index, value in ipairs(tab) do
        if value == val then
            count = count + 1
        end
    end

    return count
end

---@generic T
---@param list T[]
---@param val T
function utils.contains (list, val)
    for _, value in ipairs(list) do
        if value == val then
            return true
        end
    end
    return false
end

---@generic T
---@param tbl { [T]: any }
---@return T[]
function utils.keys(tbl)
    local keyset = {}
    for k, _ in pairs(tbl) do
        table.insert(keyset, k)
    end
    return keyset
end

---@param a string
---@param b string
function utils.icase_sort(a, b)
    return a:lower() < b:lower()
end


---@param config table<string,any>
---@return string[]
function utils.sort_abbreviations(config)
    local abbrs = utils.keys(config)
    table.sort(abbrs, utils.icase_sort)
    return abbrs
end

---@param elems pandoc.Inlines
function utils.capitalize(elems)
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

---Turn numerals within a string into words
---@param input string
---@return string
function utils.numeralsToWords(input)
    -- Define the mapping from numerals to words
    local numeralWords = {
        ["0"] = "zero",
        ["1"] = "one",
        ["2"] = "two",
        ["3"] = "three",
        ["4"] = "four",
        ["5"] = "five",
        ["6"] = "six",
        ["7"] = "seven",
        ["8"] = "eight",
        ["9"] = "nine"
    }

    -- Use gsub to replace each numeral with its corresponding word
    local result = input:gsub("%d", function(digit)
        return numeralWords[digit]
    end)

    return result
end

---Return length of longest string
---@param strings string[]
---@return string
function utils.findLongestString(strings)
    -- Initialize variables to keep track of the longest string and its length
    local longestString = ""
    local maxLength = 0

    -- Iterate through the array of strings
    for _, str in ipairs(strings) do
        -- Check if the current string is longer than the longest found so far
        if #str > maxLength then
            longestString = str
            maxLength = #str
        end
    end

    return longestString
end

return utils