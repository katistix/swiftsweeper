// Needed for Timer, ObservableObject etc.
import Combine
// The main UI framework
import SwiftUI

// Needed for NSViewRepresentable and mouse events on macOS
#if os(macOS)
    import AppKit
#endif

// MARK: - Supporting Data Structures

enum GameState {
    case playing, won, lost
}

// Added Equatable conformance for potentially better ForEach performance
struct Cell: Identifiable, Equatable {
    let id = UUID()
    var isMine: Bool = false
    var isRevealed: Bool = false
    var isFlagged: Bool = false
    var neighboringMines: Int = 0

    // Equatable conformance implementation
    static func == (lhs: Cell, rhs: Cell) -> Bool {
        // Only compare properties relevant to display changes
        return lhs.id == rhs.id  // Essential for Identifiable
            && lhs.isRevealed == rhs.isRevealed && lhs.isFlagged == rhs.isFlagged
            && lhs.isMine == rhs.isMine  // Needed if mine appearance changes on reveal
            && lhs.neighboringMines == rhs.neighboringMines  // Needed for number display
    }
}

// MARK: - Game View Model (Logic - Unchanged)

class GameViewModel: ObservableObject {
    let rows = 12
    let cols = 10
    let mineCount = 15

    @Published var grid: [[Cell]] = []
    @Published var gameState: GameState = .playing
    @Published var flagsPlaced: Int = 0
    @Published var elapsedTime: Int = 0

    private var timer: Timer?
    private var isFirstTap: Bool = true

    init() {
        resetGame()
    }

    // --- Game Logic Methods (Identical to previous version) ---
    func resetGame() {
        stopGameTimer()
        gameState = .playing
        flagsPlaced = 0
        elapsedTime = 0
        isFirstTap = true
        grid = createNewGrid()
    }
    private func createNewGrid() -> [[Cell]] {
        Array(repeating: Array(repeating: Cell(), count: cols), count: rows)
    }
    private func setupBoard(firstTapRow: Int, firstTapCol: Int) {
        placeMines(avoidRow: firstTapRow, avoidCol: firstTapCol)
        calculateNeighborCounts()
    }
    private func placeMines(avoidRow: Int, avoidCol: Int) {
        var placedMines = 0
        var potentialMineLocations = (0..<rows).flatMap { r in (0..<cols).map { c in (r, c) } }
            .filter { $0 != avoidRow || $1 != avoidCol }
        potentialMineLocations.shuffle()
        for (r, c) in potentialMineLocations.prefix(mineCount) {
            if isValid(row: r, col: c) {
                grid[r][c].isMine = true
                placedMines += 1
            }
            if placedMines >= mineCount { break }
        }
        if placedMines < mineCount {
            print("Warning: Could only place \(placedMines)/\(mineCount) mines.")
        }
    }
    private func calculateNeighborCounts() {
        for r in 0..<rows {
            for c in 0..<cols {
                guard !grid[r][c].isMine else { continue }
                var count = 0
                for dr in -1...1 {
                    for dc in -1...1 {
                        if dr == 0 && dc == 0 { continue }
                        let nr = r + dr
                        let nc = c + dc
                        if isValid(row: nr, col: nc) && grid[nr][nc].isMine { count += 1 }
                    }
                }
                grid[r][c].neighboringMines = count
            }
        }
    }
    func cellTapped(row: Int, col: Int) {
        guard gameState == .playing, isValid(row: row, col: col) else { return }
        if isFirstTap {
            isFirstTap = false
            setupBoard(firstTapRow: row, firstTapCol: col)
            if timer == nil { startGameTimer() }
        } else if timer == nil && gameState == .playing {
            startGameTimer()
        }
        guard !grid[row][col].isRevealed && !grid[row][col].isFlagged else { return }
        grid[row][col].isRevealed = true
        if grid[row][col].isMine {
            triggerGameOver(won: false)
            return
        }
        if grid[row][col].neighboringMines == 0 { revealAdjacentCells(row: row, col: col) }
        checkWinCondition()
    }
    func cellFlagged(row: Int, col: Int) {
        guard gameState == .playing, isValid(row: row, col: col) else { return }
        guard !grid[row][col].isRevealed else { return }
        grid[row][col].isFlagged.toggle()
        flagsPlaced += grid[row][col].isFlagged ? 1 : -1
    }
    private func revealAdjacentCells(row: Int, col: Int) {
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                let nr = row + dr
                let nc = col + dc
                if isValid(row: nr, col: nc) && !grid[nr][nc].isRevealed && !grid[nr][nc].isFlagged
                {
                    grid[nr][nc].isRevealed = true
                    if grid[nr][nc].neighboringMines == 0 { revealAdjacentCells(row: nr, col: nc) }
                }
            }
        }
    }
    private func checkWinCondition() {
        guard gameState == .playing else { return }
        let revealedCount = grid.flatMap { $0 }.filter { $0.isRevealed && !$0.isMine }.count
        let totalNonMineCells = (rows * cols) - mineCount
        if revealedCount == totalNonMineCells { triggerGameOver(won: true) }
    }
    private func triggerGameOver(won: Bool) {
        guard gameState == .playing else { return }
        gameState = won ? .won : .lost
        stopGameTimer()
        if !won { revealAllMines() } else { autoFlagRemainingMines() }
    }
    private func revealAllMines() {
        for r in 0..<rows {
            for c in 0..<cols { if grid[r][c].isMine { grid[r][c].isRevealed = true } }
        }
    }
    private func autoFlagRemainingMines() {
        var newFlags = 0
        for r in 0..<rows {
            for c in 0..<cols {
                if grid[r][c].isMine && !grid[r][c].isFlagged {
                    grid[r][c].isFlagged = true
                    newFlags += 1
                }
            }
        }
        flagsPlaced += newFlags
    }
    private func startGameTimer() {
        stopGameTimer()
        elapsedTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.gameState == .playing { self.elapsedTime += 1 } else { self.stopGameTimer() }
        }
    }
    private func stopGameTimer() {
        timer?.invalidate()
        timer = nil
    }
    private func isValid(row: Int, col: Int) -> Bool {
        row >= 0 && row < rows && col >= 0 && col < cols
    }
}

