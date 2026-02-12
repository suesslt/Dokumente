import Foundation
import PDFKit

enum PDFExtractionError: Error {
    case failedToLoadPDF
    case noTextContent
}

final class PDFTextExtractor {
    static let shared = PDFTextExtractor()

    private init() {}

    struct ExtractionResult {
        let text: String
        let pageCount: Int
    }

    func extractText(from url: URL, maxCharacters: Int = 50000) throws -> ExtractionResult {
        guard let pdfDocument = PDFKit.PDFDocument(url: url) else {
            throw PDFExtractionError.failedToLoadPDF
        }

        let pageCount = pdfDocument.pageCount
        var extractedText = ""

        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }

            if let pageText = page.string {
                extractedText += pageText
                extractedText += "\n\n"
            }

            // Stop if we've extracted enough text
            if extractedText.count >= maxCharacters {
                extractedText = String(extractedText.prefix(maxCharacters))
                break
            }
        }

        if extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw PDFExtractionError.noTextContent
        }

        return ExtractionResult(text: extractedText, pageCount: pageCount)
    }

    func getPageCount(from url: URL) -> Int? {
        guard let pdfDocument = PDFKit.PDFDocument(url: url) else {
            return nil
        }
        return pdfDocument.pageCount
    }
}
