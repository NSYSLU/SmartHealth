import Foundation
import CryptoKit
import CoreML
import Observation

struct DownloadableModel: Identifiable, Hashable {
    let id: String
    let tier: ModelTier
    let name: String
    let detail: String
    let sizeText: String
    let primaryURL: URL?
    let fallbackURL: URL?
    let expectedSHA256: String?
    let fileExtension: String
    let bundledResource: String
}

enum ModelDownloadState: Equatable {
    case builtIn
    case notDownloaded
    case downloading
    case downloaded(URL)
    case failed(String)
}

struct GGUFModel: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let sizeText: String
    let sourceURL: URL
    let sha256: String
    let family: String
}

@MainActor
@Observable
final class ModelLibrary {
    let ggufCatalog: [GGUFModel] = [
        GGUFModel(id: "qwen2.5-0.5b-q4_k_m", name: "Qwen2.5 0.5B Instruct", detail: "Qwen · GGUF Q4_K_M · 中文/英文对话", sizeText: "约 491 MB", sourceURL: URL(string: "https://modelscope.cn/models/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/master/qwen2.5-0.5b-instruct-q4_k_m.gguf")!, sha256: "74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db", family: "qwen"),
        GGUFModel(id: "gemma-4-e2b-q4_k_m", name: "Gemma 4 E2B Instruct", detail: "Google · GGUF Q4_K_M · 多语言健康问答", sizeText: "约 2.90 GiB", sourceURL: URL(string: "https://modelscope.cn/models/unsloth/gemma-4-E2B-it-GGUF/resolve/master/gemma-4-E2B-it-Q4_K_M.gguf")!, sha256: "740185b21d22ceb83a11c3aa62ad5842ef32c70f6096d756bbee85a1e4ec34b8", family: "gemma"),
        GGUFModel(id: "gemma-4-e4b-q4_k_m", name: "Gemma 4 E4B Instruct", detail: "Google · GGUF Q4_K_M · 更强推理能力", sizeText: "约 4.63 GiB", sourceURL: URL(string: "https://modelscope.cn/models/unsloth/gemma-4-E4B-it-GGUF/resolve/master/gemma-4-E4B-it-Q4_K_M.gguf")!, sha256: "85a896a047553e842f25297ee5b031d64ff30147d9c4af17b1e4b394cd1fab87", family: "gemma")
    ]
    let catalog: [DownloadableModel] = [
        DownloadableModel(id: "smarthealth-fast", tier: .fast, name: "内置极速分析引擎", detail: "离线规则分析 · 可更换 Core ML", sizeText: "内置配置", primaryURL: nil, fallbackURL: nil, expectedSHA256: nil, fileExtension: "mlmodel", bundledResource: "fast"),
        DownloadableModel(id: "smarthealth-balanced", tier: .balanced, name: "内置平衡分析引擎", detail: "日常规则分析 · 推荐", sizeText: "内置配置", primaryURL: nil, fallbackURL: nil, expectedSHA256: nil, fileExtension: "mlmodel", bundledResource: "balanced"),
        DownloadableModel(id: "smarthealth-deep", tier: .deep, name: "内置深度分析引擎", detail: "趋势规则分析 · 可更换 Core ML", sizeText: "内置配置", primaryURL: nil, fallbackURL: nil, expectedSHA256: nil, fileExtension: "mlmodel", bundledResource: "deep")
    ]

    private(set) var states: [String: ModelDownloadState] = [:]
    private(set) var activeProgress: [String: Double] = [:]
    private(set) var loadedModels: [String: MLModel] = [:]
    private(set) var builtInPackages: [ModelTier: BuiltInModelPackage] = [:]
    private(set) var ggufStates: [String: ModelDownloadState] = [:]
    private(set) var ggufProgress: [String: Double] = [:]
    private(set) var ggufDownloadSpeed: [String: Double] = [:]
    var sourceAddress = ""
    private var didRestore = false

