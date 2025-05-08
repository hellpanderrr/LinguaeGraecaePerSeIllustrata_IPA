local export = {}

-- Store the original require function
local original_require = require

-- Track loaded modules
local loaded_modules = {}

-- Override require with tracking functionality
function require(modname)
    local result = original_require(modname)

    -- Store module load info
    if not loaded_modules[modname] then
        loaded_modules[modname] = {
            order = #loaded_modules + 1,
            timestamp = os.time()
        }
    end

    return result
end

-- Get list of loaded modules in order
function export.get_loaded_modules()
    local ordered = {}
    for modname, info in pairs(loaded_modules) do
        table.insert(ordered, {
            name = modname,
            order = info.order,
            timestamp = info.timestamp
        })
    end

    -- Sort by load order
    table.sort(ordered, function(a, b)
        return a.order < b.order
    end)

    return ordered
end

-- Print loaded modules report
function export.print_loaded_modules()
    local modules = export.get_loaded_modules()
    print("\nLoaded modules report:")
    print("=====================")
    for i, mod in ipairs(modules) do
        print(string.format("%d. %s (loaded at: %s)",
                i,
                mod.name,
                os.date("%H:%M:%S", mod.timestamp)
        ))
    end
    print("=====================\n")
end

-- Reset tracking
function export.reset()
    loaded_modules = {}
end

return export