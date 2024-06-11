sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Importers\nPoint cloud importer...'}
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_init()
    simUI = require 'simUI'
    size = 1
    col = {255, 255, 255}
    if sim.getSimulationState() == sim.simulation_stopped then showDlg() end
end

function importClicked_callback()
    local fileNames = simUI.fileDialog(
                      simUI.filedialog_type.load_multiple, '*.xyz point cloud import', '', '', '*.xyz',
                      'xyz'
                  )
    if #fileNames > 0 then
        local pc = sim.createPointCloud(0.02, 20, 0, size)
        for _, fileName in ipairs(fileNames) do
            local pts = {}
            local cols = {}
            for line in io.lines(fileName) do
                local c = 0
                for coord in line:gmatch("([^\9 ]+)") do
                    if c >= 3 then
                        cols[#cols + 1] = coord
                    else
                        pts[#pts + 1] = coord
                    end
                    c = c + 1
                end
            end
            local opt = 0
            local ccol = {col[1], col[2], col[3]}
            if #pts == #cols then
                opt = 2
                ccol = cols
            end
            sim.insertPointsIntoPointCloud(pc, opt, pts, ccol)
        end
        sim.announceSceneContentChange()
    end
    leaveNow = true
end

function ptSizeChange_callback(ui, id, newVal)
    local v = tonumber(newVal)
    if v then
        v = math.floor(v)
        if v < 1 then v = 1 end
        if v > 5 then v = 5 end
        size = v
    end
    simUI.setEditValue(ui, 2, tostring(size), true)
end

function colorChange_callback(ui, id, newVal)
    local i = 1
    for token in (newVal .. ","):gmatch("([^,]*),") do
        local v = tonumber(token)
        if v == nil then v = 0 end
        if v > 1 then v = 1 end
        if v < 0 then v = 0 end
        col[i] = v * 255
        i = i + 1
    end
    simUI.setEditValue(
        ui, 3, string.format('%f,%f,%f', col[1] / 255, col[2] / 255, col[3] / 255), true
    )
end

function onCloseClicked()
    leaveNow = true
end

function showDlg()
    if not ui then
        xml = [[
        <ui title="Point Cloud Importer" modal="true" closeable="true" on-close="onCloseClicked" resizable="false" placement="center">
            <group layout="form" flat="true">
                <label text="Point size"/>
                <edit on-editing-finished="ptSizeChange_callback" id="2"/>
                <label text="RGB color"/>
                <edit on-editing-finished="colorChange_callback" id="3"/>
            </group>

            <button text="Import *.xyz file" checked="false"  on-click="importClicked_callback" id="1" />
            <label text="" style="* {margin-left: 380px;}"/>
        </ui>
        ]]
        ui = simUI.create(xml)
        simUI.setEditValue(ui, 2, tostring(size), true)
        simUI.setEditValue(
            ui, 3, string.format('%f,%f,%f', col[1] / 255, col[2] / 255, col[3] / 255), true
        )
    end
end

function hideDlg()
    if ui then
        simUI.destroy(ui)
        ui = nil
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
    hideDlg()
end
