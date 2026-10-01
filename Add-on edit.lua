local sim = require 'sim-2'
local simUI
local simCodeEditor

function closeUi()
    leaveNow = true
end

function selectedAddonChanged()
    index = simUI.getComboboxSelectedIndex(ui, ui_combo)
    selectedAddOn = addOns[index + 1]
end

function edit()
    if addOn_editor[selectedAddOn.handle] then return end
    local lang = 'none'
    for l, ext in pairs{python = '.py', lua = '.lua'} do
        if selectedAddOn.addOnPath:endswith(ext) then lang = l end
    end
    local opts = [[<editor
        toolbar="true"
        can-restart="true"
        title="Editing addon: ]].. selectedAddOn.addOnMenuPath ..[["
        line-numbers="true"
        lang="]] .. lang .. [["
        script-handle="]] .. sim.self.handle .. [["
        on-close="onCodeEditorClose"
        on-restart="onCodeEditorRestart"
    />]]
    local editorHandle = simCodeEditor.openFile(selectedAddOn.addOnPath, opts)
    addOn_editor[selectedAddOn.handle] = editorHandle
    editor_addOn[editorHandle] = selectedAddOn.handle
end

function reload()
    selectedAddOn:reset()
    selectedAddOn:init()
end

function onCodeEditorClose(editorHandle, event)
    simCodeEditor.close(editorHandle)
    local addOn = editor_addOn[editorHandle]
    if not addOn then return end
    addOn_editor[addOn.handle] = nil
    editor_addOn[editorHandle] = nil
end

function onCodeEditorRestart(editorHandle, event)
    local addOn = editor_addOn[editorHandle]
    if not addOn then return end
    local file, err = io.open(addOn.addOnPath, 'r')
    if file then
        local code = file:read('*a')
        file:close()
        addOn.code = code
    else
        sim.app:logError('error reading ' .. addOn.addOnPath .. ': ' .. err)
    end
    addOn:reset()
    addOn:init()
end

function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nAdd-on edit...'}
end

function sysCall_init()
    simUI = require 'simUI'
    simCodeEditor = require 'simCodeEditor'

    addOns = {}
    for _, addOn in ipairs(sim.app.addOns) do
        table.insert(addOns, addOn)
    end
    table.sort(addOns, function(a, b) return a.addOnMenuPath < b.addOnMenuPath end)
    selectedAddOn = addOns[1]

    local addonsCbItems = ''
    for _, addOn in ipairs(addOns) do
        addonsCbItems = addonsCbItems .. '<item>' .. addOn.addOnMenuPath .. '</item>\n'
    end

    addOn_editor = {}
    editor_addOn = {}

    ui = simUI.create([[<ui title="Add-on editor" closeable="true" on-close="closeUi" resizable="false">
        <combobox id="${ui_combo}" on-change="selectedAddonChanged">]] .. addonsCbItems .. [[</combobox>
        <button id="${ui_btnEdit}" text="Edit selected add-on" on-click="edit" />
        <button id="${ui_btnReload}" text="Restart selected add-on" on-click="reload" />
    </ui>]])
end

function sysCall_nonSimulation()
    if leaveNow then return {cmd = 'cleanup'} end
end

function sysCall_cleanup()
    for editorHandle, addOn in pairs(editor_addOn) do
        simCodeEditor.close(editorHandle)
    end
end