    func state(for model: DownloadableModel) -> ModelDownloadState { states[model.id] ?? .notDownloaded }
    func ggufState(for model: GGUFModel) -> ModelDownloadState { ggufStates[model.id] ?? .notDownloaded }
    func ggufURL(for model: GGUFModel) -> URL? { if case .downloaded(let url) = ggufStates[model.id] { return url }; return nil }
    var hasInstalledGGUF: Bool { ggufCatalog.contains { ggufURL(for: $0) != nil } }
    func selectGGUF(_ model: GGUFModel) { if case .downloaded = ggufStates[model.id] { } }
    func isReady(_ tier: ModelTier) -> Bool { catalog.contains { $0.tier == tier && isDownloaded($0) } }

    func installBuiltIn(_ model: DownloadableModel) {
        guard let source = Bundle.main.url(forResource: model.bundledResource, withExtension: "json") else {
            states[model.id] = .failed("找不到内置模型资源")
            return
        }
        do {
            let data = try Data(contentsOf: source)
            let package = try JSONDecoder().decode(BuiltInModelPackage.self, from: data)
            guard package.id == model.id, package.format == "smarthealth-rule-v1" else { throw ModelDownloadError.incompatibleModel }
            let destination = try modelsDirectory().appendingPathComponent("\(model.id).json")
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: destination, options: .atomic)
            builtInPackages[model.tier] = package
            states[model.id] = .builtIn
        } catch {
            states[model.id] = .failed(error.localizedDescription)
        }
        activeProgress[model.id] = 1
    }

    func installAllBuiltIns() {
        for model in catalog where !isInstalled(model) { installBuiltIn(model) }
    }

    func restoreInstalledModels() {
        guard !didRestore else { return }
        didRestore = true
        guard let directory = try? modelsDirectory() else { return }
        for model in ggufCatalog {
            let url = directory.appendingPathComponent("\(model.id).gguf")
            if FileManager.default.fileExists(atPath: url.path) { ggufStates[model.id] = .downloaded(url); ggufProgress[model.id] = 1 }
        }
        for modelInfo in catalog {
            let jsonURL = directory.appendingPathComponent("\(modelInfo.id).json")
            if let data = try? Data(contentsOf: jsonURL), let package = try? JSONDecoder().decode(BuiltInModelPackage.self, from: data), package.id == modelInfo.id {
                builtInPackages[modelInfo.tier] = package
                states[modelInfo.id] = .builtIn
                continue
            }
            let compiled = directory.appendingPathComponent("\(modelInfo.id).mlmodelc", isDirectory: true)
            guard FileManager.default.fileExists(atPath: compiled.path),
                  let model = try? MLModel(contentsOf: compiled),
                  model.modelDescription.inputDescriptionsByName.values.contains(where: { $0.type == .string }),
                  model.modelDescription.outputDescriptionsByName.values.contains(where: { $0.type == .string }) else { continue }
            loadedModels[modelInfo.id] = model
            states[modelInfo.id] = .downloaded(compiled)
        }
    }

    func download(_ model: DownloadableModel, from source: URL) {
        guard states[model.id] != .downloading else { return }
        states[model.id] = .downloading
        activeProgress[model.id] = 0
        Task {
            do {
                let destination = try await download(from: source, fallback: model.fallbackURL, id: model.id, fileExtension: model.fileExtension)
                let compiled = try await MLModel.compileModel(at: destination)
                let loadedModel = try MLModel(contentsOf: compiled)
                guard loadedModel.modelDescription.inputDescriptionsByName.values.contains(where: { $0.type == .string }), loadedModel.modelDescription.outputDescriptionsByName.values.contains(where: { $0.type == .string }) else { throw ModelDownloadError.incompatibleModel }
                let modelsDirectory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Models", isDirectory: true)
                try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
                let persistentCompiled = modelsDirectory.appendingPathComponent("\(model.id).mlmodelc", isDirectory: true)
                try? FileManager.default.removeItem(at: persistentCompiled)
                try FileManager.default.moveItem(at: compiled, to: persistentCompiled)
                try? FileManager.default.removeItem(at: destination)
                loadedModels[model.id] = loadedModel
                states[model.id] = .downloaded(persistentCompiled)
                activeProgress[model.id] = 1
            } catch {
                states[model.id] = .failed(error.localizedDescription)
                activeProgress[model.id] = 0
            }
        }
    }

    func delete(_ model: DownloadableModel) {
        loadedModels[model.id] = nil
        if case .downloaded(let url) = states[model.id] { try? FileManager.default.removeItem(at: url) }
        if case .builtIn = states[model.id], let directory = try? modelsDirectory() { try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(model.id).json")); builtInPackages[model.tier] = nil }
        states[model.id] = .notDownloaded
        activeProgress[model.id] = 0
    }

    func isInstalled(_ model: DownloadableModel) -> Bool {
        switch states[model.id] {
        case .builtIn?, .downloaded?: true
        default: false
        }
    }

    func install(_ model: DownloadableModel) {
        if model.primaryURL == nil { installBuiltIn(model) }
    }

    func downloadGGUF(_ model: GGUFModel) {
        guard ggufStates[model.id] != .downloading else { return }
        ggufStates[model.id] = .downloading
        ggufProgress[model.id] = 0
        ggufDownloadSpeed[model.id] = 0
        Task {
            do {
                let temporary = try await downloadGGUFFile(from: model.sourceURL, id: model.id)
                let actual = try SHA256Digest.hash(file: temporary)
                guard model.sha256.isEmpty || actual.caseInsensitiveCompare(model.sha256) == .orderedSame else { throw ModelDownloadError.checksumMismatch }
                let directory = try modelsDirectory()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let destination = directory.appendingPathComponent("\(model.id).gguf")
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: temporary, to: destination)
                ggufStates[model.id] = .downloaded(destination)
                ggufProgress[model.id] = 1
                ggufDownloadSpeed[model.id] = 0
            } catch {
                ggufStates[model.id] = .failed(error.localizedDescription)
                ggufProgress[model.id] = 0
                ggufDownloadSpeed[model.id] = 0
            }
        }
    }

    func deleteGGUF(_ model: GGUFModel) {
        if case .downloaded(let url) = ggufStates[model.id] { try? FileManager.default.removeItem(at: url) }
        ggufStates[model.id] = .notDownloaded
        ggufProgress[model.id] = 0
        ggufDownloadSpeed[model.id] = 0
    }

    func package(for tier: ModelTier) -> BuiltInModelPackage? { builtInPackages[tier] }

    func predictGGUF(modelID: String?, summary: String) async throws -> String? {
        let installed = ggufCatalog.compactMap { model -> (GGUFModel, URL)? in
            guard let url = ggufURL(for: model) else { return nil }
            return (model, url)
        }
        guard let selected = installed.first(where: { $0.0.id == modelID }) ?? installed.first else { return nil }
        return try await GGUFInferenceEngine.generate(modelURL: selected.1, family: selected.0.family, healthSummary: summary)
    }

    func chat(modelID: String?, question: String, summary: String) async throws -> String {
        let model = ggufCatalog.first { $0.id == modelID && ggufURL(for: $0) != nil } ?? ggufCatalog.first(where: { ggufURL(for: $0) != nil })
        guard let model, let url = ggufURL(for: model) else { throw GGUFInferenceError.modelLoadFailed }
        return try await GGUFInferenceEngine.generate(modelURL: url, family: model.family, healthSummary: "健康记录：\(summary)\n用户问题：\(question)")
    }

    func predict(tier: ModelTier, summary: String) async throws -> String? {
        guard let modelInfo = catalog.first(where: { $0.tier == tier }), let model = loadedModels[modelInfo.id],
              let inputName = model.modelDescription.inputDescriptionsByName.first(where: { $0.value.type == .string })?.key,
              let outputName = model.modelDescription.outputDescriptionsByName.first(where: { $0.value.type == .string })?.key else { return nil }
        let input = try MLDictionaryFeatureProvider(dictionary: [inputName: MLFeatureValue(string: summary)])
        let prediction = try await Task.detached(priority: .userInitiated) { try model.prediction(from: input) }.value
        return prediction.featureValue(for: outputName)?.stringValue
    }

    private func isDownloaded(_ model: DownloadableModel) -> Bool {
        if case .builtIn = states[model.id] { return true }
        if case .downloaded = states[model.id] { return true }
        return false
    }

    private func modelsDirectory() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Models", isDirectory: true)
    }

    private func downloadGGUFFile(from url: URL, id: String) async throws -> URL {
        let delegate = ModelDownloadDelegate { [weak self] received, expected, speed in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.ggufProgress[id] = expected > 0 ? min(1, Double(received) / Double(expected)) : 0
                self.ggufDownloadSpeed[id] = speed
            }
        }
        return try await delegate.download(from: url)
    }

    private func download(from primary: URL, fallback: URL?, id: String, fileExtension: String) async throws -> URL {
        guard primary.scheme == "https" else { throw ModelDownloadError.insecureSource }
        let temporary: URL
        do { (temporary, _) = try await URLSession.shared.download(from: primary) }
        catch { guard let fallback else { throw error }; (temporary, _) = try await URLSession.shared.download(from: fallback) }
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Models", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(id).appendingPathExtension(fileExtension)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)
        if let expected = catalog.first(where: { $0.id == id })?.expectedSHA256 {
            let actual = try SHA256Digest.hash(file: destination)
            guard actual.caseInsensitiveCompare(expected) == .orderedSame else {
                try? FileManager.default.removeItem(at: destination)
                throw ModelDownloadError.checksumMismatch
            }
        }
        return destination
    }
}

