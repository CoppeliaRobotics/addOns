sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nFind in scripts...'}
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_init()
    simUI = require 'simUI'
    showDlg()
end

function sysCall_nonSimulation()
    if leaveNow then return {cmd = 'cleanup'} end
end

function sysCall_beforeSimulation()
    hideDlg()
end

function sysCall_afterSimulation()
    showDlg()
end

function sysCall_cleanup()
    hideDlg()
end

function sysCall_beforeInstanceSwitch()
    hideDlg()
end

function showDlg()
    if not ui then
        local pos = 'placement="center"'
        if uiPos then
            pos = 'position="' .. uiPos[1] .. ',' .. uiPos[2] .. '" placement="absolute"'
        end
        local xml = [[
        <ui title="Find in scripts" activate="true" closeable="true" on-close="close_callback" ]] .. pos .. [[>
            <group layout="form" flat="true">
                <label text="Search string:"/>
                <edit value="" id="1" />
            </group>
            <button text="Find" on-click="find_callback" id="3"/>
        </ui>
        ]]
        ui = simUI.create(xml)
    end
end

function hideDlg()
    if ui then
        uiPos = {}
        uiPos[1], uiPos[2] = simUI.getPosition(ui)
        simUI.destroy(ui)
        ui = nil
    end
end

function find_callback(ui, id, v)
    local searchString = simUI.getEditValue(ui, 1)
    if #searchString > 0 then
        for i, handle in ipairs(sim.getObjectsInTree(sim.handle_scene, sim.object_script_type)) do
            local alias = sim.getObjectAlias(handle, 2)
            local code = sim.getProperty(handle, 'code')
            grep(code, searchString, alias)
        end
    end
end

function close_callback()
    leaveNow = true
end

function grep(text, searchText, prefix)
    local lines = {}
    for line in text:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    for lineNumber, line in ipairs(lines) do
        if line:find(searchText) then
            print(string.format("%s:%d: %s", prefix, lineNumber, line))
        end
    end
end
