sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nAlias change'}
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_init()
    simUI = require 'simUI'
    sim.addLog(
        sim.verbosity_scriptinfos, "This tool allows to replace/change aliases of selected objects."
    )
end

function sysCall_nonSimulation()
    if leaveNow then return {cmd = 'cleanup'} end
end

function sysCall_selChange(inData)
    if #inData.sel >= 1 then
        showDlg()
    else
        hideDlg()
    end
end

function sysCall_beforeSimulation()
    hideDlg()
end

function sysCall_cleanup()
    hideDlg()
end

function sysCall_beforeInstanceSwitch()
    hideDlg()
end

function showDlg()
    if not ui then
        local pos = 'position="-50,50" placement="relative"'
        if uiPos then
            pos = 'position="' .. uiPos[1] .. ',' .. uiPos[2] .. '" placement="absolute"'
        end
        local xml =
            '<ui title="Alias change tool" activate="false" closeable="true" on-close="close_callback" ' ..
                pos .. [[>
            <group layout="form" flat="true">
            <label text="Replace occurences of"/>
            <edit value="originalString" id="1" />
            <label text="with string"/>
            <edit value="replacementString" id="2" />
            </group>
            <button text="Perform operation on selected objects" on-click="replace_callback" id="3"/>
        </ui>]]
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

function replace_callback(ui, id, v)
    local selectedObjects = sim.getObjectSel()
    local originalString = simUI.getEditValue(ui, 1)
    local replacementString = simUI.getEditValue(ui, 2)
    if #originalString > 0 then
        for i, handle in ipairs(selectedObjects) do
            local name = sim.getObjectAlias(handle)
            local newName, r = string.gsub(name, originalString, replacementString)
            if r > 0 then sim.setObjectAlias(handle, newName) end
        end
        sim.announceSceneContentChange()
    end
end

function close_callback()
    leaveNow = true
end
