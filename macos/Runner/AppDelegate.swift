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
				let fileMethodChannel = FlutterMethodChannel(name: "foto_file_handler/messages", binaryMessenger: flutterController.engine.binaryMessenger)
				fileMethodChannel.setMethodCallHandler(_methodHandler);
				
				// file handler event
				let fileEventChannel = FlutterEventChannel(name: "foto_file_handler/events", binaryMessenger: flutterController.engine.binaryMessenger)
				fileEventChannel.setStreamHandler(self);

				// platform utils method
				let platformMethodChannel = FlutterMethodChannel(name: "foto_platform_utils/messages", binaryMessenger: flutterController.engine.binaryMessenger)
				platformMethodChannel.setMethodCallHandler(_methodHandler);
				
				// image utils method
				let imageMethodChannel = FlutterMethodChannel(name: "foto_image_utils/messages", binaryMessenger: flutterController.engine.binaryMessenger)
				imageMethodChannel.setMethodCallHandler(_methodHandler);
				
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
	
	func _methodHandler(_ call: FlutterMethodCall, _ result: FlutterResult) {
		if ("getInitialFile" == call.method) {
			result(self._initialFile);
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
