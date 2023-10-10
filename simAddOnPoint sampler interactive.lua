sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Geometry / Mesh\nPoint sampler'}
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_init()
    simUI = require 'simUI'
    createDummies = false
    sim.addLog(sim.verbosity_scriptinfos, "This tool allows to sample points in the scene")
    showDlg()
    sim.broadcastMsg {
        id = 'pointSampler.enable',
        data = {
            key = 'pointSampler.interactive',
            hover = true,
            surfacePoint = true,
            surfaceNormal = true,
            handle = true,
            triangle = true,
            vertex = true,
        },
    }
end

function sysCall_msg(event)
    if not event.data or not event.data.key or event.data.key ~= 'pointSampler.interactive' then
        return
    end
    if event.id == 'pointSampler.hover' then
        local txt = {[11] = 'N/A', [13] = 'N/A', [15] = 'N/A', [31] = 'N/A', [33] = 'N/A'}
        if event.data.point then
            txt[11] = string.format('(%.3f, %.3f, %.3f)', unpack(event.data.point))
        end
        if event.data.normal then
            txt[13] = string.format('(%.3f, %.3f, %.3f)', unpack(event.data.normal))
        end
        if event.data.handle then
            txt[15] = string.format('%s', sim.getObjectAlias(event.data.handle, 9))
        end
        if event.data.triangleIndex then
            txt[31] = string.format('%d', event.data.triangleIndex)
        end
        if event.data.vertexIndex then
            txt[33] = string.format(
                          '%d (%.3f, %.3f, %.3f)', event.data.vertexIndex,
                          unpack(event.data.vertexCoords)
                      )
        end
        for id, tx in pairs(txt) do simUI.setLabelText(ui, id, tx) end
    end
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
    sim.broadcastMsg {id = 'pointSampler.disable', data = {key = 'pointSampler.interactive'}}
    hideDlg()
end

function sysCall_beforeInstanceSwitch()
    hideDlg()
end

function sysCall_afterInstanceSwitch()
    showDlg()
end

function showDlg()
    if not ui then
        local pos = 'position="-50,50" placement="relative"'
        if uiPos then
            pos = 'position="' .. uiPos[1] .. ',' .. uiPos[2] .. '" placement="absolute"'
        end
        local xml =
            '<ui title="Point sampler" style="min-width: 9em;" activate="false" closeable="true" resizable="true" on-close="close_callback" ' ..
                pos .. [[>
            <group layout="form" flat="true" content-margins="0,0,0,0">
                <label id="10" text="Position:"/>
                <label id="11" text="N/A"/>
                <label id="12" text="Normal:"/>
                <label id="13" text="N/A"/>
                <label id="14" text="Object:"/>
                <label id="15" text="N/A"/>
                <label id="30" text="Triangle:"/>
                <label id="31" text="N/A"/>
                <label id="32" text="Vertex:"/>
                <label id="33" text="N/A"/>
            </group>
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

function close_callback()
    leaveNow = true
end
