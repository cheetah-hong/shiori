import ImageIO
import UserNotifications
import Flutter
import XCTest

@testable import Runner

/// Pure geometry of the OCR channel: reading-direction votes and orientation turns.
class OcrOrientationTests: XCTestCase {

  /// A text line of [characters] whose reading direction is [degrees] counter-clockwise,
  /// in normalized coordinates of a square image.
  private func quad(_ degrees: Double, _ characters: Int = 10) -> OcrOrientation.Quad {
    let r = degrees * .pi / 180
    let topLeft = CGPoint(x: 0.5, y: 0.5)
    return OcrOrientation.Quad(topLeft: topLeft,
                               topRight: CGPoint(x: 0.5 + 0.2 * cos(r), y: 0.5 + 0.2 * sin(r)),
                               characters: characters)
  }

  func testVotesFollowTheReadingDirection() {
    XCTAssertEqual(OcrOrientation.votes([quad(0), quad(3), quad(-4)], width: 1, height: 1), [30, 0, 0, 0])
    XCTAssertEqual(OcrOrientation.votes([quad(90), quad(180, 5), quad(270, 7)], width: 1, height: 1), [0, 10, 5, 7])
    // 44° still counts as 0°, 46° as 90°.
    XCTAssertEqual(OcrOrientation.votes([quad(44), quad(46)], width: 1, height: 1), [10, 10, 0, 0])
  }

  func testVotesUseThePixelAspect() {
    // On a wide image a small normalized dy is a small pixel dy: still horizontal.
    let q = OcrOrientation.Quad(topLeft: CGPoint(x: 0.1, y: 0.5), topRight: CGPoint(x: 0.2, y: 0.55), characters: 4)
    XCTAssertEqual(OcrOrientation.votes([q], width: 4000, height: 1000), [4, 0, 0, 0])
    XCTAssertEqual(OcrOrientation.votes([q], width: 1000, height: 4000), [0, 4, 0, 0])
  }

  func testTurnsNeedAClearMajority() {
    XCTAssertEqual(OcrOrientation.clockwiseTurns(votes: [100, 0, 0, 0]), 0)
    XCTAssertEqual(OcrOrientation.clockwiseTurns(votes: [3, 95, 0, 2]), 1)  // text runs up: one turn
    XCTAssertEqual(OcrOrientation.clockwiseTurns(votes: [0, 0, 88, 12]), 2)
    XCTAssertEqual(OcrOrientation.clockwiseTurns(votes: [5, 0, 0, 90]), 3)
    XCTAssertEqual(OcrOrientation.clockwiseTurns(votes: [40, 45, 0, 0]), 0, "no clear direction")
    XCTAssertEqual(OcrOrientation.clockwiseTurns(votes: [0, 12, 0, 0]), 0, "too little text")
    XCTAssertEqual(OcrOrientation.clockwiseTurns(votes: [0, 0, 0, 0]), 0)
  }

  func testOrientationTurnsCompose() {
    XCTAssertEqual(OcrOrientation.orientation(.up, turnedClockwise: 1), .right)
    XCTAssertEqual(OcrOrientation.orientation(.up, turnedClockwise: 3), .left)
    XCTAssertEqual(OcrOrientation.orientation(.right, turnedClockwise: 1), .down)
    XCTAssertEqual(OcrOrientation.orientation(.right, turnedClockwise: 3), .up)
    XCTAssertEqual(OcrOrientation.orientation(.left, turnedClockwise: 2), .right)
    XCTAssertEqual(OcrOrientation.orientation(.down, turnedClockwise: 0), .down)
    XCTAssertNil(OcrOrientation.orientation(.upMirrored, turnedClockwise: 1))
  }

  func testQuarterTurnsSwapTheSides() {
    XCTAssertFalse(OcrOrientation.swapsSides(.up))
    XCTAssertFalse(OcrOrientation.swapsSides(.downMirrored))
    XCTAssertTrue(OcrOrientation.swapsSides(.right))
    XCTAssertTrue(OcrOrientation.swapsSides(.leftMirrored))
  }
}

/// Backup exclusion channel: marks folders inside the app container only.
class BackupExclusionTests: XCTestCase {
  private var folder: URL!

  override func setUpWithError() throws {
    folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("backup-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: folder)
  }

  func testMarksAFolderAndReadsTheMarkBack() throws {
    XCTAssertFalse(try BackupExclusion.isExcluded(path: folder.path))
    try BackupExclusion.exclude(path: folder.path)
    XCTAssertTrue(try BackupExclusion.isExcluded(path: folder.path))
  }

  func testRefusesPathsOutsideTheApp() {
    XCTAssertThrowsError(try BackupExclusion.exclude(path: "/etc")) { error in
      XCTAssertEqual(error as? BackupExclusion.Failure, .outsideApp)
    }
    // Enough ".." to climb past the root (which stays "/"), so it resolves to /etc.
    let escaping = folder.path + String(repeating: "/..", count: 40) + "/etc"
    XCTAssertThrowsError(try BackupExclusion.exclude(path: escaping)) { error in
      XCTAssertEqual(error as? BackupExclusion.Failure, .outsideApp)
    }
  }

  func testRefusesAMissingPath() {
    let missing = folder.appendingPathComponent("missing").path
    XCTAssertThrowsError(try BackupExclusion.exclude(path: missing)) { error in
      XCTAssertEqual(error as? BackupExclusion.Failure, .missing)
    }
  }
}

class SystemChannelTests: XCTestCase {
  func testStatusNamesMatchTheDartSide() {
    XCTAssertEqual(SystemChannel.statusName(.notDetermined), "notDetermined")
    XCTAssertEqual(SystemChannel.statusName(.denied), "denied")
    XCTAssertEqual(SystemChannel.statusName(.authorized), "authorized")
    XCTAssertEqual(SystemChannel.statusName(.provisional), "provisional")
    XCTAssertEqual(SystemChannel.statusName(.ephemeral), "ephemeral")
  }

  func testUnknownMethodsAreNotImplemented() {
    let answered = expectation(description: "answered")
    SystemChannel().handle(FlutterMethodCall(methodName: "anything", arguments: nil)) { value in
      XCTAssertTrue((value as AnyObject) === (FlutterMethodNotImplemented as AnyObject))
      answered.fulfill()
    }
    wait(for: [answered], timeout: 1)
  }
}
