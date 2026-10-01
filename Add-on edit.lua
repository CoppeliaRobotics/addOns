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
    local lang = 'none'
    for l, ext in pairs{python = '.py', lua = '.lua'} do
        if selectedAddOn.addOnPath:endswith(ext) then lang = l end
    end
    local opts = [[<editor
        toolbar="true"
        statusbar="true"
        can-restart="true"
        title="Editing addon: ]].. selectedAddOn.addOnMenuPath ..[["
        line-numbers="true"
        lang="]] .. lang .. [["
    />]]
    simCodeEditor.openFile(selectedAddOn.addOnPath, opts)
end

function reload()
    selectedAddOn:reset()
    selectedAddOn:init()
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

    ui = simUI.create([[<ui title="Add-on editor" closeable="true" on-close="closeUi" resizable="false">
        <label text="Select an add-on to edit and click Edit; it will be loaded into a customization script. When finished, click Save to save it back to the original add-on script file." word-wrap="true" />
        <combobox id="${ui_combo}" on-change="selectedAddonChanged">]] .. addonsCbItems .. [[</combobox>
        <button id="${ui_btnEdit}" text="Edit selected add-on" on-click="edit" />
        <button id="${ui_btnReload}" text="Restart selected add-on" on-click="reload" />
    </ui>]])
end

function sysCall_nonSimulation()
    if leaveNow then return {cmd = 'cleanup'} end
end
