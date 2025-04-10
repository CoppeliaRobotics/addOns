function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nExternal model load...'}
end

function sysCall_init()
    local sim = require 'sim'
    local simUI = require 'simUI'
    local extModel = require 'addOns.extModel'
    local lfsx = require 'lfsx'
    local initPath = lfsx.dirname(sim.getStringProperty(sim.handle_scene, 'scenePath'))
    files = simUI.fileDialog(simUI.filedialog_type.load, 'Open model...', initPath, '', 'Model files', 'ttm;simmodel.xml')
    for _, file in ipairs(files) do
        extModel.loadModel(nil, file)
    end
    return {cmd = 'cleanup'}
end
