function sysCall_info()
    autoStart=sim.getNamedBoolParam('visualizationStream.autoStart')
    if autoStart==nil then autoStart=false end
    return {autoStart=autoStart,menu='Connectivity\nVisualization stream'}
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
        if sim.getNamedBoolParam('visualizationStream.ws.retryOnStartFailure') then
            while true do
                local r,e=pcall(function() wsServer=simWS.start(wsPort) end)
                if r then break end
                print('Add-on "Visualization stream": WS failed to start ('..e..'). Retrying...')
                sim.wait(0.5,false)
            end
        else
            wsServer=simWS.start(wsPort)
        end
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
        --encode=cbor.encode
        encode=function(d) return sim.packTable(d,1) end -- faster
        decode=cbor.decode
        opcode=simWS.opcode.binary
    else
        error('unsupported codec: '..codec)
    end
    base64=require('base64')
    url=require('socket.url')

    localData={}
    remoteData={}
    uidToHandle={}
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

function sysCall_suspended()
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

function sim.getHandleByUID(uid)
    local handle=uidToHandle[uid]
    if handle==nil then return nil end
    local uid1=sim.getObjectInt32Param(handle,sim.objintparam_unique_id)
    if uid==uid1 then return handle else return nil end
end

function getFileContents(path)
    local f=assert(io.open(path,"rb"))
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
        for uid,data in pairs(remoteData) do
            local d=objectAdded(uid)
            if d then table.insert(resp,d) end
        end
        for uid,data in pairs(remoteData) do
            local d=objectChanged(uid)
            if d then table.insert(resp,d) end
        end
    end
    return resp
end

function onWSOpen(server,connection)
    if server==wsServer then
        local events={}
        wsClients[connection]=1
        -- send current objects:
        for uid,data in pairs(remoteData) do
            table.insert(events,objectAdded(uid))
        end
        for uid,data in pairs(remoteData) do
            table.insert(events,objectChanged(uid))
        end
        if #events>0 then
            sendEvent(events,connection)
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
    resource=url.unescape(resource)
    if resource=='/' or resource=='/'..baseName..'.html' then
        local c=getFileContents(appPath..pathSep..baseName..'.html')
        c=string.gsub(c,'const wsPort = 23020;','const wsPort = '..wsPort..';')
        c=string.gsub(c,'const codec = "cbor";','const codec = "'..codec..'";')
        return 200,c
    elseif resource=='/'..baseName..'.js' then
        return 200,getFileContents(appPath..pathSep..baseName..'.js')
    else
        sim.addLog(sim.verbosity_errors,'resource not found: '..resource)
    end
end

function getObjectData(handle)
    local data={}
    data.handle=handle
    data.uid=sim.getObjectInt32Param(handle,sim.objintparam_unique_id)
    data.name=sim.getObjectAlias(handle,0)
    data.parentHandle=sim.getObjectParent(handle)
    if data.parentHandle==-1 then
        data.parentUid=-1
    else
        data.parentUid=sim.getObjectInt32Param(data.parentHandle,sim.objintparam_unique_id)
    end
    data.pose=sim.getObjectPose(handle,data.parentHandle)
    --data.absolutePose=sim.getObjectPose(handle,-1)
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
        if st~=sim_joint_spherical_subtype then
            data.jointPosition=sim.getJointPosition(handle)
        end
        local jointMatrix=sim.getJointMatrix(handle)
        local p={jointMatrix[4],jointMatrix[8],jointMatrix[12]}
        local q=sim.getQuaternionFromMatrix(jointMatrix)
        data.jointPose={p[1],p[2],p[3],q[1],q[2],q[3],q[4]}
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
    local wl,wa=1,17.5
    local function poseChanged(a,b)
        if a==nil and b==nil then return false end
        local d=sim.getConfigDistance(a,b,{wl,wl,wl,wa,wa,wa,wa},{0,0,0,2,2,2,2})
        return d>0.0001
    end
    local function vector3Changed(a,b)
        if a==nil and b==nil then return false end
        local d=sim.getConfigDistance(a,b,{wl,wl,wl},{0,0,0})
        return d>0.0001
    end
    local function quaternionChanged(a,b)
        if a==nil and b==nil then return false end
        local d=sim.getConfigDistance(a,b,{wa,wa,wa,wa},{2,2,2,2})
        return d>0.0001
    end
    local function numberChanged(a,b)
        if a==nil and b==nil then return false end
        return math.abs(a-b)>0.0001
    end
    return false
        or poseChanged(a.pose,b.pose)
        or poseChanged(a.absolutePose,b.absolutePose)
        or quaternionChanged(a.jointQuaternion,b.jointQuaternion)
        or numberChanged(a.jointPosition,b.jointPosition)
        or a.parentUid~=b.parentUid
        or a.name~=b.name
end

function scan()
    localData={}
    for i,handle in ipairs(sim.getObjectsInTree(sim.handle_scene)) do
        local uid=sim.getObjectInt32Param(handle,sim.objintparam_unique_id)
        uidToHandle[uid]=handle
        localData[uid]=getObjectData(handle)
    end

    local events={}

    for uid,_ in pairs(remoteData) do
        if localData[uid]==nil or remoteData[uid].uid~=uid then
            table.insert(events,objectRemoved(uid))
            remoteData[uid]=nil
        end
    end

    for uid,data in pairs(localData) do
        if remoteData[uid]==nil then
            table.insert(events,objectAdded(uid))
        end
    end

    for uid,data in pairs(localData) do
        if remoteData[uid]==nil or objectDataChanged(localData[uid],remoteData[uid]) then
            table.insert(events,objectChanged(uid))
            remoteData[uid]=data
        end
    end

    if #events>0 then
        sendEvent(events)
    end
end

function objectAdded(uid)
    local data={
        event='objectAdded',
        uid=uid,
    }

    local handle=sim.getHandleByUID(uid)
    if handle==nil then return nil end

    data.handle=handle
    data.visible=sim.getObjectInt32Param(handle,sim.objintparam_visible)>0

    local objProp=sim.getObjectProperty(handle)
    data.selectModelBaseInstead=(objProp&sim.objectproperty_selectmodelbaseinstead)>0

    local modelProp=sim.getModelProperty(handle)
    data.modelBase=(modelProp&sim.modelproperty_not_model)==0

    local t=sim.getObjectType(handle)
    if t==sim.object_shape_type then
        data.type="shape"
        data.meshData={}
        for i=0,1000000000 do
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
        local st=sim.getJointType(handle)
        if st==sim_joint_revolute_subtype then
            data.subtype='revolute'
        elseif st==sim_joint_prismatic_subtype then
            data.subtype='prismatic'
        elseif st==sim_joint_spherical_subtype then
            data.subtype='spherical'
        end
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

function objectRemoved(uid)
    local data={
        event='objectRemoved',
        uid=uid,
    }
    return data
end

function objectChanged(uid)
    local data={
        event='objectChanged',
        uid=uid,
    }
    for field,value in pairs(localData[uid]) do
        data[field]=value
    end
    return data
end

function sendEvent(d,conn)
    if d==nil then return end

    if verbose()>0 then
        print('Visualization stream:',d)
    end
    d=encode(d)
    sendEventRaw(d,conn)
end

function sendEventRaw(d,conn)
    if d==nil then return end

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
