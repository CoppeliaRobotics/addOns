sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Kinematics\nDenavit-Hartenberg Extractor'}
end

function sysCall_init()
    simUI = require 'simUI'
    local sel = sim.getObjectSel()
    if #sel ~= 1 then
        simUI.msgBox(
            simUI.msgbox_type.critical, simUI.msgbox_buttons.ok, 'Denavit-Hartenberg extractor',
            'This tool requires exactly one object, representing a kinematic chain, to be selected.\n\ne.g. select the last joint or the end-effector of a kinematic chain.'
        )
    else
        local jointsAndEndEffector = {}
        local obj = sel[1]
        while obj ~= -1 do
            if sim.getObjectType(obj) == sim.sceneobject_joint or #jointsAndEndEffector == 0 then
                table.insert(jointsAndEndEffector, 1, obj)
            end
            obj = sim.getObjectParent(obj)
        end
        if #jointsAndEndEffector > 1 then
            print('Denavit-Hartenberg parameters (classic DH convention):')
            for i = 1, #jointsAndEndEffector - 1 do
                local dhParams = getDHParams(jointsAndEndEffector[i], jointsAndEndEffector[i + 1])
                local onn = 'joint'
                if i == #jointsAndEndEffector - 1 and sim.getObjectType(sel[1]) ~= sim.sceneobject_joint then
                    onn = 'object'
                end
                print(
                    string.format(
                        "    - between joint '%s' and " .. onn .. " '%s': d=%.4f [m], theta=%.1f [deg], r=%.4f [m], alpha=%.1f [deg]",
                        sim.getObjectAlias(jointsAndEndEffector[i], 6), sim.getObjectAlias(jointsAndEndEffector[i + 1], 6),
                        dhParams[1], dhParams[2] * 180 / math.pi, dhParams[3],
                        dhParams[4] * 180 / math.pi
                    )
                )
            end
            print(
                'Keep in mind that for a same kinematic chain, there can be an infinite number of D-H parameter definitions (depends on the selected direction of the X/Y axes around their joint axis.)'
            )
        else
            print('Did not find enough joints in the selected chain')
        end
    end
    return {cmd = 'cleanup'}
end

function getDHParams(obj1, obj2)
    local dhParams = {0, 0, 0, 0}
    local m1 = sim.getObjectMatrix(obj1)
    m1 = sim.multiplyMatrices(m1, sim.poseToMatrix(sim.getObjectChildPose(obj1))) -- don't forget the joint's intrinsic transformation (if joint)
    local m2 = sim.getObjectMatrix(obj2)
    sim.invertMatrix(m1)
    local m = sim.multiplyMatrices(m1, m2)
    -- m is obj2 relative to obj1 frame
    m = Matrix(3, 4, m)
    local p = m:slice(1, 4, 3, 4)
    local z = m:slice(1, 3, 3, 3)
    if math.abs(z[3]) > 0.9999 then
        -- z axes are parallel
        dhParams[2] = sim.getEulerAnglesFromMatrix(m:data())[3]
        dhParams[3] = math.sqrt(p[1] * p[1] + p[2] * p[2])
    else
        -- z axes are not parallel
        local z0 = Vector({0, 0, 1})
        local n = z:cross(z0):normalized()
        if n:dot(p) < 0 then n = n * -1.0 end
        -- n points towards the axis of the second joint

        local x0 = Vector({1, 0, 0})
        local angle = math.acos(x0:dot(n))
        if x0:cross(n)[3] < 0 then angle = -angle end
        dhParams[2] = angle

        local mt = sim.multiplyMatrices(sim.buildMatrix({0, 0, 0}, {0, 0, -angle}), m:data())
        mt = Matrix(3, 4, mt)
        local p2 = mt:slice(1, 4, 3, 4)
        local z2 = mt:slice(1, 3, 3, 3)
        local t = -p2[2] / z2[2]
        dhParams[1] = p2[3] + z2[3] * t
        dhParams[3] = math.abs(n:dot(p)) / math.sqrt(n[1] * n[1] + n[2] * n[2] + n[3] * n[3])
        local alpha = math.acos(z0:dot(z))
        if z0:cross(z):dot(n) < 0 then alpha = -alpha end
        dhParams[4] = alpha
    end
    return dhParams
end
