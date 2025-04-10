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

    if extModel.hasExternalModel(sel[1]) then
        extModel.saveModel(sel[1])
        return {cmd = 'cleanup'}
    end

    if extModel.prompt('Object %s does not reference an external model.\n\nDo you want to choose one?', sim.getObjectAlias(sel[1], 2)) then
        local simUI = require 'simUI'
        local lfsx = require 'lfsx'
        local initPath = lfsx.dirname(sim.getStringProperty(sim.handle_scene, 'scenePath'))
        files = simUI.fileDialog(simUI.filedialog_type.save, 'Save model...', initPath, '', 'Model files', 'ttm;simmodel.xml')
        if #files > 1 then
            sim.addLog(sim.verbosity_errors, 'Please choose exactly one file')
        elseif #files == 1 then
            local f = io.open(files[1], 'r')
            local exists = false
            if f then
                f:close()
                exists = true
            end
            if not exists or extModel.prompt('File %s already exists.\n\nDo you want to overwrite it?', files[1]) then
                extModel.saveModel(sel[1], files[1])
            end
        end
    end

    return {cmd = 'cleanup'}
end
