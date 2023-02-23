function sysCall_info()
    return {autoStart=false,menu='Geometry / Mesh\nMesh convex hull (IGL)'}
end

function sysCall_init()
    if sim.isPluginLoaded('IGL') then
        local sel=sim.getObjectSelection()
        local ok,err=pcall(simIGL.convexHullShape,sel)
        if not ok then
            simUI.msgBox(simUI.msgbox_type.critical,simUI.msgbox_buttons.ok,'Mesh convex hull add-on','simIGL error: '..err)
        else
            sim.announceSceneContentChange()
        end
    else
        simUI.msgBox(simUI.msgbox_type.critical,simUI.msgbox_buttons.ok,'Mesh convex hull add-on','This tool requires the IGL plugin.')
    end
    return {cmd='cleanup'}
end
