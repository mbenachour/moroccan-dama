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

/// A pending *nefkh* (huffing) decision, Café Mode only: the player who
/// just moved captured less than the maximum available, so before the
/// side to move plays, they may remove one of the offender's pieces that
/// should have captured — or let it slide.
public struct HuffOpportunity: Equatable, Sendable {
    /// Squares (in the *current* board) holding offending pieces.
    public var targets: [Position]
    /// The player entitled to huff — always the side to move.
    public var decider: PlayerColor
    /// The player who under-captured.
    public var offender: PlayerColor

    public init(targets: [Position], decider: PlayerColor, offender: PlayerColor) {
        self.targets = targets
        self.decider = decider
        self.offender = offender
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
    public let variant: GameVariant

    /// Café Mode only: a huff decision waiting on the side to move.
    /// While set, `legalMoves` is empty — the decision comes first.
    public private(set) var pendingHuff: HuffOpportunity?

    /// Plies since the last capture or man move (the no-progress counter).
    public private(set) var pliesWithoutProgress: Int
    private var positionCounts: [String: Int]

    public static let noProgressPlyLimit = 80

    public init(board: Board = .initial, turn: PlayerColor = .white, variant: GameVariant = .tournament) {
        self.board = board
        self.turn = turn
        self.result = nil
        self.history = []
        self.variant = variant
        self.pendingHuff = nil
        self.pliesWithoutProgress = 0
        self.positionCounts = [Game.positionKey(board: board, turn: turn): 1]
        evaluateEnd()
    }

    public var legalMoves: [Move] {
        guard result == nil, pendingHuff == nil else { return [] }
        return MoveGenerator.moves(on: board, for: turn, variant: variant)
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
        // Café Mode: remember what the mover *could* have captured, so an
        // under-capture can be punished by huffing once the move lands.
        let mover = turn
        let cafeObligation: (origins: Set<Position>, max: Int)? = variant == .cafe
            ? (MoveGenerator.captureOrigins(on: board, for: mover),
               MoveGenerator.maxCaptureCount(on: board, for: mover))
            : nil

        let movingPiece = board[move.from]
        let madeProgress = move.isCapture || (movingPiece?.isKing == false)
        board = move.applying(to: board)
        history.append(move)
        turn = turn.opponent
        pliesWithoutProgress = madeProgress ? 0 : pliesWithoutProgress + 1

        let key = Game.positionKey(board: board, turn: turn)
        positionCounts[key, default: 0] += 1
        evaluateEnd(repetitionCount: positionCounts[key] ?? 0)

        if let cafeObligation, result == nil, move.captured.count < cafeObligation.max {
            // Offending pieces in the new position: a piece that itself
            // moved is tracked to its landing square.
            let targets = cafeObligation.origins
                .map { $0 == move.from ? move.to : $0 }
                .filter { board[$0]?.color == mover }
            let unique = Array(Set(targets)).sorted()
            if !unique.isEmpty {
                pendingHuff = HuffOpportunity(targets: unique, decider: turn, offender: mover)
            }
        }
    }

    /// Resolves a pending huff: the decider blows the offending piece on
    /// `position` off the board. It counts as a capture for the
    /// no-progress counter, and it can end the game. Returns false when
    /// there is no pending huff or the square is not a legal target.
    @discardableResult
    public mutating func applyHuff(at position: Position) -> Bool {
        guard let huff = pendingHuff,
              huff.targets.contains(position),
              board[position]?.color == huff.offender
        else { return false }
        board[position] = nil
        pendingHuff = nil
        pliesWithoutProgress = 0
        let key = Game.positionKey(board: board, turn: turn)
        positionCounts[key, default: 0] += 1
        evaluateEnd(repetitionCount: positionCounts[key] ?? 0)
        return true
    }

    /// Resolves a pending huff by letting the offence slide.
    public mutating func declineHuff() {
        pendingHuff = nil
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
        // A side with no pieces left loses — checked for both colors
        // because a huff can remove the *offender's* last piece during
        // the decider's turn, before the offender ever moves again.
        if board.count(of: turn.opponent) == 0 {
            result = .win(turn)
            return
        }
        // The side to move loses when it has no pieces or no legal move.
        if board.count(of: turn) == 0
            || MoveGenerator.moves(on: board, for: turn, variant: variant).isEmpty {
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
