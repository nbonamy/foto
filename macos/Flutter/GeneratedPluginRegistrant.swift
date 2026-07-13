//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import contextual_menu
import macos_ui
import macos_window_utils
import pasteboard
import screen_retriever_macos
import shared_preferences_foundation
import window_manager

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  ContextualMenuPlugin.register(with: registry.registrar(forPlugin: "ContextualMenuPlugin"))
  MacOSUiPlugin.register(with: registry.registrar(forPlugin: "MacOSUiPlugin"))
  MacOSWindowUtilsPlugin.register(with: registry.registrar(forPlugin: "MacOSWindowUtilsPlugin"))
  PasteboardPlugin.register(with: registry.registrar(forPlugin: "PasteboardPlugin"))
  ScreenRetrieverMacosPlugin.register(with: registry.registrar(forPlugin: "ScreenRetrieverMacosPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
  WindowManagerPlugin.register(with: registry.registrar(forPlugin: "WindowManagerPlugin"))
}
