sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Exporters\nScript capture'}
end

function sysCall_init()
    simUI = require 'simUI'
    cbor = require 'org.conman.cbor'
    sim.test('sim.enableEvents', true)
    sim.test('sim.mergeEvents', true)
    sim.test('sim.cborEvents', true)
    captureObjPose = true
    captureObjParent = true
    captureObjAlias = false
    captureAddonStart = true
    captureAddonStop = false
    ui = simUI.create [[<ui
        title="Script capture"
        resizable="true"
        closeable="true"
        activate="false"
        size="400,500"
        position="-10,-90"
        placement="relative"
        on-close="editorClosed"
    >
        <group flat="true" content-margins="1,1,1,1" layout="hbox">
            <edit id="${edtComment}" />
            <button id="${btnInsertComment}" text="Insert comment" on-click="insertComment" />
        </group>
        <text-browser id="${txtCode}" text="" html="false" />
        <label id="${lblCapturing}" text="Capturing: N/A" word-wrap="true" on-link-activated="editSettings" />
    </ui>]]
    trackedHandles = {}
    log = {}
    updateCode()
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_nonSimulation()
    if leaveNow then return {cmd = 'cleanup'} end
end

function sysCall_cleanup()
end

function sysCall_event(es)
    es = cbor.decode(tostring(es))
    for _, e in ipairs(es) do
        if e.event == 'objectAdded' then
            onObjectAdded(e.handle)
        elseif e.event == 'objectChanged' then
            onObjectChanged(e.handle)
        elseif e.event == 'objectRemoved' then
            onObjectRemoved(e.handle)
        end
    end
end

function sysCall_msg(e)
    if e.id == 'systemCall' then
        local descr = sim.getObjectStringParam(e.data.script, sim.scriptstringparam_description)
        if captureAddonStart and e.data.callType == sim.syscb_init then
            insertComment('Started ' .. descr)
            updateCode()
        elseif captureAddonStop and e.data.callType == sim.syscb_cleanup then
            insertComment('Stopped ' .. descr)
            updateCode()
        end
    end
end

function insertComment(txt)
    if txt == ui then
        txt = simUI.getEditValue(ui, edtComment)
        simUI.setEditValue(ui, edtComment, '')
    end
    table.insert(log, {type = 'comment', handles = sim.getObjectSel(), code = '-- ' .. txt})
    updateCode()
end

function editorClosed()
    leaveNow = true
end

function onObjectAdded(handle)
    if not sim.isHandle(handle) then return end
    trackedHandles[handle] = {}
    local code = ''
    local objType = sim.getObjectType(handle)
    local id = objectId(handle)
    if objType == sim.sceneobject_shape then
        result, pureType, dims = sim.getShapeGeomInfo(handle)
        if result & 2 > 0 then
            code = string.format(
                       '%s=sim.createPrimitiveShape(%s,%s,%d)', id,
                       getConstantName(pureType, 'primitiveshape_'), table.tostring(dims, ','),
                       1 * sim.getObjectInt32Param(handle, sim.shapeintparam_culling) + 2 *
                           sim.getObjectInt32Param(handle, sim.shapeintparam_edge_visibility)
                   )
        else
            code = string.format('%s=sim.createShape(...)', id)
        end
    elseif objType == sim.sceneobject_joint then
        local jointType = sim.getJointType(handle)
        local jointMode = sim.getJointMode(handle)
        code = string.format(
                   '%s=sim.createJoint(%s,%s,0)', id,
                   getConstantName(jointType, 'joint_', '_subtype'),
                   getConstantName(jointMode, 'jointmode_')
               )
    elseif objType == sim.sceneobject_dummy then
        code = string.format('%s=sim.createDummy(0.01)', id)
    else
        code = id .. '=nil -- not implemented type (type=' ..
                   getConstantName(objType, 'object_', '_type') .. ', handle=' .. handle .. ')'
        trackedHandles[handle] = nil
    end
    table.insert(log, {type = 'create', handles = {handle}, code = code})
    onObjectChanged(handle)
end

