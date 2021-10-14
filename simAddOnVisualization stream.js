class VisualizationStreamClient {
    constructor(host = 'localhost', port = 23020, codec = 'cbor') {
        const client = this;
        this.host = host;
        this.port = port;
        this.codec = codec;
        this.websocket = new WebSocket(`ws://${this.host}:${this.port}`);
        this.listeners = {};
        if(codec == 'cbor') {
            this.websocket.binaryType = 'arraybuffer';
            this.websocket.onmessage = function(event) {
                client.dispatchEvents(CBOR.decode(event.data));
            }
        } else if(codec == 'json') {
            this.websocket.onmessage = function(event) {
                client.dispatchEvents(JSON.parse(event.data));
            }
        }
    }

    dispatchEvents(events) {
        if(events.length !== undefined)
            for(var event of events)
                this.dispatchEvent(event);
        else if(events.event !== undefined)
            this.dispatchEvent(events);
    }

    dispatchEvent(event) {
        var eventType = event.event;
        var listeners = this.listeners[eventType] || [];
        for(var listener of listeners)
            listener(event);
    }

    addEventListener(eventType, listener) {
        if(this.listeners[eventType] === undefined)
            this.listeners[eventType] = [];
        this.listeners[eventType].push(listener);
    }
}

class SceneWrapper {
    constructor() {
        this.scene = new THREE.Scene();

        const ambientLight = new THREE.AmbientLight(0xffffff, 0.7);
        this.scene.add(ambientLight);

        const light = new THREE.PointLight(0xffffff, 0.3);

        this.camera = new THREE.PerspectiveCamera(50, window.innerWidth / window.innerHeight, 0.1, 1000);
        this.camera.position.set(1.12, -1.9, 1.08);
        this.camera.rotation.set(1.08, 0.64, 0.31);
        this.camera.up.set(0, 0, 1);
        this.camera.add(light);
        this.scene.add(this.camera); // required because the camera has a child

        this.raycaster = new THREE.Raycaster();

        this.objectsByUid = {};

        const sceneWrapper = this;
        window.addEventListener('resize', () => {
            var w = window.innerWidth;
            var h = window.innerHeight;
            sceneWrapper.adjustCameraAspect(w, h);
        });
    }

    setCameraPose(pose) {
        this.camera.position.set(pose[0], pose[1], pose[2]);
        this.camera.quaternion.set(pose[3], pose[4], pose[5], pose[6]);
        if(this.orbitControls !== undefined)
            this.orbitControls.update();
    }

    fitCameraToSelection(selection, fitOffset = 1.2) {
        const camera = this.camera;
        const controls = this.orbitControls;

        const box = new THREE.Box3();
        for(const object of selection) box.expandByObject(object);
        const size = box.getSize(new THREE.Vector3());
        const center = box.getCenter(new THREE.Vector3());
        const maxSize = Math.max(size.x, size.y, size.z);
        if(maxSize < 0.01) {
            window.alert('Nothing to show!');
            return;
        }
        const fitHeightDistance = maxSize / (2 * Math.atan(Math.PI * camera.fov / 360));
        const fitWidthDistance = fitHeightDistance / camera.aspect;
        const distance = fitOffset * Math.max(fitHeightDistance, fitWidthDistance);
        const direction = controls.target.clone()
            .sub(camera.position)
            .normalize()
            .multiplyScalar(distance);

        //controls.maxDistance = distance * 10;
        controls.target.copy(center);

        //camera.near = distance / 100;
        //camera.far = distance * 100;
        camera.updateProjectionMatrix();

        camera.position.copy(controls.target).sub(direction);

        controls.update();
    }

    adjustCameraAspect(width, height) {
        this.camera.aspect = width / height;
        this.camera.updateProjectionMatrix();
    }

    commonUserData(data) {
        return {
            uid: data.uid,
            type: data.type,
            handle: data.handle,
            modelBase: data.modelBase,
            selectModelBaseInstead: data.selectModelBaseInstead
        };
    }

