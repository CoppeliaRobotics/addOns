sim = require 'sim'
extModel = require 'addOns.extModel'

function sysCall_info()
    return {
        autoStart = sim.getNamedBoolParam('externalModelService.autoStart') ~= false,
        menu = 'Developer tools\nExternal model auto reload and save',
    }
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_init()
end

function sysCall_afterLoad()
    extModel.scanForExtModelsToReload()
end

function sysCall_afterInstanceSwitch()
    extModel.scanForExtModelsToReload()
end

function sysCall_beforeSave(inData)
    if inData.regularSave then
        extModel.scanForExtModelsToSave()
    end
end
