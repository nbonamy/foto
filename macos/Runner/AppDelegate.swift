import Cocoa
import CryptoKit
import FlutterMacOS
import ImageIO
import MapKit
import UniformTypeIdentifiers

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
	var _clipboardCopyGeneration: UInt64 = 0;
	
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
	
	func _platformUtilsHandler(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
		if ("setAppearance" == call.method) {
			guard let appearance = call.arguments as? String,
				  let window = mainFlutterWindow else {
				result(FlutterError(code: "appearance_failed", message: "A valid appearance and main window are required.", details: call.arguments))
				return
			}
			switch appearance {
			case "system":
				window.appearance = nil
			case "light":
				window.appearance = NSAppearance(named: .aqua)
			case "dark":
				window.appearance = NSAppearance(named: .darkAqua)
			default:
				result(FlutterError(code: "appearance_failed", message: "Unknown appearance.", details: appearance))
				return
			}
			result(true)
		} else if ("enterInstantFullScreen" == call.method) {
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
		} else if ("renderMapSnapshot" == call.method) {
			guard let arguments = call.arguments as? [String: Any],
				  let latitude = arguments["latitude"] as? Double,
				  let longitude = arguments["longitude"] as? Double,
				  let width = arguments["width"] as? Double,
				  let height = arguments["height"] as? Double,
				  let scale = arguments["scale"] as? Double else {
				result(FlutterError(code: "invalid_map_location", message: "Map coordinates and dimensions are required.", details: call.arguments))
				return
			}
			let dark = arguments["dark"] as? Bool ?? false
			let distance = arguments["distance"] as? Double ?? 60_000
			_renderMapSnapshot(
				latitude: latitude,
				longitude: longitude,
				width: width,
				height: height,
				scale: scale,
				distance: distance,
				dark: dark,
				result
			)
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

	private func _renderMapSnapshot(
		latitude: Double,
		longitude: Double,
		width: Double,
		height: Double,
		scale: Double,
		distance: Double,
		dark: Bool,
		_ result: @escaping FlutterResult
	) {
		let options = MKMapSnapshotter.Options()
		let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
		let clampedDistance = max(350, min(distance, 500_000))
		options.region = MKCoordinateRegion(
			center: center,
			latitudinalMeters: clampedDistance,
			longitudinalMeters: clampedDistance
		)
		let requestedScale = max(1, min(scale, 3))
		options.size = NSSize(
			width: max(1, width) * requestedScale,
			height: max(1, height) * requestedScale
		)
		options.mapType = .standard
		options.showsBuildings = true
		if #available(macOS 10.15, *) {
			options.pointOfInterestFilter = .excludingAll
		}
		options.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)

		let renderQueue = DispatchQueue.global(qos: .userInitiated)
		MKMapSnapshotter(options: options).start(with: renderQueue) { snapshot, error in
			let png = autoreleasepool { snapshot?.image.png }
			DispatchQueue.main.async {
				if let error {
					result(FlutterError(code: "map_snapshot_failed", message: error.localizedDescription, details: nil))
					return
				}
				guard let png else {
					result(nil)
					return
				}
				result(FlutterStandardTypedData(bytes: png))
			}
		}
	}
	
	func _fileUtilsHandler(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
		guard let filepath = call.arguments as? String else {
			result(FlutterError(code: "invalid_path", message: "A valid filesystem path is required.", details: nil))
			return
		}
		if ("scanDirectory" == call.method) {
			_scanDirectory(filepath, result)
		} else if ("getCreationDate" == call.method) {
			_fileDate(filepath, method: call.method, result) {
				FileUtils.getCreationDate(forFile: filepath)
			}
		} else if ("getModificationDate" == call.method) {
			_fileDate(filepath, method: call.method, result) {
				FileUtils.getModificationDate(forFile: filepath)
			}
		} else {
			result(FlutterMethodNotImplemented)
		}
	}

	private func _fileDate(
		_ filepath: String,
		method: String,
		_ result: @escaping FlutterResult,
		loader: @escaping () -> Date?
	) {
		DispatchQueue.global(qos: .utility).async {
			let datetime = loader()
			DispatchQueue.main.async {
				guard let datetime else {
					result(FlutterError(
						code: "date_failed",
						message: "The file date could not be read.",
						details: ["method": method, "path": filepath]
					))
					return
				}
				result(datetime.timeIntervalSince1970)
			}
		}
	}

	private func _scanDirectory(_ filepath: String, _ result: @escaping FlutterResult) {
		guard !filepath.isEmpty else {
			result(FlutterError(code: "invalid_path", message: "A valid directory path is required.", details: filepath))
			return
		}

		DispatchQueue.global(qos: .userInitiated).async {
			do {
				let directoryURL = URL(fileURLWithPath: filepath, isDirectory: true)
				let directoryValues = try directoryURL.resourceValues(forKeys: [
					.isDirectoryKey,
					.isSymbolicLinkKey,
				])
				guard directoryValues.isDirectory == true,
					  directoryValues.isSymbolicLink != true else {
					DispatchQueue.main.async {
						result(FlutterError(
							code: "invalid_path",
							message: "The path is not a readable directory.",
							details: filepath
						))
					}
					return
				}

				let resourceKeys: [URLResourceKey] = [
					.isDirectoryKey,
					.isRegularFileKey,
					.isSymbolicLinkKey,
					.creationDateKey,
					.contentModificationDateKey,
					.fileSizeKey,
				]
				let urls = try FileManager.default.contentsOfDirectory(
					at: directoryURL,
					includingPropertiesForKeys: resourceKeys,
					options: []
				)

				var entries: [[String: Any]] = []
				entries.reserveCapacity(urls.count)
				for url in urls {
					let values: URLResourceValues
					do {
						values = try url.resourceValues(forKeys: Set(resourceKeys))
					} catch {
						continue
					}
					guard values.isSymbolicLink != true else { continue }

					let type: String
					if values.isDirectory == true {
						type = "directory"
					} else if values.isRegularFile == true {
						type = "file"
					} else {
						continue
					}

					let modificationDate = values.contentModificationDate
						?? values.creationDate
						?? Date(timeIntervalSince1970: 0)
					let creationDate = values.creationDate ?? modificationDate
					var entry: [String: Any] = [
						"path": url.path,
						"type": type,
						"creationDate": creationDate.timeIntervalSince1970,
						"modificationDate": modificationDate.timeIntervalSince1970,
					]
					if type == "file", let fileSize = values.fileSize {
						entry["size"] = fileSize
					}
					entries.append(entry)
				}

				DispatchQueue.main.async {
					result(entries)
				}
			} catch {
				DispatchQueue.main.async {
					result(FlutterError(
						code: "scan_failed",
						message: error.localizedDescription,
						details: filepath
					))
				}
			}
		}
	}

	func _imageUtilsHandler(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
		
		if ("copyImageToClipboard" == call.method) {
			guard let filepath = call.arguments as? String else {
				result(FlutterError(code: "invalid_path", message: "A valid filesystem path is required.", details: nil))
				return
			}
			_clipboardCopyGeneration &+= 1
			_copyImageToClipboard(
				filepath,
				generation: _clipboardCopyGeneration,
				result
			)
		} else if ("getCreationDate" == call.method) {
			guard let filepath = call.arguments as? String else {
				result(FlutterError(code: "invalid_path", message: "A valid filesystem path is required.", details: nil))
				return
			}
			DispatchQueue.global(qos: .utility).async {
				let datetime = ImageUtils.getCreationDate(forImage: filepath)
				DispatchQueue.main.async {
					guard let datetime else {
						result(FlutterError(
							code: "date_failed",
							message: "The image date could not be read.",
							details: filepath
						))
						return
					}
					result(datetime.timeIntervalSince1970)
				}
			}
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

	private func _copyImageToClipboard(
		_ filepath: String,
		generation: UInt64,
		_ result: @escaping FlutterResult
	) {
		DispatchQueue.global(qos: .userInitiated).async {
			let representations: (png: Data, tiff: Data)? = autoreleasepool {
				guard let source = CGImageSourceCreateWithURL(
					URL(fileURLWithPath: filepath) as CFURL,
					nil
				),
				let properties = CGImageSourceCopyPropertiesAtIndex(
					source,
					0,
					nil
				) as? [CFString: Any],
				let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
				let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
					return nil
				}

				let maxPixelSize = max(width.intValue, height.intValue)
				guard maxPixelSize > 0 else {
					return nil
				}
				let options: [CFString: Any] = [
					kCGImageSourceCreateThumbnailFromImageAlways: true,
					kCGImageSourceCreateThumbnailWithTransform: true,
					kCGImageSourceShouldCacheImmediately: true,
					kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
				]
				guard let image = CGImageSourceCreateThumbnailAtIndex(
					source,
					0,
					options as CFDictionary
				),
				let png = self._encodeClipboardImage(
					image,
					type: UTType.png.identifier as CFString
				),
				let tiff = self._encodeClipboardImage(
					image,
					type: UTType.tiff.identifier as CFString
				) else {
					return nil
				}
				return (png, tiff)
			}

			DispatchQueue.main.async {
				guard generation == self._clipboardCopyGeneration else {
					result(true)
					return
				}
				guard let representations else {
					result(FlutterError(
						code: "image_decode_failed",
						message: "The image could not be decoded for the clipboard.",
						details: filepath
					))
					return
				}

				let item = NSPasteboardItem()
				guard item.setData(representations.png, forType: .png),
					  item.setData(representations.tiff, forType: .tiff) else {
					result(FlutterError(
						code: "clipboard_failed",
						message: "The image representations could not be prepared.",
						details: filepath
					))
					return
				}

				let pasteboard = NSPasteboard.general
				pasteboard.clearContents()
				guard pasteboard.writeObjects([item]) else {
					result(FlutterError(
						code: "clipboard_failed",
						message: "The image could not be written to the clipboard.",
						details: filepath
					))
					return
				}
				result(true)
			}
		}
	}

	private func _encodeClipboardImage(_ image: CGImage, type: CFString) -> Data? {
		let data = NSMutableData()
		guard let destination = CGImageDestinationCreateWithData(
			data,
			type,
			1,
			nil
		) else {
			return nil
		}
		CGImageDestinationAddImage(destination, image, nil)
		guard CGImageDestinationFinalize(destination) else {
			return nil
		}
		return data as Data
	}
	
	
}
