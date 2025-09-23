import Foundation
import Combine

struct TranscriptItem {
    let id = UUID()
    let source: String
    let target: String
}

final class TranscriptModel: ObservableObject {
    @Published var items: [TranscriptItem] = []

    func append(source: String?, target: String?) {
        let s = source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let t = target?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if s.isEmpty && t.isEmpty { return }
        
        // Ensure all @Published property modifications happen on main thread
        if Thread.isMainThread {
            items.append(TranscriptItem(source: s, target: t))
            if items.count > 200 { items.removeFirst(items.count - 200) }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.items.append(TranscriptItem(source: s, target: t))
                if let count = self?.items.count, count > 200 {
                    self?.items.removeFirst(count - 200)
                }
            }
        }
    }

    func clear() {
        if Thread.isMainThread {
            items.removeAll()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.items.removeAll()
            }
        }
    }
}

