sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Tools\nPause/Stop Simulation on condition...'}
end

function sysCall_init()
    simUI = require 'simUI'
    ui = simUI.create[[<ui closeable="true" title="Pause/Stop Simulation on condition" placement="relative" position="-10,500" on-close="uiClosed">
        <label text="This add-on will pause or stop the simulation when the specified condition occurs" word-wrap="true" />
        <group id="${ui_all}" flat="true" content-margins="0,0,0,0" layout="form">
            <label text="Action:" />
            <group flat="true" content-margins="0,0,0,0" layout="hbox">
                <radiobutton text="Pause" on-click="setActionPause" checked="true" />
                <radiobutton text="Stop" on-click="setActionStop" />
            </group>
            <label text="Condition:" />
            <group flat="true" content-margins="0,0,0,0">
                <combobox id="${ui_condition}">
                    <item>When all objects stop moving</item>
                </combobox>
                <group id="${ui_grp_condStatic}" visible="true" flat="true" content-margins="0,0,0,0">
                    <label text="Time threshold: [s]" />
                    <edit id="${ui_timeThreshold}" value="1.0" />
                </group>
            </group>
        </group>
    </ui>]]
    setActionPause()
    setConditionWhenObjectsStopMoving()
end

function sysCall_nonSimulation()
    if leaveNow then return {cmd = 'cleanup'} end
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_beforeSimulation()
    threshold = tonumber(simUI.getEditValue(ui, ui_timeThreshold))
    reset()
    simUI.setEnabled(ui, ui_all, false)
end

function sysCall_suspend()
    simUI.setEnabled(ui, ui_all, true)
end

function sysCall_resume()
    threshold = tonumber(simUI.getEditValue(ui, ui_timeThreshold))
    reset()
    simUI.setEnabled(ui, ui_all, false)
end

function sysCall_afterSimulation()
    simUI.setEnabled(ui, ui_all, true)
end

function sysCall_actuation()
    if leaveNow then return {cmd = 'cleanup'} end

    checkCondition()
end

function reset()
    lastLocalPose = {}
    lastPose = {}
    lastMotionTime = sim.getSimulationTime()
end

function onStaticConditionReached()
    sim.addLog(sim.verbosity_scriptinfos, 'Static condition reached: pausing simulation...')
    sim.pauseSimulation()
end

function uiClosed()
    leaveNow = true
end

function setActionPause()
    onStaticConditionReached = function()
        sim.addLog(sim.verbosity_scriptinfos, 'Condition reached: pausing simulation...')
        sim.pauseSimulation()
    end
end

function setActionStop()
    onStaticConditionReached = function()
        sim.addLog(sim.verbosity_scriptinfos, 'Condition reached: stopping simulation...')
        sim.stopSimulation()
    end
end

function setConditionWhenObjectsStopMoving()
    simUI.setWidgetVisibility(ui, ui_grp_condStatic, true)
    checkCondition = function()
        local d, n = 0, 0
        for _, h in ipairs(sim.getObjectsInTree(sim.handle_scene)) do
            local lp = sim.getObjectPosition(h, sim.handle_parent)
            local p = sim.getObjectPosition(h)
            if lastPose[h] then
                d = d + (Vector(lp) - Vector(lastLocalPose[h])):norm()
                d = d + (Vector(p) - Vector(lastPose[h])):norm()
            end
            lastPose[h] = p
            lastLocalPose[h] = lp
            n = n + 2
        end
        d = d / n
        if d > 0.0001 then
            lastMotionTime = sim.getSimulationTime()
        end
        if (sim.getSimulationTime() - lastMotionTime) > threshold then
            onStaticConditionReached()
        end
    end
end
