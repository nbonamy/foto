import Cocoa
import FlutterMacOS

@NSApplicationMain
class AppDelegate: FlutterAppDelegate, FlutterStreamHandler {
	
	var _eventSink:FlutterEventSink?;
	var _initialFile:String?;
	var _latestFile:String?;
	
	override func applicationDidFinishLaunching(_ notification: Notification) {
		let rootController : NSViewController? = mainFlutterWindow?.contentViewController
		for controller in rootController!.children {
			if (controller is FlutterViewController) {

				let flutterController = controller as! FlutterViewController
				
				// method
				let channel = FlutterMethodChannel(name: "foto_file_handler/messages", binaryMessenger: flutterController.engine.binaryMessenger)
				channel.setMethodCallHandler(_methodHandler);
				
				// event
				let chargingChannel = FlutterEventChannel(name: "foto_file_handler/events", binaryMessenger: flutterController.engine.binaryMessenger)
				chargingChannel.setStreamHandler(self);
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
		}
	}
	
}
