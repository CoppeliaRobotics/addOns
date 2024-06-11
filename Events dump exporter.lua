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
    local scenePath = sim.getStringParam(sim.stringparam_scene_path)
    local sceneName = sim.getStringParam(sim.stringparam_scene_name):match("(.+)%..+")
    if sceneName == nil then sceneName = 'untitled' end
    local fileNames = simUI.fileDialog(
                         simUI.filedialog_type.save, 'Export events dump...', scenePath,
                         sceneName .. '.cbor', 'CBOR file', 'cbor'
                     )
    if #fileNames == 0 then return end
    local fileName = fileNames[1]
    local data = sim.getGenesisEvents()
    local file = io.open(fileName, 'w')
    file:write(data)
    file:close()
    sim.addLog(sim.verbosity_infos + sim.verbosity_undecorated, 'Exported events dump to ' .. fileName)
end