// MARK: - Right Click Handling (macOS - Unchanged)

#if os(macOS)
    struct RightClickableView<Content: View>: NSViewRepresentable {
        var content: Content
        var onLeftClick: () -> Void
        var onRightClick: () -> Void

        func makeNSView(context: Context) -> RightClickHostingView<Content> {
            let hostingView = RightClickHostingView(rootView: content)
            hostingView.onLeftClick = onLeftClick
            hostingView.onRightClick = onRightClick
            return hostingView
        }
        func updateNSView(_ nsView: RightClickHostingView<Content>, context: Context) {
            nsView.rootView = content
        }
    }
    class RightClickHostingView<Content: View>: NSHostingView<Content> {
        var onLeftClick: (() -> Void)?
        var onRightClick: (() -> Void)?
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 1 { onLeftClick?() }
            super.mouseDown(with: event)
        }
        override func rightMouseDown(with event: NSEvent) { onRightClick?() /* Omit super */ }
    }
#endif  // os(macOS)

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()
    private let cellSize: CGFloat = 32

    var body: some View {
        ZStack {
            // Cleaner Background
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            // Or a very subtle gradient if preferred
            /*
             LinearGradient(
                 gradient: Gradient(colors: [Color(white: 0.95), Color(white: 0.85)]),
                 startPoint: .top, endPoint: .bottom
             ).ignoresSafeArea()
             */

            VStack(spacing: 12) {  // Slightly tighter spacing
                InfoBarView(
                    flagsRemaining: viewModel.mineCount - viewModel.flagsPlaced,
                    elapsedTime: viewModel.elapsedTime,
                    gameState: viewModel.gameState,
                    resetAction: viewModel.resetGame
                )
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .cornerRadius(10)  // Slightly less rounding
                .shadow(color: .black.opacity(0.06), radius: 3, y: 1)  // Even subtler shadow

                GridView(
                    grid: viewModel.grid,
                    cellSize: cellSize,
                    cellTappedAction: viewModel.cellTapped,
                    cellFlagAction: viewModel.cellFlagged
                )
                .padding(4)
                .background(.regularMaterial)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)  // Subtler shadow

                Spacer()
            }
            .padding()  // Keep overall padding

            if viewModel.gameState != .playing {
                GameOverView(
                    didWin: viewModel.gameState == .won,
                    resetAction: viewModel.resetGame
                )
                .transition(.opacity.combined(with: .scale))  // Keep transition for overlay
                .zIndex(1)
            }
        }
        // REMOVED .animation modifiers
    }
}

// MARK: - Subviews

struct InfoBarView: View {
    let flagsRemaining: Int
    let elapsedTime: Int
    let gameState: GameState
    let resetAction: () -> Void

    var body: some View {
        HStack {
            Label {
                Text("\(flagsRemaining)").font(
                    .system(.title3, design: .monospaced).weight(.medium)
                ).frame(minWidth: 40, alignment: .leading)
            } icon: {
                Image(systemName: "flag.fill").foregroundColor(.red)
            }
            Spacer()
            Button(action: resetAction) {
                Image(systemName: faceImageName).font(.system(size: 28)).foregroundColor(faceColor)
                // REMOVED conditional shadow on face
            }
            .buttonStyle(.plain).frame(width: 35, height: 35)
            Spacer()
            Label {
                Text("\(elapsedTime)").font(.system(.title3, design: .monospaced).weight(.medium))
                    .frame(minWidth: 40, alignment: .trailing)
            } icon: {
                Image(systemName: "timer").foregroundColor(.blue)
            }
        }
        .foregroundStyle(.primary)
    }
    private var faceImageName: String {
        switch gameState {
        case .playing: "face.smiling"
        case .won: "sunglasses"
        case .lost: "face.dizzy"
        }
    }
    private var faceColor: Color {
        switch gameState {
        case .playing: .yellow
        case .won: .green
        case .lost: .red
        }
    }
}

