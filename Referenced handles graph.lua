function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nReferenced handles graph'}
end

function sysCall_init()
    local sim = require 'sim'
    local Graph = require 'Graph'
    local g = Graph(true)
    local function edge(h1, h2, name)
        for _, h in ipairs{h1, h2} do
            if not g:hasVertex(h) then
                g:addVertex(h, {
                    name = sim.getStringProperty(h, 'alias'),
                    handle = h,
                })
            end
        end
        g:addEdge(h1, h2, {name = name})
    end
    for _, handle in ipairs(sim.getObjectsInTree(sim.handle_scene, sim.handle_all)) do
        local tags = sim.getReferencedHandlesTags(handle)
        for _, tag in ipairs(tags) do
            for _, handle2 in ipairs(sim.getReferencedHandles(handle, tag)) do
                if sim.isHandle(handle2) then
                    edge(handle, handle2, tag)
                end
            end
        end
    end
    if g:vertexCount() == 0 then
        local simUI = require 'simUI'
        simUI.msgBox(
            simUI.msgbox_type.info, simUI.msgbox_buttons.ok, 'Empty result',
            'There are no objects with referenced handles in this scene.'
        )
    else
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
    end
    return {cmd = 'cleanup'}
end
