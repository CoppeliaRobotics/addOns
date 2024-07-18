sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Kinematics\nDenavit-Hartenberg Creator'}
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_init()
    simUI = require 'simUI'
    sim.addLog(
        sim.verbosity_scriptinfos,
        "This tool allows to create joints with the Denavit-Hartenberg notation (classic DH convention). Simply select an object in the scene on top of which you wish to create a joint, then adjust the D-H parameters in the dialog."
    )
    d = 0.05
    theta = math.pi / 2
    r = 0.1
    alpha = math.pi / 4
end

function showDlg()
    if not ui then
        local pos = 'position="-50,50" placement="relative"'
        if uiPos then
            pos = 'position="' .. uiPos[1] .. ',' .. uiPos[2] .. '" placement="absolute"'
        end
        local xml =
            '<ui title="DH joint creator" activate="false" on-close="close_callback" closeable="true" layout="form" ' ..
                pos .. [[>
                <label text="d [m]"/>
                <edit value="" id="1" on-editing-finished="d_callback"/>
                <label text="theta [deg]"/>
                <edit value="" id="2" on-editing-finished="theta_callback"/>
                <label text="r [m]"/>
                <edit value="" id="3" on-editing-finished="r_callback"/>
                <label text="alpha [deg]"/>
                <edit value="" id="4" on-editing-finished="alpha_callback"/>
                <button text="Create revolute joint" on-click="rev_callback"/>
                <button text="Create prismatic joint" on-click="prism_callback"/>
        </ui>]]
        ui = simUI.create(xml)
        simUI.setEditValue(ui, 1, string.format("%.4f", d))
        simUI.setEditValue(ui, 2, string.format("%.1f", theta * 180 / math.pi))
        simUI.setEditValue(ui, 3, string.format("%.4f", r))
        simUI.setEditValue(ui, 4, string.format("%.1f", alpha * 180 / math.pi))
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

function d_callback(ui, id, v)
    v = tonumber(v)
    if not v then v = 0 end
    d = v
    simUI.setEditValue(ui, 1, string.format("%.4f", d))
end

function theta_callback(ui, id, v)
    v = tonumber(v)
    if v then
        if v < -180 then v = -180 end
        if v > 180 then v = 180 end
    else
        v = 0
    end
    theta = v * math.pi / 180
    simUI.setEditValue(ui, 2, string.format("%.1f", theta * 180 / math.pi))
end

function r_callback(ui, id, v)
    v = tonumber(v)
    if v then
        if v < 0 then v = 0 end
    else
        v = 0
    end
    r = v
    simUI.setEditValue(ui, 3, string.format("%.4f", r))
end

function alpha_callback(ui, id, v)
    v = tonumber(v)
    if v then
        if v < -180 then v = -180 end
        if v > 180 then v = 180 end
    else
        v = 0
    end
    alpha = v * math.pi / 180
    simUI.setEditValue(ui, 4, string.format("%.1f", alpha * 180 / math.pi))
end

function rev_callback()
    buildJoint(true)
end

function prism_callback()
    buildJoint(false)
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

function sysCall_nonSimulation()
    if leaveNow then return {cmd = 'cleanup'} end
end

function sysCall_selChange(inData)
    if #inData.sel == 1 then
        showDlg()
    else
        hideDlg()
    end
end

function buildJoint(revoluteJoint)
    local sel = sim.getObjectSel()
    local objMatr = sim.getObjectMatrix(sel[1])
    if sim.getObjectType(sel[1]) == sim.sceneobject_joint then
        objMatr = sim.multiplyMatrices(objMatr, sim.poseToMatrix(sim.getObjectChildPose(sel[1]))) -- don't forget the joint's intrinsic transformation
    end
    local m1 = sim.buildMatrix({0, 0, d}, {0, 0, theta})
    local m2 = sim.buildMatrix({r, 0, 0}, {alpha, 0, 0})
    local m = sim.multiplyMatrices(m1, m2)
    objMatr = sim.multiplyMatrices(objMatr, m)
    local newJoint = -1
    if revoluteJoint then
        newJoint = sim.createJoint(sim.joint_revolute, sim.jointmode_force, 0)
    else
        newJoint = sim.createJoint(sim.joint_prismatic, sim.jointmode_force, 0)
    end
    sim.setObjectMatrix(newJoint, objMatr)
    sim.setObjectParent(newJoint, sel[1], true)
    sim.setObjectSel({newJoint})
    sim.announceSceneContentChange()
end
