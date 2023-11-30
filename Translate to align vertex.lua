sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Geometry / Mesh\nTranslate to align vertex'}
end

function sysCall_init()
    simUI = require 'simUI'
    if sim.getSimulationState() ~= sim.simulation_stopped then return {cmd = 'cleanup'} end
    sim.addLog(
        sim.verbosity_scriptinfos,
        "This tool translates a shape to bring first clicked vertex to the position of second clicked vertex."
    )
    ui = simUI.create [[<ui closeable="false" title="Translate to align vertex add-on">
        <label id="1" text="1) Select a shape to translate" />
        <label id="2" text="2) Select first vertex" />
        <label id="3" text="3) Select second vertex" />
        <button text="Abort" on-click="abort" />
    </ui>]]
    phase = 1
    updateUi()
    sim.broadcastMsg {
        id = 'pointSampler.enable',
        data = {key = 'translateToAlignVertex', handle = true},
    }
end

function sysCall_cleanup()
    sim.broadcastMsg {id = 'pointSampler.disable', data = {key = 'translateToAlignVertex'}}
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_msg(event)
    if not event.data or not event.data.key or event.data.key ~= 'translateToAlignVertex' then
        return
    end
    if event.id == 'pointSampler.click' then
        if phase == 1 then
            targetObject = event.data.handle
            phase = 2
            updateUi()
            sim.broadcastMsg {
                id = 'pointSampler.setFlags',
                data = {key = 'translateToAlignVertex', vertex = true},
            }
        elseif phase == 2 then
            firstVertex = event.data.vertexCoords
            phase = 3
            updateUi()
            sim.broadcastMsg {
                id = 'pointSampler.setFlags',
                data = {key = 'translateToAlignVertex', arrowSource = firstVertex},
            }
        elseif phase == 3 then
            local p = sim.getObjectPosition(targetObject)
            p = Vector(p) + Vector(event.data.vertexCoords) - Vector(firstVertex)
            sim.setObjectPosition(targetObject, p:data())
            sim.announceSceneContentChange()
            return {cmd = 'cleanup'}
        end
    end
end

function sysCall_beforeSimulation()
    return {cmd = 'cleanup'}
end

function sysCall_beforeInstanceSwitch()
    return {cmd = 'cleanup'}
end

function sysCall_nonSimulation()
    if leaveNow then return {cmd = 'cleanup'} end
end

function updateUi()
    for i = 1, 3 do
        simUI.setEnabled(ui, i, i <= phase)
        simUI.setStyleSheet(ui, i, i == phase and 'font-weight: bold;' or '')
    end
end

function abort()
    leaveNow = true
end
