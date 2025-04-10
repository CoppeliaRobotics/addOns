function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nExternal model reload selected...'}
end

function sysCall_init()
    local sim = require 'sim'
    local extModel = require 'addOns.extModel'
    local sel = sim.getObjectSel()
    if #sel == 0 then
        if false then
            sim.addLog(sim.verbosity_errors, 'No objects selected')
        else
            if extModel.prompt('No object selected. Do you want to scan all available external models in the scene?') then
                extModel.scanForExtModelsToReload()
            end
        end
    else
        selExtModels = filter(extModel.hasExternalModel, sel)
        if #selExtModels ~= #sel then
            if #sel == 1 then
                sim.addLog(sim.verbosity_errors, 'Object does not reference an external model')
            elseif #selExtModels == 0 then
                sim.addLog(sim.verbosity_errors, 'Objects do not reference any external model')
            elseif #selExtModels < #sel then
                sim.addLog(sim.verbosity_errors, 'Not all selected objects reference an external model')
            else
                for _, modelHandle in ipairs(selExtModels) do
                    extModel.loadModel(modelHandle)
                end
            end
        end
    end
    return {cmd = 'cleanup'}
end
