import Foundation

/// Computer opponent: negamax search with alpha-beta pruning over the pure
/// rules engine. Moroccan dama helps the search — maximum capture is
/// mandatory, so capture turns have very few legal moves and forced lines
/// run deep for free.
public struct DamaAI: Sendable {

    public enum Difficulty: String, CaseIterable, Sendable {
        case easy
        case medium
        case hard

        public var searchDepth: Int {
            switch self {
            case .easy: return 2
            case .medium: return 4
            case .hard: return 6
            }
        }

        public var displayName: String {
            switch self {
            case .easy: return "Easy"
            case .medium: return "Medium"
            case .hard: return "Hard"
            }
        }
    }

    /// The best move found for `color` in `game`, or nil when there is none.
    /// Medium and hard are deterministic; easy deliberately blunders sometimes.
    public static func bestMove(for color: PlayerColor, in game: Game, difficulty: Difficulty) -> Move? {
        let moves = MoveGenerator.legalMoves(on: game.board, for: color)
        guard !moves.isEmpty else { return nil }
        if moves.count == 1 { return moves[0] }

        let scored = moves.map { move -> (move: Move, score: Int) in
            let next = move.applying(to: game.board)
            let score = -negamax(board: next, toMove: color.opponent,
                                 depth: difficulty.searchDepth - 1,
                                 alpha: -Score.mate, beta: Score.mate)
            return (move, score)
        }
        let bestScore = scored.map { $0.score }.max() ?? 0

        switch difficulty {
        case .easy:
            // Playable but fallible: 1 in 4 turns it just picks any legal
            // move, otherwise it picks among moves close to the best.
            if Int.random(in: 0..<4) == 0 { return moves.randomElement() }
            let nearBest = scored.filter { $0.score >= bestScore - 60 }
            return nearBest.randomElement()?.move ?? scored.first?.move
        case .medium, .hard:
            return scored.first { $0.score == bestScore }?.move
        }
    }

    // MARK: - Search

    private enum Score { static let mate = 100_000 }

    private static func negamax(board: Board, toMove: PlayerColor, depth: Int, alpha: Int, beta: Int) -> Int {
        var moves = MoveGenerator.legalMoves(on: board, for: toMove)
        if moves.isEmpty {
            // Side to move is captured out or blocked: it loses. Prefer
            // slower losses (and faster wins, from the caller's side).
            return -Score.mate - depth
        }
        if depth == 0 { return evaluate(board: board, for: toMove) }

        // Captures first, longest first: they are forcing and prune hardest.
        moves.sort { $0.captured.count > $1.captured.count }

        var alpha = alpha
        var best = -Score.mate - 100
        for move in moves {
            let next = move.applying(to: board)
            let score = -negamax(board: next, toMove: toMove.opponent,
                                 depth: depth - 1, alpha: -beta, beta: -alpha)
            best = max(best, score)
            alpha = max(alpha, score)
            if alpha >= beta { break }
        }
        return best
    }

    // MARK: - Evaluation

    /// Static score from `perspective`'s point of view.
    static func evaluate(board: Board, for perspective: PlayerColor) -> Int {
        var score = 0
        for row in 0..<8 {
            for col in 0..<8 {
                let pos = Position(row: row, col: col)
                guard let piece = board[pos] else { continue }
                var value: Int
                if piece.isKing {
                    value = 300
                } else {
                    value = 100
                    // Reward advancing men; they are a crown in waiting.
                    let advancement = piece.color == .white ? 7 - row : row
                    value += advancement * 7
                    // Men still guarding the back row keep the crownhead safe.
                    if row == (piece.color == .white ? 7 : 0) { value += 5 }
                }
                // Center squares see more diagonals.
                if (2...5).contains(row) && (2...5).contains(col) { value += 6 }
                score += piece.color == perspective ? value : -value
            }
        }
        return score
    }
}
