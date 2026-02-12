import Foundation

enum ClaudeAPIError: Error {
    case noAPIKey
    case invalidResponse
    case networkError(Error)
    case apiError(String)
}

final class ClaudeAPIService {
    static let shared = ClaudeAPIService()

    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-sonnet-4-20250514"
    private let apiVersion = "2023-06-01"

    /// Serialisiert alle Aufrufe zur Claude-API, damit nie zwei gleichzeitig
    /// inflight sind.  Der Semaphor wird auf einem eigenen Task in einem
    /// nichtblockierenden Muster verwendet (kein .wait() auf einem
    /// kooperativen Thread).
    private let requestSemaphore = DispatchSemaphore(value: 1)

    private init() {}

    // MARK: - Private Helper

    /// Führt einen einzelnen Claude-API-Aufruf durch und gibt den Textinhalt der Antwort zurück.
    /// Vor dem Aufruf wird auf den Semaphor gewartet; nach dem Aufruf wird
    /// eine Wartezeit von 2 Sekunden eingehalten, bevor der Semaphor wieder
    /// freigegeben wird.
    private func sendRequest(prompt: String, maxTokens: Int) async throws -> String {
        // ── Semaphor erwerben ohne kooperativen Thread zu blockieren ──
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global().async { [self] in
                self.requestSemaphore.wait()
                continuation.resume()
            }
        }

        // ── Semaphor wird am Ende IMMER freigegeben (auch bei Fehler) ──
        defer {
            // 2 s Wartezeit vor der Freigabe – auf einem Background-Thread,
            // damit der kooperative Thread nicht blockiert wird.
            DispatchQueue.global().async { [self] in
                Thread.sleep(forTimeInterval: 4.0)
                self.requestSemaphore.signal()
            }
        }

        guard let apiKey = try KeychainService.shared.getAPIKey() else {
            throw ClaudeAPIError.noAPIKey
        }

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        guard let url = URL(string: baseURL) else {
            throw ClaudeAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw ClaudeAPIError.apiError(message)
            }
            throw ClaudeAPIError.apiError("HTTP \(httpResponse.statusCode)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw ClaudeAPIError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Public API

    /// Rückgabetyp für den kombinierten Metadaten-Aufruf.
    struct DocumentMetadata {
        let summary: String
        let author: String?   // nil, wenn kein Autor erkennbar war
        let title: String?    // nil, wenn kein Titel erkennbar war
        let keywords: String?
        let dateCreated: String?
    }

    /// Einzelner Claude-Aufruf: Zusammenfassung, Autor und Titel gleichzeitig.
    /// Claude gibt ein JSON-Objekt zurück, das hier geparst wird.
    func extractDocumentMetadata(from text: String) async throws -> DocumentMetadata {
        let prompt = """
        Analysiere das folgende Dokument und antworte NUR mit einem JSON-Objekt in diesem exakten Format – ohne Markdown-Codeblocks, ohne Einleitung, ohne Kommentare:

        {
          "summary": "<Zusammenfassung in der Sprache des Dokuments von maximal 200 Wörtern, die die wichtigsten Kernaussagen erfasst>",
          "author": "<Vor- und Nachname(n) des Autors, durch Kommas getrennt – oder null, falls kein Autor erkennbar ist>",
          "title": "<Titel des Dokuments – bevorzuge einen im Dokument vorhandenen Titel; sonst einen kurzen, beschreibenden Titel – oder null, falls kein Titel bestimmbar ist>"
          "keywords": "<Die maximal zehn wichtigsten Schlüsselwörter, welche als 'Tag' verwendet werden könnten. Diese sind durch Semikolon getrennt>"
          "date_created": "<Datum, wann das Dokument erstellt wurde. Das Datum soll im Format yyyyMMdd sein>"
        }

        Regeln:
        - "summary" darf nicht leer sein.
        - "author" ist null (ohne Anführungszeichen), wenn kein Autor erkennbar ist.
        - "title" ist null (ohne Anführungszeichen), wenn kein Titel bestimmbar ist. Maximal 120 Zeichen.
        - "keywords" darf nicht leer sein.
        - "date_created" ist null, wenn kein Datum eruierbar ist.
        - Antworte NUR mit dem JSON-Objekt. Kein weiterer Text.

        Dokument:
        \(text)
        """

        let rawResponse = try await sendRequest(prompt: prompt, maxTokens: 700)

        // Claude gibt manchmal ```json … ``` zurück – diese Wrapper entfernen
        let cleaned = rawResponse
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let summary = json["summary"] as? String, !summary.isEmpty else {
            throw ClaudeAPIError.invalidResponse
        }

        let author      = json["author"]  as? String   // nil bei JSON-null
        let title       = json["title"]   as? String   // nil bei JSON-null
        let keywords    = json["keywords"] as? String
        let dateCreated = json["date_created"] as? String
        
        return DocumentMetadata(
            summary: summary,
            author:  author,
            title:   title.map { String($0.prefix(120)) },   // Sicherheitscheck: max 120 Zeichen
            keywords: keywords,
            dateCreated: dateCreated
        )
    }
}
