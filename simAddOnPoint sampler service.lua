sim = require 'sim'

function sysCall_info()
    return {
        autoStart = not sim.getBoolParam(sim.boolparam_headless),
        menu = 'Misc\nPoint sampler service',
    }
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_init()
    enabled = 0
    flags = {}
    flagsStack = {}
end

function sysCall_nonSimulation()
    if enabled == 0 then return end

    if sim.getBoolParam(sim.boolparam_rayvalid) then
        currentCameraPos = sim.getObjectPosition(sim.adjustView(0, -1, 512))

        local orig = sim.getArrayParam(sim.arrayparam_rayorigin)
        local dir = sim.getArrayParam(sim.arrayparam_raydirection)

        local newClickCnt = sim.getInt32Param(sim.intparam_mouseclickcounterdown)
        local clicked = newClickCnt ~= clickCnt and clickCnt ~= nil
        clickCnt = newClickCnt

        local pt, n, o = rayCast(orig, dir)
        local ti, vi, tc, vc = nil, nil, nil, nil
        local event = {key = flagsStack[1], rayOrigin = orig, rayDirection = dir}
        local normalOrig = pt
        if pt then
            if currentFlags().handle then event.handle = o end
            if currentFlags().surfacePoint then
                event.point = pt
                if currentFlags().surfaceNormal then
                    event.normal = n
                    event.pointNormalMatrix = pointNormalToMatrix(pt, n)
                end
            end
            if (currentFlags().vertex or currentFlags().triangle) and sim.getObjectType(o) ==
                sim.object_shape_type then
                ti, vi, tc, vc = getTriangleAndVertexInfo(pt, n, o)
                if currentFlags().triangle and ti then
                    event.triangleIndex = ti
                    event.triangleCoords = tc
                end
                if currentFlags().vertex and vi then
                    event.vertexIndex = vi
                    event.vertexCoords = vc
                end
                if currentFlags().surfaceNormal and not event.normal then
                    local p1, p2, p3 = Vector(table.slice(tc, 1, 3)), Vector(table.slice(tc, 4, 6)), Vector(table.slice(tc, 7, 9))
                    local n = (p2 - p1):cross(p3 - p1):normalized():data()
                    event.normal = n
                    event.pointNormalMatrix = pointNormalToMatrix(vc, n)
                    normalOrig = vc
                end
            end
        end
        if currentFlags().dummy then event.dummy = rayCastDummies(orig, dir) end

        if currentFlags().snapToClosest then
            if event.dummy and event.vertexCoords then
                local dummyPos = sim.getObjectPosition(event.dummy)
                local dd = distanceToRay(dummyPos, orig, dir)
                local dv = distanceToRay(event.vertexCoords, orig, dir)
                if dd < dv then
                    event.triangleIndex = nil
                    event.vertexIndex = nil
                    event.triangleCoords = nil
                    event.vertexCoords = nil
                else
                    event.dummy = nil
                end
            end
            if event.dummy and not simUI.getKeyboardModifiers().shift then
                event.point = nil
                event.normal = nil
                event.pointNormalMatrix = nil
                event.triangleIndex = nil
                event.vertexIndex = nil
                event.triangleCoords = nil
                event.vertexCoords = nil
            end
            if event.vertexCoords and not simUI.getKeyboardModifiers().shift then
                local p = Vector(pt)
                local v = Vector(event.vertexCoords)
                local d = distanceToCamera((p + v) / 2)
                if (p - v):norm() / d < 0.015 then
                    event.point = nil
                    event.normal = nil
                    event.pointNormalMatrix = nil
                    event.dummy = nil
                end
            end
        end

        sim.addDrawingObjectItem(pts, nil)
        sim.addDrawingObjectItem(lines, nil)
        sim.addDrawingObjectItem(triangles, nil)
        sim.addDrawingObjectItem(trianglesv, nil)
        if event.dummy then
            local pt = sim.getObjectPosition(event.dummy)
            local d = distanceToCamera(pt)
            sim.addDrawingObjectItem(pts, {pt[1], pt[2], pt[3], 0.005 * d})
        end
        if event.point then
            local d = distanceToCamera(event.point)
            sim.addDrawingObjectItem(pts, {event.point[1], event.point[2], event.point[3], 0.005 * d})
        end
        if event.vertexCoords then
            local vertexPos = table.slice(event.vertexCoords)
            table.insert(vertexPos, 0.005 * distanceToCamera(event.vertexCoords))
            sim.addDrawingObjectItem(trianglesv, vertexPos)
        end
        if event.normal and normalOrig then
            local p = normalOrig
            local d = distanceToCamera(p)
            local off = Vector(event.normal) * 0.1 * d
            sim.addDrawingObjectItem(lines, {p[1], p[2], p[3], p[1] + off[1], p[2] + off[2], p[3] + off[3]})
        end
        if event.triangleCoords then
            local c = Matrix(3, 3, event.triangleCoords)
            for _, i in ipairs {1, 2, 3, 1} do
                sim.addDrawingObjectItem(triangles, c[i]:data())
            end
        end

        if currentFlags().arrowSource or currentFlags().segmentSource then
            local src = currentFlags().arrowSource or currentFlags().segmentSource
            local tgt = nil
            if event.dummy then
                tgt = sim.getObjectPosition(event.dummy)
            elseif event.vertexCoords then
                tgt = event.vertexCoords
            elseif event.point then
                tgt = event.point
            end
            sim.addDrawingObjectItem(arrow, nil)
            if tgt then
                local a = Vector(src)
                local b = Vector(tgt)
                if currentFlags().arrowSource then
                    local c = Vector(currentCameraPos)
                    local up = (b - a):cross(c - b):normalized()
                    local d = distanceToCamera((a + b) / 2)
                    local n = (a - b):normalized()
                    local k = d * 0.01
                    local p1 = b + k * (n + up)
                    local p2 = b + k * (n - up)
                    sim.addDrawingObjectItem(
                        arrow | sim.handleflag_addmultiple,
                        Matrix:horzcat(a, b, b, p1, b, p2):t():data()
                    )
                else
                    sim.addDrawingObjectItem(arrow, Matrix:horzcat(a, b):t():data())
                end
            end
        end

        if clicked or currentFlags().hover then
            sim.broadcastMsg {
                id = 'pointSampler.' .. (clicked and 'click' or 'hover'),
                data = event,
            }
        end
    end
