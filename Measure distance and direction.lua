sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Geometry / Mesh\nMeasure distance/direction'}
end

function sysCall_init()
    if sim.getSimulationState() ~= sim.simulation_stopped then return {cmd = 'cleanup'} end
    sim.addLog(
        sim.verbosity_scriptinfos,
        "This tool measures distance and direction between first clicked vertex/dummy and second clicked vertex/dummy."
    )
    sim.broadcastMsg {
        id = 'pointSampler.enable',
        data = {key = 'measureDistanceDirection', vertex = true, dummy = true, snapToClosest = true},
    }
end

function sysCall_cleanup()
    sim.broadcastMsg {id = 'pointSampler.disable', data = {key = 'measureDistanceDirection'}}
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_msg(event)
    if not event.data or not event.data.key or event.data.key ~= 'measureDistanceDirection' then
        return
    end
    if event.id == 'pointSampler.click' then
        if event.data.dummy then
            point = sim.getObjectPosition(event.data.dummy)
        else
            point = event.data.vertexCoords
        end
        if not firstPoint then
            firstPoint = Vector(point)
            sim.broadcastMsg {
                id = 'pointSampler.setFlags',
                data = {key = 'measureDistanceDirection', arrowSource = point},
            }
        else
            secondPoint = Vector(point)
            dir = secondPoint - firstPoint
            sim.addLog(
                sim.verbosity_scriptinfos,
                string.format("Direction: (%.3f %.3f %.3f)", unpack(dir:data()))
            )
            sim.addLog(sim.verbosity_scriptinfos, string.format("Distance: %.3f", dir:norm()))
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
