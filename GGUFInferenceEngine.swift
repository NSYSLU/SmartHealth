import Foundation
#if canImport(LlamaSwift)
import LlamaSwift
#endif

enum GGUFInferenceError: LocalizedError {
    case runtimeUnavailable
    case modelLoadFailed
    case contextCreationFailed
    case promptEncodingFailed
    case inferenceFailed

    var errorDescription: String? {
        switch self {
        case .runtimeUnavailable: "GGUF 推理组件不可用，请在 Xcode 中解析 llama.swift 包后重试"
        case .modelLoadFailed: "GGUF 模型无法加载，请确认文件完整且设备内存充足"
        case .contextCreationFailed: "模型上下文创建失败，设备可能没有足够可用内存"
        case .promptEncodingFailed: "模型无法处理本次健康分析文本"
        case .inferenceFailed: "GGUF 推理未能完成"
        }
    }
}

enum GGUFInferenceEngine {
    static func generate(modelURL: URL, family: String, healthSummary: String) async throws -> String {
        #if canImport(LlamaSwift)
        try await Task.detached(priority: .userInitiated) {
            try generateSynchronously(modelURL: modelURL, family: family, healthSummary: healthSummary)
        }.value
        #else
        throw GGUFInferenceError.runtimeUnavailable
        #endif
    }

    #if canImport(LlamaSwift)
    private static func generateSynchronously(modelURL: URL, family: String, healthSummary: String) throws -> String {
        llama_backend_init()
        defer { llama_backend_free() }

        let modelParameters = llama_model_default_params()
        guard let model = llama_model_load_from_file(modelURL.path, modelParameters) else {
            throw GGUFInferenceError.modelLoadFailed
        }
        defer { llama_model_free(model) }

        var contextParameters = llama_context_default_params()
        contextParameters.n_ctx = 2048
        contextParameters.n_batch = 512
        guard let context = llama_init_from_model(model, contextParameters) else {
            throw GGUFInferenceError.contextCreationFailed
        }
        defer { llama_free(context) }

        let vocabulary = llama_model_get_vocab(model)
        let prompt: String
        if family == "gemma" {
            prompt = "<start_of_turn>system\n你是一位谨慎、友善的健康生活助手。根据用户提供的数据给出简短、非诊断性的建议；不得编造数据，异常症状应建议咨询医生。<end_of_turn>\n<start_of_turn>user\n请分析这些健康记录并给出一条具体建议：\n\(healthSummary)<end_of_turn>\n<start_of_turn>model\n"
        } else {
            prompt = "<|im_start|>system\n你是一位谨慎、友善的健康生活助手。根据用户提供的数据给出简短、非诊断性的建议；不得编造数据，异常症状应建议咨询医生。<|im_end|>\n<|im_start|>user\n请分析这些健康记录并给出一条具体建议：\n\(healthSummary)<|im_end|>\n<|im_start|>assistant\n"
        }
        var tokens = [llama_token](repeating: 0, count: prompt.utf8.count + 8)
        let tokenCount = prompt.withCString { pointer in
            llama_tokenize(vocabulary, pointer, Int32(prompt.utf8.count), &tokens, Int32(tokens.count), true, true)
        }
        guard tokenCount > 0, tokenCount < 1800 else { throw GGUFInferenceError.promptEncodingFailed }
        tokens = Array(tokens.prefix(Int(tokenCount)))

        let batchCapacity = max(512, tokens.count + 1)
        var batch = llama_batch_init(Int32(batchCapacity), 0, 1)
        defer { llama_batch_free(batch) }
        // llama.cpp assumes sequence 0 when seq_id is nil. Do not dereference
        // the imported `llama_seq_id **` from Swift; on iOS it can be an invalid
        // sentinel pointer and causes EXC_BAD_ACCESS.
        batch.seq_id = nil
        batch.n_tokens = Int32(tokens.count)
        for index in tokens.indices {
            batch.token[index] = tokens[index]
            batch.pos[index] = Int32(index)
            batch.n_seq_id[index] = 1
            batch.logits[index] = index == tokens.count - 1 ? 1 : 0
        }
        guard llama_decode(context, batch) == 0 else { throw GGUFInferenceError.inferenceFailed }

        var generated = ""
        var position = Int32(tokens.count)
        let vocabularySize = Int(llama_vocab_n_tokens(vocabulary))
        let endToken = llama_vocab_eos(vocabulary)
        for _ in 0..<120 {
            guard let logits = llama_get_logits_ith(context, batch.n_tokens - 1) else { throw GGUFInferenceError.inferenceFailed }
            var nextToken: llama_token = 0
            var bestLogit = -Float.infinity
            for index in 0..<vocabularySize where logits[index] > bestLogit {
                bestLogit = logits[index]
                nextToken = llama_token(index)
            }
            if nextToken == endToken { break }

            var piece = [CChar](repeating: 0, count: 256)
            let pieceLength = llama_token_to_piece(vocabulary, nextToken, &piece, Int32(piece.count), 0, false)
            if pieceLength > 0, pieceLength <= piece.count {
                let bytes = piece.prefix(Int(pieceLength)).map { UInt8(bitPattern: $0) }
                generated += String(decoding: bytes, as: UTF8.self)
            }

            batch.n_tokens = 1
            batch.token[0] = nextToken
            batch.pos[0] = position
            batch.n_seq_id[0] = 1
            batch.logits[0] = 1
            position += 1
            guard llama_decode(context, batch) == 0 else { throw GGUFInferenceError.inferenceFailed }
        }
        let result = generated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw GGUFInferenceError.inferenceFailed }
        return result
    }
    #endif
}