end

function sysCall_msg(event)
    if event.id == 'pointSampler.enable' then
        if not event.data.key then
            sim.addLog(sim.verbosity_errors, 'missing required field data.key')
            return
        end
        if flags[event.data.key] then
            sim.addLog(sim.verbosity_warnings, 'already enabled')
            return
        end
        flags[event.data.key] = event.data
        table.insert(flagsStack, 1, event.data.key)
        enable()
    elseif event.id == 'pointSampler.disable' then
        if not event.data.key then
            sim.addLog(sim.verbosity_errors, 'missing required field data.key')
            return
        end
        flags[event.data.key] = nil
        table.remove(flagsStack, 1)
        disable()
    elseif event.id == 'pointSampler.setFlags' then
        if not event.data.key then
            sim.addLog(sim.verbosity_errors, 'missing required field data.key')
            return
        end
        if not flags[event.data.key] then
            sim.addLog(sim.verbosity_warnings, 'invalid key')
            return
        end
        for k, v in pairs(event.data) do flags[event.data.key][k] = v end
    end
end

function sysCall_beforeInstanceSwitch()
    if enabled == 0 then return end
    removeDrawingObjects()
end

function sysCall_afterInstanceSwitch()
    if enabled == 0 then return end
    createDrawingObjects()
end

