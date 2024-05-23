sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nReferenced handles explorer'}
end

function sysCall_init()
    simUI = require 'simUI'
    sim.addLog(
        sim.verbosity_scriptinfos,
        "This tool will display the referenced handles stored in the selected object. Referenced handles can be read and written with sim.getReferencedHandles and sim.setReferencedHandles."
    )
    object = -1
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_cleanup()
    hideDlg()
end

function sysCall_beforeSimulation()
    hideDlg()
end

function sysCall_beforeInstanceSwitch()
    hideDlg()
end

function onCloseClicked()
    leaveNow = true
end

function onSelectionChange(ui, id, index)
end

function beginEdit()
    hideDlg()

    local xml =
        '<ui title="Referenced Handles Explorer" activate="false" closeable="false" resizable="false">'
    xml =
        xml .. '<label text="<b>Editing referenced handles of ' .. sim.getObjectAlias(object, 9) ..
            '</b>" />'
    xml = xml ..
              '<label text="<small>Make changes to selection and then press one of the buttons below:</small>" />'
    xml = xml .. '<button text="Save" on-click="acceptEdit" />'
    xml = xml .. '<button text="Cancel" on-click="abortEdit" />'
    xml = xml .. '</ui>'
    uiEdit = simUI.create(xml)

    editing = object
    sim.setObjectSel(content)
end

function abortEdit()
    editing = nil
    sim.setObjectSel {object}
    simUI.destroy(uiEdit)
    uiEdit = nil
end

function acceptEdit()
    sim.setReferencedHandles(object, sim.getObjectSel())
    abortEdit()
end

function setSelection()
    sim.setObjectSel(content)
end

function printHandles()
    print(content)
end

function showDlg()
    if not ui then
        local pos = 'position="-30,160" placement="relative"'
        if uiPos then
            pos = 'position="' .. uiPos[1] .. ',' .. uiPos[2] .. '" placement="absolute"'
        end
        aliasOption = sim.getNamedInt32Param('referencedHandlesExplorer.aliasOption') or 9
        if not ui then
            xml =
                '<ui title="Referenced Handles Explorer" activate="false" closeable="true" on-close="onCloseClicked" resizable="true" ' ..
                    pos .. '>'
            xml = xml .. '<group flat="true"><label text="Referenced handles in object &quot;<b>' ..
                      sim.getObjectAlias(object, aliasOption) .. '</b>&quot;:" /></group>'
            xml = xml ..
                      '<table id="600" selection-mode="row" editable="false" on-selection-change="onSelectionChange">'
            xml = xml .. '<header><item>Handle</item><item>Name</item></header>'
            for ch, content1 in pairs(content) do
                local flagDisplay = ch == 'normal' and '' or string.format(' [%s]', ch)
                for tag, content2 in pairs(content1) do
                    xml = xml .. '<row><item></item><item>tag = \'' .. string.gsub(tag, '\'', '\\\'') .. '\'' .. flagDisplay .. '</item></row>'
                    for i, handle in ipairs(content2) do
                        local name = ''
                        if handle ~= -1 then name = sim.getObjectAlias(handle, aliasOption) end
                        xml = xml .. '<row><item>' .. handle .. '</item><item>    ' .. name .. '</item></row>'
                    end
                end
            end
            xml = xml .. '</table>'
            --xml = xml .. '<button text="Edit..." on-click="beginEdit" />'
            --xml = xml .. '<button text="Set selection" on-click="setSelection" />'
            --xml = xml .. '<button text="Print handles" on-click="printHandles" />'
            xml = xml .. '</ui>'
            ui = simUI.create(xml)
        end
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

function sysCall_nonSimulation()
    if leaveNow then return {cmd = 'cleanup'} end
end

function sysCall_selChange(inData)
    if editing then return end

    local s = inData.sel
    local previousObject, previousContent = object, content
    content = nil
    object = -1
    if #s == 1 then
        object = s[1]
        content = {}
        for k, handle in pairs{
            normal = object,
            ['sim.handleflag_keeporiginal'] = object | sim.handleflag_keeporiginal,
        } do
            local content1 = {}
            for _, tag in ipairs(sim.getReferencedHandlesTags(handle)) do
                content1[tag] = sim.getReferencedHandles(handle, tag)
            end
            if next(content1) then
                content[k] = content1
            end
        end
    end
    if previousObject ~= object then hideDlg() end
    if content and next(content) then
        local _ = function(x)
            return x ~= nil and sim.packTable(x) or nil
        end
        if _(content) ~= _(previousContent) then hideDlg() end
        showDlg()
    else
        hideDlg()
    end
end
