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
///
/// Two rulesets: Tournament (captures forced by the move list) and Café
/// (Moroccan café rules — captures optional, under-capturing is punished
/// by *nefkh*, touch-move, bottle-cap pieces, and a sound for everything).
@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var game = Game()
    @Published private(set) var variant: GameVariant = .tournament
    @Published private(set) var selected: Position?
    /// When several distinct capture lines land on the same square (same
    /// length, different pieces), the player picks which one to play.
    @Published private(set) var pendingOptions: [Move] = []
    @Published private(set) var isAIThinking = false
    /// The square whose piece is mid-huff-animation (flying off the board).
    @Published private(set) var huffedPosition: Position?
    /// A short café callout ("Koul!", "Yeddak 3la lbidaq…"), shown briefly.
    @Published private(set) var callout: String?
    @Published var difficulty: DamaAI.Difficulty = .medium

    let humanColor: PlayerColor = .white
    private let sound = SoundPlayer.shared
    private var undoStack: [Game] = []
    private var generation = 0
    /// Café touch-move: the piece the human has committed to by touching.
    private var touchLocked: Position?
    private var announcedResult: GameResult?

    init() {
        // Visual-QA / screenshot hooks (see .github/workflows/screenshots.yml):
        //   -cafe      start in Café Mode
        //   -cafeHuff  Café Mode position where Dama has just missed a
        //               capture and the human is offered the huff
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-kings") || args.contains("-kingsT") {
            // Visual-QA position: crowned pieces next to plain men, so a
            // screenshot proves a dama can never be mistaken for a man.
            variant = args.contains("-kingsT") ? .tournament : .cafe
            var board = Board.empty
            board[Position(row: 4, col: 4)] = Piece(color: .white, isKing: true)
            board[Position(row: 5, col: 1)] = Piece(color: .white)
            board[Position(row: 6, col: 6)] = Piece(color: .white)
            board[Position(row: 2, col: 2)] = Piece(color: .black, isKing: true)
            board[Position(row: 1, col: 5)] = Piece(color: .black)
            board[Position(row: 3, col: 7)] = Piece(color: .black)
            game = Game(board: board, turn: .white, variant: variant)
        } else if args.contains("-cafeHuff") {
            variant = .cafe
            var board = Board.empty
            board[Position(row: 5, col: 1)] = Piece(color: .white)
            board[Position(row: 3, col: 5)] = Piece(color: .white)
            board[Position(row: 6, col: 2)] = Piece(color: .white)
            board[Position(row: 2, col: 6)] = Piece(color: .black)
            board[Position(row: 1, col: 5)] = Piece(color: .black)
            game = Game(board: board, turn: .black, variant: .cafe)
            // Black ignores the capture of the man on (3,5) and steps aside.
            if let quiet = game.legalMoves.first(where: {
                $0.from == Position(row: 2, col: 6) && $0.to == Position(row: 3, col: 7) && !$0.isCapture
            }) {
                game.apply(quiet)
            }
        } else if args.contains("-cafe") {
            variant = .cafe
            game = Game(variant: .cafe)
        }
    }

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

    /// A huff decision is waiting on the human (Café Mode).
    var awaitingHumanHuff: Bool { game.pendingHuff?.decider == humanColor }
    var huffTargets: [Position] { game.pendingHuff?.targets ?? [] }

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
            if awaitingHumanHuff {
                return "Dama missed a capture — Nfoukh?"
            }
            if isAIThinking { return "Dama is thinking…" }
            if game.turn == humanColor {
                if variant == .tournament, let first = legalMoves.first, first.isCapture {
                    let count = first.captured.count
                    return count > 1
                        ? "Your move — capture is forced: take \(count) pieces."
                        : "Your move — capture is forced."
                }
                if variant == .cafe,
                   MoveGenerator.maxCaptureCount(on: game.board, for: humanColor) > 0 {
                    return "Your move — a capture is there; skip it and Dama will blow."
                }
                return "Your move."
            }
            return "Dama to move."
        }
    }

    // MARK: Interaction

    func tapSquare(_ position: Position) {
        guard !isAIThinking, game.result == nil else { return }

        // Café Mode: the huff decision comes before any move.
        if let huff = game.pendingHuff {
            if huff.decider == humanColor, huff.targets.contains(position) {
                performHumanHuff(at: position)
            }
            return
        }
        guard isHumanTurn else { return }

        if !pendingOptions.isEmpty {
            pendingOptions = []
            // Café touch-move: cancelling the path choice does not
            // un-touch the piece.
            selected = variant == .cafe ? touchLocked : nil
            return
        }

        if let selected, selected == position {
            if variant == .cafe, touchLocked == position {
                showCallout("Yeddak 3la lbidaq — you touched it, you play it.")
            } else {
                self.selected = nil
            }
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
            if let lock = touchLocked, lock != position {
                showCallout("Yeddak 3la lbidaq — you touched it, you play it.")
                return
            }
            selected = position
            if variant == .cafe { touchLocked = position }
        } else if touchLocked == nil {
            selected = nil
        }
    }

    func choosePendingOption(_ move: Move) {
        pendingOptions = []
        playHumanMove(move)
    }

    func declineHumanHuff() {
        guard awaitingHumanHuff else { return }
        game.declineHuff()
        showCallout("You let it slide. This time.")
    }

    func newGame() {
        generation += 1
        game = Game(variant: variant)
        resetInteraction()
        undoStack = []
        isAIThinking = false
        announcedResult = nil
    }

    func setVariant(_ newVariant: GameVariant) {
        guard newVariant != variant else { return }
        variant = newVariant
        newGame()
    }

    /// Takes back the last full round (your move and Dama's reply).
    func undoRound() {
        guard let snapshot = undoStack.popLast() else { return }
        generation += 1
        game = snapshot
        resetInteraction()
        isAIThinking = false
        announcedResult = game.result
    }

    var canUndo: Bool { !undoStack.isEmpty && !isAIThinking }

    private func resetInteraction() {
        selected = nil
        pendingOptions = []
        touchLocked = nil
        huffedPosition = nil
        callout = nil
    }

    // MARK: Huff plumbing

    private func performHumanHuff(at position: Position) {
        animateHuff(at: position) { [weak self] in
            guard let self else { return }
            self.game.applyHuff(at: position)
            self.showCallout("Nfoukh! 💨 Off it goes.")
            self.announceResultIfNeeded()
        }
    }

    /// The puff, the flying piece, then the state change.
    private func animateHuff(at position: Position, completion: @escaping () -> Void) {
        let token = generation
        huffedPosition = position
        sound.play(.puff)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 480_000_000)
            await MainActor.run {
                guard let self, self.generation == token else { return }
                self.huffedPosition = nil
                completion()
            }
        }
    }

    /// After the human's move, if Dama is owed a huff decision she makes
    /// it (Koul!) before moving herself.
    private func resolveAIHuffThenMove() {
        guard let huff = game.pendingHuff, huff.decider == humanColor.opponent else {
            triggerAI()
            return
        }
        isAIThinking = true
        let snapshot = game
        let level = difficulty
        let aiColor = humanColor.opponent
        let token = generation
        Task.detached(priority: .userInitiated) {
            try? await Task.sleep(nanoseconds: 650_000_000)
            let target = DamaAI.huffTarget(for: aiColor, in: snapshot, difficulty: level)
            await MainActor.run { [weak self] in
                guard let self, self.generation == token else { return }
                self.isAIThinking = false
                if let target {
                    self.showCallout("Koul! Dama blows your piece off the board. 💨")
                    self.animateHuff(at: target) {
                        self.game.applyHuff(at: target)
                        self.announceResultIfNeeded()
                        if self.game.result == nil { self.triggerAI() }
                    }
                } else {
                    self.game.declineHuff()
                    self.showCallout("Dama lets it slide — this time.")
                    self.triggerAI()
                }
            }
        }
    }

    // MARK: Move plumbing

    private func playHumanMove(_ move: Move) {
        undoStack.append(game)
        selected = nil
        touchLocked = nil
        let promotes = move.promotes(on: game.board)
        game.apply(move)
        sound.play(move.isCapture ? .capture : .tok)
        if promotes { sound.play(.crown) }
        advanceAfterMove()
    }

    /// Whatever comes next after any completed move: a result, a huff
    /// decision (either side's), or Dama's turn.
    private func advanceAfterMove() {
        if announceResultIfNeeded() { return }
        if game.pendingHuff != nil {
            if awaitingHumanHuff {
                showCallout("Dama missed a capture…")
            } else {
                resolveAIHuffThenMove()
            }
            return
        }
        if game.turn != humanColor { triggerAI() }
    }

    @discardableResult
    private func announceResultIfNeeded() -> Bool {
        guard let result = game.result else { return false }
        if announcedResult != result {
            announcedResult = result
            if case .win(let winner) = result {
                sound.play(winner == humanColor ? .win : .lose)
            }
        }
        return true
    }

    private func showCallout(_ text: String) {
        callout = text
        let token = generation
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            await MainActor.run {
                guard let self, self.generation == token else { return }
                if self.callout == text { self.callout = nil }
            }
        }
    }

    private func triggerAI() {
        guard game.result == nil, game.turn != humanColor, game.pendingHuff == nil else { return }
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
                if let move {
                    let boardBefore = self.game.board
                    self.game.apply(move)
                    self.sound.play(move.isCapture ? .capture : .tok)
                    if move.promotes(on: boardBefore) {
                        self.sound.play(.crown)
                    }
                    self.advanceAfterMove()
                }
            }
        }
    }
}
