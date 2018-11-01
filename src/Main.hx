package;

import openfl.Lib;
import openfl.display.Sprite;
import openfl.display.MovieClip;
import openfl.ui.Mouse;
import openfl.ui.MouseCursor;
import openfl.utils.Timer;
import openfl.events.TimerEvent;
import openfl.geom.Vector3D;
import openfl.geom.Point;
import openfl.events.TouchEvent;
import openfl.events.Event;
import openfl.events.EventDispatcher;
import openfl.events.MouseEvent;
import openfl.ui.Multitouch;
import openfl.ui.MultitouchInputMode;
import openfl.Vector;
import openfl.net.URLRequest;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFieldType;
import openfl.text.AntiAliasType;

import away3d.Away3D;
import away3d.loaders.Loader3D;
import away3d.loaders.misc.AssetLoaderToken;
import away3d.loaders.parsers.AWD2Parser;
import away3d.loaders.parsers.Parsers;
import away3d.loaders.Loader3D;
import away3d.loaders.misc.AssetLoaderContext;
import away3d.core.managers.*;
import away3d.containers.*;
import away3d.cameras.*;
import away3d.cameras.lenses.*;
import away3d.lights.*;
import away3d.lights.shadowmaps.*;
import away3d.materials.*;
import away3d.materials.lightpickers.*;
import away3d.materials.methods.*;
import away3d.controllers.*;
import away3d.primitives.*;
import away3d.library.Asset3DLibrary;
import away3d.events.*;
import away3d.entities.*;
import away3d.library.assets.*;
import away3d.textures.*;
import away3d.core.pick.*;


/**
 * ...
 * @author Circle Creative Limited
 */

class Main extends Sprite 
{
	var inited:Bool;
	var sS:Float;
	var check3DTimer:Timer = new Timer(100, 0);
	var libraryLoader:Loader3D;
	var token:AssetLoaderToken;
	var rotateSpeed:Float = -0.02;
	var plan2D:Bool = false;
	var camLookAtPos:Vector3D = new Vector3D(0, 0, 0);
	var stage3DManager:Stage3DManager;
	var stage3DProxy:Stage3DProxy;
	var stage3DReady:Bool = false;
	var view:View3D;
	var lensP:PerspectiveLens = new PerspectiveLens();
	var siteDims:Array<Float> = new Array();
	var lensO:OrthographicOffCenterLens = new OrthographicOffCenterLens(-5000, 5000, -5000, 5000);
	var cameraController:HoverController;
	var orbitContainer:ObjectContainer3D;
	var ContainerArray:Array<ObjectContainer3D> = new Array();
	var unitArray:Array<Mesh> = new Array();
	var materialOrig:ColorMaterial = new ColorMaterial();
	var materialCopy:ColorMaterial = new ColorMaterial();
	var shadowStrength:Float = 0.6;
	var unitCurrent:String = "";
	var touches:Map<Int, Point> = new Map();
	var touchesCache:Map<Int, Point> = new Map();
	var camDistanceCache:Float;
	var move:Bool = false;
	var click:Bool = false;
	var lastPanAngle:Float;
	var lastTiltAngle:Float;
	var lastMouseX:Float;
	var lastMouseY:Float;
	var uiFormat:TextFormat = new TextFormat();
	var bTrace:Sprite;
	
	function init():Void {
		if (inited) return;
		inited = true;
		
		uiFormat.size = 30;
		uiFormat.color = 0xFFFFFF;
		uiFormat.align = TextFormatAlign.CENTER;
		uiFormat.bold = false;
		
		stage3DManager = Stage3DManager.getInstance(stage);
		check3DTimer.addEventListener(TimerEvent.TIMER, onContextCreated);
		
		Parsers.enableAllBundled();
		libraryLoader = new Loader3D();
		token = libraryLoader.load(new URLRequest("assets/3d/test.awd"));
		token.addEventListener(LoaderEvent.RESOURCE_COMPLETE, onResourceComplete);
		token.addEventListener(LoaderEvent.LOAD_ERROR, onLoadError);
	}
	
