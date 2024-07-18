sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Tools\nColor changer'}
end

function sysCall_init()
    simUI = require 'simUI'
    sim.addLog(
        sim.verbosity_scriptinfos,
        "This tool allows you to change the color of shapes, when those colors are named. Simply select individual shapes or models."
    )
    previousSelectedObjects = {}
    colorNameIndex = -1
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function getSameColor(allCols, col)
    for name, coll in pairs(allCols) do
        local same = true
        for i = 1, 3, 1 do
            for j = 1, 3, 1 do
                if coll[i][j] ~= col[i][j] then
                    same = false
                    break
                end
            end
            if not same then break end
        end
        if same and name:sub(1, 1) == '*' then return name end
    end
end

function sysCall_nonSimulation()
    if leaveNow then return {cmd = 'cleanup'} end
end

function sysCall_selChange(inData)
    selectedObjects = inData.sel
    selectedObjects = getAlsoModelObjectsAndOnlyVisibleShapes(selectedObjects)
    if not table.eq(selectedObjects, previousSelectedObjects) then
        hideDlg2()
        hideDlg1()
        previousSelectedObjects = table.slice(selectedObjects)
        if #selectedObjects > 0 then
            allCols = {}
            allShapesAndCols = {}
            for i = 1, #selectedObjects, 1 do
                local s = sim.getObjectStringParam(
                              selectedObjects[i], sim.shapestringparam_colorname
                          )
                local r, a_cols = sim.getShapeColor(
                                      selectedObjects[i], '@compound',
                                      sim.colorcomponent_ambient_diffuse
                                  )
                local r, b_cols = sim.getShapeColor(
                                      selectedObjects[i], '@compound', sim.colorcomponent_specular
                                  )
                local r, c_cols = sim.getShapeColor(
                                      selectedObjects[i], '@compound', sim.colorcomponent_emission
                                  )
                local scolnms = {}
                if s and s ~= '' then
                    local i = 0
                    for token in string.gmatch(s, "[^%s]+") do
                        local col = {
                            {a_cols[3 * i + 1], a_cols[3 * i + 2], a_cols[3 * i + 3]},
                            {b_cols[3 * i + 1], b_cols[3 * i + 2], b_cols[3 * i + 3]},
                            {c_cols[3 * i + 1], c_cols[3 * i + 2], c_cols[3 * i + 3]},
                        }
                        if token ~= '*' then
                            colName = token
                            allCols[colName] = col
                        else
                            colName = getSameColor(allCols, col)
                            if not colName then
                                local j = 1
                                while allCols['*' .. j] ~= nil do
                                    j = j + 1
                                end
                                colName = '*' .. j
                                allCols[colName] = col
                            end
                        end
                        scolnms[i + 1] = colName
                        i = i + 1
                    end
                end
                allShapesAndCols[#allShapesAndCols + 1] = scolnms
            end
            colorNameTable = {}
            for name, coll in pairs(allCols) do
                colorNameTable[#colorNameTable + 1] = name
            end
            table.sort(colorNameTable)
            --            print(allCols)
            --            print(allShapesAndCols)
            --            print(colorNameTable)
            --[[
            colorNames={}
            for i=1,#selectedObjects,1 do
                local s=sim.getObjectStringParam(selectedObjects[i],sim.shapestringparam_color_name)
                if s and s~='' then
                    for token in string.gmatch(s,"[^%s]+") do
                        colorNames[token]=token
                    end
                end
            end
            colorNameTable={}
            for k, v in pairs(colorNames) do
                colorNameTable[#colorNameTable+1]=k
            end
            --]]
            showDlg1(colorNameTable)
        end
    end
end

function sysCall_cleanup()
    hideDlg2()
    hideDlg1()
end

function sysCall_beforeSimulation()
    hideDlg2()
    hideDlg1()
    previousSelectedObjects = {}
end

function sysCall_beforeInstanceSwitch()
    hideDlg2()
    hideDlg1()
    previousSelectedObjects = {}
end

function showDlg1()
    if not ui and #colorNameTable > 0 then
        local pos = 'position="-50,50" placement="relative"'
        if uiPos then
            pos = 'position="' .. uiPos[1] .. ',' .. uiPos[2] .. '" placement="absolute"'
        end
        local xml =
            '<ui title="Color names" activate="false" closeable="true" on-close="close_callback" layout="vbox" ' ..
                pos .. '>'
        for i = 1, #colorNameTable, 1 do
            local cn = colorNameTable[i]
            cn = cn:gsub("*", "Unnamed color ")
            xml = xml .. '<button text="' .. cn .. '" on-click="colorClick_callback" id="' .. i ..
                      '" />'
        end
        xml = xml .. '</ui>'
        ui = simUI.create(xml)
    end
end

function hideDlg1()
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

function colorClick_callback(ui, id, v)
    hideDlg1()
    colorNameIndex = id
    showDlg2()
end

function showDlg2()
    local pos = 'position="-50,50" placement="relative"'
    if ui2Pos then
        pos = 'position="' .. ui2Pos[1] .. ',' .. ui2Pos[2] .. '" placement="absolute"'
    end
    local cn = colorNameTable[colorNameIndex]
    cn = cn:gsub("*", "Unnamed color ")
    local xml = '<ui title="Color [' .. cn ..
                    ']" activate="false" closeable="true" on-close="close2_callback" layout="vbox" ' ..
                    pos .. '>'
    xml = xml .. [[
        <label text="Ambient+diffuse" style="* {font-weight: bold;}"/>
            <group layout="form" flat="true">
                <label text="red"/>
                <hslider id="1" on-change="sliderMoved" minimum="0" maximum="100"/>
                <label text="green"/>
                <hslider id="2" on-change="sliderMoved" minimum="0" maximum="100"/>
                <label text="blue"/>
                <hslider id="3" on-change="sliderMoved" minimum="0" maximum="100"/>
            </group>

        <label text="Specular" style="* {font-weight: bold;}"/>
            <group layout="form" flat="true">
                <label text="red"/>
                <hslider id="4" on-change="sliderMoved" minimum="0" maximum="100"/>
                <label text="green"/>
                <hslider id="5" on-change="sliderMoved" minimum="0" maximum="100"/>
                <label text="blue"/>
                <hslider id="6" on-change="sliderMoved" minimum="0" maximum="100"/>
            </group>

        <label text="Emission" style="* {font-weight: bold;}"/>
            <group layout="form" flat="true">
                <label text="red"/>
                <hslider id="7" on-change="sliderMoved" minimum="0" maximum="100"/>
                <label text="green"/>
                <hslider id="8" on-change="sliderMoved" minimum="0" maximum="100"/>
                <label text="blue"/>
                <hslider id="9" on-change="sliderMoved" minimum="0" maximum="100"/>
            </group>
    </ui>]]
    ui2 = simUI.create(xml)
    ambientDiffuse = allCols[colorNameTable[colorNameIndex]][1]
    specular = allCols[colorNameTable[colorNameIndex]][2]
    emission = allCols[colorNameTable[colorNameIndex]][3]
    for i = 1, 3, 1 do
        simUI.setSliderValue(ui2, i + 0, ambientDiffuse[i] * 100)
        simUI.setSliderValue(ui2, i + 3, specular[i] * 100)
        simUI.setSliderValue(ui2, i + 6, emission[i] * 100)
    end
end

function hideDlg2()
    if ui2 then
        ui2Pos = {}
        ui2Pos[1], ui2Pos[2] = simUI.getPosition(ui2)
        simUI.destroy(ui2)
        ui2 = nil
        colorNameIndex = -1
        previousSelectedObjects = {}
    end
end

function sliderMoved(ui, id, v)
    local s = v / 100
    if id <= 3 then ambientDiffuse[id] = s end
    if id > 3 and id <= 6 then
        id = id - 3
        specular[id] = s
    end
    if id > 6 then
        id = id - 6
        emission[id] = s
    end
    local colName = colorNameTable[colorNameIndex]
    for i = 1, #selectedObjects, 1 do
        local r, a_cols = sim.getShapeColor(
                              selectedObjects[i], "@compound", sim.colorcomponent_ambient_diffuse
                          )
        local r, b_cols = sim.getShapeColor(
                              selectedObjects[i], "@compound", sim.colorcomponent_specular
                          )
        local r, c_cols = sim.getShapeColor(
                              selectedObjects[i], "@compound", sim.colorcomponent_emission
                          )
        for j = 1, #allShapesAndCols[i], 1 do
            if allShapesAndCols[i][j] == colName then
                for k = 1, 3, 1 do
                    a_cols[3 * (j - 1) + k] = ambientDiffuse[k]
                    b_cols[3 * (j - 1) + k] = specular[k]
                    c_cols[3 * (j - 1) + k] = emission[k]
                end
            end
        end
        sim.setShapeColor(
            selectedObjects[i], "@compound", sim.colorcomponent_ambient_diffuse, a_cols
        )
        sim.setShapeColor(selectedObjects[i], "@compound", sim.colorcomponent_specular, b_cols)
        sim.setShapeColor(selectedObjects[i], "@compound", sim.colorcomponent_emission, c_cols)
    end
    sim.announceSceneContentChange()
end

function close2_callback()
    hideDlg2()
end

function getAlsoModelObjectsAndOnlyVisibleShapes(sel)
    local tsel = {}
    for i = 1, #sel, 1 do
        local p = sim.getModelProperty(sel[i])
        if (p & sim.modelproperty_not_model) == 0 then
            -- We have a model
            local modObjs = sim.getObjectsInTree(sel[i], sim.sceneobject_shape)
            for k = 1, #modObjs, 1 do
                local addIt = true
                for j = 1, #tsel, 1 do
                    if tsel[j] == modObjs[k] then
                        addIt = false
                        break
                    end
                end
                if addIt then tsel[#tsel + 1] = modObjs[k] end
            end
        else
            -- We do not have a model
            if sim.getObjectType(sel[i]) == sim.sceneobject_shape then
                -- We have a shape
                local addIt = true
                for j = 1, #tsel, 1 do
                    if tsel[j] == sel[i] then
                        addIt = false
                        break
                    end
                end
                if addIt then tsel[#tsel + 1] = sel[i] end
            end
        end
    end
    sel = {}
    for i = 1, #tsel, 1 do
        if sim.getObjectInt32Param(tsel[i], sim.objintparam_visible) ~= 0 then
            sel[#sel + 1] = tsel[i]
        end
    end
    return sel
end

function getColorValuesForColorName(colName, selObjects)
    for i = 1, #selObjects, 1 do
        local r, v0 = sim.getShapeColor(selObjects[i], colName, sim.colorcomponent_ambient_diffuse)
        if r > 0 then
            local r, v1 = sim.getShapeColor(selObjects[i], colName, sim.colorcomponent_specular)
            local r, v2 = sim.getShapeColor(selObjects[i], colName, sim.colorcomponent_emission)
            return v0, v1, v2
        end
    end
    return nil, nil, nil
end

