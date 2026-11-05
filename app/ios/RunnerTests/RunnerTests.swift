import ImageIO
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