	function onResourceComplete(e:LoaderEvent):Void{
		
		trace("onResourceComplete");
		
		libraryLoader.removeEventListener(LoaderEvent.RESOURCE_COMPLETE, onResourceComplete);
		libraryLoader.removeEventListener(LoaderEvent.LOAD_ERROR, onLoadError);
		
		var tempContainer:ObjectContainer3D = new ObjectContainer3D();
		
		tempContainer.addChild(libraryLoader);
		
		
		
		for (i in 0...tempContainer.getChildAt(0).numChildren){
			trace("tempContainer.getChildAt(0).getChildAt(i).name: " + tempContainer.getChildAt(0).getChildAt(i).name);
			
			if (tempContainer.getChildAt(0).getChildAt(i).name == "site"){
				ContainerArray.push(tempContainer.getChildAt(0).getChildAt(i));
			}
		}
		trace("tempContainer.getChildAt(0).numChildren: " + tempContainer.getChildAt(0).numChildren);
		
		init3DProxy();
	}
	
	function onLoadError(e:LoaderEvent):Void{
		trace("Error loading: " + e.url);
	}
	
	function init3DProxy():Void{
		
		trace("init3DProxy");
		
		stage3DReady = false;

		var viewWidth = 1920;
		var viewHeight = 1080;
		
		stage3DProxy = stage3DManager.getFreeStage3DProxy();
		stage3DProxy.antiAlias = 16;
		stage3DProxy.color = 0xFFFFFF;
		stage3DProxy.bufferClear = false;
		stage3DProxy.width = viewWidth;
		stage3DProxy.height = viewHeight;
		stage3DProxy.x = 0;
		stage3DProxy.y = 0;
		
		check3DTimer.start();
	}
	
	function onContextCreated(e:TimerEvent){
		
		trace("onContextCreated");
		
		if (stage3DProxy.context3D != null){
			check3DTimer.reset();
			
			initEngine();
			add3DScene();
			plan2d3d();
			addUI();
		}
	}

	function initEngine():Void {

		trace("initEngine");
		
		var camera:Camera3D = new Camera3D();
		camera.x = 0;
		camera.y = 0;
		camera.z = 0;
		
		if (plan2D == true){
			camera.lens = lensO;
		}else{
			camera.lens = lensP;
		}
		
		var scene:Scene3D = new Scene3D();
		
		var viewWidth = 1920;
		var viewHeight = 1080;

		view = new View3D();
		view.stage3DProxy = stage3DProxy;
        view.shareContext = true;
		view.scene = scene;
		view.camera = camera;
		view.width = viewWidth;
		view.height = viewHeight;
		addChild(view);

		cameraController = new HoverController();
		cameraController.targetObject = view.camera;
		cameraController.lookAtPosition = camLookAtPos;
		cameraController.distance = 10000;
		cameraController.yFactor = 1;
		
		orbitContainer = new ObjectContainer3D();
		view.scene.addChild(orbitContainer);

		stage3DReady = true;
	}
	
	function add3DScene():Void{

		trace("add3DScene");
		
		var tempLightPicker:StaticLightPicker = new StaticLightPicker([]);
		siteDims = [];
		
		for (i in 0...ContainerArray[0].numChildren-1){
			
			var assetTypeTemp:String = ContainerArray[0].getChildAt(i).assetType;
			
			if (assetTypeTemp == "light"){
				var lightTemp:LightBase = cast(ContainerArray[0].getChildAt(i), LightBase);
				tempLightPicker.lights = [lightTemp];
				view.scene.addChild(lightTemp);
			}
		}
		
		var lightsTemp:Vector<DirectionalLight> = tempLightPicker.castingDirectionalLights;
		var lightTemp:DirectionalLight = lightsTemp[0];
		
		for (i in 0...ContainerArray[0].numChildren - 1){
			var assetTypeTemp:String = ContainerArray[0].getChildAt(i).assetType;
			
			if (assetTypeTemp == "mesh"){
				
				var softShadowMap:SoftShadowMapMethod = new SoftShadowMapMethod(lightTemp);
				softShadowMap.alpha = shadowStrength;
				softShadowMap.epsilon = 0.015;
				softShadowMap.numSamples = 32;
				softShadowMap.range = 5;

				var meshTemp:Mesh = cast(ContainerArray[0].getChildAt(i).clone(), Mesh);
				meshTemp.material.lightPicker = tempLightPicker;
				meshTemp.castsShadows = true;
				meshTemp.mouseEnabled = true;
				meshTemp.pivotPoint = camLookAtPos;

				var meshName:String = meshTemp.name.toLowerCase();
					
				if (meshName == "ground"){
					siteDims.push(meshTemp.minX);
					siteDims.push(meshTemp.maxX + 4000);
					siteDims.push(meshTemp.minZ);
					siteDims.push(meshTemp.maxZ);
					var tempTexture:TextureMaterial = cast(meshTemp.material, TextureMaterial);
					tempTexture.shadowMethod = softShadowMap;
				}
				
				var unitTemp:String = meshTemp.name.substr(0, 4);
				
				if (unitTemp == "unit"){
					meshTemp.addEventListener(MouseEvent3D.MOUSE_DOWN, unitDown);
					meshTemp.addEventListener(MouseEvent3D.MOUSE_OVER, unitOver);
					meshTemp.addEventListener(MouseEvent3D.MOUSE_OUT, unitOut);
					unitArray.push(meshTemp);
				}
				
				orbitContainer.addChild(meshTemp);
			}
		}
		
		orbitContainer.pivotPoint = camLookAtPos;
		cameraController.lookAtPosition = camLookAtPos;
		
		var matTemp:ColorMaterial = cast(unitArray[0].material, ColorMaterial);
		
		materialOrig = matTemp;
		
		materialCopy.alpha = 0.4;
		materialCopy.ambient = matTemp.ambient;
		materialCopy.ambientColor = matTemp.ambientColor;
		materialCopy.color = matTemp.color;
		materialCopy.specular = matTemp.specular;
		materialCopy.specularColor = matTemp.specularColor;
		materialCopy.lightPicker = tempLightPicker;
		
		commonListeners();
	}
	