function onObjectChanged(handle)
    if not sim.isHandle(handle) then return end
    if not trackedHandles[handle] then return end

    if captureObjParent then
        local parent = sim.getObjectParent(handle)
        if parent ~= sim.handle_world and parent ~= trackedHandles[handle].parent then
            trackedHandles[handle].parent = parent
            table.insert(
                log, {
                    type = 'set-parent',
                    handles = {handle, parent},
                    code = string.format(
                        'sim.setObjectParent(%s,%s)', objectId(handle), objectId(parent)
                    ),
                }
            )
        end
    end

    if captureObjAlias then
        local alias = sim.getObjectAlias(handle)
        if alias ~= trackedHandles[handle].alias then
            trackedHandles[handle].alias = alias
            table.insert(
                log, {
                    type = 'set-alias',
                    handles = {handle},
                    code = string.format('sim.setObjectAlias(%s,"%s")', objectId(handle), alias),
                }
            )
        end
    end

    if captureObjPose then
        local pose = sim.getObjectPose(handle, sim.handle_parent)
        if not table.eq(pose, trackedHandles[handle].pose) then
            trackedHandles[handle].pose = pose
            table.insert(
                log, {
                    type = 'set-pose',
                    handles = {handle},
                    code = string.format(
                        'sim.setObjectPose(%s,%s,sim.handle_parent)', objectId(handle),
                        table.tostring(pose, ',')
                    ),
                }
            )
        end
    end

    updateCode()
end

function onObjectRemoved(handle)
    if not trackedHandles[handle] then return end

    table.insert(
        log, {
            type = 'remove',
            handles = {handle},
            code = string.format('sim.removeObjects{%s}', objectId(handle)),
        }
    )
    trackedHandles[handle] = nil

    updateCode()
end

function updateCode()
    consolidateLog()
    code = '-- Script capture is running. Close this window to stop.\n\n'
    for i, entry in ipairs(log) do code = code .. entry.code .. '\n' end
    simUI.setText(ui, txtCode, code)

    local capturing = {}
    for _, k in ipairs {'ObjPose', 'ObjParent', 'ObjAlias', 'AddonStart', 'AddonStop'} do
        if _G['capture' .. k] then table.insert(capturing, k) end
    end
    capturing = 'Capturing: ' .. (#capturing > 0 and table.join(capturing) or 'none') ..
                    ' <a href="#">[Edit...]</a>'
    simUI.setLabelText(ui, lblCapturing, capturing)
end

function getConstantName(v, prefix, suffix)
    for k, v_ in pairs(sim) do
        if (prefix == nil or string.startswith(k, prefix)) and
            (suffix == nil or string.endswith(k, suffix)) and v == v_ then return 'sim.' .. k end
    end
end

function objectId(handle)
    return string.format('obj%d', handle)
end

function consolidateLog()
    local newLog = {}
    local i = 1
    while i <= #log do
        if log[i].type == 'remove' then
            local r = table.slice(log[i].handles)
            while i < #log and log[i + 1].type == 'remove' do
                i = i + 1
                for _, x in ipairs(log[i].handles) do table.insert(r, x) end
            end
            table.insert(
                newLog, {
                    type = 'remove',
                    handles = r,
                    code = string.format(
                        'sim.removeObjects%s', table.tostring(map(objectId, r), ',')
                    ),
                }
            )
        elseif log[i].type == 'comment' or
            (i == #log or log[i].type ~= log[i + 1].type or log[i].handle ~= log[i + 1].handle) then
            table.insert(newLog, log[i])
        end
        i = i + 1
    end
    log = newLog
end

function editSettings()
    ui2 =
        simUI.create [[<ui modal="true" title="Script capture settings" closeable="true" on-close="saveSettings">
        <label text="Script capture settings:" />
        <group flat="false" content-margins="5,5,5,5">
            <checkbox id="${chkObjPose}" text="Object pose" checked="${captureObjPose}" />
            <checkbox id="${chkObjParent}" text="Object parent" checked="${captureObjParent}" />
            <checkbox id="${chkObjAlias}" text="Object alias" checked="${captureObjAlias}" />
        </group>
        <group flat="false" content-margins="5,5,5,5">
            <checkbox id="${chkAddonStart}" text="Add-on start" checked="${captureAddonStart}" />
            <checkbox id="${chkAddonStop}" text="Add-on stop" checked="${captureAddonStop}" />
        </group>
    </ui>]]
end

function saveSettings()
    captureObjPose = simUI.getCheckboxValue(ui2, chkObjPose) > 0
    captureObjParent = simUI.getCheckboxValue(ui2, chkObjParent) > 0
    captureObjAlias = simUI.getCheckboxValue(ui2, chkObjAlias) > 0
    captureAddonStart = simUI.getCheckboxValue(ui2, chkAddonStart) > 0
    captureAddonStop = simUI.getCheckboxValue(ui2, chkAddonStop) > 0
    simUI.destroy(ui2)
    ui2 = nil
    updateCode()
end