    createMesh(data) {
        const geometry = new THREE.BufferGeometry();
        // XXX: vertex attribute format handed by CoppeliaSim is not correct
        //      we expand all attributes and discard indices
        if(false) {
            geometry.setIndex(data.indices);
            geometry.setAttribute('position', new THREE.Float32BufferAttribute(data.vertices, 3));
            geometry.setAttribute('normal', new THREE.Float32BufferAttribute(data.normals, 3));
        } else {
            var ps = [];
            var ns = [];
            for(var i = 0; i < data.indices.length; i++) {
                var index = data.indices[i];
                var p = data.vertices.slice(3 * index, 3 * (index + 1));
                ps.push(p[0], p[1], p[2]);
                var n = data.normals.slice(3 * i, 3 * (i + 1));
                ns.push(n[0], n[1], n[2]);
            }
            geometry.setAttribute('position', new THREE.Float32BufferAttribute(ps, 3));
            geometry.setAttribute('normal', new THREE.Float32BufferAttribute(ns, 3));
        }
        var texture = null;
        if(data.texture !== undefined) {
            var image = new Image();
            image.src =  "data:image/png;base64," + data.texture.texture;
            texture = new THREE.Texture();
            texture.image = image;
            if((data.texture.options & 1) > 0)
                texture.wrapS = THREE.RepeatWrapping;
            if((data.texture.options & 2) > 0)
                texture.wrapT = THREE.RepeatWrapping;
            if((data.texture.options & 4) > 0)
                texture.magFilter = texture.minFilter = THREE.LinearFilter;
            else
                texture.magFilter = texture.minFilter = THREE.NearestFilter;
            image.onload = function() {
                texture.needsUpdate = true;
            };

            if(false) { // XXX: see above
                geometry.setAttribute('uv', new THREE.Float32BufferAttribute(data.texture.coordinates, 2));
            } else {
                var uvs = [];
                for(var i = 0; i < data.indices.length; i++) {
                    var index = data.indices[i];
                    var uv = data.texture.coordinates.slice(2 * i, 2 * (i + 1));
                    uvs.push(uv[0], uv[1]);
                }
                geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
            }
        }
        const c = data.colors;
        const material = new THREE.MeshPhongMaterial({
            side: THREE.DoubleSide,
            color:    new THREE.Color(c[0], c[1], c[2]),
            specular: new THREE.Color(c[3], c[4], c[5]),
            emissive: new THREE.Color(c[6], c[7], c[8]),
            map: texture
        });
        if(data.transparency !== undefined && data.transparency > 0.001) {
            material.transparent = true;
            material.opacity = 1 - data.transparency;
        }
        return new THREE.Mesh(geometry, material);
    }

    createShape(data) {
        var obj;
        if(data.meshData.length > 1) {
            obj = new THREE.Group();
            for(var i = 0; i < data.meshData.length; i++) {
                var submesh = this.createMesh(data.meshData[i]);
                submesh.userData.meshGroupUid = data.uid;
                obj.add(submesh);
            }
        } else if(data.meshData.length == 1) {
            obj = this.createMesh(data.meshData[0]);
        }
        obj.userData = this.commonUserData(data);
        // create an initially hidden object
        // will be shown as soon as some property is changed
        obj.visible = false;
        return obj;
    }

    createPointCloud(data) {
        const geometry = new THREE.BufferGeometry();
        geometry.setAttribute('position', new THREE.Float32BufferAttribute(data.points, 3));
        const material = new THREE.PointsMaterial({color: 0x0000FF, size: 0.005});
        var obj = new THREE.Points(geometry, material);
        obj.userData = this.commonUserData(data);
        // create an initially hidden object
        // will be shown as soon as some property is changed
        obj.visible = false;
        return obj
    }

    createDummy(data) {
        var obj = new THREE.Group();
        obj.userData = this.commonUserData(data);
        // create an initially hidden object
        // will be shown as soon as some property is changed
        obj.visible = false;
        return obj
    }

    createForceSensor(data) {
        var obj = new THREE.Group();
        obj.userData = this.commonUserData(data);
        // create an initially hidden object
        // will be shown as soon as some property is changed
        obj.visible = false;
        return obj
    }