	function plan2d3d():Void{
		
		trace("plan2d3d");
		
		if (plan2D == false){
			
			plan2D = true;
			
			lensO = new OrthographicOffCenterLens(siteDims[0], siteDims[1], siteDims[2], siteDims[3]);
			lensO.far = 30000;
			lensO.near = 2000;
			
			for (i in 0...ContainerArray[0].numChildren - 1){
				
				var assetTypeTemp:String = ContainerArray[0].getChildAt(i).assetType;
				
				if (assetTypeTemp == "mesh"){
					var meshTemp:Mesh = cast(ContainerArray[0].getChildAt(i), Mesh);
					var meshName:String = meshTemp.name.toLowerCase();

					if (meshName == "ground"){
						var tempTexture:TextureMaterial = cast(meshTemp.material, TextureMaterial);
						if (tempTexture.shadowMethod != null){
							tempTexture.shadowMethod.alpha = 0;
						}
					}
					
					var unitTemp:String = meshTemp.name.substr(0, 4);
				
					if (unitTemp == "unit"){
						var tempTexture:ColorMaterial = cast(meshTemp.material, ColorMaterial);
					}
				}
			}
			
			cameraController.maxTiltAngle = 90;
			cameraController.tiltAngle = 90;
			cameraController.panAngle = 0;
			view.camera.lens = lensO;
			
		}else{

			plan2D = false;
			
			lensP.far = 30000;
			lensP.near = 2000;
			lensP.focalLength = 2;
			
			cameraController.minTiltAngle = 12;
			cameraController.maxTiltAngle = 90;
			cameraController.panAngle = 0;
			cameraController.tiltAngle = 30;
			
			for (i in 0...ContainerArray[0].numChildren - 1){
				
				var assetTypeTemp:String = ContainerArray[0].getChildAt(i).assetType;
				
				if (assetTypeTemp == "mesh"){
					var meshTemp:Mesh = cast(ContainerArray[0].getChildAt(i), Mesh);
					var meshName:String = meshTemp.name.toLowerCase();

					if (meshName == "ground"){
						var tempTexture:TextureMaterial = cast(meshTemp.material, TextureMaterial);
						if (tempTexture.shadowMethod != null){
							tempTexture.shadowMethod.alpha = shadowStrength;
						}
					}
					
					var unitTemp:String = meshTemp.name.substr(0, 4);
				
					if (unitTemp == "unit"){
						var tempTexture:ColorMaterial = cast(meshTemp.material, ColorMaterial);
					}
				}
			}
		
			view.camera.lens = lensP;
		}
	}

