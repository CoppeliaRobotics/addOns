local sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nCheck selected model'}
end

function sysCall_init()
    local sel = sim.getObjectSel()
    if #sel == 0 or #sel > 1 then
        sim.addLog(sim.verbosity_scripterrors, "This add-on requires one object to be selected.")
        return {cmd = 'cleanup'}
    end
    if sim.getSimulationState() == sim.simulation_paused then
        check()
        return {cmd = 'cleanup'}
    else
        sim.addLog(sim.verbosity_scriptwarnings, "This add-on works with paused simulation.")
        if sim.getSimulationState() == sim.simulation_advancing_running then
            sim.pauseSimulation()
            afterCheck = sim.startSimulation
        elseif sim.getSimulationState() == sim.simulation_stopped then
            pause = true
            sim.startSimulation()
            afterCheck = sim.stopSimulation
        end
    end
end

function sysCall_sensing()
    if pause then
        sim.pauseSimulation()
    end
end

function sysCall_suspended()
    check()
    return {cmd = 'cleanup'}
end

function check()
    sim.addLog(sim.verbosity_scriptwarnings, "Checking...")
    local checkmodel = require 'checkmodel'
    local sel = sim.getObjectSel()
    local results = ''
    for handle, issues in pairs(checkmodel.check(sel[1])) do
        results = results .. string.format("  Object %s (handle: %d)", sim.getObjectAlias(handle, 2), handle) .. '\n'
        for _, issue in ipairs(issues) do
            results = results .. "    " .. issue .. '\n'
        end
    end
    check = function() end
    if afterCheck then afterCheck() end
    sim.addLog(sim.verbosity_scriptwarnings, 'Check finished. Results:\n\n' .. results)
end
