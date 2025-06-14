-- this add-on function is a minimalistic scene content importer, meant as an example.
local sim = require 'sim'
local simUI

function sysCall_info()
    return {autoStart = false, menu = 'Importers\nMinimalistic importer...'}
end

function sysCall_init()
    simUI = require 'simUI'
    if simUI.msgbox_result.yes == sim.msgBox(
        simUI.msgbox_type.info, simUI.msgbox_buttons.yesno, "Minimalistic Importer",
        "This add-on is a minimalistic importer, meant as an example. Content in folder 'exportedContent' will be imported. Do you want to proceed?"
    ) then

        local directoryName = "exportedContent"
        local fileName = "sceneObjects.txt"

        idTag = 0
        refTag = 1
        parentTag = 2
        typeTag = 3
        fileTag = 4
        colorTag = 5
        positionTag = 6
        limitsTag = 7
        commentTag = 8
        visibilityTag = 9
        aliasTag = 10

        local appPath = sim.getStringParam(sim.stringparam_application_path)
        local importDir = appPath .. "/" .. directoryName
        local file = io.open(importDir .. "/" .. fileName, "r")

        local lines = {}
        while true do
            local line = file:read()
            if line == nil then break end
            lines[#lines + 1] = line
        end

        local l = 1
        local newHandlesAndIds = {}
        while l <= #lines do
            local value = getValue(lines[l], commentTag)
            if value == nil then
                value = getValue(lines[l], idTag)
                if value then
                    local objId = value
                    local objAlias = getValue(lines[l], aliasTag)
                    value = getValue(lines[l], refTag)
                    local objMatr = getNumberTable(value)
                    value = getValue(lines[l], parentTag)
                    local objParent = value
                    local visible = tonumber(getValue(lines[l], visibilityTag))
                    value = getValue(lines[l], typeTag)
                    local objType = value
                    if objType == 'object' then
                        objHandle = sim.createDummy(0.01)
                        sim.setObjectMatrix(objHandle, objMatr)
                    end
                    if objType == 'shape' then
                        l = l + 1
                        local filename = getValue(lines[l], fileTag)
                        local form = -1
                        if string.find(string.lower(filename), ".stl") then
                            form = 4
                        end
                        if string.find(string.lower(filename), ".dxf") then
                            form = 1
                        end
                        if string.find(string.lower(filename), ".obj") then
                            form = 0
                        end
                        local color = getNumberTable(getValue(lines[l], colorTag))
                        objHandle = sim.importShape(form, importDir .. "/" .. filename, 0, 0, 1)
                        local m = sim.getObjectMatrix(objHandle)
                        objMatr = sim.multiplyMatrices(objMatr, m)
                        sim.setObjectMatrix(objHandle, objMatr)
                        sim.setShapeColor(objHandle, nil, sim.colorcomponent_ambient_diffuse, color)
                        sim.setShapeColor(
                            objHandle, nil, sim.colorcomponent_diffuse,
                            {color[4], color[5], color[6]}
                        )
                    end
                    if objType == 'multishape' then
                        l = l + 1
                        local filename = getValue(lines[l], fileTag)
                        local subshapes = {}
                        while filename do
                            local form = -1
                            if string.find(string.lower(filename), ".stl") then
                                form = 4
                            end
                            if string.find(string.lower(filename), ".dxf") then
                                form = 1
                            end
                            if string.find(string.lower(filename), ".obj") then
                                form = 0
                            end
                            local color = getNumberTable(getValue(lines[l], colorTag))
                            objHandle = sim.importShape(form, importDir .. "/" .. filename, 0, 0, 1)
                            sim.setShapeColor(
                                objHandle, nil, sim.colorcomponent_ambient_diffuse, color
                            )
                            sim.setShapeColor(
                                objHandle, nil, sim.colorcomponent_specular,
                                {color[4], color[5], color[6]}
                            )
                            subshapes[#subshapes + 1] = objHandle
                            l = l + 1
                            if l <= #lines then
                                filename = getValue(lines[l], fileTag)
                            else
                                filename = nil
                            end
                        end
                        objHandle = sim.groupShapes(subshapes)
                        local m = sim.getObjectMatrix(objHandle)
                        objMatr = sim.multiplyMatrices(objMatr, m)
                        sim.setObjectMatrix(objHandle, objMatr)
                        l = l - 1
                    end
                    if objType == 'joint' then
                        l = l + 1
                        value = getValue(lines[l], typeTag)
                        local jointType = value

                        value = getValue(lines[l], positionTag)
                        local position = value
                        value = getValue(lines[l], limitsTag)
                        local limits = nil
                        if value ~= "none" and value ~= "cyclic" then
                            limits = getNumberTable(value)
                            limits[2] = limits[2] - limits[1]
                        end
                        if jointType == "prismatic" then
                            objHandle = sim.createJoint(
                                            sim.joint_prismatic, sim.jointmode_kinematic, 0
                                        )
                            sim.setJointInterval(objHandle, false, limits)
                            sim.setJointPosition(objHandle, tonumber(position))
                        end
                        if jointType == "revolute" then
                            objHandle = sim.createJoint(
                                            sim.joint_revolute, sim.jointmode_kinematic, 0
                                        )
                            if limits then
                                sim.setJointInterval(objHandle, false, limits)
                            else
                                sim.setJointInterval(objHandle, true, {math.pi, 2 * math.pi})
                            end
                            sim.setJointPosition(objHandle, tonumber(position))
                        end
                        if jointType == "spherical" then
                            objHandle = sim.createJoint(
                                            sim.joint_spherical, sim.jointmode_kinematic, 0
                                        )
                            sim.setJointInterval(objHandle, false, {math.pi, 2 * math.pi})
                            sim.setSphericalJointMatrix(objHandle, getNumberTable(position))
                        end
                        sim.setObjectMatrix(objHandle, objMatr)
                    end
                    if visible == 0 then
                        sim.setObjectInt32Param(objHandle, 10, 256)
                    end
                    sim.setObjectAlias(objHandle, objAlias)
                    newHandlesAndIds[#newHandlesAndIds + 1] = objHandle
                    newHandlesAndIds[#newHandlesAndIds + 1] = objId
                    newHandlesAndIds[#newHandlesAndIds + 1] = objParent
                end
            end
            l = l + 1
        end
        for i = 1, #newHandlesAndIds / 3, 1 do
            local objHandle = newHandlesAndIds[3 * (i - 1) + 1]
            local parentName = newHandlesAndIds[3 * (i - 1) + 3]
            for j = 1, #newHandlesAndIds / 3, 1 do
                local objHandle2 = newHandlesAndIds[3 * (j - 1) + 1]
                local objName2 = newHandlesAndIds[3 * (j - 1) + 2]
                if objName2 == parentName then
                    sim.setObjectParent(objHandle, objHandle2, true)
                    break
                end
            end
        end
        local nsel = {}
        for i = 1, #newHandlesAndIds / 3, 1 do
            nsel[i] = newHandlesAndIds[3 * (i - 1) + 1]
        end
        sim.setObjectSel(nsel)
        sim.announceSceneContentChange()
    end
    return {cmd = 'cleanup'}
end

getValue = function(str, tg)
    local s = nil
    if tg == idTag then s = "id" end
    if tg == aliasTag then s = "alias" end
    if tg == refTag then s = "ref" end
    if tg == parentTag then s = "parent" end
    if tg == typeTag then s = "type" end
    if tg == fileTag then s = "file" end
    if tg == colorTag then s = "color" end
    if tg == positionTag then s = "position" end
    if tg == limitsTag then s = "limits" end
    if tg == visibilityTag then s = "visibility" end
    if tg == commentTag then
        local r = string.match(str, "%/%/.*")
        return r
    end
    if s == nil then return nil end
    local r = string.match(str, s .. "[ ]*{(.-)}")
    if r == nil then return nil end
    r = string.reverse(string.match(r, " *(.*)"))
    return string.reverse(string.match(r, " *(.*)"))
end

getNumberTable = function(str)
    local retTable = {}
    for w in string.gmatch(str, "%S+") do table.insert(retTable, tonumber(w)) end
    return retTable
end

