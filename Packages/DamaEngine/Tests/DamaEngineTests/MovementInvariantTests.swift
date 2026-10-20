import XCTest
@testable import DamaEngine

/// Permanent regression guard (added 2026-10-20 after a field report of
/// "men flying"): property-test that no uncrowned man
/// ever moves more than one square, ever moves backward, or flies —
/// in either variant, over many random games.
final class MovementInvariantTests: XCTestCase {
    func testMenNeverFlyInRandomGames() {
        var rng = SystemRandomNumberGenerator()
        for variant in [GameVariant.tournament, .cafe] {
            for _ in 0..<60 {
                var game = Game(variant: variant)
                var plies = 0
                while game.result == nil, plies < 400 {
                    if let huff = game.pendingHuff {
                        // randomly blow or decline
                        if Bool.random(using: &rng), let t = huff.targets.first {
                            game.applyHuff(at: t)
                        } else {
                            game.declineHuff()
                        }
                        continue
                    }
                    let moves = game.legalMoves
                    XCTAssertFalse(moves.isEmpty)
                    guard let move = moves.randomElement(using: &rng) else { break }
                    let piece = game.board[move.from]!
                    if !piece.isKing {
                        // Every leg of a man's move: exactly one row forward
                        // per step (quiet) or two per capture jump.
                        for i in 1..<move.path.count {
                            let dr = move.path[i].row - move.path[i - 1].row
                            let dc = abs(move.path[i].col - move.path[i - 1].col)
                            let fwd = piece.color.forwardDelta
                            if move.isCapture {
                                XCTAssertEqual(dr, 2 * fwd, "man capture jumped dr=\(dr) in \(variant)")
                                XCTAssertEqual(dc, 2)
                            } else {
                                XCTAssertEqual(dr, fwd, "man quiet move dr=\(dr) in \(variant)")
                                XCTAssertEqual(dc, 1)
                            }
                        }
                        // A man may only be a king after ending on promotion row.
                        let after = move.applying(to: game.board)
                        if let landed = after[move.to], landed.isKing {
                            XCTAssertEqual(move.to.row, piece.color.promotionRow)
                        }
                    }
                    game.apply(move)
                    plies += 1
                }
            }
        }
    }
}
