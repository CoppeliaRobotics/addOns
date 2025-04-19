sim = require 'sim'
extModel = require 'addOns.extModel'

function sysCall_info()
    return {
        menu = 'Developer tools\nExternal model auto reload',
    }
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_init()
    scanInterval = 5.
end

function sysCall_afterLoad()
    extModel.scanForExtModelsToReload()
end

function sysCall_beforeInstanceSwitch()
    extModel.changedModelsBannerDestroy()
    extModel.changedModelsDialogDestroy()
end

function sysCall_afterInstanceSwitch()
    extModel.scanForExtModelsToReload()
end

function sysCall_nonSimulation()
    local t = sim.getSystemTime()
    if (lastScanTime or 0) + scanInterval < t then
        lastScanTime = t
        extModel.scanForExtModelsToReload()
    end
end

require('addOns.autoStart').setup{ns = 'extModelAutoReload', readNamedParam = false}