struct GridView: View {
    let grid: [[Cell]]
    let cellSize: CGFloat
    let cellTappedAction: (Int, Int) -> Void
    let cellFlagAction: (Int, Int) -> Void

    private var rowCount: Int { grid.count }
    private var colCount: Int { grid.first?.count ?? 0 }

    var body: some View {
        VStack(spacing: 1) {
            ForEach(0..<rowCount, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<colCount, id: \.self) { col in
                        let cell = grid[row][col]
                        #if os(macOS)
                            RightClickableView(
                                content: CleanedCellView(cell: cell, size: cellSize),  // Use CleanedCellView
                                onLeftClick: { cellTappedAction(row, col) },
                                onRightClick: { cellFlagAction(row, col) }
                            )
                            .frame(width: cellSize, height: cellSize)
                        #else
                            CleanedCellView(cell: cell, size: cellSize)  // Use CleanedCellView
                                .frame(width: cellSize, height: cellSize)
                                .onTapGesture { cellTappedAction(row, col) }
                                .onLongPressGesture(minimumDuration: 0.3) {
                                    cellFlagAction(row, col)
                                }
                        #endif
                    }
                }
            }
        }
        .frame(
            width: CGFloat(colCount) * (cellSize + 1) - 1,
            height: CGFloat(rowCount) * (cellSize + 1) - 1
        )
        .background(Color.secondary.opacity(0.4))  // Subtler grid line color
        .clipped()
    }
}

// CLEANED Cell View Content
struct CleanedCellView: View {
    let cell: Cell
    let size: CGFloat

    private let cornerRadiusRatio: CGFloat = 0.1
    private let contentScale: CGFloat = 0.55

    var body: some View {
        ZStack {
            // --- Cleaned Background ---
            RoundedRectangle(cornerRadius: size * cornerRadiusRatio)
                .fill(cellBackground)
            // REMOVED the overlay stroke for cleaner look

            // --- Cell Content (Flag, Mine, Number) ---
            cellContent
                .font(.system(size: size * contentScale, weight: .bold, design: .rounded))
        }
        .frame(width: size, height: size)
    }

    // Determine background (Color or Material)
    private var cellBackground: AnyShapeStyle {
        if cell.isRevealed {
            if cell.isMine {
                return AnyShapeStyle(Color.red.opacity(0.5))  // Slightly less intense red
            } else {
                // Brighter gray for revealed cells - cleaner contrast with Material
                return AnyShapeStyle(Color(white: 0.9))
            }
        } else {
            // Keep Material for glass effect on unrevealed
            return AnyShapeStyle(.thinMaterial)
        }
    }

    // Cell content view (logic unchanged, styling simplified)
    @ViewBuilder private var cellContent: some View {
        if cell.isFlagged && !cell.isRevealed {
            Image(systemName: "flag.fill")
                .resizable().scaledToFit()
                .frame(width: size * contentScale)
                .foregroundColor(.red.opacity(0.9))  // Slightly less intense flag
        } else if cell.isRevealed {
            if cell.isMine {
                Image(systemName: "circle.fill")
                    .resizable().scaledToFit()
                    .frame(width: size * contentScale * 0.75)  // Adjusted size
                    .foregroundColor(.black)
            } else if cell.neighboringMines > 0 {
                Text("\(cell.neighboringMines)")
                    .foregroundColor(numberColor)
            }
        }
    }

    // Number colors (unchanged logic)
    private var numberColor: Color {
        switch cell.neighboringMines {
        case 1: .blue
        case 2: Color(red: 0.0, green: 0.5, blue: 0.1)
        case 3: .red
        case 4: Color(red: 0.0, green: 0.0, blue: 0.6)
        case 5: Color(red: 0.6, green: 0.0, blue: 0.0)
        case 6: Color(red: 0.0, green: 0.5, blue: 0.5)
        case 7: .black
        case 8: Color(white: 0.4)
        default: .clear
        }
    }
}

// GameOverView (Unchanged - retains prominence)
struct GameOverView: View {
    let didWin: Bool
    let resetAction: () -> Void

    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: didWin ? "party.popper.fill" : "explosion.fill").font(
                .system(size: 60)
            ).foregroundColor(didWin ? .yellow : .orange).shadow(
                color: .black.opacity(0.3), radius: 5)
            Text(didWin ? "Congratulations!" : "Game Over!").font(
                .system(.largeTitle, design: .rounded).weight(.bold)
            ).foregroundColor(didWin ? .green : .red)
            Button(didWin ? "Play Again?" : "Try Again?", action: resetAction).font(
                .title2.weight(.semibold)
            ).buttonStyle(.borderedProminent).tint(didWin ? .green : .red).controlSize(.large)
                .keyboardShortcut(.defaultAction).shadow(
                    color: .black.opacity(0.2), radius: 5, y: 2)
        }
        .padding(.vertical, 40).padding(.horizontal, 50).background(.ultraThickMaterial)
        .cornerRadius(25).overlay(
            RoundedRectangle(cornerRadius: 25).stroke(.white.opacity(0.2), lineWidth: 1)
        ).shadow(color: .black.opacity(0.3), radius: 15, y: 5)
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 420, height: 600)
    }
}
