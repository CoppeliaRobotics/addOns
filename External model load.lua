function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nExternal model load...'}
end

function sysCall_init()
    local sim = require 'sim'
    local simUI = require 'simUI'
    local scenePath = sim.getStringProperty(sim.handle_scene, 'scenePath')
    if scenePath == '' then
        simUI.msgBox(simUI.msgbox_type.critical, simUI.msgbox_buttons.ok, 'Error', 'To use this add-on, first save the scene to a file.')
        return {cmd = 'cleanup'}
    end
    local extModel = require 'addOns.extModel'
    local lfsx = require 'lfsx'
    local initPath = ''
    if simUI.getKeyboardModifiers().shift then
        initPath = sim.getStringProperty(sim.handle_app, 'modelPath')
    else
        initPath = lfsx.dirname(scenePath)
    end
    files = simUI.fileDialog(simUI.filedialog_type.load, 'Open model...', initPath, '', 'Model files', 'ttm;simmodel.xml')
    for _, file in ipairs(files) do
        extModel.loadModel(nil, file)
    end
    return {cmd = 'cleanup'}
end