    createJoint(data) {
        var jointFrame = new THREE.Group();
        var obj = new THREE.Group();
        obj.add(jointFrame);
        obj.userData = this.commonUserData(data);
        obj.userData.jointFrameId = jointFrame.id;
        // create an initially hidden object
        // will be shown as soon as some property is changed
        obj.visible = false;
        return obj
    }

    createCamera(data) {
        var fov = 50;   // FIXME: extract this from data
        var aspect = 1; // FIXME: extract this from data
        var near = 1;   // FIXME: extract this from data
        var far = 1000; // FIXME: extract this from data
        var obj = new THREE.PerspectiveCamera(fov, aspect, near, far);
        obj.userData = this.commonUserData(data);
        // create an initially hidden object
        // will be shown as soon as some property is changed
        obj.visible = false;
        return obj;
    }

    addObject(data) {
        var obj = null;
        if(data.type == "shape") {
            obj = this.createShape(data);
        } else if(data.type == "pointcloud") {
            obj = this.createPointCloud(data);
        } else if(data.type == "dummy") {
            obj = this.createDummy(data);
        } else if(data.type == "forcesensor") {
            obj = this.createForceSensor(data);
        } else if(data.type == "joint") {
            obj = this.createJoint(data);
        } else if(data.type == "camera") {
            if(data.name == "DefaultCamera" && data.absolutePose !== undefined) {
                this.setCameraPose(data.absolutePose);
                return;
            } else {
                obj = this.createCamera(data);
            }
        }
        if(obj === null)
            return;
        this.objectsByUid[data.uid] = obj;
        this.scene.add(obj);
    }

    getObjectByUid(uid) {
        return this.objectsByUid[uid];
    }

    setObjectName(obj, name) {
        obj.name = name;
    }

    setObjectParentUid(obj, parentUid) {
        obj.userData.parentUid = parentUid;
        var parentObj = this.getObjectByUid(parentUid);
        if(parentObj !== undefined) {
            if(parentObj.userData.jointFrameId !== undefined) {
                // when parenting to a joint, attach to joint child frame:
                var jointFrame = this.scene.getObjectById(parentObj.userData.jointFrameId);
                if(jointFrame !== undefined) {
                    jointFrame.attach(obj);
                } else {
                    console.log(`joint frame with id=${parentObj.userData.jointFrameId} not known`);
                }
            } else {
                parentObj.attach(obj);
            }
        } else /*if(parentUid === -1)*/ {
            if(parentUid !== -1)
                console.log(`parent with uid=${parentUid} is not known`);
            this.scene.attach(obj);
        }
    }

    setObjectPose(obj, pose) {
        obj.position.set(pose[0], pose[1], pose[2]);
        obj.quaternion.set(pose[3], pose[4], pose[5], pose[6]);
    }

    setJointPose(joint, pose) {
        if(joint.userData.jointFrameId !== undefined) {
            var jointFrame = this.scene.getObjectById(joint.userData.jointFrameId);
            jointFrame.position.set(pose[0], pose[1], pose[2]);
            jointFrame.quaternion.set(pose[3], pose[4], pose[5], pose[6]);
        }
    }

    setObjectVisible(obj, visible) {
        // layer 0 -> visible
        // layer 1 -> hidden
        if(obj.type === "Mesh") {
            obj.layers.set(visible ? 0 : 1);
        } else if(obj.type === "Group") {
            for(var child of obj.children)
                if(child.userData.meshGroupUid == obj.userData.uid)
                    child.layers.set(visible ? 0 : 1);
        }
        obj.userData.visible = visible;
    }

    setObjectHandle(obj, handle) {
        obj.userData.handle = handle;
    }

    setObjectData(obj, data) {
        obj.visible = true;
        if(data.name !== undefined)
            this.setObjectName(obj, data.name);
        if(data.parentUid !== undefined)
            this.setObjectParentUid(obj, data.parentUid);
        if(data.pose !== undefined)
            this.setObjectPose(obj, data.pose);
        if(data.jointPose !== undefined)
            this.setJointPose(obj, data.jointPose);
        if(data.visible !== undefined)
            this.setObjectVisible(obj, data.visible);
        if(data.handle !== undefined)
            this.setObjectHandle(obj, data.handle);
    }

