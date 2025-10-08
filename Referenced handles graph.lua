local sim = require 'sim'
local simUI

function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nReferenced handles graph'}
end

function sysCall_init()
    simUI = require 'simUI'

    allTags = collectTags()
    if next(allTags) == nil then
        simUI.msgBox(
            simUI.msgbox_type.info, simUI.msgbox_buttons.ok, 'Empty result',
            'There are no objects with referenced handles in this scene.'
        )
        return {cmd = 'cleanup'}
    end

    local cb = {}
    for tag, info in pairs(allTags) do
        local label = tag == '' and '[empty]' or tag
        if info.count then
            label = label .. ' (' .. info.count .. ')'
        end
        table.insert(cb, '<checkbox text="' .. label .. '" id="' .. info.id .. '" checked="' .. (info.include and 'true' or 'false') .. '" />')
    end
    table.sort(cb)
    ui = simUI.create([[
        <ui title="Referenced Handles Graph" modal="true" closable="false">
            <group>
                <label text="Select which tags to include in the graph:" />
                ]] .. table.concat(cb, '\n') .. [[
            </group>
            <group>
                <label text="Node label style:" />
                <combobox id="${ui_comboNameStyle}">
                    <item>Simple alias</item>
                    <item>Short path</item>
                    <item>Full path</item>
                </combobox>
                <checkbox id="${ui_chkIncludeHandle}" text="Include object handle" checked="true" />
            </group>
            <group layout="hbox">
                <button text="Generate" on-click="generate" />
                <button text="Cancel" on-click="cancel" />
            </group>
        </ui>
    ]])
end

function sysCall_nonSimulation()
    if leaveNow then return {cmd = 'cleanup'} end
end

function collectTags()
    local allTags = {}
    local nextId = 1000
    for _, handle in ipairs(sim.getObjectsInTree(sim.handle_scene, sim.handle_all)) do
        local tags = sim.getReferencedHandlesTags(handle)
        for _, tag in ipairs(tags) do
            if allTags[tag] == nil then
                allTags[tag] = {
                    count = 0,
                    include = true,
                    id = nextId,
                }
                nextId = nextId + 1
            end
            allTags[tag].count = allTags[tag].count + 1
        end
    end
    return allTags
end

function generate()
    local aliasOpt = ({[0]=-1, [1]=1, [2]=2})[simUI.getComboboxSelectedIndex(ui, ui_comboNameStyle)]
    local includeHandle = simUI.getCheckboxValue(ui, ui_chkIncludeHandle) > 0
    local function label(h)
        local s = sim.getObjectAlias(h, aliasOpt)
        if includeHandle then s = s .. ' (' .. h .. ')' end
        return s
    end
    for tag, info in pairs(allTags) do
        info.include = simUI.getCheckboxValue(ui, info.id) > 0
    end

    local Graph = require 'Graph'
    local g = Graph(true)
    local function edge(h1, h2, name)
        for _, h in ipairs{h1, h2} do
            if not g:hasVertex(h) then
                g:addVertex(h, {
                    name = label(h),
                    handle = h,
                })
            end
        end
        g:addEdge(h1, h2, {name = name})
    end
    for _, handle in ipairs(sim.getObjectsInTree(sim.handle_scene, sim.handle_all)) do
        local tags = sim.getReferencedHandlesTags(handle)
        for _, tag in ipairs(tags) do
            if allTags[tag].include then
                for _, handle2 in ipairs(sim.getReferencedHandles(handle, tag)) do
                    if sim.isHandle(handle2) then
                        edge(handle, handle2, tag)
                    end
                end
            end
        end
    end
    local outFile = sim.getStringProperty(sim.handle_app, 'tempPath') .. '/graph.png'
    g:render{
        nodeStyle = function(id)
            local node = g:getVertex(id)
            return {
                shape = 'box',
                label = '"' .. node.name .. '"',
            }
        end,
        edgeStyle = function(id1, id2)
            local edge = g:getEdge(id1, id2)
            return {
                label = '"' .. edge.name .. '"',
            }
        end,
        outFile = outFile,
    }
    sim.openFile(outFile)
    leaveNow = true
end

function cancel()
    simUI.destroy(ui)
    ui = nil
    leaveNow = true
end
