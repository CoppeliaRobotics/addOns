function sysCall_info()
    return {autoStart=false,menu='Connectivity\nVisualization stream'}
end

function sysCall_init()
    appPath=sim.getStringParam(sim.stringparam_application_path)
    pathSep=package.config:sub(1,1)
    baseName='simAddOnVisualization stream'

    zmqEnable=sim.getNamedBoolParam('visualizationStream.zmq.enable')
    wsEnable=sim.getNamedBoolParam('visualizationStream.ws.enable')
    if wsEnable==nil then wsEnable=true end

    if zmqEnable and simZMQ then
        simZMQ.__raiseErrors(true) -- so we don't need to check retval with every call
        zmqPUBPort=sim.getNamedInt32Param('visualizationStream.zmq.pub.port') or 23010
        zmqREPPort=sim.getNamedInt32Param('visualizationStream.zmq.rep.port') or (zmqPUBPort+1)
        print('Add-on "Visualization stream": ZMQ endpoint on ports '..tostring(zmqPUBPort)..', '..tostring(zmqREPPort)..'...')
        zmqContext=simZMQ.ctx_new()
        zmqPUBSocket=simZMQ.socket(zmqContext,simZMQ.PUB)
        simZMQ.bind(zmqPUBSocket,string.format('tcp://*:%d',zmqPUBPort))
        zmqREPSocket=simZMQ.socket(zmqContext,simZMQ.REP)
        simZMQ.bind(zmqPUBSocket,string.format('tcp://*:%d',zmqREPPort))
    elseif zmqEnable then
        sim.addLog(sim.verbosity_errors,'Visualization stream: the ZMQ plugin is not available')
        zmqEnable=false
    end

    if wsEnable and simWS then
        wsPort=sim.getNamedInt32Param('visualizationStream.ws.port') or 23020
        print('Add-on "Visualization stream": WS endpoint on port '..tostring(wsPort)..'...')
        wsServer=simWS.start(wsPort)
        simWS.setOpenHandler(wsServer,'onWSOpen')
        simWS.setCloseHandler(wsServer,'onWSClose')
        simWS.setMessageHandler(wsServer,'onWSMessage')
        simWS.setHTTPHandler(wsServer,'onWSHTTP')
        wsClients={}
    elseif wsEnable then
        sim.addLog(sim.verbosity_errors,'Visualization stream: the WS plugin is not available')
        wsEnable=false
    end

    if not zmqEnable and not wsEnable then
        sim.addLog(sim.verbosity_errors,'Visualization stream: aborting because no RPC backend available')
        return {cmd='cleanup'}
    end

    codec=sim.getNamedStringParam('visualizationStream.codec') or 'cbor'
    if codec=='json' then
        json=require('dkjson')
        encode=json.encode
        decode=json.decode
        opcode=simWS.opcode.text
    elseif codec=='cbor' then
        cbor=require('org.conman.cbor')
        encode=cbor.encode
        decode=cbor.decode
        opcode=simWS.opcode.binary
    else
        error('unsupported codec: '..codec)
    end
    base64=require('base64')

    localData={}
    remoteData={}
end

function sysCall_addOnScriptSuspend()
    return {cmd='cleanup'}
end

function sysCall_nonSimulation()
    processZMQRequests()
    scan()
end

function sysCall_sensing()
    processZMQRequests()
    scan()
end

function sysCall_cleanup()
    if zmqPUBSocket or zmqREPSocket then
        if zmqPUBSocket then simZMQ.close(zmqPUBSocket) end
        if zmqREPSocket then simZMQ.close(zmqREPSocket) end
        simZMQ.ctx_term(zmqContext)
    end

    if wsServer then
        simWS.stop(wsServer)
    end
end

function getFileContents(path)
    local f=assert(io.open(file, "rb"))
    local content=f:read("*all")
    f:close()
    return content
end

function processZMQRequests()
    if not zmqREPSocket then return end
    while true do
        local rc,revents=simZMQ.poll({zmqREPSocket},{simZMQ.POLLIN},0)
        if rc<=0 then break end
        local rc,req=simZMQ.recv(zmqREPSocket,0)
        local resp=onZMQRequest(decode(req))
        simZMQ.send(zmqREPSocket,encode(resp),0)
    end
end

function onZMQRequest(data)
    local resp={}
    if data.cmd=='getbacklog' then
        -- send current objects:
        for handle,data in pairs(remoteData) do
            table.insert(resp,objectAdded(handle))
            table.insert(resp,objectChanged(handle))
        end
    end
    return resp
end

function onWSOpen(server,connection)
    if server==wsServer then
        wsClients[connection]=1
        -- send current objects:
        for handle,data in pairs(remoteData) do
            sendEvent(objectAdded(handle),connection)
            sendEvent(objectChanged(handle),connection)
        end
    end
end

function onWSClose(server,connection)
    if server==wsServer then
        wsClients[connection]=nil
    end
end

function onWSMessage(server,connection,message)
end

function onWSHTTP(server,connection,resource,data)
    if resource=='/' or resource=='/index.html' then
        local c=getFileContents(appPath..pathSep..baseName..'.html')
        c=string.gsub(c,'const wsPort = 23020;','const wsPort = '..wsPort..';')
        c=string.gsub(c,'const codec = "cbor";','const codec = "'..codec..'";')
        return 200,c
    elseif resource=='/index.js' then
        return 200,getFileContents(appPath..pathSep..baseName..'.js')
    end
