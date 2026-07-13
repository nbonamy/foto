import Cocoa
import CryptoKit
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
    var sha256: String {
        SHA256.hash(data: self).map { String(format: "%02x", $0) }.joined()
    }
}

@main
class AppDelegate: FlutterAppDelegate, FlutterStreamHandler {
	
	var _eventSink:FlutterEventSink?;
	var _initialFile:String?;
	var _latestFile:String?;
	var _cachedIcons:Set<String> = [];
	
	override func applicationDidFinishLaunching(_ notification: Notification) {
		guard let rootController = mainFlutterWindow?.contentViewController else {
			return
		}
		for controller in rootController.children {
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

	override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
		return true
	}

	override func applicationWillTerminate(_ notification: Notification) {
		(mainFlutterWindow as? MainFlutterWindow)?.exitInstantFullScreen()
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
		guard let filename = filenames.first else { return }
		self._process(filename: filename)
	}
	
	override func application(_ application: NSApplication, open urls: [URL]) {
		guard let url = urls.first else { return }
		self._process(filename: url.path)
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
		} else {
			result(FlutterMethodNotImplemented)
		}
	}
	
	func _platformUtilsHandler(_ call: FlutterMethodCall, _ result: FlutterResult) {
		if ("enterInstantFullScreen" == call.method) {
			guard let window = mainFlutterWindow as? MainFlutterWindow else {
				result(FlutterError(code: "fullscreen_failed", message: "The main window is unavailable.", details: nil))
				return
			}
			result(window.enterInstantFullScreen())
		} else if ("exitInstantFullScreen" == call.method) {
			guard let window = mainFlutterWindow as? MainFlutterWindow else {
				result(FlutterError(code: "fullscreen_failed", message: "The main window is unavailable.", details: nil))
				return
			}
			result(window.exitInstantFullScreen())
		} else if ("moveToTrash" == call.method) {
			guard let filepath = call.arguments as? String else {
				result(FlutterError(
					code: "invalid_path",
					message: "A valid filesystem path is required.",
					details: nil
				));
				return;
			}
			do {
				try FileUtils.moveItem(toTrash: filepath)
				result(true);
			} catch {
				result(FlutterError(
					code: "trash_failed",
					message: error.localizedDescription,
					details: filepath
				));
			}
		} else if ("getPlatformIcon" == call.method) {
			guard let filepath = call.arguments as? String else {
				result(FlutterError(code: "invalid_path", message: "A valid filesystem path is required.", details: nil))
				return
			}
			let image = NSWorkspace.shared.icon(forFile: filepath);
			let hash = image.name() ?? image.tiffRepresentation?.sha256 ?? filepath;
			if (self._cachedIcons.contains(hash)) {
				result(hash);
			} else if let png = image.png {
				self._cachedIcons.insert(hash);
				result(["key": hash, "png": FlutterStandardTypedData(bytes: png)]);
			} else {
				result(FlutterError(code: "icon_failed", message: "The file icon could not be rendered.", details: filepath))
			}
		} else if ("bundlePathForIdentifier" == call.method) {
			guard let identifier = call.arguments as? String else {
				result(FlutterError(code: "invalid_identifier", message: "A valid bundle identifier is required.", details: nil))
				return
			}
			result(SystemUtils.bundlePath(forIdentifier:identifier));
		} else if ("openFilesWithBundleIdentifier" == call.method) {
			guard let args = call.arguments as? [String:Any],
				  let files = args["files"] as? [String],
				  let identifier = args["identifier"] as? String else {
				result(FlutterError(code: "invalid_arguments", message: "Files and a bundle identifier are required.", details: nil))
				return
			}
			SystemUtils.openFiles(files, withBundleIdentifier: identifier);
			result(true);
		} else {
			result(FlutterMethodNotImplemented)
		}
	}
	
	func _fileUtilsHandler(_ call: FlutterMethodCall, _ result: FlutterResult) {
		guard let filepath = call.arguments as? String else {
			result(FlutterError(code: "invalid_path", message: "A valid filesystem path is required.", details: nil))
			return
		}
		if ("getCreationDate" == call.method), let datetime = FileUtils.getCreationDate(forFile: filepath) {
			result(datetime.timeIntervalSince1970);
		} else if ("getModificationDate" == call.method), let datetime = FileUtils.getModificationDate(forFile: filepath) {
			result(datetime.timeIntervalSince1970);
		} else if (call.method == "getCreationDate" || call.method == "getModificationDate") {
			result(FlutterError(code: "date_failed", message: "The file date could not be read.", details: filepath))
		} else {
			result(FlutterMethodNotImplemented)
		}
	}

	func _imageUtilsHandler(_ call: FlutterMethodCall, _ result: FlutterResult) {
		
		if ("getCreationDate" == call.method) {
			guard let filepath = call.arguments as? String,
				  let datetime = ImageUtils.getCreationDate(forImage: filepath) else {
				result(FlutterError(code: "date_failed", message: "The image date could not be read.", details: call.arguments))
				return
			}
			result(datetime.timeIntervalSince1970);
		} else if ("transformImage" == call.method) {
			guard let args = call.arguments as? [String:Any],
				  let filepath = args["filepath"] as? String,
				  let transformationNumber = args["transformation"] as? NSNumber,
				  let compressionNumber = args["jpegCompression"] as? NSNumber else {
				result(FlutterError(code: "invalid_arguments", message: "A path, transformation, and JPEG compression are required.", details: call.arguments))
				return
			}
			guard transformationNumber.uint32Value <= 4 else {
				result(FlutterError(code: "invalid_transformation", message: "The requested image transformation is invalid.", details: transformationNumber))
				return
			}
			let transformation = ImageTransformation(rawValue: transformationNumber.uint32Value)
			let rc = ImageUtils.transformImage(filepath, withTransform: transformation, jpegCompression: compressionNumber.floatValue);
			result(rc);
		} else if ("losslessRotate" == call.method) {
			guard let filepath = call.arguments as? String else {
				result(FlutterError(code: "invalid_path", message: "A valid filesystem path is required.", details: nil))
				return
			}
			let rc = ImageUtils.autoLosslessRotateImage(filepath);
			result(rc);
		} else {
			result(FlutterMethodNotImplemented)
		}
	}
	
	
}