function currentFlags()
    return flags[flagsStack[1]]
end

function createDrawingObjects()
    pts = sim.addDrawingObject(
              sim.drawing_spherepts | sim.drawing_itemsizes, 0.01, 0, -1, 1, {0, 1, 0}
          )
    lines = sim.addDrawingObject(sim.drawing_lines, 2, 0, -1, 1, {0, 1, 0})
    triangles = sim.addDrawingObject(sim.drawing_linestrip, 4, 0, -1, 4, {0, 1, 0})
    trianglesv = sim.addDrawingObject(
                     sim.drawing_spherepts | sim.drawing_itemsizes, 0.0025, 0, -1, 1, {0, 1, 0}
                 )
    arrow = sim.addDrawingObject(sim.drawing_lines | sim.drawing_overlay, 4, 0, -1, 3, {1, 0, 0})
end

function removeDrawingObjects()
    sim.removeDrawingObject(pts)
    sim.removeDrawingObject(lines)
    sim.removeDrawingObject(triangles)
    sim.removeDrawingObject(trianglesv)
    sim.removeDrawingObject(arrow)
end

function enable()
    if enabled == 0 then savedNavigationMode = sim.getNavigationMode() end
    enabled = enabled + 1
    if enabled == 1 then
        sim.setNavigationMode(sim.navigation_camerashift | sim.navigation_camerarotatemiddlebutton | sim.navigation_camerazoomwheel)
        createDrawingObjects()
        clickCnt = sim.getInt32Param(sim.intparam_mouseclickcounterdown)
        simUI = require 'simUI'
        simIGL = require 'simIGL'
    end
end

function disable()
    if enabled == 0 then return end
    enabled = enabled - 1
    if enabled == 0 then
        removeDrawingObjects()
        sim.setNavigationMode(savedNavigationMode)
    end
end

function distanceToCamera(pt)
    return (Vector(pt) - Vector(currentCameraPos)):norm()
end

function distanceToRay(pt, orig, dir)
    local p, o, d = Vector(pt), Vector(orig), Vector(dir)
    local t0 = d:dot(p - o) / d:norm()
    return (p - (o + t0 * d)):norm()
end

function rayCast(orig, dir)
    local sensor = sim.createProximitySensor(
        sim.proximitysensor_ray_subtype, 16, 1, {3, 3, 2, 2, 1, 1, 0, 0},
        {0, 2000, 0.01, 0.01, 0.01, 0.01, 0, 0, 0, 0, 0, 0, 0.01, 0, 0}
    )
    local m = pointNormalToMatrix(orig, dir)
    sim.setObjectMatrix(sensor, m)
    local coll = allVisibleObjectsColl({sim.object_shape_type, sim.object_octree_type})
    local r, d, pt, o, n = sim.checkProximitySensor(sensor, coll)
    sim.destroyCollection(coll)
    sim.removeObjects({sensor})
    if r > 0 then
        pt, n = pointNormalToGlobal(pt, n, m)
        return pt, n, o
    end
end

function rayCastDummies(orig, dir)
    local a = 3 * math.pi / 180
    local sensor = sim.createProximitySensor(
        sim.proximitysensor_cone_subtype, 16, 1, {3, 3, 2, 2, 1, 1, 0, 0},
        {0, 2000, 0.01, 0.01, 0.01, 0.01, 0, 0, 0, a, 0, 0, 0.01, 0, 0}
    )
    local m = pointNormalToMatrix(orig, dir)
    sim.setObjectMatrix(sensor, m)
    local coll = allVisibleObjectsColl({sim.object_dummy_type})
    local r, d, pt, o, n = sim.checkProximitySensor(sensor, coll)
    sim.destroyCollection(coll)
    sim.removeObjects({sensor})
    if r > 0 then
        return o
    end
end

function poseHash(p)
    return table.join(map(function(x)
        return math.floor(x * 1000000)
    end, p), '-')
