import Foundation

public enum GameResult: Equatable, Sendable {
    case win(PlayerColor)
    case draw(DrawReason)

    public enum DrawReason: String, Sendable {
        /// The same position occurred for the third time.
        case threefoldRepetition
        /// 40 moves by each side with no capture and no man moving.
        case noProgress
    }
}

/// A full game state: board, side to move, and end-of-game detection.
///
/// Draw law (Moroccan / Spanish family): the game is drawn by threefold
/// repetition, or after 40 moves by each player (80 plies) in which no
/// piece was captured and no man moved. A player with no pieces, or with no
/// legal move on their turn, loses.
public struct Game: Equatable, Sendable {
    public private(set) var board: Board
    public private(set) var turn: PlayerColor
    public private(set) var result: GameResult?
    public private(set) var history: [Move]

    /// Plies since the last capture or man move (the no-progress counter).
    public private(set) var pliesWithoutProgress: Int
    private var positionCounts: [String: Int]

    public static let noProgressPlyLimit = 80

    public init(board: Board = .initial, turn: PlayerColor = .white) {
        self.board = board
        self.turn = turn
        self.result = nil
        self.history = []
        self.pliesWithoutProgress = 0
        self.positionCounts = [Game.positionKey(board: board, turn: turn): 1]
        evaluateEnd()
    }

    public var legalMoves: [Move] {
        guard result == nil else { return [] }
        return MoveGenerator.legalMoves(on: board, for: turn)
    }

    public func legalMoves(from position: Position) -> [Move] {
        legalMoves.filter { $0.from == position }
    }

    /// Applies a legal move. Returns false (and changes nothing) when the
    /// move is not among the current legal moves or the game is over.
    @discardableResult
    public mutating func apply(_ move: Move) -> Bool {
        guard result == nil, legalMoves.contains(move) else { return false }
        applyUnchecked(move)
        return true
    }

    /// Applies a move without checking legality — used by search and tests
    /// that have already generated the move from this position.
    public mutating func applyUnchecked(_ move: Move) {
        let movingPiece = board[move.from]
        let madeProgress = move.isCapture || (movingPiece?.isKing == false)
        board = move.applying(to: board)
        history.append(move)
        turn = turn.opponent
        pliesWithoutProgress = madeProgress ? 0 : pliesWithoutProgress + 1

        let key = Game.positionKey(board: board, turn: turn)
        positionCounts[key, default: 0] += 1
        evaluateEnd(repetitionCount: positionCounts[key] ?? 0)
    }

    private mutating func evaluateEnd(repetitionCount: Int = 1) {
        guard result == nil else { return }
        if repetitionCount >= 3 {
            result = .draw(.threefoldRepetition)
            return
        }
        if pliesWithoutProgress >= Game.noProgressPlyLimit {
            result = .draw(.noProgress)
            return
        }
        // The side to move loses when it has no pieces or no legal move.
        if board.count(of: turn) == 0
            || MoveGenerator.legalMoves(on: board, for: turn).isEmpty {
            result = .win(turn.opponent)
        }
    }

    private static func positionKey(board: Board, turn: PlayerColor) -> String {
        var key = turn.rawValue + ":"
        for square in board.squares {
            switch square {
            case .none: key += "."
            case .some(let piece):
                key += piece.color == .white
                    ? (piece.isKing ? "W" : "w")
                    : (piece.isKing ? "B" : "b")
            }
        }
        return key
    }
}