struct BuiltInModelPackage: Decodable {
    let id: String
    let format: String
    let tier: String
    let title: String
    let latency: String
    let prompt: String
}

enum ModelDownloadError: LocalizedError {
    case insecureSource
    case checksumMismatch
    case incompatibleModel
    case downloadFailed
    var errorDescription: String? {
        switch self {
        case .insecureSource: "模型地址必须使用 HTTPS"
        case .checksumMismatch: "模型校验失败，已删除不完整文件"
        case .incompatibleModel: "模型格式不兼容：需要至少一个文本输入和文本输出"
        case .downloadFailed: "模型下载失败，请检查网络连接"
        }
    }
}

enum SHA256Digest {
    static func hash(file: URL) throws -> String {
        let data = try Data(contentsOf: file, options: .mappedIfSafe)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private final class ModelDownloadDelegate: NSObject, URLSessionDataDelegate {
    private let progressHandler: (Int64, Int64, Double) -> Void
    private var continuation: CheckedContinuation<URL, Error>?
    private var session: URLSession?
    private var fileHandle: FileHandle?
    private var fileURL: URL?
    private var expectedBytes: Int64 = 0
    private var receivedBytes: Int64 = 0
    private var startedAt = Date()

    init(progressHandler: @escaping (Int64, Int64, Double) -> Void) {
        self.progressHandler = progressHandler
    }

    func download(from url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let temporary = FileManager.default.temporaryDirectory
                .appendingPathComponent("smarthealth-\(UUID().uuidString).gguf")
            self.fileURL = temporary
            FileManager.default.createFile(atPath: temporary.path, contents: nil)
            self.fileHandle = try? FileHandle(forWritingTo: temporary)
            self.startedAt = Date()
            let configuration = URLSessionConfiguration.default
            configuration.waitsForConnectivity = true
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
            self.session = session
            session.dataTask(with: url).resume()
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let response = response as? HTTPURLResponse,
              (200...299).contains(response.statusCode) else {
            completionHandler(.cancel)
            finish(.failure(ModelDownloadError.downloadFailed))
            return
        }
        expectedBytes = response.expectedContentLength
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        do {
            try fileHandle?.write(contentsOf: data)
            receivedBytes += Int64(data.count)
            let elapsed = max(Date().timeIntervalSince(startedAt), 0.001)
            progressHandler(receivedBytes, expectedBytes, Double(receivedBytes) / elapsed)
        } catch {
            session.invalidateAndCancel()
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            finish(.failure(error))
        } else if let fileURL {
            progressHandler(receivedBytes, expectedBytes, Double(receivedBytes) / max(Date().timeIntervalSince(startedAt), 0.001))
            finish(.success(fileURL))
        } else {
            finish(.failure(ModelDownloadError.downloadFailed))
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        try? fileHandle?.close()
        fileHandle = nil
        session?.invalidateAndCancel()
        session = nil
        continuation?.resume(with: result)
        continuation = nil
    }
}
