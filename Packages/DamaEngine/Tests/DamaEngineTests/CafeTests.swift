import XCTest
@testable import DamaEngine

/// Café Mode (nefkh / huffing): captures are not forced by the move list;
/// capturing less than the maximum available hands the opponent a huff —
/// the right to remove one of the pieces that should have captured.
final class CafeTests: XCTestCase {

    private func boardWith(_ pieces: [(Int, Int, PlayerColor, Bool)]) -> Board {
        var board = Board.empty
        for (row, col, color, king) in pieces {
            board[Position(row: row, col: col)] = Piece(color: color, isKing: king)
        }
        return board
    }

    /// White man (5,3) can capture the black man (4,2) by landing (3,1).
    private func missPosition() -> Game {
        Game(board: boardWith([(5, 3, .white, false), (4, 2, .black, false)]),
             turn: .white, variant: .cafe)
    }

    func testCafeOffersQuietMovesAlongsideCaptures() {
        let game = missPosition()
        XCTAssertTrue(game.legalMoves.contains { $0.isCapture })
        XCTAssertTrue(game.legalMoves.contains { !$0.isCapture && $0.from == Position(row: 5, col: 3) },
                      "café play must offer the quiet move too")
    }

    func testTournamentStillForcesCapture() {
        let game = Game(board: boardWith([(5, 3, .white, false), (4, 2, .black, false)]),
                        turn: .white, variant: .tournament)
        XCTAssertFalse(game.legalMoves.isEmpty)
        XCTAssertTrue(game.legalMoves.allSatisfy { $0.isCapture })
    }

    func testMissedCaptureCreatesHuffOnTheMovedPiece() {
        var game = missPosition()
        let quiet = game.legalMoves.first { !$0.isCapture && $0.to == Position(row: 4, col: 4) }!
        XCTAssertTrue(game.apply(quiet))

        let huff = try! XCTUnwrap(game.pendingHuff)
        XCTAssertEqual(huff.offender, .white)
        XCTAssertEqual(huff.decider, .black)
        XCTAssertEqual(huff.targets, [Position(row: 4, col: 4)],
                       "the piece that failed to capture is tracked to its landing square")
        XCTAssertTrue(game.legalMoves.isEmpty, "the huff decision comes before the next move")
    }

    func testHuffRemovesThePieceAndCanEndTheGame() {
        var game = missPosition()
        game.apply(game.legalMoves.first { !$0.isCapture }!)
        XCTAssertTrue(game.applyHuff(at: Position(row: 4, col: 4)))
        XCTAssertEqual(game.board.count(of: .white), 0)
        XCTAssertEqual(game.result, .win(.black))
        XCTAssertNil(game.pendingHuff)
    }

    func testDecliningHuffLeavesTheBoardUntouched() {
        var game = missPosition()
        game.apply(game.legalMoves.first { !$0.isCapture }!)
        game.declineHuff()
        XCTAssertNil(game.pendingHuff)
        XCTAssertEqual(game.board.count(of: .white), 1)
        XCTAssertFalse(game.legalMoves.isEmpty, "black can move after declining")
        XCTAssertNil(game.result)
    }

    /// White can take 2 with the man on (5,1), or 1 with the man on (5,7).
    private func underCapturePosition() -> Game {
        Game(board: boardWith([
            (5, 1, .white, false), (5, 7, .white, false),
            (4, 2, .black, false), (2, 2, .black, false), (4, 6, .black, false),
        ]), turn: .white, variant: .cafe)
    }

    func testUnderCaptureExposesEveryPieceThatCouldHaveCaptured() {
        var game = underCapturePosition()
        let single = game.legalMoves.first { $0.captured.count == 1 }!
        XCTAssertTrue(game.apply(single))
        let huff = try! XCTUnwrap(game.pendingHuff)
        XCTAssertEqual(Set(huff.targets),
                       [Position(row: 3, col: 5), Position(row: 5, col: 1)],
                       "the piece that took one (now on (3,5)) and the piece that could have taken two")
    }

    func testTakingTheMaximumLeavesNoHuff() {
        var game = underCapturePosition()
        let best = game.legalMoves.first { $0.captured.count == 2 }!
        XCTAssertTrue(game.apply(best))
        XCTAssertNil(game.pendingHuff)
        XCTAssertEqual(game.turn, .black)
    }

    func testAIHuffPrefersTheKing() {
        // Black to move. Both the man on (2,2) and the king on (2,6) have
        // captures; a third black man plays a quiet move instead.
        var game = Game(board: boardWith([
            (0, 0, .black, false), (2, 2, .black, false), (2, 6, .black, true),
            (3, 3, .white, false), (3, 5, .white, false),
        ]), turn: .black, variant: .cafe)
        let quiet = game.legalMoves.first { !$0.isCapture && $0.from == Position(row: 0, col: 0) }!
        XCTAssertTrue(game.apply(quiet))
        XCTAssertEqual(game.pendingHuff?.decider, .white)
        XCTAssertEqual(DamaAI.bestHuffTarget(in: game), Position(row: 2, col: 6),
                       "the king is the most valuable offender")
        XCTAssertEqual(DamaAI.huffTarget(for: .white, in: game, difficulty: .hard),
                       Position(row: 2, col: 6),
                       "hard always huffs, and huffs the king")
    }

    func testHardAINeverHangsItsOnlyPiece() {
        // Black's only man can capture the white man (3,3) — or play quiet
        // and be huffed off the board, losing on the spot.
        let game = Game(board: boardWith([
            (2, 4, .black, false), (3, 3, .white, false),
        ]), turn: .black, variant: .cafe)
        let move = DamaAI.bestMove(for: .black, in: game, difficulty: .hard)
        XCTAssertEqual(move?.isCapture, true,
                       "café search must price the huff: the quiet move loses the piece")
    }
}