    removeObject(obj) {
        this.scene.remove(obj);
        delete this.objectsByUid[obj.userData.uid];
    }

    isObjectPickable(obj) {
        if(obj.visible === false)
            return null;
        if(obj.userData.uid !== undefined)
            return obj;
        if(obj.userData.meshGroupUid !== undefined) {
            var meshGroup = this.getObjectByUid(obj.userData.meshGroupUid);
            if(meshGroup !== undefined) {
                if(meshGroup.userData.visible)
                    return meshGroup;
            } else {
                console.log(`found an intersect but meshGroup with uid ${obj.userData.meshGroupUid} is not known`);
            }
        }
        return null;
    }

    pickObject(camera, mousePos) {
        if(mousePos.x < -1 || mousePos.x > 1 || mousePos.y < -1 || mousePos.y > 1) {
            console.error('x and y must be in normalized device coordinates (-1...+1)');
            return null;
        }
        this.raycaster.setFromCamera(mousePos, camera);
        const intersects = this.raycaster.intersectObjects(this.scene.children, true);
        for(let i = 0; i < intersects.length; i++) {
            var x = intersects[i];
            var obj = this.isObjectPickable(x.object);
            if(obj !== null) {
                return {
                    distance: x.distance,
                    point: x.point,
                    face: x.face,
                    faceIndex: x.faceIndex,
                    object: obj,
                    originalObject: x.object
                };
            }
        }
        return null;
    }

    findModelBase(obj, followSMBI) {
        if(obj === null) return null;
        if(obj.userData.modelBase && !obj.userData.selectModelBaseInstead) {
            return obj;
        } else {
            return this.findModelBase(obj.parent);
        }
    }
}

class View {
    constructor(viewCanvas, sceneWrapper) {
        this.viewCanvas = viewCanvas
        this.sceneWrapper = sceneWrapper;
        this.renderer = new THREE.WebGLRenderer({canvas: this.viewCanvas, alpha: true});
        this.renderer.setPixelRatio(window.devicePixelRatio);
        this.renderer.setSize(window.innerWidth, window.innerHeight);

        this.bboxHelper = new THREE.BoxHelper(undefined, 0xffffff);
        this.bboxHelper.visible = false;
        this.sceneWrapper.scene.add(this.bboxHelper);

        this.selectPointMode = false;
        this.selectedPointConfirmed = false;
        this.selectedObject = null;

        const view = this;
        this.mouse = {
            dragStart: {x: 0, y: 0},
            dragDistance: function(event) {
                return Math.hypot(
                    view.mouse.pos.x - view.mouse.dragStart.x,
                    view.mouse.pos.y - view.mouse.dragStart.y
                );
            },
            pos: {x: 0, y: 0},
            normPos: {x: 0, y: 0},
            clickDragTolerance: 1
        };

        this.selectPointSphere = new THREE.Mesh(
            new THREE.SphereGeometry(0.01, 8, 4),
            new THREE.MeshBasicMaterial({color: 0xff0000})
        );
        this.selectPointSphere.visible = false;
        this.sceneWrapper.scene.add(this.selectPointSphere);

        this.selectPointArrow = new THREE.ArrowHelper(
            new THREE.Vector3(0, 0, 1),
            new THREE.Vector3(0, 0, 0),
            0.2,
            0xff0000
        );
        this.selectPointArrow.visible = false;
        this.sceneWrapper.scene.add(this.selectPointArrow);

        this.viewCanvas.addEventListener('mousedown', (e) => {this.onMouseDown(e);}, false);
        this.viewCanvas.addEventListener('mouseup', (e) => {this.onMouseUp(e);}, false);
        this.viewCanvas.addEventListener('mousemove', (e) => {this.onMouseMove(e);}, false);

        window.addEventListener('resize', () => {
            var w = window.innerWidth;
            var h = window.innerHeight;
            view.renderer.setSize(w, h);
        });

        this.listeners = {};
    }

