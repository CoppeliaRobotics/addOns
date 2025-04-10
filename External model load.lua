function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nExternal model load...'}
end

function sysCall_init()
    local sim = require 'sim'
    local simUI = require 'simUI'
    local extModel = require 'addOns.extModel'
    local lfsx = require 'lfsx'
    local initPath = ''
    local scenePath = sim.getStringProperty(sim.handle_scene, 'scenePath')
    if scenePath ~= '' and not simUI.getKeyboardModifiers().shift then
        initPath = lfsx.dirname(scenePath)
    else
        initPath = sim.getStringProperty(sim.handle_app, 'modelPath')
    end
    files = simUI.fileDialog(simUI.filedialog_type.load, 'Open model...', initPath, '', 'Model files', 'ttm;simmodel.xml')
    for _, file in ipairs(files) do
        extModel.loadModel(nil, file)
    end
    return {cmd = 'cleanup'}
end
