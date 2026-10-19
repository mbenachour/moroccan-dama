import Foundation

/// The two players. White sits at the bottom of the board and moves first,
/// as in Moroccan / Spanish-family dama.
public enum PlayerColor: String, Codable, CaseIterable, Sendable {
    case white
    case black

    public var opponent: PlayerColor { self == .white ? .black : .white }

    /// Row direction a man travels: white moves toward row 0, black toward row 7.
    public var forwardDelta: Int { self == .white ? -1 : 1 }

    /// The far row on which a man of this color is crowned.
    public var promotionRow: Int { self == .white ? 0 : 7 }

    /// The home rows a color starts on.
    public var homeRows: [Int] { self == .white ? [5, 6, 7] : [0, 1, 2] }
}

/// A single checker. A crowned piece is itself called a *dama*.
public struct Piece: Equatable, Codable, Sendable {
    public var color: PlayerColor
    public var isKing: Bool

    public init(color: PlayerColor, isKing: Bool = false) {
        self.color = color
        self.isKing = isKing
    }
}

/// A square on the 8x8 board. Row 0 is the far (black) edge, row 7 the near
/// (white) edge; column 0 is White's left.
///
/// Playable squares are the dark squares. The Moroccan board is *mirrored*:
/// the double corner is on each player's left and the near-left corner
/// (row 7, col 0) is a light square — so playable squares satisfy
/// `(row + col) % 2 == 0`.
public struct Position: Hashable, Codable, Sendable, Comparable {
    public var row: Int
    public var col: Int

    public init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }

    public var isOnBoard: Bool { (0..<8).contains(row) && (0..<8).contains(col) }
    public var isPlayableSquare: Bool { isOnBoard && (row + col) % 2 == 0 }
    public var index: Int { row * 8 + col }

    public func offset(row dr: Int, col dc: Int) -> Position {
        Position(row: row + dr, col: col + dc)
    }

    public static func < (lhs: Position, rhs: Position) -> Bool {
        lhs.row != rhs.row ? lhs.row < rhs.row : lhs.col < rhs.col
    }
}

/// The board: 64 squares, only the 32 playable ones are ever occupied.
public struct Board: Equatable, Codable, Sendable {
    public private(set) var squares: [Piece?]

    public init(squares: [Piece?]) {
        precondition(squares.count == 64, "board needs exactly 64 squares")
        self.squares = squares
    }

    /// The standard starting position: 12 men per side on the three home rows.
    public static var initial: Board {
        var squares = [Piece?](repeating: nil, count: 64)
        for color in PlayerColor.allCases {
            for row in color.homeRows {
                for col in 0..<8 where (row + col) % 2 == 0 {
                    squares[row * 8 + col] = Piece(color: color)
                }
            }
        }
        return Board(squares: squares)
    }

    /// An empty board, for setting up test or puzzle positions.
    public static var empty: Board { Board(squares: [Piece?](repeating: nil, count: 64)) }

    public subscript(position: Position) -> Piece? {
        get { position.isOnBoard ? squares[position.index] : nil }
        set { if position.isOnBoard { squares[position.index] = newValue } }
    }

    public func pieces(of color: PlayerColor) -> [(position: Position, piece: Piece)] {
        var result: [(Position, Piece)] = []
        for row in 0..<8 {
            for col in 0..<8 {
                let pos = Position(row: row, col: col)
                if let piece = self[pos], piece.color == color {
                    result.append((pos, piece))
                }
            }
        }
        return result
    }

    public func count(of color: PlayerColor) -> Int { pieces(of: color).count }
}

/// One complete move: the path the moving piece travels (starting square
/// first, then every landing square) and every piece it captures, in order.
///
/// A move is always the *whole* turn — multi-captures are a single `Move`
/// whose `path` has more than two entries.
public struct Move: Equatable, Sendable {
    public var path: [Position]
    public var captured: [Position]

    public init(path: [Position], captured: [Position] = []) {
        precondition(path.count >= 2, "a move needs a start and a landing")
        self.path = path
        self.captured = captured
    }

    public var from: Position { path[0] }
    public var to: Position { path[path.count - 1] }
    public var isCapture: Bool { !captured.isEmpty }

    /// True when a man ends this move on its promotion row and is crowned.
    public func promotes(on board: Board) -> Bool {
        guard let piece = board[from], !piece.isKing else { return false }
        return to.row == piece.color.promotionRow
    }

    public func applying(to board: Board) -> Board {
        var next = board
        guard let piece = next[from] else { return board }
        next[from] = nil
        for capturedPosition in captured { next[capturedPosition] = nil }
        var moved = piece
        if !piece.isKing && to.row == piece.color.promotionRow { moved.isKing = true }
        next[to] = moved
        return next
    }
}
