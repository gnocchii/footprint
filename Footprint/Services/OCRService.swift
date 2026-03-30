import Foundation
import Vision
import AppKit

class OCRService {
    /// Extract text from a screenshot using macOS Vision framework (runs locally, no API cost)
    func extractText(from imageURL: URL) -> String? {
        guard let image = NSImage(contentsOf: imageURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        var recognizedText = ""
        let semaphore = DispatchSemaphore(value: 0)

        let request = VNRecognizeTextRequest { request, error in
            defer { semaphore.signal() }
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else { return }

            let texts = observations.compactMap { $0.topCandidates(1).first?.string }
            recognizedText = texts.joined(separator: "\n")
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage)
        try? handler.perform([request])
        semaphore.wait()

        return recognizedText.isEmpty ? nil : recognizedText
    }
}
