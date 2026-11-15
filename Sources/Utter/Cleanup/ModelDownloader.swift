import Foundation

/// A downloadable cleanup model hosted on Hugging Face.
struct CleanupModel: Identifiable, Equatable {
    let id: String
    let name: String
    let repo: String
    /// Approximate download size, shown before the real size is known.
    let sizeGB: Double
    /// Rough memory needed while loaded.
    let memoryGB: Double
    let summary: String

    static let catalog: [CleanupModel] = [
        CleanupModel(
            id: "qwen3-0.6b", name: "Qwen3 0.6B", repo: "mlx-community/Qwen3-0.6B-4bit",
            sizeGB: 0.35, memoryGB: 0.8, summary: "Smallest and fastest. Light fixes only."
        ),
        CleanupModel(
            id: "qwen3-1.7b", name: "Qwen3 1.7B", repo: "mlx-community/Qwen3-1.7B-4bit",
            sizeGB: 1.0, memoryGB: 1.6, summary: "Fast, and handles corrections and numbers."
        ),
        CleanupModel(
            id: "qwen3-4b", name: "Qwen3 4B", repo: "mlx-community/Qwen3-4B-4bit",
            sizeGB: 2.3, memoryGB: 3.2, summary: "Most capable, and the slowest."
        ),
    ]

    /// Pick by installed memory: bigger models only where they leave the Mac room to breathe.
    static func recommended(memoryGB: Double) -> CleanupModel {
        if memoryGB >= 32 { return catalog[2] }
        if memoryGB >= 16 { return catalog[1] }
        return catalog[0]
    }
}

struct DownloadProgress: Equatable {
    var received: Int64
    var total: Int64
    var fraction: Double { total > 0 ? min(1, Double(received) / Double(total)) : 0 }
}

/// Downloads a model repository file by file into Application Support.
/// Finished files are kept, so an interrupted download resumes where it stopped.
final class ModelDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    static var modelsDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Utter/Models", isDirectory: true)
    }

    static func directory(for model: CleanupModel) -> URL {
        modelsDirectory.appendingPathComponent(model.id, isDirectory: true)
    }

    private static func marker(for model: CleanupModel) -> URL {
        directory(for: model).appendingPathComponent(".complete")
    }

    static func isInstalled(_ model: CleanupModel) -> Bool {
        FileManager.default.fileExists(atPath: marker(for: model).path)
    }

    static func remove(_ model: CleanupModel) {
        try? FileManager.default.removeItem(at: directory(for: model))
    }

    private struct RepoInfo: Decodable {
        struct File: Decodable {
            let rfilename: String
            let size: Int64?
        }
        let siblings: [File]
    }

    private let lock = NSLock()
    private var onBytes: ((Int64) -> Void)?
    private var continuation: CheckedContinuation<URL, Error>?
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    /// Downloads every file the model needs. Throws `CancellationError` if the task is cancelled.
    func download(_ model: CleanupModel, progress: @escaping @Sendable (DownloadProgress) -> Void) async throws {
        let fm = FileManager.default
        let directory = Self.directory(for: model)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        let infoURL = URL(string: "https://huggingface.co/api/models/\(model.repo)?blobs=true")!
        let (data, response) = try await URLSession.shared.data(from: infoURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw EngineError("Could not reach Hugging Face to find the model files.")
        }
        let files = try JSONDecoder().decode(RepoInfo.self, from: data).siblings.filter { file in
            let name = file.rfilename.lowercased()
            return !name.hasSuffix(".md") && !name.hasPrefix(".") && !name.hasSuffix(".png") && !name.hasSuffix(".jpg")
        }
        let total = files.reduce(Int64(0)) { $0 + ($1.size ?? 0) }

        var done: Int64 = 0
        for file in files {
            try Task.checkCancellation()
            let destination = directory.appendingPathComponent(file.rfilename)
            let size = file.size ?? 0
            let existing = (try? fm.attributesOfItem(atPath: destination.path)[.size] as? Int64) ?? -1
            if existing == size, size > 0 {
                done += size
                progress(DownloadProgress(received: done, total: total))
                continue
            }
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            let base = done
            let source = URL(string: "https://huggingface.co/\(model.repo)/resolve/main/\(file.rfilename)")!
            let temporary = try await fetch(source) { received in
                progress(DownloadProgress(received: base + received, total: total))
            }
            try? fm.removeItem(at: destination)
            try fm.moveItem(at: temporary, to: destination)
            done += size
            progress(DownloadProgress(received: done, total: total))
        }
        fm.createFile(atPath: Self.marker(for: model).path, contents: nil)
    }

    private func fetch(_ url: URL, onBytes: @escaping (Int64) -> Void) async throws -> URL {
        let task = session.downloadTask(with: url)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.withLock {
                    self.onBytes = onBytes
                    self.continuation = continuation
                }
                task.resume()
            }
        } onCancel: {
            task.cancel()
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        let continuation = lock.withLock { () -> CheckedContinuation<URL, Error>? in
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume(with: result)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        lock.withLock { onBytes }?(totalBytesWritten)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let status = (downloadTask.response as? HTTPURLResponse)?.statusCode, status != 200 {
            return finish(.failure(EngineError("Download failed (HTTP \(status)).")))
        }
        // The file at `location` is deleted when this method returns, so move it first.
        let kept = FileManager.default.temporaryDirectory.appendingPathComponent("utter-\(UUID().uuidString)")
        do {
            try FileManager.default.moveItem(at: location, to: kept)
            finish(.success(kept))
        } catch {
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        finish(.failure((error as? URLError)?.code == .cancelled ? CancellationError() : error))
    }
}