	function addUI():Void{
		
		var tempName:Array<String> = ["Ortho", "Perspective"];
		
		for (i in 0...tempName.length){
			var btn:Sprite = new Sprite();
			btn.graphics.beginFill(0x000, 1);
			btn.graphics.drawRect(0, 0, 200, 60);
			btn.graphics.endFill();
			btn.addEventListener(MouseEvent.CLICK, menuClick);
			btn.addEventListener(MouseEvent.MOUSE_OVER, bOver);
			btn.addEventListener(MouseEvent.MOUSE_OUT, bOut);
			btn.x = 1400 + (250 * i);
			btn.y = 60;
			btn.name = tempName[i];
			btn.buttonMode = true;
			btn.mouseEnabled = true;
			btn.mouseChildren  = false;
			
			var tField:TextField = new TextField();
			tField.htmlText = tempName[i];
			tField.defaultTextFormat = uiFormat;
			tField.autoSize = TextFieldAutoSize.CENTER;
			tField.type = TextFieldType.DYNAMIC;
			tField.width = 200;
			tField.height = 60;
			tField.mouseEnabled = false;
			tField.antiAliasType = ADVANCED;
			tField.cacheAsBitmap = true;
			tField.selectable = false;
			tField.embedFonts = true;
			tField.x = 0;
			tField.y = 0 + 6;
			
			btn.addChild(tField);
			addChild(btn);
		}
		
		bTrace = new Sprite();
		bTrace.graphics.beginFill(0x719ec2, 0.8);
		bTrace.graphics.drawRect(0, 0, 600, 60);
		bTrace.graphics.endFill();
		bTrace.x = 100;
		bTrace.y = 60;
		
		var tField:TextField = new TextField();
		tField.htmlText = "";
		tField.defaultTextFormat = uiFormat;
		tField.autoSize = TextFieldAutoSize.CENTER;
		tField.type = TextFieldType.DYNAMIC;
		tField.width = 600;
		tField.height = 60;
		tField.mouseEnabled = false;
		tField.antiAliasType = ADVANCED;
		tField.cacheAsBitmap = true;
		tField.selectable = false;
		tField.embedFonts = true;
		tField.x = 0;
		tField.y = 0 + 6;
		tField.name = "traceOut";
		
		bTrace.addChild(tField);
		addChild(bTrace);

	}
	
	function menuClick(e:MouseEvent):Void{
		
		trace("menuClick");
		
		var tempButton:Sprite = cast(e.target, Sprite);

		switch(tempButton.name){
			case "Ortho":
				plan2D = false;
				plan2d3d();
				
			case "Perspective":
				plan2D = true;
				plan2d3d();
		}
	}
	
	function bOver(e:MouseEvent):Void{
		Mouse.cursor = MouseCursor.BUTTON;
	}
	
	function bOut(e:MouseEvent):Void{
		Mouse.cursor = MouseCursor.ARROW;
	}
		
	function mouseDown3d(e:MouseEvent):Void {
		lastPanAngle = cameraController.panAngle;
		lastTiltAngle = cameraController.tiltAngle;
		lastMouseX = stage.mouseX;
		lastMouseY = stage.mouseY;
		move = true;
		stage.addEventListener(Event.MOUSE_LEAVE, onStageMouseLeave);
	}

	function mouseUp3d(e:MouseEvent):Void {
		move = false;
		stage.removeEventListener(Event.MOUSE_LEAVE, onStageMouseLeave);
	}

    function onStageMouseLeave(event:Event):Void{
    	move = false;
    	stage.removeEventListener(Event.MOUSE_LEAVE, onStageMouseLeave);     
    }

	function mouseWheel3d(e:MouseEvent):Void{

		var rangeTemp:Float = 16000;
		var rangeSteps:Int = 20;
		
		if (e.delta > 0){
			cameraController.distance -= rangeTemp/rangeSteps;
		}else{
			cameraController.distance += rangeTemp/rangeSteps;
		}
		
		if (cameraController.distance < 4000){
			cameraController.distance = 4000;
		} else if (cameraController.distance > 20000){
			cameraController.distance = 20000;
		}
	}
	
	function unitDown(e:MouseEvent3D):Void{

		trace("unitDown");
		var meshTemp:Mesh = cast(e.target, Mesh);
		trace("meshTemp.name: " + meshTemp.name);
		
		showTrace("Unit Down: " + meshTemp.name);
	}
	
	function unitOver(e:MouseEvent3D):Void{

		trace("unitOver");
		Mouse.cursor = MouseCursor.BUTTON;
		var meshTemp:Mesh = cast(e.target, Mesh);
		trace("meshTemp.name: " + meshTemp.name);
		
		showTrace("Unit Over: " + meshTemp.name);

	}
	
	function unitOut(e:MouseEvent3D):Void{

		trace("unitOut");
		Mouse.cursor = MouseCursor.ARROW;
	}
	
