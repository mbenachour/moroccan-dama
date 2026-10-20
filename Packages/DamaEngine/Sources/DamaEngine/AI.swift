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
        if game.variant == .cafe {
            return cafeBestMove(for: color, in: game, difficulty: difficulty)
        }
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

    // MARK: - Café Mode

    /// Café search depth by difficulty. Café branching is wider than
    /// tournament branching (quiet moves are always legal), so the café
    /// search runs one ply shallower than the tournament search.
    private static func cafeDepth(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: return 2
        case .medium: return 3
        case .hard: return 5
        }
    }

    private static func cafeBestMove(for color: PlayerColor, in game: Game, difficulty: Difficulty) -> Move? {
        let moves = game.legalMoves
        guard !moves.isEmpty else { return nil }
        if moves.count == 1 { return moves[0] }

        // Dama never *forgets* a capture. The café search prices the
        // huff into every line, so an under-capture is only ever chosen
        // when it still comes out ahead after the opponent blows the
        // most valuable offending piece — a calculated trade, never a
        // lapse. (An earlier build deliberately "forgot" captures on
        // the lower difficulties; the café doesn't work that way.)
        let depth = cafeDepth(for: difficulty)
        let scored = moves.map { move -> (move: Move, score: Int) in
            var next = game
            next.applyUnchecked(move)
            let score = -cafeNegamax(game: next, depth: depth - 1, alpha: -Score.mate, beta: Score.mate)
            return (move, score)
        }
        let bestScore = scored.map { $0.score }.max() ?? 0

        switch difficulty {
        case .easy:
            // Easy still plays loosely — but its randomness is fenced
            // inside the full-capture pool: it may pick a weaker line
            // that takes the maximum, it may not skip a capture.
            let maxCapture = MoveGenerator.maxCaptureCount(on: game.board, for: color)
            let pool = maxCapture > 0
                ? scored.filter { $0.move.captured.count == maxCapture }
                : scored
            let poolBest = pool.map { $0.score }.max() ?? bestScore
            if Int.random(in: 0..<4) == 0 { return pool.randomElement()?.move }
            let nearBest = pool.filter { $0.score >= poolBest - 60 }
            return nearBest.randomElement()?.move
                ?? pool.first { $0.score == poolBest }?.move
                ?? scored.first { $0.score == bestScore }?.move
        case .medium, .hard:
            return scored.first { $0.score == bestScore }?.move
        }
    }

    /// Negamax over full café game states. A pending huff is resolved
    /// inside the search by the decider removing the most valuable
    /// offending piece — letting it slide is never better than taking
    /// free material, so the single resolution is exact enough.
    private static func cafeNegamax(game: Game, depth: Int, alpha: Int, beta: Int) -> Int {
        if let result = game.result {
            switch result {
            case .win(let winner): return winner == game.turn ? Score.mate + depth : -Score.mate - depth
            case .draw: return 0
            }
        }
        var game = game
        if game.pendingHuff != nil {
            if let target = bestHuffTarget(in: game) {
                game.applyHuff(at: target)
            } else {
                game.declineHuff()
            }
            return cafeNegamax(game: game, depth: depth, alpha: alpha, beta: beta)
        }
        if depth == 0 { return evaluate(board: game.board, for: game.turn) }

        var moves = game.legalMoves
        if moves.isEmpty { return -Score.mate - depth }
        moves.sort { $0.captured.count > $1.captured.count }

        var alpha = alpha
        var best = -Score.mate - 100
        for move in moves {
            var next = game
            next.applyUnchecked(move)
            let score = -cafeNegamax(game: next, depth: depth - 1, alpha: -beta, beta: -alpha)
            best = max(best, score)
            alpha = max(alpha, score)
            if alpha >= beta { break }
        }
        return best
    }

    /// The most valuable huff target in a pending-huff game: kings first,
    /// then the most advanced man. Nil when no huff is pending.
    public static func bestHuffTarget(in game: Game) -> Position? {
        guard let huff = game.pendingHuff else { return nil }
        return huff.targets.max { a, b in
            huffValue(of: game.board[a], at: a) < huffValue(of: game.board[b], at: b)
        }
    }

    private static func huffValue(of piece: Piece?, at position: Position) -> Int {
        guard let piece else { return -1 }
        if piece.isKing { return 1_000 }
        // A man one step from crowning is worth more than one at home.
        let advancement = piece.color == .white ? 7 - position.row : position.row
        return 100 + advancement * 10
    }

    /// The piece the pending huff's decider blows off — always the most
    /// valuable offender, at every difficulty. Café law is café law:
    /// miss a capture and you get blown; there is no letting it slide.
    public static func huffTarget(for color: PlayerColor, in game: Game, difficulty: Difficulty) -> Position? {
        guard let huff = game.pendingHuff, huff.decider == color else { return nil }
        return bestHuffTarget(in: game)
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
