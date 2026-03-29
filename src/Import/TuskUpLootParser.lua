-- Handles parsing sixtyupgrades JSON exports into Lua tables.

TuskUpLoot.Parser = TuskUpLoot.Parser or {}

-- Core Parsing Functions

local function skipWhitespace(str, pos)
    while pos <= #str do
        local char = str:sub(pos, pos)
        -- JSON whitespace is space, tab, newline, carriage return
        if char == " " or char == "\t" or char == "\n" or char == "\r" then
            pos = pos + 1
        else
            break
        end
    end
    return pos
end

local parseValue -- Forward declaration for recursion

local function parseString(str, pos)
    -- pos should point to the opening quote
    assert(str:sub(pos, pos) == '"', "Expected '\"' at position " .. pos)
    pos = pos + 1
    local parts = {}

    while pos <= #str do
        local char = str:sub(pos, pos)
        if char == '"' then
            return table.concat(parts), pos + 1
        elseif char == '\\' then
            -- Handle escape sequences
            local esc = str:sub(pos + 1, pos + 1)
            if esc == '"' then
                table.insert(parts, '"')
            elseif esc == '\\' then
                table.insert(parts, '\\')
            elseif esc == '/' then
                table.insert(parts, '/')
            elseif esc == 'n' then
                table.insert(parts, '\n')
            elseif esc == 'r' then
                table.insert(parts, '\r')
            elseif esc == 't' then
                table.insert(parts, '\t')
            elseif esc == 'b' then
                table.insert(parts, '\b')
            elseif esc == 'f' then
                table.insert(parts, '\f')
            elseif esc == 'u' then
                -- basic \uXXXX passthrough (wow strings are utf-8 agnostic enough)
                table.insert(parts, str:sub(pos, pos + 5))
                pos = pos + 6
            else
                table.insert(parts, esc)
                pos = pos + 2
            end
            if esc ~= 'u' then pos = pos + 2 end
        else
            table.insert(parts, char)
            pos = pos + 1
        end
    end
    error("Unterminated string starting at position " .. pos)
end

local function parseNumber(str, pos)
    local numStr = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
    assert(numStr, "Invalid number at position " .. pos)
    return tonumber(numStr), pos + #numStr
end

local function parseArray(str, pos)
    -- pos should point to the opening '['
    pos = skipWhitespace(str, pos + 1)
    local arr = {}
    if str:sub(pos, pos) == ']' then return arr, pos + 1 end
    while true do
        local val
        val, pos = parseValue(str, pos)
        table.insert(arr, val)
        pos = skipWhitespace(str, pos)
        local char = str:sub(pos, pos)
        if char == ']' then
            return arr, pos + 1
        elseif char == ',' then
            pos = skipWhitespace(str, pos + 1)
        else
            error("Expected ',' or ']' in array at position " .. pos)
        end
    end
end

local function parseObject(str, pos)
    -- pos should point to the opening '{'
    pos = skipWhitespace(str, pos + 1)
    local obj = {}
    if str:sub(pos, pos) == '}' then return obj, pos + 1 end
    while true do
        pos = skipWhitespace(str, pos)
        assert(str:sub(pos, pos) == '"', "Expected string key at position " .. pos)
        local key
        key, pos = parseString(str, pos)
        pos = skipWhitespace(str, pos)
        assert(str:sub(pos, pos) == ':', "Expected ':' at position " .. pos)
        pos = skipWhitespace(str, pos + 1)
        local val
        val, pos = parseValue(str, pos)
        obj[key] = val
        pos = skipWhitespace(str, pos)
        local char = str:sub(pos, pos)
        if char == '}' then
            return obj, pos + 1
        elseif char == ',' then
            pos = skipWhitespace(str, pos + 1)
        else
            error("Expected ',' or '}' in object at position " .. pos)
        end
    end
end

parseValue = function(str, pos)
    pos = skipWhitespace(str, pos)
    local char = str:sub(pos, pos)
    if char == '"' then
        return parseString(str, pos)
    elseif char == '{' then
        return parseObject(str, pos)
    elseif char == '[' then
        return parseArray(str, pos)
    elseif char == 't' then
        assert(str:sub(pos, pos + 3) == 'true', "Invalid token at position " .. pos)
        return true, pos + 4
    elseif char == 'f' then
        assert(str:sub(pos, pos + 4) == 'false', "Invalid token at position " .. pos)
        return false, pos + 5
    elseif char == 'n' then
        assert(str:sub(pos, pos + 3) == 'null', "Invalid token at position " .. pos)
        return nil, pos + 4
    elseif char == '-' or char:match('%d') then
        return parseNumber(str, pos)
    else
        error("Unexpected character '" .. char .. "' at position " .. pos)
    end
end

-- Public JSON Parsing API

-- Parse a raw JSON string into a Lua table
-- Returns (table, nil) on success, (nil, errorMessage) on failure

function TuskUpLoot.Parser.Parse(jsonString)
    if type(jsonString) ~= "string" then
        return nil, "Input must be a string"
    end
    -- pcall captures errors from function rather than propagating
    local ok, result, _ = pcall(parseValue, jsonString, 1)
    if not ok then
        return nil, result -- result holds the error message from pcall
    end
    return result, nil
end
