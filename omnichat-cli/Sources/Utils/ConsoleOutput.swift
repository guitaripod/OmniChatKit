import Foundation
import Rainbow

enum ConsoleOutput {
    
    static func printHeader(_ text: String) {
        print("\n" + String(repeating: "═", count: 60).cyan.dim)
        print("  \(text)".cyan.bold)
        print(String(repeating: "═", count: 60).cyan.dim + "\n")
    }
    
    static func printSubheader(_ text: String) {
        print("\n" + String(repeating: "─", count: 40).blue.dim)
        print("  \(text)".blue)
        print(String(repeating: "─", count: 40).blue.dim)
    }
    
    static func printSuccess(_ message: String) {
        print("✅ \(message)".green)
    }
    
    static func printError(_ message: String) {
        print("❌ \(message)".red.bold)
    }
    
    static func printWarning(_ message: String) {
        print("⚠️  \(message)".yellow)
    }
    
    static func printInfo(_ message: String) {
        print("ℹ️  \(message)".blue)
    }
    
    static func printDebug(_ message: String) {
        print("🔍 \(message)".magenta.dim)
    }
    
    static func printJSON(_ data: Data) {
        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            print(prettyString.green)
        }
    }
    
    static func printKeyValue(_ key: String, _ value: String, color: NamedColor = .white) {
        let paddedKey = key.padding(toLength: 20, withPad: " ", startingAt: 0)
        print("  \(paddedKey.bold): \(value.applyingColor(color))")
    }
    
    static func printList(_ items: [String], numbered: Bool = false) {
        for (index, item) in items.enumerated() {
            if numbered {
                print("  \(String(index + 1).blue.bold). \(item)")
            } else {
                print("  • \(item)")
            }
        }
    }
    
    static func printTable(headers: [String], rows: [[String]]) {
        let columnWidths = headers.enumerated().map { index, header in
            let headerWidth = header.count
            let maxRowWidth = rows.map { $0[safe: index]?.count ?? 0 }.max() ?? 0
            return max(headerWidth, maxRowWidth) + 2
        }
        
        printTableSeparator(columnWidths)
        printTableRow(headers.map { $0.bold }, columnWidths)
        printTableSeparator(columnWidths)
        
        for row in rows {
            printTableRow(row, columnWidths)
        }
        printTableSeparator(columnWidths)
    }
    
    private static func printTableRow(_ row: [String], _ widths: [Int]) {
        var output = "│"
        for (index, cell) in row.enumerated() {
            let width = widths[safe: index] ?? 10
            let paddedCell = " " + cell.padding(toLength: width - 1, withPad: " ", startingAt: 0)
            output += paddedCell + "│"
        }
        print(output.cyan)
    }
    
    private static func printTableSeparator(_ widths: [Int]) {
        var output = "├"
        for (index, width) in widths.enumerated() {
            output += String(repeating: "─", count: width)
            output += index < widths.count - 1 ? "┼" : "┤"
        }
        print(output.cyan.dim)
    }
    
    static func printProgressBar(current: Int, total: Int, width: Int = 50) {
        let percentage = Double(current) / Double(total)
        let filled = Int(percentage * Double(width))
        let empty = width - filled
        
        let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: empty)
        let percentageText = String(format: "%.1f%%", percentage * 100)
        
        print("\r[\(bar.green)] \(percentageText.bold) (\(current)/\(total))", terminator: "")
        fflush(stdout)
        
        if current >= total {
            print()
        }
    }
    
    static func startSpinner(message: String) -> Timer {
        let spinnerChars = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
        
        class SpinnerState {
            var index = 0
        }
        let state = SpinnerState()
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            print("\r\(spinnerChars[state.index].cyan) \(message)", terminator: "")
            fflush(stdout)
            state.index = (state.index + 1) % spinnerChars.count
        }
        
        return timer
    }
    
    static func stopSpinner(_ timer: Timer) {
        timer.invalidate()
        print("\r" + String(repeating: " ", count: 80) + "\r", terminator: "")
        fflush(stdout)
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension String {
    func applyingColor(_ color: NamedColor) -> String {
        switch color {
        case .black: return self.black
        case .red: return self.red
        case .green: return self.green
        case .yellow: return self.yellow
        case .blue: return self.blue
        case .magenta: return self.magenta
        case .cyan: return self.cyan
        case .white: return self.white
        case .default: return self
        case .lightBlack: return self.lightBlack
        case .lightRed: return self.lightRed
        case .lightGreen: return self.lightGreen
        case .lightYellow: return self.lightYellow
        case .lightBlue: return self.lightBlue
        case .lightMagenta: return self.lightMagenta
        case .lightCyan: return self.lightCyan
        case .lightWhite: return self.lightWhite
        }
    }
}