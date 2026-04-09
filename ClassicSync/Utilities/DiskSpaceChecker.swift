import Foundation

enum DiskSpaceChecker {
    static let estimatedBytesPerTrack: Int64 = 30 * 1_048_576 // 30 MB

    static func availableBytes(at url: URL) -> Int64? {
        do {
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                return capacity
            }
        } catch {}
        return nil
    }

    static func hasSufficientSpace(for trackCount: Int, at url: URL) -> Bool {
        guard let available = availableBytes(at: url) else { return true }
        let needed = estimatedBytesPerTrack * Int64(trackCount)
        return available >= needed
    }

    static func formattedAvailable(at url: URL) -> String {
        guard let bytes = availableBytes(at: url) else { return "Unknown" }
        let gb = Double(bytes) / 1_073_741_824
        return String(format: "%.1f GB free", gb)
    }
}
