import XCTest

/// Placeholder UI test case so the AcmeBankUITests target has at least one
/// Swift source file to compile. Without any sources, xcodebuild produces an
/// empty .xctest bundle (no Mach-O executable) and XCTRunner fails to load it,
/// causing the entire test action to fail.
///
/// Real UI tests will be added in a follow-up PR; this placeholder exists
/// solely to keep the UI-test target buildable and loadable.
final class PlaceholderUITests: XCTestCase {
    func testPlaceholder() {
        XCTAssertTrue(true)
    }
}
