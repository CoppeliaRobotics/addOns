sim = require 'sim'
extModel = require 'addOns.extModel'

function sysCall_info()
    return {
        menu = 'Developer tools\nScene file watch for ext. changes',
    }
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_init()
    scanInterval = 5.
end

function sysCall_afterLoad()
    sceneFile = sim.getStringProperty(sim.handle_scene, 'scenePath')
    sceneFileMTime = extModel.getFileModTime(sceneFile)
    sim.setIntProperty(sim.handle_scene, 'signal.sceneFileChangeWatch.modTime', sceneFileMTime)
end

function sysCall_beforeInstanceSwitch()
    if bannerId then
        simUI.bannerDestroy(bannerId)
        bannerId = nil
    end
end

function sysCall_afterInstanceSwitch()
    sceneFile = sim.getStringProperty(sim.handle_scene, 'scenePath')
    sceneFileMTime = sim.getIntProperty(sim.handle_scene, 'signal.sceneFileChangeWatch.modTime', {noError = true})
    lastScanTime = nil
end

function sysCall_nonSimulation()
    local t = sim.getSystemTime()
    if (lastScanTime or 0) + scanInterval < t then
        lastScanTime = t
        if sceneFile and sceneFileMTime and not bannerId then
            newSceneFileMTime = extModel.getFileModTime(sceneFile)
            if newSceneFileMTime ~= sceneFileMTime then
                import 'simUI'
                bannerId = simUI.bannerCreate('<b>Scene file changed externally:</b> file ' .. sceneFile .. ' has been changed externally.', {'reload', 'dismiss'}, {'Reload...', 'Dismiss'}, 'onChangedFileBannerButtonClick')

                function onChangedFileBannerButtonClick(bannerId, k)
                    if bannerId ~= _G.bannerId then return end

                    sceneFileMTime = newSceneFileMTime
                    sim.setIntProperty(sim.handle_scene, 'signal.sceneFileChangeWatch.modTime', sceneFileMTime)

                    if bannerId then
                        simUI.bannerDestroy(bannerId)
                        _G.bannerId = nil
                    end

                    if k == 'dismiss' then
                        -- nothing to do
                    elseif k == 'reload' then
                        sim.loadScene(sceneFile)
                    end
                end
            end
        end
    end
end

require('addOns.autoStart').setup{ns = 'sceneFileChangeWatch', readNamedParam = false}