    dispatchEvent(eventType, eventData) {
        var listeners = this.listeners[eventType] || [];
        for(var listener of listeners)
            listener(eventData);
    }

    addEventListener(eventType, listener) {
        if(this.listeners[eventType] === undefined)
            this.listeners[eventType] = [];
        this.listeners[eventType].push(listener);
    }

    setSelectPointMode(enable) {
        this.selectPointMode = enable;
        if(enable) {
            this.selectedPointConfirmed = false;
        } else {
            if(!this.selectedPointConfirmed) {
                this.selectPointSphere.visible = false;
                this.selectPointArrow.visible = false;
            }
        }
    }

    setSelectedObject(obj, followSMBI) {
        var previous = this.selectedObject;

        if(obj == null) {
            this.bboxHelper.visible = false;
            this.selectedObject = null;
        } else {
            if(followSMBI && obj.userData.selectModelBaseInstead) {
                var modelBase = sceneWrapper.findModelBase(obj);
                if(modelBase !== null)
                    obj = modelBase;
            }

            debug(`id = ${obj.id}`);
            this.selectedObject = obj;
            this.bboxHelper.setFromObject(this.selectedObject);
            this.bboxHelper.visible = true;
        }

        var current = this.selectedObject;
        this.dispatchEvent('selectedObjectChanged', {previous, current});
    }

    isPartOfSelection(obj) {
        if(this.selectedObject === null) return false;
        if(this.selectedObject === obj) return true;
        return obj.parent === null ? false : this.isPartOfSelection(obj.parent);
    }

    updateBB() {
        if(this.selectedObject === null) return;
        this.bboxHelper.setFromObject(this.selectedObject);
    }

    readMousePos(event) {
        this.mouse.pos.x = event.clientX;
        this.mouse.pos.y = event.clientY;
        this.mouse.normPos.x = (event.clientX / window.innerWidth) * 2 - 1;
        this.mouse.normPos.y = -(event.clientY / window.innerHeight) * 2 + 1;
    }

    onMouseDown(event) {
        this.readMousePos(event);
        this.mouse.dragStart.x = event.clientX;
        this.mouse.dragStart.y = event.clientY;
    }

    onMouseUp(event) {
        this.readMousePos(event);
        if(this.mouse.dragDistance() <= this.mouse.clickDragTolerance)
            this.onClick(event);
    }

    onClick(event) {
        if(this.selectPointMode) {
            this.selectedPointConfirmed = true;
            this.setSelectPointMode(false);
            this.dispatchEvent('selectedPoint', {
                direction: this.selectPointArrow.direction,
                position: this.selectPointSphere.position
            });
            return;
        }

        var pick = this.sceneWrapper.pickObject(this.sceneWrapper.camera, this.mouse.normPos);
        view.setSelectedObject(pick === null ? null : pick.object, true);
    }

    onMouseMove(event) {
        this.readMousePos(event);
    }

    showSurfacePoint(pick) {
        pick.originalObject.updateMatrixWorld();
        this.selectPointSphere.position.copy(pick.point);
        this.selectPointSphere.visible = true;
        // normal is local, convert it to global:
        var normalMatrix = new THREE.Matrix3().getNormalMatrix(pick.originalObject.matrixWorld);
        var normal = pick.face.normal.clone().applyMatrix3(normalMatrix).normalize();
        this.selectPointArrow.setDirection(normal);
        this.selectPointArrow.position.copy(pick.point);
        this.selectPointArrow.visible = true;
    }

    render(camera) {
        if(this.selectPointMode) {
            var pick = sceneWrapper.pickObject(this.sceneWrapper.camera, this.mouse.normPos);
            if(pick !== null)
                this.showSurfacePoint(pick);
        }

        this.renderer.render(this.sceneWrapper.scene, camera);
    }
}

class AxesView {
    constructor(axesCanvas, upVector) {
        this.axesScene = new THREE.Scene();
        this.axesHelper = new THREE.AxesHelper(20);
        this.axesScene.add(this.axesHelper);
        this.axesRenderer = new THREE.WebGLRenderer({canvas: axesCanvas, alpha: true});
        this.axesRenderer.setPixelRatio(window.devicePixelRatio);
        this.axesRenderer.setSize(80, 80);
        this.axesCamera = new THREE.PerspectiveCamera(40, axesCanvas.width / axesCanvas.height, 1, 1000);
        this.axesCamera.up = upVector;
        this.axesScene.add(this.axesCamera);
    }

