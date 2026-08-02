import Flutter
import UIKit
import XCTest

class RunnerTests: XCTestCase {

  func testAppBundleIdentifier() {
    let bundle = Bundle.main
    let bundleId = bundle.bundleIdentifier ?? ""
    XCTAssertFalse(bundleId.isEmpty, "App bundle identifier must be configured.")
  }

  func testAppDisplayName() {
    let bundle = Bundle.main
    let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
    XCTAssertEqual(displayName, "VSP", "App display name must be VSP.")
  }
}
