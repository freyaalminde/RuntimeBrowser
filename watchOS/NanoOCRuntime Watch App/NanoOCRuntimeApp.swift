import SwiftUI
import CoreFoundation

let appDelegate = RTBAppDelegate()

@main
struct NanoOCRuntime_Watch_AppApp: App {
  init() {
    appDelegate.start()
    //print(RTBRuntime.sharedInstance())
    //print(RTBRuntime.sharedInstance().rootClasses)
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
