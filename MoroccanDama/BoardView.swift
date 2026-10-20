import SwiftUI
import DamaEngine

/// The 8x8 board. Mirrored the Moroccan way: White's near-left corner is a
/// light square, so playable (dark) squares have `(row + col) % 2 == 0`.
///
/// Layout is a plain grid: every cell is a real layout participant sized
/// by the grid from the available width, so the board is always exactly
/// square and can never drift, scale, or clip the way the previous
/// GeometryReader + manual-offset version did.
struct BoardView: View {
    @ObservedObject var viewModel: GameViewModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 8)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(0..<64, id: \.self) { index in
                cellView(position: Position(row: index / 8, col: index % 8))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brown.opacity(0.6), lineWidth: 2))
        .shadow(radius: 6, y: 3)
        .animation(.easeInOut(duration: 0.25), value: viewModel.game.history.count)
    }

    // MARK: Cells

    private func cellView(position: Position) -> some View {
        let isDark = (position.row + position.col) % 2 == 0
        let isSelected = viewModel.selected == position
        let isDestination = viewModel.selectedDestinations.contains(position)
        let isLastMove = viewModel.lastMove?.from == position || viewModel.lastMove?.to == position

        return ZStack {
            Rectangle()
                .fill(isDark ? Color(red: 0.62, green: 0.38, blue: 0.20)
                             : Color(red: 0.94, green: 0.85, blue: 0.66))
            if isLastMove {
                Rectangle().fill(Color.yellow.opacity(0.25))
            }
            if isSelected {
                Rectangle().stroke(Color.yellow, lineWidth: 3)
            }
            if isDestination {
                Circle()
                    .fill(Color.black.opacity(0.25))
                    .padding(15)
            }
            // Coordinates: files along White's edge, ranks along the left file.
            if position.row == 7 {
                Text(String(UnicodeScalar(UInt8(97 + position.col))))
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(isDark ? Color.white.opacity(0.85) : Color.brown.opacity(0.85))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(2)
            }
            if position.col == 0 {
                Text("\(8 - position.row)")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(isDark ? Color.white.opacity(0.85) : Color.brown.opacity(0.85))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(2)
            }
            if let piece = viewModel.game.board[position] {
                pieceView(piece: piece, isSelected: isSelected)
                    .offset(x: viewModel.huffedPosition == position ? -16 : 0,
                            y: viewModel.huffedPosition == position ? -30 : 0)
                    .scaleEffect(viewModel.huffedPosition == position ? 1.3 : 1.0)
                    .opacity(viewModel.huffedPosition == position ? 0.1 : 1.0)
                    .rotationEffect(.degrees(viewModel.huffedPosition == position ? -28 : 0))
                    .animation(.easeIn(duration: 0.45), value: viewModel.huffedPosition)
            }
            // Café Mode: pieces the human may blow off pulse with a ring.
            if viewModel.awaitingHumanHuff, viewModel.huffTargets.contains(position) {
                PulsingHuffRing()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
        .onTapGesture { viewModel.tapSquare(position) }
    }

    // MARK: Pieces

    private func pieceView(piece: Piece, isSelected: Bool) -> some View {
        Group {
            if viewModel.variant == .cafe {
                capView(piece: piece, isSelected: isSelected)
            } else {
                discView(piece: piece, isSelected: isSelected)
            }
        }
    }

    // MARK: Bottle caps (Café Mode)

    /// A crimped bottle cap — the traditional café piece. Gold for White,
    /// deep red for Black, stamped with a star (or a crown for a dama).
    private func capView(piece: Piece, isSelected: Bool) -> some View {
        let isWhite = piece.color == .white
        return ZStack {
            BottleCapShape()
                .fill(
                    LinearGradient(
                        colors: isWhite
                            ? [Color(red: 1.0, green: 0.86, blue: 0.42), Color(red: 0.76, green: 0.55, blue: 0.15)]
                            : [Color(red: 0.66, green: 0.18, blue: 0.14), Color(red: 0.32, green: 0.07, blue: 0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    BottleCapShape()
                        .stroke(Color.black.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
            Circle()
                .fill(Color.white.opacity(isWhite ? 0.22 : 0.16))
                .padding(7)
            Image(systemName: piece.isKing ? "crown.fill" : "star.fill")
                .resizable()
                .scaledToFit()
                .frame(width: piece.isKing ? 19 : 13, height: piece.isKing ? 19 : 13)
                .foregroundStyle(isWhite
                                 ? Color(red: 0.45, green: 0.30, blue: 0.05).opacity(0.85)
                                 : Color(red: 1.0, green: 0.88, blue: 0.75).opacity(0.9))
        }
        .padding(3)
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .allowsHitTesting(false)
    }

    // MARK: Discs (Tournament Mode)

    private func discView(piece: Piece, isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: piece.color == .white
                            ? [Color(red: 1.0, green: 0.98, blue: 0.92), Color(red: 0.87, green: 0.80, blue: 0.66)]
                            : [Color(red: 0.23, green: 0.16, blue: 0.11), Color(red: 0.05, green: 0.03, blue: 0.02)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(Circle().stroke(piece.color == .white ? Color.brown.opacity(0.55) : Color.black, lineWidth: 1.5))
                .overlay(
                    Circle()
                        .stroke(piece.color == .white ? Color.brown.opacity(0.35) : Color.white.opacity(0.25), lineWidth: 1.5)
                        .padding(6)
                )
                .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
            if piece.isKing {
                Image(systemName: "crown.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(piece.color == .white ? Color(red: 0.72, green: 0.5, blue: 0.1) : Color(red: 0.95, green: 0.77, blue: 0.3))
            }
        }
        .padding(4)
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .allowsHitTesting(false)
    }
}

/// The crimped outline of a bottle cap: 21 flutes around the rim.
struct BottleCapShape: Shape {
    func path(in rect: CGRect) -> Path {
        let crimps = 21
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for i in 0...(crimps * 2) {
            let angle = Double(i) * .pi / Double(crimps) - .pi / 2
            let r = i % 2 == 0 ? radius : radius * 0.93
            let point = CGPoint(x: center.x + r * CGFloat(cos(angle)),
                                y: center.y + r * CGFloat(sin(angle)))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// A breathing orange ring marking a piece that can be huffed.
struct PulsingHuffRing: View {
    @State private var pulsing = false

    var body: some View {
        Circle()
            .stroke(Color(red: 0.95, green: 0.45, blue: 0.10), lineWidth: 3)
            .padding(1)
            .scaleEffect(pulsing ? 1.0 : 0.82)
            .opacity(pulsing ? 1.0 : 0.45)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
            .allowsHitTesting(false)
    }
}
