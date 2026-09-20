import ComposableArchitecture
#if DEBUG
import Inject
#endif
import Sparkle
import AppKit
import SwiftUI

@main
struct HexApp: App {
	static let appStore = Store(initialState: AppFeature.State()) {
		AppFeature()
	}

	@NSApplicationDelegateAdaptor(HexAppDelegate.self) var appDelegate
  
    var body: some Scene {
        MenuBarExtra {
            MenuBarCopyLastTranscriptButton()

            Button("Settings…") {
                appDelegate.presentSettingsView()
            }.keyboardShortcut(",")

            CheckForUpdatesView()
			
			Divider()
			
			Button("Quit Hex") {
				NSApplication.shared.terminate(nil)
			}.keyboardShortcut("q")
		} label: {
			if let image = NSImage(named: "HexIcon").map({
				let ratio = $0.size.height / $0.size.width
				$0.size.height = 18
				$0.size.width = 18 / ratio
				return $0
			}) {
				Image(nsImage: image)
			} else {
				Image(systemName: "hexagon")
			}
		}
		.commands {
			CommandGroup(after: .appInfo) {
				CheckForUpdatesView()

				Button("Settings…") {
					appDelegate.presentSettingsView()
				}.keyboardShortcut(",")
			}

			CommandGroup(replacing: .help) {}
		}
	}
}

#if !DEBUG
// ponytail: Release excludes Inject (hot-reload is Debug-only); no-op shims so call sites compile unchanged. If Inject is ever needed in Release, delete this and link the package for all configs.
@propertyWrapper
struct ObserveInjection: DynamicProperty {
    var wrappedValue: Void { () }
}

extension View {
    func enableInjection() -> some View { self }
}
#endif
