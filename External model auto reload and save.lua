sim = require 'sim'
extModel = require 'addOns.extModel'

function sysCall_info()
    return {
        autoStart = sim.getBoolProperty(sim.handle_app, 'customData.extModel.autoStart', {noError = true}) == true,
        menu = 'Developer tools\nExternal model auto reload and save',
    }
end

function sysCall_addOnScriptSuspend()
    sim.setBoolProperty(sim.handle_app, 'customData.extModel.autoStart', false)
    return {cmd = 'cleanup'}
end

function sysCall_init()
    sim.setBoolProperty(sim.handle_app, 'customData.extModel.autoStart', true)
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