    render(cameraPosition, targetPosition) {
        this.axesCamera.position.subVectors(cameraPosition, targetPosition);
        this.axesCamera.position.setLength(50);
        this.axesCamera.lookAt(this.axesScene.position);
        this.axesRenderer.render(this.axesScene, this.axesCamera);
    }
}

class OrbitControlsWrapper {
    constructor(sceneWrapper, renderer) {
        this.sceneWrapper = sceneWrapper;
        this.orbitControls = new THREE.OrbitControls(this.sceneWrapper.camera, renderer.domElement);
        this.sceneWrapper.orbitControls = this.orbitControls;
    }
}

class TransformControlsWrapper {
    constructor(sceneWrapper, renderer) {
        this.sceneWrapper = sceneWrapper;
        this.transformControls = new THREE.TransformControls(this.sceneWrapper.camera, renderer.domElement);
        this.transformControls.enabled = false;
        const self = this;
        this.transformControls.addEventListener('dragging-changed', function(event) {
            if(event.value) self.onStartTransform();
            else self.onEndTransform();
        });
        this.sceneWrapper.scene.add(this.transformControls);
        this.sceneWrapper.transformControls = this.transformControls;

        this.sendTransformRate = 0;
        this.sendTransformInterval = null;
    }

    enable() {
        this.transformControls.enabled = true;
    }

    disable() {
        this.transformControls.enabled = false;
    }

    setMode(mode) {
        this.transformControls.setMode(mode);
    }

    attach(obj) {
        if(obj === null || obj === undefined) return;

        var clone = obj.clone(true);
        if(clone.material !== undefined) {
            clone.material = obj.material.clone();
            clone.material.transparent = true;
            clone.material.opacity = 0.4;
        }

        delete clone.userData.uid;

        obj.parent.add(clone);

        obj.userData.clone = clone;
        clone.userData.original = obj;

        view.bboxHelper.setFromObject(clone);

        this.transformControls.attach(clone);
    }

    updateTargetPosition() {
        var clone = this.transformControls.object;
        var obj = clone.userData.original;
        /* (original object will change as the result of synchronization)
        obj.position.copy(clone.position);
        obj.quaternion.copy(clone.quaternion);
        */
        var p = clone.position.toArray();
        var q = clone.quaternion.toArray();
        sim.setObjectPose([obj.userData.handle, sim.handle_parent, p.concat(q)], function(e) {});
    }

    detach() {
        if(this.transformControls.object === undefined)
            return; // was not attached

        var clone = this.transformControls.object;
        var obj = clone.userData.original;

        //obj.userData.uid = clone.userData.uid;

        clone.removeFromParent();

        delete clone.userData.original;
        delete obj.userData.clone;

        view.bboxHelper.setFromObject(obj);

        this.transformControls.detach();
    }

    onStartTransform() {
        if(this.sendTransformRate > 0) {
            this.sendTransformInterval = setInterval(this.updateTargetPosition, Math.max(50, 1000 / this.sendTransformRate), true);
        }
    }

    onEndTransform() {
        clearInterval(this.sendTransformInterval);
        this.updateTargetPosition();
    }
}

class ObjTree {
    constructor(sceneWrapper, domElement) {
        this.sceneWrapper = sceneWrapper;
        this.domElement = domElement
        if(this.domElement.jquery !== undefined)
            this.domElement = this.domElement.get()[0];
        this.listeners = {};
        this.faiconForType = {
            scene: 'globe',
            camera: 'video',
            shape: 'cubes',
            light: 'lightbulb',
            joint: 'cogs',
            dummy: 'bullseye'
        }
        const objTree = this;
        this.updateRequested = false;
        setInterval(() => {
            if(objTree.updateRequested && $(objTree.domElement).is(":visible")) {
                objTree.update();
                objTree.updateRequested = false;
            }
        }, 200);
    }

