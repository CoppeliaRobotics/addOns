function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nExternal model save'}
end

function sysCall_init()
    local sim = require 'sim'
    local extModel = require 'addOns.extModel'

    local sel = sim.getObjectSel()

    if #sel == 0 and false then
        sim.addLog(sim.verbosity_errors, 'No objects selected')
        return {cmd = 'cleanup'}
    end

    if #sel == 0 then
        if extModel.prompt('No object selected. Do you want to scan all available external models in the scene?') then
            extModel.scanForExtModelsToSave()
        end
        return {cmd = 'cleanup'}
    end

    if #sel > 1 then
        sim.addLog(sim.verbosity_errors, 'Too many objects selected')
        return {cmd = 'cleanup'}
    end

    if not sim.getBoolProperty(sel[1], 'modelBase') then
        sim.addLog(sim.verbosity_errors, 'Selection must be a model')
        return {cmd = 'cleanup'}
    end

    extModel.saveModelInteractive(sel[1])

    return {cmd = 'cleanup'}
end
