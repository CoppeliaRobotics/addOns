local sim = require 'sim'
local simUI

function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nCheck selected model'}
end

function sysCall_init()
    simUI = require 'simUI'
    showGraph = simUI.getKeyboardModifiers().shift
    local sel = sim.getObjectSel()
    if #sel == 0 or #sel > 1 then
        sim.addLog(sim.verbosity_scripterrors, "This add-on requires one object to be selected.")
        return {cmd = 'cleanup'}
    end

    step = 0
    if sim.getSimulationState() == sim.simulation_stopped then
        stop = true
        sim.startSimulation()
    end
end

function sysCall_sensing()
    step = step + 1
    if step > 1 then
        check()
        if stop then
            sim.stopSimulation()
        end
    end
    if leaveNow then return {cmd = 'cleanup'} end
end

function sysCall_nonSimulation()
    if leaveNow then return {cmd = 'cleanup'} end
end

function sysCall_suspended()
    check()
    if leaveNow then return {cmd = 'cleanup'} end
end

function check()
    sim.addLog(sim.verbosity_scriptwarnings, "Checking...")
    local checkmodel = require 'checkmodel'
    local sel = sim.getObjectSel()
    assert(#sel == 1)
    if showGraph then
        local g = checkmodel.buildObjectsGraph(sel[1])
        checkmodel.showObjectsGraph(g)
    end
    check = function() end
    local issues = checkmodel.check(sel[1])
    showReport(issues)
end

function showReport(issues)
    if next(issues) == nil then
        simUI.msgBox(
            simUI.msgbox_type.info, simUI.msgbox_buttons.ok, 'Check Model - Results',
            'No issues were found.'
        )
        return
    end

    local items = {}
    for handle, issues in pairs(issues) do
        local itemText = '<h4>Object ' .. sim.getObjectAlias(handle, 9) .. ' (handle: ' .. handle .. ')</h4>'
        itemText = itemText .. '<ul>'
        for _, issue in ipairs(issues) do
            itemText = itemText .. '<li>' .. issue .. '</li>'
        end
        itemText = itemText .. '</ul>'
        table.insert(items, itemText)
    end
    simUI.create([[
        <ui
                title="Check Model - Results"
                resizable="true"
                closeable="true"
                placement="center"
                modal="true"
                size="600,400"
                on-close="closed">
            <text-browser text="]] .. string.escapehtml(table.concat(items, '')) .. [["></text-browser>
        </ui>
    ]])
end

function closed()
    leaveNow = true
end