    dispatchEvent(eventType, eventData) {
        var listeners = this.listeners[eventType] || [];
        for(var listener of listeners)
            listener(eventData);
    }

    addEventListener(eventType, listener) {
        if(this.listeners[eventType] === undefined)
            this.listeners[eventType] = [];
        this.listeners[eventType].push(listener);
    }

    update(obj = undefined) {
        const objTree = this;
        if(obj === undefined) {
            while(this.domElement.firstChild)
                this.domElement.removeChild(this.domElement.lastChild);
            this.domElement.appendChild(this.update(this.sceneWrapper.scene));
        } else {
            var li = document.createElement('li');
            var icon = document.createElement('i');
            icon.classList.add('tree-item-icon');
            icon.classList.add('fas');
            var type = obj.type == "Scene" ? 'scene' : obj.userData.type;
            var faicon = this.faiconForType[type];
            if(faicon === undefined) faicon = 'question';
            icon.classList.add(`fa-${faicon}`);
            var nameLabel = document.createElement('span');
            nameLabel.classList.add("tree-item");
            if(view.selectedObject === obj)
                nameLabel.classList.add("selected");
            nameLabel.appendChild(document.createTextNode(" " +
                (obj === this.sceneWrapper.scene ? "(scene)" : obj.name)
            ));
            nameLabel.addEventListener('click', function() {
                objTree.dispatchEvent('itemClicked', obj.userData.uid);
            });
            obj.userData.treeElement = nameLabel;
            var hasChildren = false;
            var childrenContainer = obj;
            if(obj.userData.type === "joint" && obj.userData.jointFrameId !== undefined) {
                childrenContainer = this.sceneWrapper.scene.getObjectById(obj.userData.jointFrameId);
                if(childrenContainer === undefined) {
                    console.log(`invalid joint frame id ${obj.userData.jointFrameId} for object id ${obj.id}`, obj);
                }
            }
            for(var c of childrenContainer.children) {
                if(c.userData.uid !== undefined) {
                    hasChildren = true;
                    break;
                }
            }
            if(hasChildren) {
                var ul = document.createElement('ul');
                ul.classList.add('active');
                for(var c of childrenContainer.children)
                    if(c.userData.uid !== undefined)
                        ul.appendChild(this.update(c));
                var toggler = document.createElement('span');
                toggler.classList.add('toggler');
                toggler.classList.add('toggler-open');
                toggler.addEventListener('click', function() {
                    ul.classList.toggle('active');
                    toggler.classList.toggle('toggler-open');
                    toggler.classList.toggle('toggler-close');
                });
                li.appendChild(toggler);
                li.appendChild(icon);
                li.appendChild(nameLabel);
                li.appendChild(ul);
            } else {
                li.appendChild(icon);
                li.appendChild(nameLabel);
            }
            return li;
        }
    }

    requestUpdate() {
        this.updateRequested = true;
    }
}

window.addEventListener('keydown', onKeyDown);

function debug(text) {
    if(text !== undefined && $('#debug').is(":visible"))
        console.log(text);
    if(typeof text === 'string' || text instanceof String) {
        $('#debug').text(text);
    } else {
        debug(JSON.stringify(text, undefined, 2));
    }
}

THREE.Object3D.DefaultUp = new THREE.Vector3(0,0,1);

//const scene = new THREE.Scene();

var sceneWrapper = new SceneWrapper();

const visualizationStreamClient = new VisualizationStreamClient('localhost', wsPort, codec);
visualizationStreamClient.addEventListener('objectAdded', onObjectAdded);
visualizationStreamClient.addEventListener('objectChanged', onObjectChanged);
visualizationStreamClient.addEventListener('objectRemoved', onObjectRemoved);

