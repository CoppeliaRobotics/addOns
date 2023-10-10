sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nPlugin enumerator'}
end

function sysCall_init()
    print('Following CoppeliaSim plugins are loaded and operational:')
    i = 0
    while true do
        name, version = sim.getModuleName(i)
        if name then
            str = '  - ' .. name .. ' (version: ' .. version
            local extVer = sim.getModuleInfo(name, 0)
            if #extVer > 0 then str = str .. ', extended version string: ' .. extVer end
            local buildDate = sim.getModuleInfo(name, 1)
            if #buildDate > 0 then str = str .. ', build date: ' .. buildDate end
            str = str .. ')'
            print(str)
        else
            break
        end
        i = i + 1
    end
    return {cmd = 'cleanup'}
end
