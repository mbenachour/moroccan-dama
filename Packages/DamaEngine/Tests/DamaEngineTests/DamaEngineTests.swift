import XCTest
@testable import DamaEngine

final class DamaEngineTests: XCTestCase {

    // MARK: Helpers

    private func board(with pieces: [(Int, Int, PlayerColor, Bool)]) -> Board {
        var board = Board.empty
        for (row, col, color, isKing) in pieces {
            let pos = Position(row: row, col: col)
            XCTAssertTrue(pos.isPlayableSquare, "(\(row),\(col)) is not a playable square")
            board[pos] = Piece(color: color, isKing: isKing)
        }
        return board
    }

    private func pos(_ row: Int, _ col: Int) -> Position { Position(row: row, col: col) }

    // MARK: Setup

    func testInitialSetup() {
        let board = Board.initial
        XCTAssertEqual(board.count(of: .white), 12)
        XCTAssertEqual(board.count(of: .black), 12)
        // Mirrored board: the near-left corner (7,0) is light, i.e. not playable.
        XCTAssertFalse(pos(7, 0).isPlayableSquare)
        XCTAssertNil(board[pos(7, 0)])
        // Nobody starts crowned.
        XCTAssertTrue(board.squares.allSatisfy { $0?.isKing != true })
    }

    func testWhiteHasSevenOpeningMoves() {
        let game = Game()
        XCTAssertEqual(game.turn, .white)
        XCTAssertEqual(game.legalMoves.count, 7)
        XCTAssertTrue(game.legalMoves.allSatisfy { !$0.isCapture })
    }

    // MARK: Men

    func testManMovesForwardOnly() {
        let board = board(with: [(4, 2, .white, false), (0, 0, .black, false)])
        let moves = MoveGenerator.quietMoves(on: board, for: .white)
            .filter { $0.from == pos(4, 2) }
        XCTAssertEqual(Set(moves.map { $0.to }), Set([pos(3, 1), pos(3, 3)]))
    }

    func testManCannotCaptureBackward() {
        // Black man sits behind the white man with an empty landing beyond:
        // a backward capture in International draughts, illegal here.
        let board = board(with: [
            (4, 4, .white, false),
            (5, 3, .black, false)
        ])
        let moves = MoveGenerator.legalMoves(on: board, for: .white)
        XCTAssertFalse(moves.isEmpty)
        XCTAssertTrue(moves.allSatisfy { !$0.isCapture })
    }

    func testCaptureIsMandatory() {
        let board = board(with: [
            (5, 1, .white, false),   // can capture the black man
            (6, 6, .white, false),   // has quiet moves, but they are illegal now
            (4, 2, .black, false)
        ])
        let moves = MoveGenerator.legalMoves(on: board, for: .white)
        XCTAssertFalse(moves.isEmpty)
        XCTAssertTrue(moves.allSatisfy { $0.isCapture && $0.from == pos(5, 1) })
    }

    func testMaximumCaptureRuleAndMultiCaptureChain() {
        // From (5,5): left takes 1 piece, right takes 2 in a zigzag chain.
        // Only the 2-piece line is legal.
        let board = board(with: [
            (5, 5, .white, false),
            (4, 4, .black, false),
            (4, 6, .black, false),
            (2, 6, .black, false)
        ])
        let moves = MoveGenerator.legalMoves(on: board, for: .white)
        XCTAssertFalse(moves.isEmpty)
        XCTAssertTrue(moves.allSatisfy { $0.captured.count == 2 })
        XCTAssertTrue(moves.contains {
            $0.path == [pos(5, 5), pos(3, 7), pos(1, 5)]
                && $0.captured == [pos(4, 6), pos(2, 6)]
        })
    }

    func testManPromotesOnQuietMove() {
        let board = board(with: [(1, 1, .white, false), (7, 7, .black, false)])
        var game = Game(board: board, turn: .white)
        let move = game.legalMoves.first { $0.to == pos(0, 0) || $0.to == pos(0, 2) }
        XCTAssertNotNil(move)
        XCTAssertTrue(game.apply(move!))
        XCTAssertEqual(game.board[move!.to]?.isKing, true)
        XCTAssertEqual(game.turn, .black)
    }

    func testPromotionStopsCapture() {
        // The man crowns on (0,4). As a fresh king it *could* capture the
        // black man on (1,5) backwards — but the crownhead rule ends the move.
        let board = board(with: [
            (2, 2, .white, false),
            (1, 3, .black, false),
            (1, 5, .black, false)
        ])
        let moves = MoveGenerator.legalMoves(on: board, for: .white)
        XCTAssertTrue(moves.contains { $0.captured == [pos(1, 3)] && $0.to == pos(0, 4) })
        XCTAssertTrue(moves.allSatisfy { $0.captured.count == 1 })

        var game = Game(board: board, turn: .white)
        let crowning = moves.first { $0.to == pos(0, 4) }!
        XCTAssertTrue(game.apply(crowning))
        XCTAssertEqual(game.board[pos(0, 4)]?.isKing, true)
        XCTAssertEqual(game.board.count(of: .black), 1)
    }

    // MARK: Kings

    func testKingSlidesAnyDistance() {
        let board = board(with: [(4, 4, .white, true), (0, 6, .black, false)])
        let moves = MoveGenerator.quietMoves(on: board, for: .white)
            .filter { $0.from == pos(4, 4) }
        XCTAssertEqual(moves.count, 13)
    }

