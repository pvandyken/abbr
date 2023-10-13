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

return utils