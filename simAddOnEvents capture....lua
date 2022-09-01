function sysCall_info()
    return {autoStart=false,menu='Exporters\nEvents capture...'}
end

function sysCall_init()
    sim.test('sim.enableEvents',true)
    sim.test('sim.mergeEvents',true)
    sim.test('sim.cborEvents',true)
    data=string.char(159)
    sim.addLog(sim.verbosity_infos+sim.verbosity_undecorated,'Recording events... (stop the add-on to save to file)')
end

function sysCall_addOnScriptSuspend()
    -- menu triggered by the user
    export()
    return {cmd='cleanup'}
end

function sysCall_cleanup()
end

function sysCall_event(eventData)
    assert(eventData:byte(1)==159 and eventData:byte(#eventData)==255,'event data error')
    data=data..eventData:sub(2,#eventData-1)
end

function export()
    local scenePath=sim.getStringParameter(sim.stringparam_scene_path)
    local sceneName=sim.getStringParameter(sim.stringparam_scene_name):match("(.+)%..+")
    if sceneName==nil then sceneName='untitled' end
    local fileName=sim.fileDialog(sim.filedlg_type_save,'Export events dump...',scenePath,sceneName..'.cbor','CBOR file','cbor')
    if fileName==nil then return end
    local file=io.open(fileName,'w')
    data=data..string.char(255)
    file:write(data)
    file:close()
    sim.addLog(sim.verbosity_infos+sim.verbosity_undecorated,'Exported events to '..fileName)
end
