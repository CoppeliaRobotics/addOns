sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Exporters\nEvents dump exporter...'}
end

function sysCall_init()
    sim.test('sim.enableEvents', true)
    sim.test('sim.mergeEvents', true)
    sim.test('sim.cborEvents', true)
    export()
    return {cmd = 'cleanup'}
end

function sysCall_event(data)
end

function export()
    local scenePath = sim.getStringParameter(sim.stringparam_scene_path)
    local sceneName = sim.getStringParameter(sim.stringparam_scene_name):match("(.+)%..+")
    if sceneName == nil then sceneName = 'untitled' end
    local fileName = sim.fileDialog(
                         sim.filedlg_type_save, 'Export events dump...', scenePath,
                         sceneName .. '.cbor', 'CBOR file', 'cbor'
                     )
    if fileName == nil then return end
    local data = sim.getGenesisEvents()
    local file = io.open(fileName, 'w')
    file:write(data)
    file:close()
    sim.addLog(
        sim.verbosity_infos + sim.verbosity_undecorated, 'Exported events dump to ' .. fileName
    )
end