    func testKingCapturesFromDistanceWithLandingChoice() {
        let board = board(with: [
            (7, 1, .white, true),
            (4, 4, .black, false)
        ])
        let moves = MoveGenerator.legalMoves(on: board, for: .white)
        XCTAssertEqual(moves.count, 3)
        XCTAssertEqual(Set(moves.map { $0.to }), Set([pos(3, 5), pos(2, 6), pos(1, 7)]))
        XCTAssertTrue(moves.allSatisfy { $0.captured == [pos(4, 4)] })
    }

    func testKingCannotJumpOwnPieceOrJumpSamePieceTwice() {
        // Own man blocks the king's diagonal toward the black man.
        let blocked = board(with: [
            (4, 4, .white, true),
            (3, 5, .white, false),
            (2, 6, .black, false)
        ])
        let kingMoves = MoveGenerator.legalMoves(on: blocked, for: .white)
            .filter { $0.from == pos(4, 4) }
        XCTAssertTrue(kingMoves.allSatisfy { !$0.isCapture })

        // Deferred removal: after jumping the black man, the king may not
        // turn around and jump it again — captured pieces stay on the board
        // until the move ends.
        let loop = board(with: [
            (4, 0, .white, true),
            (3, 1, .black, false)
        ])
        let captures = MoveGenerator.legalMoves(on: loop, for: .white)
        XCTAssertFalse(captures.isEmpty)
        XCTAssertTrue(captures.allSatisfy { $0.captured.count == 1 })
    }

    func testKingMultiCaptureAcrossDiagonals() {
        // King takes (5,3) landing long, then swings up-right to take (2,6).
        let board = board(with: [
            (7, 1, .white, true),
            (5, 3, .black, false),
            (2, 6, .black, false)
        ])
        let moves = MoveGenerator.legalMoves(on: board, for: .white)
        XCTAssertTrue(moves.allSatisfy { $0.captured.count == 2 })
        XCTAssertTrue(moves.contains {
            $0.captured == [pos(5, 3), pos(2, 6)]
        })
    }

    // MARK: Game end

    func testEliminationWins() {
        let board = board(with: [
            (4, 4, .white, true),
            (3, 3, .black, false)
        ])
        var game = Game(board: board, turn: .white)
        let winning = game.legalMoves.first { $0.captured == [pos(3, 3)] }
        XCTAssertNotNil(winning)
        XCTAssertTrue(game.apply(winning!))
        XCTAssertEqual(game.result, .win(.white))
    }

    func testBlockedPlayerLoses() {
        // Black to move: both forward squares are occupied and neither
        // capture has a free landing.
        let board = board(with: [
            (1, 1, .black, false),
            (2, 0, .white, false),
            (2, 2, .white, false),
            (3, 3, .white, false)
        ])
        let game = Game(board: board, turn: .black)
        XCTAssertEqual(game.result, .win(.white))
    }

    func testThreefoldRepetitionDraws() {
        // The two kings shuttle on squares that never share a diagonal, so
        // no capture ever interrupts the cycle.
        let board = board(with: [
            (5, 1, .white, true),
            (0, 2, .black, true)
        ])
        var game = Game(board: board, turn: .white)
        let cycle: [(Position, Position)] = [
            (pos(5, 1), pos(4, 2)), (pos(0, 2), pos(1, 3)),
            (pos(4, 2), pos(5, 1)), (pos(1, 3), pos(0, 2))
        ]
        for _ in 0..<2 {
            for (from, to) in cycle {
                XCTAssertTrue(game.apply(Move(path: [from, to])), "move \(from)->\(to) should be legal")
            }
        }
        XCTAssertEqual(game.result, .draw(.threefoldRepetition))
    }

    func testNoProgressCounterResetsOnManMove() {
        let board = board(with: [
            (7, 7, .white, true),
            (5, 3, .white, false),
            (2, 4, .black, false),
            (0, 0, .black, true)
        ])
        var game = Game(board: board, turn: .white)
        XCTAssertTrue(game.apply(Move(path: [pos(7, 7), pos(6, 6)])))
        XCTAssertEqual(game.pliesWithoutProgress, 1)
        XCTAssertTrue(game.apply(Move(path: [pos(2, 4), pos(3, 3)])))
        XCTAssertEqual(game.pliesWithoutProgress, 0)
    }

    func testIllegalMoveIsRejected() {
        var game = Game()
        let before = game.board
        XCTAssertFalse(game.apply(Move(path: [pos(6, 0), pos(4, 2)])))
        XCTAssertEqual(game.board, before)
        XCTAssertEqual(game.turn, .white)
    }

    // MARK: AI

    func testAITakesTheWinningCapture() {
        let board = board(with: [
            (4, 4, .white, true),
            (1, 1, .black, false)
        ])
        let game = Game(board: board, turn: .white)
        let move = DamaAI.bestMove(for: .white, in: game, difficulty: .medium)
        XCTAssertEqual(move?.captured, [pos(1, 1)])
    }

    func testAIReturnsLegalMovesInRealGame() {
        var game = Game()
        var plies = 0
        while game.result == nil && plies < 60 {
            guard let move = DamaAI.bestMove(for: game.turn, in: game, difficulty: .easy) else {
                XCTFail("AI found no move in a live game")
                return
            }
            XCTAssertTrue(game.apply(move))
            plies += 1
        }
        XCTAssertGreaterThan(plies, 10)
    }
}
