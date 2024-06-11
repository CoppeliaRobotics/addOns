sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Exporters\nEvents capture...'}
end

function sysCall_init()
    simUI = require 'simUI'
    sim.test('sim.enableEvents', true)
    sim.test('sim.mergeEvents', true)
    sim.test('sim.cborEvents', true)
    data = string.char(159)
    if simUI.msgBox(
        simUI.msgbox_type.info, simUI.msgbox_buttons.okcancel, "Events capture add-on",
        'This add-on allows to record events for a given time period. Recording will start after pressing Ok, and will end by selecting the add-on menu item again. After stopping, the location where to save the file can be selected.\n\nPress Ok to start recording, or Cancel to abort.'
    ) == simUI.msgbox_result.ok then
        sim.addLog(
            sim.verbosity_scriptinfos, 'Recording events... (stop the add-on to save to file)'
        )
    else
        return {cmd = 'cleanup'}
    end
end

function sysCall_addOnScriptSuspend()
    -- menu triggered by the user
    export()
    return {cmd = 'cleanup'}
end

function sysCall_cleanup()
end

function sysCall_event(eventData)
    assert(eventData:byte(1) == 159 and eventData:byte(#eventData) == 255, 'event data error')
    data = data .. eventData:sub(2, #eventData - 1)
end

function export()
    local scenePath = sim.getStringParam(sim.stringparam_scene_path)
    local sceneName = sim.getStringParam(sim.stringparam_scene_name):match("(.+)%..+")
    if sceneName == nil then sceneName = 'untitled' end
    local fileNames = simUI.fileDialog(
                         simUI.filedialog_type.save, 'Export events dump...', scenePath,
                         sceneName .. '.cbor', 'CBOR file', 'cbor'
                     )
    if #fileNames == 0 then return end
    local fileName = fileNames[1]
    local file = io.open(fileName, 'w')
    data = data .. string.char(255)
    file:write(data)
    file:close()
    sim.addLog(sim.verbosity_scriptinfos, 'Exported events to ' .. fileName)
end
