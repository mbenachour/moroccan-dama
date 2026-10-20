import Foundation

/// Generates legal moves under Moroccan dama rules:
///
/// - Men move and capture diagonally **forward only** — never backward.
/// - Capturing is mandatory, and the **maximum capture rule** applies: when
///   several capture lines exist, only those capturing the most pieces are
///   legal. (Moroccan rule: on a tie of count, any of the lines is legal —
///   there is no Spanish-style "most kings" tiebreak.)
/// - Kings are *flying*: they move and capture any distance along a diagonal
///   and may land on any empty square beyond a captured piece.
/// - Multi-captures chain within one move. Captured pieces are removed only
///   when the whole move ends (Spanish-family rule), so during a sequence
///   they still block squares and no piece can be jumped twice.
/// - A man that reaches the far row during a capture stops there and crowns;
///   it does not continue capturing as a king in the same move.
public enum MoveGenerator {

    public static func legalMoves(on board: Board, for color: PlayerColor) -> [Move] {
        let captures = allCaptureMoves(on: board, for: color)
        guard captures.isEmpty else {
            let best = captures.map { $0.captured.count }.max() ?? 0
            return captures.filter { $0.captured.count == best }
        }
        return quietMoves(on: board, for: color)
    }

    /// Legal moves under a ruleset. Café play allows every capture line
    /// (each is a *complete* chain — you may choose a shorter line than
    /// another piece's, but a piece that starts capturing finishes its
    /// chain) plus every quiet move; the maximum-capture obligation is
    /// enforced socially, by huffing, instead of by the move list.
    public static func moves(on board: Board, for color: PlayerColor, variant: GameVariant) -> [Move] {
        switch variant {
        case .tournament:
            return legalMoves(on: board, for: color)
        case .cafe:
            return allCaptureMoves(on: board, for: color) + quietMoves(on: board, for: color)
        }
    }

    /// The most pieces `color` could capture in a single move here.
    public static func maxCaptureCount(on board: Board, for color: PlayerColor) -> Int {
        allCaptureMoves(on: board, for: color).map { $0.captured.count }.max() ?? 0
    }

    /// The squares of `color`'s pieces that have at least one capture —
    /// the pieces that *should* have captured, and therefore the pieces
    /// exposed to huffing when a lesser move is played instead.
    public static func captureOrigins(on board: Board, for color: PlayerColor) -> Set<Position> {
        Set(allCaptureMoves(on: board, for: color).map { $0.from })
    }

    /// Every capture sequence available to a color, before the maximum
    /// capture filter is applied. Each returned move is a *complete*
    /// sequence — a piece that can keep capturing must do so.
    public static func allCaptureMoves(on board: Board, for color: PlayerColor) -> [Move] {
        var moves: [Move] = []
        for (position, piece) in board.pieces(of: color) {
            var stripped = board
            stripped[position] = nil // the moving piece is "in hand" during the sequence
            moves += captureSequences(
                board: stripped,
                position: position,
                piece: piece,
                capturedSoFar: [],
                path: [position],
                captured: []
            )
        }
        return moves.filter { $0.isCapture }
    }

    // MARK: - Capture search

    /// All maximal capture continuations from `position`. Returns an empty
    /// array when the piece cannot capture from here.
    private static func captureSequences(
        board: Board,
        position: Position,
        piece: Piece,
        capturedSoFar: Set<Position>,
        path: [Position],
        captured: [Position]
    ) -> [Move] {
        piece.isKing
            ? kingCaptureSequences(board: board, position: position, piece: piece,
                                   capturedSoFar: capturedSoFar, path: path, captured: captured)
            : manCaptureSequences(board: board, position: position, piece: piece,
                                  capturedSoFar: capturedSoFar, path: path, captured: captured)
    }

    private static func manCaptureSequences(
        board: Board, position: Position, piece: Piece,
        capturedSoFar: Set<Position>, path: [Position], captured: [Position]
    ) -> [Move] {
        let forward = piece.color.forwardDelta
        var results: [Move] = []
        for dc in [-1, 1] {
            let victim = position.offset(row: forward, col: dc)
            let landing = position.offset(row: 2 * forward, col: 2 * dc)
            guard landing.isOnBoard,
                  let target = board[victim],
                  target.color != piece.color,
                  !capturedSoFar.contains(victim),
                  board[landing] == nil
            else { continue }

            let newCaptured = captured + [victim]
            let newPath = path + [landing]
            if landing.row == piece.color.promotionRow {
                // Crownhead stop: the move ends on the promotion row.
                results.append(Move(path: newPath, captured: newCaptured))
                continue
            }
            let continuations = captureSequences(
                board: board, position: landing, piece: piece,
                capturedSoFar: capturedSoFar.union([victim]),
                path: newPath, captured: newCaptured
            )
            if continuations.isEmpty {
                results.append(Move(path: newPath, captured: newCaptured))
            } else {
                results += continuations
            }
        }
        return results
    }

    private static func kingCaptureSequences(
        board: Board, position: Position, piece: Piece,
        capturedSoFar: Set<Position>, path: [Position], captured: [Position]
    ) -> [Move] {
        var results: [Move] = []
        for (dr, dc) in [(-1, -1), (-1, 1), (1, -1), (1, 1)] {
            // Scan along the diagonal to the first occupied square.
            var step = 1
            var victim: Position?
            while true {
                let square = position.offset(row: dr * step, col: dc * step)
                guard square.isOnBoard else { break }
                if let occupant = board[square] {
                    if occupant.color != piece.color && !capturedSoFar.contains(square) {
                        victim = square
                    }
                    break // any piece blocks the scan, friend or foe
                }
                step += 1
            }
            guard let victimSquare = victim else { continue }

            // Every empty square beyond the victim is a possible landing.
            var landingStep = step + 1
            while true {
                let landing = position.offset(row: dr * landingStep, col: dc * landingStep)
                guard landing.isOnBoard, board[landing] == nil else { break }
                let newCaptured = captured + [victimSquare]
                let newPath = path + [landing]
                let continuations = captureSequences(
                    board: board, position: landing, piece: piece,
                    capturedSoFar: capturedSoFar.union([victimSquare]),
                    path: newPath, captured: newCaptured
                )
                if continuations.isEmpty {
                    results.append(Move(path: newPath, captured: newCaptured))
                } else {
                    results += continuations
                }
                landingStep += 1
            }
        }
        return results
    }

    // MARK: - Quiet moves

    public static func quietMoves(on board: Board, for color: PlayerColor) -> [Move] {
        var moves: [Move] = []
        for (position, piece) in board.pieces(of: color) {
            if piece.isKing {
                for (dr, dc) in [(-1, -1), (-1, 1), (1, -1), (1, 1)] {
                    var step = 1
                    while true {
                        let dest = position.offset(row: dr * step, col: dc * step)
                        guard dest.isOnBoard, board[dest] == nil else { break }
                        moves.append(Move(path: [position, dest]))
                        step += 1
                    }
                }
            } else {
                let forward = color.forwardDelta
                for dc in [-1, 1] {
                    let dest = position.offset(row: forward, col: dc)
                    if dest.isOnBoard, board[dest] == nil {
                        moves.append(Move(path: [position, dest]))
                    }
                }
            }
        }
        return moves
    }
}