	function onTouchBegin(e:TouchEvent):Void {
		var tempPoint:Point = new Point(e.stageX, e.stageY);
		touchesCache.set(e.touchPointID, tempPoint);
		camDistanceCache = cameraController.distance;
	}

	function onTouchMove(e:TouchEvent):Void {
		
		var tempPoint:Point = new Point(e.stageX, e.stageY);
		touches.set(e.touchPointID, tempPoint);
		
		if (Lambda.count(touchesCache) == 2 && Lambda.count(touches) == 2){
			move = false;
			var idArray:Array<Int> = new Array();
	
			for (i in touchesCache.keys()){
				idArray.push(i);
			}
			
			var distanceCache:Float = Point.distance(touchesCache.get(idArray[0]), touchesCache.get(idArray[1]));
			var distance:Float = Point.distance(touches.get(idArray[0]), touches.get(idArray[1]));
			var zoomVal:Float = distance - distanceCache;
		
			cameraController.distance = camDistanceCache - (zoomVal * 12);
			
			if (cameraController.distance < 4000){
				cameraController.distance = 4000;
			}
			
			if (cameraController.distance > 20000){
				cameraController.distance = 20000;
			}
		}
	}

	function onTouchEnd(e:TouchEvent):Void {
		touchesCache.remove(e.touchPointID);
		touches.remove(e.touchPointID);
	}
	
	function showTrace(s:String):Void{
		var tempText:TextField = cast(bTrace.getChildByName("traceOut"), TextField);
		tempText.htmlText = s;
	}
	
	function onEnterFrame(e:Event):Void{

		if (plan2D == false){
			cameraController.panAngle -= rotateSpeed;
		}
		
		if (move) {
			cameraController.panAngle = 0.3*(stage.mouseX - lastMouseX) + lastPanAngle;
			cameraController.tiltAngle = 0.3 * (stage.mouseY - lastMouseY) + lastTiltAngle;
		}

		if (stage3DReady == true){
			stage3DProxy.clear();
			view.render();
			stage3DProxy.present();
		}
	}
	
	function commonListeners():Void{
		if (hasEventListener(Event.ENTER_FRAME) == false){
			addEventListener(Event.ENTER_FRAME, onEnterFrame);
		}
		
		if (stage.hasEventListener(MouseEvent.MOUSE_DOWN) == false){
			stage.addEventListener(MouseEvent.MOUSE_DOWN, mouseDown3d);
			stage.addEventListener(MouseEvent.MOUSE_UP, mouseUp3d);
			stage.addEventListener(MouseEvent.MOUSE_WHEEL, mouseWheel3d);
		}

		var multiTouchSupported:Bool = Multitouch.supportsTouchEvents;
		
		if (multiTouchSupported){
			
			Multitouch.inputMode = MultitouchInputMode.TOUCH_POINT;
			
			stage.addEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin);
			stage.addEventListener(TouchEvent.TOUCH_MOVE, onTouchMove);
			stage.addEventListener(TouchEvent.TOUCH_END, onTouchEnd);
			
		}else{
			trace("MultiTouch Not Supported");
		}
	}

	public function new() {
		super();	
		addEventListener(Event.ADDED_TO_STAGE, added);
	}
	
	function added(e):Void {
		removeEventListener(Event.ADDED_TO_STAGE, added);
		#if(flash || cpp || html5)
			stage.addEventListener(Event.RESIZE, resize);
		#end
		#if ios
			haxe.Timer.delay(init, 100);
		#else
			init();
		#end
	}

	function resize(e):Void {	
		setSizes();
	}

	function setSizes():Void {
		var scaleTestWidth:Float;
		var scaleTestHeight:Float;
		var xOrig:Float;
		var yOrig:Float;
		
		scaleTestWidth = stage.stageWidth / 1920;
		scaleTestHeight = stage.stageHeight / 1080;
		
		if (scaleTestWidth < scaleTestHeight) {
			sS = scaleTestWidth;
		}else {
			sS = scaleTestHeight;
		}
		
		var wUnit:Float = stage.stageWidth / 16;
		var hUnit:Float = stage.stageHeight / 9;
		
		if (hUnit > wUnit) {
			xOrig = 0;
			yOrig = (stage.stageHeight - (1080 * sS)) / 2;
		}else {
			xOrig = (stage.stageWidth - (1920 * sS)) / 2;
			yOrig = 0;
		}
		
		Lib.current.x = xOrig;
		Lib.current.y = yOrig;
		Lib.current.scaleX = sS;
		Lib.current.scaleY = sS;
	}
	
}
