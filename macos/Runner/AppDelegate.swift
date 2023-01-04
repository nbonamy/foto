import Cocoa
import CommonCrypto
import FlutterMacOS

extension NSBitmapImageRep {
    var png: Data? { representation(using: .png, properties: [:]) }
}
extension Data {
    var bitmap: NSBitmapImageRep? { NSBitmapImageRep(data: self) }
}
extension NSImage {
    var png: Data? { tiffRepresentation?.bitmap?.png }
}

extension Data {
    var md5 : String {
        let digest = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(CC_MD5_DIGEST_LENGTH))
				defer { digest.deallocate() }
        self.withUnsafeBytes { bytes in 
					guard let baseAddress = bytes.baseAddress else { return }
					CC_MD5(baseAddress, CC_LONG(bytes.count), digest)
				}
        var digestHex = ""
        for index in 0..<Int(CC_MD5_DIGEST_LENGTH) {
            digestHex += String(format: "%02x", digest[index])
        }
        return digestHex
    }
}

@NSApplicationMain
class AppDelegate: FlutterAppDelegate, FlutterStreamHandler {
	
	var _eventSink:FlutterEventSink?;
	var _initialFile:String?;
	var _latestFile:String?;
	var _cachedIcons:[String] = [];
	
	override func applicationDidFinishLaunching(_ notification: Notification) {
		let rootController : NSViewController? = mainFlutterWindow?.contentViewController
		for controller in rootController!.children {
			if (controller is FlutterViewController) {

				let flutterController = controller as! FlutterViewController
				
				// file handler method
				let fileHandlerMethodChannel = FlutterMethodChannel(name: "foto_file_handler/messages", binaryMessenger: flutterController.engine.binaryMessenger)
                fileHandlerMethodChannel.setMethodCallHandler(_fileHandler);
				
				// file handler event
				let filHandlerEventChannel = FlutterEventChannel(name: "foto_file_handler/events", binaryMessenger: flutterController.engine.binaryMessenger)
                filHandlerEventChannel.setStreamHandler(self);

				// platform utils method
				let platformUtilsMethodChannel = FlutterMethodChannel(name: "foto_platform_utils/messages", binaryMessenger: flutterController.engine.binaryMessenger)
                platformUtilsMethodChannel.setMethodCallHandler(_platformUtilsHandler);
				
				// file utils method
				let fileUtilsMethodChannel = FlutterMethodChannel(name: "foto_file_utils/messages", binaryMessenger: flutterController.engine.binaryMessenger)
                fileUtilsMethodChannel.setMethodCallHandler(_fileUtilsHandler);
				
				// image utils method
				let imageUtilsMethodChannel = FlutterMethodChannel(name: "foto_image_utils/messages", binaryMessenger: flutterController.engine.binaryMessenger)
                imageUtilsMethodChannel.setMethodCallHandler(_imageUtilsHandler);
				
			}
		}
	}
	
	override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
		return true
	}
	
	public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
		self._eventSink = events;
		return nil;
	}
	
	public func onCancel(withArguments arguments: Any?) -> FlutterError? {
		self._eventSink = nil;
		return nil;
	}
	
	override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
		self._process(filename: filename)
		return true
	}
	
	override func application(_ sender: NSApplication, openFiles filenames: [String]) {
		self._process(filename: filenames[0])
	}
	
	override func application(_ application: NSApplication, open urls: [URL]) {
		self._process(filename: urls[0].path)
	}
	
	func _process(filename: String) {
		self._latestFile = filename;
		if(self._initialFile == nil) {
			self._initialFile = self._latestFile;
		}
		guard let sink = self._eventSink else{
			return;
		}
		sink(self._latestFile);
	}
	
	func _fileHandler(_ call: FlutterMethodCall, _ result: FlutterResult) {
		if ("getInitialFile" == call.method) {
			result(self._initialFile);
		}
	}
	
	func _platformUtilsHandler(_ call: FlutterMethodCall, _ result: FlutterResult) {
		if ("moveToTrash" == call.method) {
			let filepath = call.arguments as! String;
			FileUtils.moveItem(toTrash: filepath);
			result(true);
		} else if ("getPlatformIcon" == call.method) {
			let filepath = call.arguments as! String;
			let image = NSWorkspace.shared.icon(forFile: filepath);
			let hash = image.name() ?? image.tiffRepresentation?.md5 ?? filepath;
			if (self._cachedIcons.contains(hash)) {
				result(hash);
			} else {
				let png = image.png;
				self._cachedIcons.append(hash);
				result([
					"key": hash,
					"png": FlutterStandardTypedData.init(bytes: png!)
				]);
			}
		} else if ("bundlePathForIdentifier" == call.method) {
			let identifier = call.arguments as! String;
			result(SystemUtils.bundlePath(forIdentifier:identifier));
		} else if ("openFilesWithBundleIdentifier" == call.method) {
			guard let args = call.arguments as? [String:Any] else {return}
			let files = args["files"] as? Array<String>;
			let identifier = args["identifier"] as? String;
			SystemUtils.openFiles(files, withBundleIdentifier: identifier);
			result(true);
		}
	}
	
	func _fileUtilsHandler(_ call: FlutterMethodCall, _ result: FlutterResult) {
		if ("getCreationDate" == call.method) {
			let filepath = call.arguments as! String;
			let datetime = FileUtils.getCreationDate(forFile: filepath);
			result(datetime!.timeIntervalSince1970);
		} else if ("getModificationDate" == call.method) {
			let filepath = call.arguments as! String;
			let datetime = FileUtils.getModificationDate(forFile: filepath);
			result(datetime!.timeIntervalSince1970);
		}
	}

	func _imageUtilsHandler(_ call: FlutterMethodCall, _ result: FlutterResult) {
		
		if ("getCreationDate" == call.method) {
			let filepath = call.arguments as! String;
			let datetime = ImageUtils.getCreationDate(forImage: filepath);
			result(datetime!.timeIntervalSince1970);
		} else if ("transformImage" == call.method) {
			guard let args = call.arguments as? [String:Any] else {return}
			let filepath = args["filepath"] as? String;
			let transformation = args["transformation"] as? UInt32;
			let jpegcompression = args["jpegCompression"] as? Float;
			let rc = ImageUtils.transformImage(filepath, withTransform: ImageTransformation(rawValue: transformation!), jpegCompression: jpegcompression!);
			result(rc);
		} else if ("losslessRotate" == call.method) {
			let filepath = call.arguments as! String;
			let rc = ImageUtils.autoLosslessRotateImage(filepath);
			result(rc);
		}
	}
	
	
}

