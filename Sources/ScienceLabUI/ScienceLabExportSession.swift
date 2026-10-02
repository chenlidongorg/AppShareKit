#if canImport(UIKit) && canImport(SwiftUI)
import Foundation
import CoreGraphics
import SwiftUI
import UIKit

public typealias ScienceLabExportSaveCompletion = (Result<Void, Error>) -> Void
public typealias ScienceLabExportSaveHandler = (UIImage, @escaping ScienceLabExportSaveCompletion) -> Void

struct ScienceLabExportFile: Sendable {
    let url: URL
    let pixelWidth: Int
    let pixelHeight: Int
    let byteCount: Int
}

enum ScienceLabExportPNG {
    enum Failure: LocalizedError {
        case invalidImage, encodingFailed
        var errorDescription: String? {
            switch self {
            case .invalidImage: return ScienceLabExportLabels.text("export.invalidImage", "The image has no usable pixels.")
            case .encodingFailed: return ScienceLabExportLabels.text("export.encodingFailed", "The PNG image could not be created.")
            }
        }
    }

    /// Normalize orientation at the original pixel dimensions. An opaque
    /// renderer or point-sized draw would lose alpha or downsample the capture.
    static func data(for image: UIImage) throws -> (Data, Int, Int) {
        let swapsAxes = [.left, .leftMirrored, .right, .rightMirrored].contains(image.imageOrientation)
        let sourceWidth = image.cgImage.map { CGFloat($0.width) } ?? image.size.width * image.scale
        let sourceHeight = image.cgImage.map { CGFloat($0.height) } ?? image.size.height * image.scale
        let width = swapsAxes ? sourceHeight : sourceWidth
        let height = swapsAxes ? sourceWidth : sourceHeight
        guard width.isFinite, height.isFinite, width > 0, height > 0,
              width <= CGFloat(Int.max), height <= CGFloat(Int.max) else { throw Failure.invalidImage }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        format.preferredRange = .standard
        let normalized = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        guard let data = normalized.pngData() else { throw Failure.encodingFailed }
        return (data, Int(width), Int(height))
    }

    static func prepare(image: UIImage, title: String) async throws -> ScienceLabExportFile {
        let work = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let (data, width, height) = try Self.data(for: image)
            try Task.checkCancellation()
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("science-lab-export-" + UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            var name = (trimmed.isEmpty ? "Experiment" : trimmed)
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .components(separatedBy: .controlCharacters).joined(separator: "-")
            while name.utf8.count > 180 { name.removeLast() }
            let url = directory.appendingPathComponent(name + ".png")
            do {
                try data.write(to: url, options: .atomic)
                try Task.checkCancellation()
                return ScienceLabExportFile(url: url, pixelWidth: width, pixelHeight: height, byteCount: data.count)
            } catch {
                try? FileManager.default.removeItem(at: directory)
                throw error
            }
        }
        return try await withTaskCancellationHandler(operation: { try await work.value }, onCancel: { work.cancel() })
    }

    static func remove(_ file: ScienceLabExportFile?) {
        guard let file else { return }
        try? FileManager.default.removeItem(at: file.url.deletingLastPathComponent())
    }
}

@available(iOS 15.0, macCatalyst 15.0, *)
@MainActor
final class ScienceLabExportSession: ObservableObject {
    enum Operation: Equatable { case prepare, save, share }
    enum Phase: Equatable {
        case processing(Operation)
        case preview
        case sharing
        case success(Operation)
        case failed(Operation, String)
        case cancelled
    }

    let title: String
    private let image: UIImage
    private let onSave: ScienceLabExportSaveHandler?
    private let fileBuilder: (UIImage, String) async throws -> ScienceLabExportFile
    private var generation = UUID()
    private var isPreparing = false
    @Published private(set) var phase: Phase = .processing(.prepare)
    @Published private(set) var file: ScienceLabExportFile?
    @Published private(set) var previewImage: UIImage

    init(image: UIImage, title: String, onSave: ScienceLabExportSaveHandler? = nil,
         fileBuilder: @escaping (UIImage, String) async throws -> ScienceLabExportFile = ScienceLabExportPNG.prepare) {
        self.image = image
        self.previewImage = image
        self.title = title
        self.onSave = onSave
        self.fileBuilder = fileBuilder
    }

    var canSave: Bool { onSave != nil && canAct }
    var canAct: Bool {
        guard file != nil else { return false }
        switch phase {
        case .preview, .success, .failed: return true
        default: return false
        }
    }

    func prepareForPreview() async {
        guard phase != .cancelled, file == nil, !isPreparing else { return }
        isPreparing = true
        defer { isPreparing = false }
        let token = UUID()
        generation = token
        phase = .processing(.prepare)
        do {
            let prepared = try await fileBuilder(image, title)
            guard generation == token, phase != .cancelled, !Task.isCancelled else {
                ScienceLabExportPNG.remove(prepared)
                return
            }
            file = prepared
            previewImage = UIImage(contentsOfFile: prepared.url.path) ?? image
            phase = .preview
        } catch {
            guard generation == token, phase != .cancelled else { return }
            if Task.isCancelled || error is CancellationError { cancel() }
            else { phase = .failed(.prepare, error.localizedDescription) }
        }
    }

    func save() {
        guard canSave, let onSave else { return }
        let token = UUID()
        generation = token
        phase = .processing(.save)
        onSave(previewImage) { [weak self] result in
            Task { @MainActor in self?.finishSave(result, token: token) }
        }
    }

    private func finishSave(_ result: Result<Void, Error>, token: UUID) {
        guard generation == token, phase == .processing(.save) else { return }
        switch result {
        case .success: phase = .success(.save)
        case .failure(let error): phase = .failed(.save, error.localizedDescription)
        }
    }

    func beginShare() -> URL? {
        guard canAct, let file else { return nil }
        phase = .sharing
        return file.url
    }

    func finishShare(completed: Bool, error: Error?) {
        guard phase == .sharing else { return }
        if let error { phase = .failed(.share, error.localizedDescription) }
        else { phase = completed ? .success(.share) : .preview }
    }

    func retry() async {
        guard case .failed(let operation, _) = phase else { return }
        switch operation {
        case .prepare: await prepareForPreview()
        case .save: save()
        case .share: phase = .preview
        }
    }

    func cancel() {
        generation = UUID()
        phase = .cancelled
        ScienceLabExportPNG.remove(file)
        file = nil
    }
}

enum ScienceLabExportLabels {
    static func text(_ key: String, _ fallback: String) -> String {
        NSLocalizedString(key, bundle: .module, value: fallback, comment: "Science lab export flow")
    }
}
#endif
