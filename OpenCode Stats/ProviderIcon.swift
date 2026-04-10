//
//  ProviderIcon.swift
//  OpenCode Stats
//
//  Created by Fayaz Ahmed Aralikatti on 10/04/26.
//

import SwiftUI

// MARK: - Provider Icon Mapping

enum ProviderIconMapper {

    /// Returns the asset catalog image name for a given provider/model,
    /// matched via regex patterns. Returns nil for unknown providers.
    static func assetName(provider: String, model: String) -> String? {
        let p = provider.lowercased()
        let m = model.lowercased()

        // Anthropic / Claude
        if p.contains("anthropic") || m.range(of: #"claude"#, options: .regularExpression) != nil {
            return "icon-anthropic"
        }

        // OpenAI / GPT / o1 / o3 / o4 / codex
        if p.contains("openai") || m.range(of: #"gpt|^o[0-9]|codex"#, options: .regularExpression) != nil {
            return "icon-openai"
        }

        // Google / Gemini / Gemma
        if p.contains("google") || m.range(of: #"gemini|gemma"#, options: .regularExpression) != nil {
            return "icon-gemini"
        }

        // Kimi / Moonshot
        if p.contains("kimi") || p.contains("moonshot")
            || m.range(of: #"kimi|moonshot"#, options: .regularExpression) != nil {
            return "icon-kimi"
        }

        // Zhipu / GLM
        if p.contains("zhipu") || m.range(of: #"glm"#, options: .regularExpression) != nil {
            return "icon-glm"
        }

        return nil
    }
}

// MARK: - Provider Icon View

struct ProviderIcon: View {
    let provider: String
    let model: String
    let size: CGFloat

    init(provider: String, model: String, size: CGFloat = 14) {
        self.provider = provider
        self.model = model
        self.size = size
    }

    var body: some View {
        Group {
            if let assetName = ProviderIconMapper.assetName(provider: provider, model: model) {
                Image(assetName)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "cpu")
                    .font(.system(size: size * 0.7))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}