end

function getTriangleAndVertexInfo(pt, n, o)
    pt = Matrix(1, 3, pt)
    if not simIGL then return end
    if not meshInfo then meshInfo = {} end
    local hash = poseHash(sim.getObjectPose(o))
    if not meshInfo[o] or meshInfo[o].hash ~= hash then
        meshInfo[o] = {}
        meshInfo[o].hash = hash
        meshInfo[o].mesh = simIGL.getMesh(o)
        meshInfo[o].f = Matrix(-1, 3, meshInfo[o].mesh.indices)
        meshInfo[o].v = Matrix(-1, 3, meshInfo[o].mesh.vertices)
        meshInfo[o].e, meshInfo[o].ue, meshInfo[o].emap, meshInfo[o].uec, meshInfo[o].uee =
            simIGL.uniqueEdgeMap(meshInfo[o].f:totable{})
    end
    local r, s = nil, nil
    local succ, errMsg = pcall(function()
        r, s = simIGL.closestFacet(
            meshInfo[o].mesh, pt:totable{}, meshInfo[o].emap,
            meshInfo[o].uec, meshInfo[o].uee
        )
    end)
    if not succ then
        sim.addLog(sim.verbosity_errors, 'IGL: ' .. errMsg)
        return
    end
    local triangleIndex, vertexIndex = r[1], nil
    local tri = meshInfo[o].f[1 + triangleIndex]
    local v = {meshInfo[o].v[1 + tri[1]], meshInfo[o].v[1 + tri[2]], meshInfo[o].v[1 + tri[3]]}
    local dist = {(v[1] - pt):t():norm(), (v[2] - pt):t():norm(), (v[3] - pt):t():norm()}
    if currentFlags().triangle and currentFlags().vertex then
        table.insert(dist, ((v[1] + v[2] + v[3]) / 3 - pt):t():norm())
    end
    local closest, d = nil, nil
    for i = 1, #dist do if not d or dist[i] < d then closest, d = i, dist[i] end end
    local triangleCoords = Matrix:vertcat(unpack(v)):data()
    local vertexCoords = nil
    if closest ~= 4 then
        vertexIndex = tri[closest]
        vertexCoords = meshInfo[o].v[1 + vertexIndex]:data()
    end
    return triangleIndex, vertexIndex, triangleCoords, vertexCoords
end

function allVisibleObjectsColl(types)
    local coll = sim.createCollection(1)
    for i, obj in ipairs(sim.getObjectsInTree(sim.handle_scene)) do
        if (types == nil or table.find(types, sim.getObjectType(obj))) and
            sim.getObjectInt32Param(obj, sim.objintparam_visible) ~= 0 then
            sim.addItemToCollection(coll, sim.handle_single, obj, 0)
        end
    end
    return coll
end

function pointNormalToMatrix(pt, n)
    local m = sim.buildIdentityMatrix()
    m[4] = pt[1]
    m[8] = pt[2]
    m[12] = pt[3]
    if n[1] < 0.99 then
        local z = Vector3(n)
        local x = Vector3({1, 0, 0})
        local y = z:cross(x):normalized()
        local x = y:cross(z)
        m[1] = x[1]; m[5] = x[2]; m[9] = x[3];
        m[2] = y[1]; m[6] = y[2]; m[10] = y[3];
        m[3] = z[1]; m[7] = z[2]; m[11] = z[3];
    else
        m[1] = 0; m[5] = 1; m[9] = 0;
        m[2] = 0; m[6] = 0; m[10] = 1;
        m[3] = 1; m[7] = 0; m[11] = 0;
    end
    return m
end

function pointNormalToGlobal(pt, n, m)
    pt = sim.multiplyVector(m, pt)
    n = sim.multiplyVector({m[1], m[2], m[3], 0, m[5], m[6], m[7], 0, m[9], m[10], m[11], 0}, n)
    return pt, n
end
