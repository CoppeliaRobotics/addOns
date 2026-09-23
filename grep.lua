local sim = require 'sim-2'

function sysCall_info()
    return {autoStart = false, menu = 'Misc\nGrep tool'}
end

function sysCall_init()
    local params = sim.PropertyGroup(sim.app, {prefix = 'namedParam.grep'})
    local expr = params.expr
    local files = params.files
    local dirs = params.dirs
    local sep = package.config:sub(3, 3)
    if expr and (files or dirs) then
        local function processScene(scenePath)
            sim.app:logInfo('Loading scene ' .. scenePath .. '...')
            sim.app:loadScene(scenePath)
            for _, obj in ipairs(sim.scene:getObjects{types={'scriptObject'}}) do
                local ctx = obj:getName {mode = 'fullPath'}
                local matches = string.grep(obj.script.code, expr)
                if #matches > 0 then
                    for _, match in ipairs(matches) do
                        print('grep: ' .. scenePath .. ': ' .. obj:getName{mode = 'fullPath'} .. ':' .. match.line .. ': ' .. match.lineText)
                    end
                end
            end
        end

        if files then
            for _, file in ipairs(string.split(files, sep)) do
                processScene(file)
            end
        end
        if dirs then
            for _, dir in ipairs(string.split(dirs, sep)) do
                for path, attr in lfs.iwalk(dir) do
                    if path:endswith '.ttt' then
                        processScene(path)
                    end
                end
            end
        end
        sim.app:quit()
    else
        print('To use this addOn start coppeliaSim with params' ..
              ' -H -a ' .. sim.self.addOnPath ..
              ' -G addOns.autoLoad=false ' ..
              ' -G "grep.expr=<regular expression>"' ..
              ' -G "grep.files=' .. table.join({'file1', 'file2', '...', 'fileN'}, sep) .. '"'
        )
    end
    return {cmd = 'cleanup'}
end