var view = new View(document.querySelector('#view'), sceneWrapper);
view.addEventListener('selectedObjectChanged', (event) => {
    if(event.previous !== null && event.previous.userData.treeElement !== undefined)
        $(event.previous.userData.treeElement).removeClass('selected');
    if(event.current !== null && event.current.userData.treeElement !== undefined)
        $(event.current.userData.treeElement).addClass('selected');

    if(transformControlsWrapper.transformControls.object !== undefined)
        transformControlsWrapper.detach();
    if(event.current !== null && transformControlsWrapper.transformControls.enabled)
        transformControlsWrapper.attach(event.current);
});
view.addEventListener('selectedPoint', (event) => {
    transformControlsWrapper.disable();
    if(view.selectedObject !== null) {
        transformControlsWrapper.detach();
    }
});

var axesView = new AxesView(document.querySelector('#axes'), sceneWrapper.camera.up);

var orbitControlsWrapper = new OrbitControlsWrapper(sceneWrapper, view.renderer);
orbitControlsWrapper.orbitControls.addEventListener('change', render);

var transformControlsWrapper = new TransformControlsWrapper(sceneWrapper, view.renderer);
transformControlsWrapper.transformControls.addEventListener('dragging-changed', function(event) {
    // disable orbit controls while dragging:
    orbitControlsWrapper.orbitControls.enabled = !event.value;
});
transformControlsWrapper.transformControls.addEventListener('change', function(event) {
    // make bbox follow
    view.bboxHelper.update();

    render();
});

var remoteApiClient = new RemoteAPIClient();
var sim = null;
remoteApiClient.websocket.addEventListener('open', function(event) {
    remoteApiClient.getObject('sim', function(o) { sim = o; });
});

var objTree = new ObjTree(sceneWrapper, $('#objtree'));
objTree.addEventListener('itemClicked', onTreeItemSelected);

function render() {
    view.render(sceneWrapper.camera);
    axesView.render(sceneWrapper.camera.position, orbitControlsWrapper.orbitControls.target);
}

function animate() {
	requestAnimationFrame(animate);
    orbitControlsWrapper.orbitControls.update();
    render();
}
animate();

function onTreeItemSelected(uid) {
    var obj = sceneWrapper.getObjectByUid(uid);
    view.setSelectedObject(obj, false);
}

function onObjectAdded(data) {
    //console.log("added", data);

    sceneWrapper.addObject(data);

    objTree.requestUpdate();
}

function containedIn(a, b) {
    if(a === b) return true;
    return a.parent === null ? false : containedIn(a.parent, b);
}

function onObjectChanged(data) {
    //console.log("changed", data);

    var obj = sceneWrapper.getObjectByUid(data.uid);
    if(obj === undefined) return;

    if(data.name != obj.name || data.parentUid != obj.userData.parentUid)
        objTree.requestUpdate();

    sceneWrapper.setObjectData(obj, data);
    if(view.isPartOfSelection(obj)) view.updateBB();

}

function onObjectRemoved(data) {
    //console.log("removed", data);

    var obj = sceneWrapper.getObjectByUid(data.uid);
    if(obj === undefined) return;
    if(obj === view.selectedObject)
        view.setSelectedObject(null, false);
    sceneWrapper.removeObject(obj);

    objTree.requestUpdate();
}

function onKeyDown(event) {
    switch(event.code) {
        case 'KeyH':
            $("#objtreeBG").toggle();
            break;
        case 'KeyD':
            $("#debug").toggle();
            break;
        case 'Escape':
            view.setSelectPointMode(false);
            transformControlsWrapper.disable();
            if(view.selectedObject !== null) {
                transformControlsWrapper.detach();
            }
            break;
        case 'KeyT':
            view.setSelectPointMode(false);
            transformControlsWrapper.enable();
            transformControlsWrapper.setMode('translate');
            if(view.selectedObject !== null) {
                transformControlsWrapper.attach(view.selectedObject);
            }
            break;
        case 'KeyR':
            view.setSelectPointMode(false);
            transformControlsWrapper.enable();
            transformControlsWrapper.setMode('rotate');
            if(view.selectedObject !== null) {
                transformControlsWrapper.attach(view.selectedObject);
            }
            break;
        case 'KeyP':
            transformControlsWrapper.detach();
            view.setSelectPointMode(true);
            break;
        case 'KeyZ':
            if(view.selectedObject !== null)
                sceneWrapper.fitCameraToSelection([view.selectedObject]);
            break;
    }
}
