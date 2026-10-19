import Foundation
import DamaEngine

extension Position {
    /// Chess-style square label: columns are files a–h, ranks count 8→1
    /// from Black's edge to White's edge. (5,5) is "f3".
    var label: String {
        let file = String(UnicodeScalar(UInt8(97 + col)))
        return "\(file)\(8 - row)"
    }
}

extension Move {
    /// "f3 takes d5, b7" style description for capture-path choices.
    var choiceLabel: String {
        if isCapture {
            let taken = captured.map { $0.label }.joined(separator: ", ")
            let via = path.dropFirst().dropLast().map { $0.label }
            let route = via.isEmpty ? "" : " via " + via.joined(separator: ", ")
            return "Take \(taken)\(route) — land on \(to.label)"
        }
        return "Move to \(to.label)"
    }
}

/// Drives one Player-vs-Computer game. The human plays White (bottom,
/// moves first); the computer plays Black and is called *Dama*.
@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var game = Game()
    @Published private(set) var selected: Position?
    /// When several distinct capture lines land on the same square (same
    /// length, different pieces), the player picks which one to play.
    @Published private(set) var pendingOptions: [Move] = []
    @Published private(set) var isAIThinking = false
    @Published var difficulty: DamaAI.Difficulty = .medium

    let humanColor: PlayerColor = .white
    private var undoStack: [Game] = []
    private var generation = 0

    // MARK: Derived state

    var legalMoves: [Move] { game.legalMoves }
    var isHumanTurn: Bool { game.turn == humanColor && game.result == nil }
    var selectablePositions: Set<Position> { Set(legalMoves.map { $0.from }) }
    var selectedDestinations: Set<Position> {
        guard let selected else { return [] }
        return Set(legalMoves.filter { $0.from == selected }.map { $0.to })
    }
    var lastMove: Move? { game.history.last }

    var capturedByHuman: Int { 12 - game.board.count(of: humanColor.opponent) }
    var capturedByAI: Int { 12 - game.board.count(of: humanColor) }

    var statusText: String {
        switch game.result {
        case .win(let winner):
            return winner == humanColor ? "You win — chapeau!" : "Dama wins this one."
        case .draw(.threefoldRepetition):
            return "Draw — same position three times."
        case .draw(.noProgress):
            return "Draw — 40 moves with no progress."
        case .draw:
            return "Draw."
        case nil:
            if isAIThinking { return "Dama is thinking…" }
            if game.turn == humanColor {
                if let first = legalMoves.first, first.isCapture {
                    let count = first.captured.count
                    return count > 1
                        ? "Your move — capture is forced: take \(count) pieces."
                        : "Your move — capture is forced."
                }
                return "Your move."
            }
            return "Dama to move."
        }
    }

    // MARK: Interaction

    func tapSquare(_ position: Position) {
        guard isHumanTurn, !isAIThinking else { return }

        if !pendingOptions.isEmpty {
            pendingOptions = []
            selected = nil
            return
        }

        if let selected, selected == position {
            self.selected = nil
            return
        }

        if let selected, selectedDestinations.contains(position) {
            let variants = legalMoves.filter { $0.from == selected && $0.to == position }
            if variants.count == 1 {
                playHumanMove(variants[0])
            } else {
                pendingOptions = variants
            }
            return
        }

        if selectablePositions.contains(position) {
            selected = position
        } else {
            selected = nil
        }
    }

    func choosePendingOption(_ move: Move) {
        pendingOptions = []
        playHumanMove(move)
    }

    func newGame() {
        generation += 1
        game = Game()
        selected = nil
        pendingOptions = []
        undoStack = []
        isAIThinking = false
    }

    /// Takes back the last full round (your move and Dama's reply).
    func undoRound() {
        guard let snapshot = undoStack.popLast() else { return }
        generation += 1
        game = snapshot
        selected = nil
        pendingOptions = []
        isAIThinking = false
    }

    var canUndo: Bool { !undoStack.isEmpty && !isAIThinking }

    // MARK: Move plumbing

    private func playHumanMove(_ move: Move) {
        undoStack.append(game)
        selected = nil
        game.apply(move)
        triggerAI()
    }

    private func triggerAI() {
        guard game.result == nil, game.turn != humanColor else { return }
        isAIThinking = true
        let snapshot = game
        let level = difficulty
        let aiColor = humanColor.opponent
        let token = generation
        Task.detached(priority: .userInitiated) {
            // Small pause so the reply doesn't feel instantaneous.
            try? await Task.sleep(nanoseconds: 350_000_000)
            let move = DamaAI.bestMove(for: aiColor, in: snapshot, difficulty: level)
            await MainActor.run { [weak self] in
                guard let self, self.generation == token else { return }
                self.isAIThinking = false
                if let move { self.game.apply(move) }
            }
        }
    }
}