end

function getObjectData(handle)
    local data={}
    data.name=sim.getObjectAlias(handle,0)
    data.parent=sim.getObjectParent(handle)
    data.pose=sim.getObjectPose(handle,data.parent)
    data.absolutePose=sim.getObjectPose(handle,-1)
    data.visible=sim.getObjectInt32Param(handle,sim.objintparam_visible)>0
    -- fetch type-specific data:
    local t=sim.getObjectType(handle)
    if t==sim.object_shape_type then
        --local _,o=sim.getShapeColor(handle,'',sim.colorcomponent_transparency)
        ---- XXX: opacity of compounds is always 0.5
        ---- XXX: sim.getShapeViz doesn't return opacity... maybe it should?
        --data.opacity=o
    elseif t==sim.object_joint_type then
        local st=sim.getJointType(handle)
        if st==sim_joint_revolute_subtype then
            data.subtype='revolute'
        elseif st==sim_joint_prismatic_subtype then
            data.subtype='prismatic'
        elseif st==sim_joint_spherical_subtype then
            data.subtype='spherical'
        end
        if st~=sim_joint_spherical_subtype then
            data.jointPosition=sim.getJointPosition(handle)
        else
            data.jointMatrix=sim.getJointMatrix(handle)
        end
    elseif t==sim.object_graph_type then
    elseif t==sim.object_camera_type then
    elseif t==sim.object_light_type then
    elseif t==sim.object_dummy_type then
    elseif t==sim.object_proximitysensor_type then
    elseif t==sim.object_octree_type then
    elseif t==sim.object_pointcloud_type then
    elseif t==sim.object_visionsensor_type then
    elseif t==sim.object_forcesensor_type then
    end
    return data
end

function objectDataChanged(a,b)
    local function poseChanged(a,b)
        if a==nil and b==nil then return false end
        local wl,wa=1,17.5
        local d=sim.getConfigDistance(a,b,{wl,wl,wl,wa,wa,wa,wa},{0,0,0,2,2,2,2})
        return d>0.0001
    end
    return false
        or poseChanged(a.pose,b.pose)
        or poseChanged(a.absolutePose,b.absolutePose)
        or a.parent~=b.parent
        or a.name~=b.name
end

function scan()
    localData={}
    for i,handle in ipairs(sim.getObjectsInTree(sim.handle_scene)) do
        localData[handle]=getObjectData(handle)
    end

    for handle,_ in pairs(remoteData) do
        if localData[handle]==nil then
            sendEvent(objectRemoved(handle))
            remoteData[handle]=nil
        end
    end

    for handle,data in pairs(localData) do
        if remoteData[handle]==nil then
            sendEvent(objectAdded(handle))
        end
    end

    for handle,data in pairs(localData) do
        if remoteData[handle]==nil or objectDataChanged(localData[handle],remoteData[handle]) then
            sendEvent(objectChanged(handle))
            remoteData[handle]=data
        end
    end
end

function objectAdded(handle)
    local data={
        event='objectAdded',
        handle=handle,
    }
    local t=sim.getObjectType(handle)
    if t==sim.object_shape_type then
        data.type="shape"
        data.meshData={}
        for i=0,1000 do
            local meshData=sim.getShapeViz(handle,i)
            if meshData==nil then break end
            if meshData.texture then
                local im=meshData.texture.texture
                local res=meshData.texture.resolution
                local imPNG=sim.saveImage(im,res,1,'.png',-1)
                meshData.texture.texture=base64.encode(imPNG)
            end
            table.insert(data.meshData,meshData)
        end
    elseif t== sim.object_joint_type then
        data.type="joint"
    elseif t==sim.object_graph_type then
        data.type="graph"
    elseif t==sim.object_camera_type then
        data.type="camera"
        -- XXX: trick for giving an initial position for the default frontend camera
        data.absolutePose=sim.getObjectPose(handle,-1)
    elseif t==sim.object_light_type then
        data.type="light"
    elseif t==sim.object_dummy_type then
        data.type="dummy"
    elseif t==sim.object_proximitysensor_type then
        data.type="proximitysensor"
    elseif t==sim.object_octree_type then
        data.type="octree"
    elseif t==sim.object_pointcloud_type then
        data.type="pointcloud"
        data.points=sim.getPointCloudPoints(handle)
    elseif t==sim.object_visionsensor_type then
        data.type="visionsensor"
    elseif t==sim.object_forcesensor_type then
        data.type="forcesensor"
    end
    return data
end

function objectRemoved(handle)
    local data={
        event='objectRemoved',
        handle=handle,
    }
    return data
end

function objectChanged(handle)
    local data={
        event='objectChanged',
        handle=handle,
    }
    for field,value in pairs(localData[handle]) do
        data[field]=value
    end
    return data
end

function sendEvent(d,conn)
    if verbose()>0 then
        print('Visualization stream:',d)
    end
    --d=encode(d)
    d=sim.packTable(d,1)
    if zmqPUBSocket then
        simZMQ.send(zmqPUBSocket,d,0)
    end
    if wsServer then
        for connection,_ in pairs(wsClients) do
            if conn==nil or conn==connection then
                simWS.send(wsServer,connection,d,opcode)
            end
        end
    end
end

function verbose()
    return sim.getNamedInt32Param('visualizationStream.verbose') or 0
end
