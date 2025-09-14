import Foundation
import UIKit

@MainActor
class ShareURLManager: ObservableObject {
    static let shared = ShareURLManager()

    private let baseURL = "https://share.stylesync.app"
    private let keychain = KeychainService.shared

    private init() {}

    func createShareLink(
        for content: ShareableContent,
        expiry: ShareLinkExpiry = .oneWeek,
        isPrivate: Bool = false,
        requiresAccessCode: Bool = false
    ) async -> ShareLink? {
        do {
            let linkId = UUID().uuidString
            let accessCode = requiresAccessCode ? generateAccessCode() : nil

            let request = CreateShareLinkRequest(
                linkId: linkId,
                contentType: content.type,
                contentData: content.data,
                expiresAt: calculateExpiryDate(from: expiry),
                isPrivate: isPrivate,
                accessCode: accessCode,
                metadata: content.metadata
            )

            let response = try await uploadShareContent(request)

            let shareLink = ShareLink(
                id: linkId,
                url: URL(string: "\(baseURL)/\(linkId)")!,
                title: content.title,
                contentType: content.type,
                createdAt: Date(),
                expiresAt: calculateExpiryDate(from: expiry),
                isPrivate: isPrivate,
                accessCode: accessCode,
                viewCount: 0
            )

            PrivacyManager.shared.addShareLink(shareLink)
            return shareLink

        } catch {
            print("Failed to create share link: \(error)")
            return nil
        }
    }

    func revokeLink(_ linkId: String) async {
        do {
            let request = RevokeShareLinkRequest(linkId: linkId)
            _ = try await performAPIRequest("/api/share/revoke", method: "DELETE", body: request)
        } catch {
            print("Failed to revoke share link: \(error)")
        }
    }

    func getShareLinkAnalytics(_ linkId: String) async -> ShareLinkAnalytics? {
        do {
            let response: ShareLinkAnalyticsResponse = try await performAPIRequest(
                "/api/share/\(linkId)/analytics",
                method: "GET"
            )
            return response.analytics
        } catch {
            print("Failed to get share link analytics: \(error)")
            return nil
        }
    }

    func validateAccessCode(_ code: String, for linkId: String) async -> Bool {
        do {
            let request = ValidateAccessCodeRequest(linkId: linkId, accessCode: code)
            let response: ValidateAccessCodeResponse = try await performAPIRequest(
                "/api/share/validate-code",
                method: "POST",
                body: request
            )
            return response.isValid
        } catch {
            return false
        }
    }

    private func calculateExpiryDate(from expiry: ShareLinkExpiry) -> Date {
        guard let interval = expiry.timeInterval else {
            return Date.distantFuture
        }
        return Date().addingTimeInterval(interval)
    }

    private func generateAccessCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).compactMap { _ in characters.randomElement() })
    }

    private func uploadShareContent(_ request: CreateShareLinkRequest) async throws -> CreateShareLinkResponse {
        var apiRequest = URLRequest(url: URL(string: "\(baseURL)/api/share/create")!)
        apiRequest.httpMethod = "POST"
        apiRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        apiRequest.setValue("Bearer \(getAPIKey())", forHTTPHeaderField: "Authorization")

        let jsonData = try JSONEncoder().encode(request)
        apiRequest.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: apiRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ShareURLError.uploadFailed
        }

        return try JSONDecoder().decode(CreateShareLinkResponse.self, from: data)
    }

    private func performAPIRequest<T: Codable, R: Codable>(
        _ endpoint: String,
        method: String,
        body: T? = nil
    ) async throws -> R {
        var request = URLRequest(url: URL(string: "\(baseURL)\(endpoint)")!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(getAPIKey())", forHTTPHeaderField: "Authorization")

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode < 300 else {
            throw ShareURLError.requestFailed
        }

        return try JSONDecoder().decode(R.self, from: data)
    }

    private func getAPIKey() -> String {
        return keychain.get("share_api_key") ?? ""
    }
}

struct ShareableContent {
    let type: ShareContentType
    let title: String
    let data: Data
    let metadata: [String: String]
}

enum ShareContentType: String, Codable {
    case outfitPhoto = "outfit_photo"
    case outfitCollage = "outfit_collage"
    case magazineLayout = "magazine_layout"
    case styleReport = "style_report"
}

struct ShareLink: Codable, Identifiable {
    let id: String
    let url: URL
    let title: String
    let contentType: ShareContentType
    let createdAt: Date
    let expiresAt: Date
    let isPrivate: Bool
    let accessCode: String?
    var viewCount: Int

    var isExpired: Bool {
        Date() > expiresAt
    }
}

struct ShareLinkAnalytics: Codable {
    let totalViews: Int
    let uniqueViews: Int
    let viewsByCountry: [String: Int]
    let viewsByDate: [String: Int]
    let referrers: [String: Int]
    let lastViewed: Date?
}

struct CreateShareLinkRequest: Codable {
    let linkId: String
    let contentType: ShareContentType
    let contentData: Data
    let expiresAt: Date
    let isPrivate: Bool
    let accessCode: String?
    let metadata: [String: String]
}

struct CreateShareLinkResponse: Codable {
    let success: Bool
    let linkId: String
    let uploadUrl: String?
}

struct RevokeShareLinkRequest: Codable {
    let linkId: String
}

struct ShareLinkAnalyticsResponse: Codable {
    let analytics: ShareLinkAnalytics
}

struct ValidateAccessCodeRequest: Codable {
    let linkId: String
    let accessCode: String
}

struct ValidateAccessCodeResponse: Codable {
    let isValid: Bool
}

enum ShareURLError: Error {
    case uploadFailed
    case requestFailed
    case invalidResponse
    case expired
    case accessDenied
}

extension ShareURLManager {
    func shareToSocialMedia(_ shareLink: ShareLink, platform: SocialPlatform) {
        let url = shareLink.url
        let text = "Check out my style! \(shareLink.title)"

        let shareURL: URL

        switch platform {
        case .instagram:
            shareURL = URL(string: "instagram://library")!
        case .twitter:
            let twitterText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            shareURL = URL(string: "twitter://post?message=\(twitterText)&url=\(urlString)")!
        case .facebook:
            let urlString = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            shareURL = URL(string: "facebook://sharer/sharer.php?u=\(urlString)")!
        case .pinterest:
            let urlString = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let description = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            shareURL = URL(string: "pinterest://pin/create/link/?url=\(urlString)&description=\(description)")!
        }

        if UIApplication.shared.canOpenURL(shareURL) {
            UIApplication.shared.open(shareURL)
        } else {
            let activityVC = UIActivityViewController(
                activityItems: [text, url],
                applicationActivities: nil
            )

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(activityVC, animated: true)
            }
        }
    }

    func copyShareLink(_ shareLink: ShareLink) {
        var linkText = shareLink.url.absoluteString

        if let accessCode = shareLink.accessCode {
            linkText += "\nAccess Code: \(accessCode)"
        }

        UIPasteboard.general.string = linkText
    }

    func generateQRCode(for shareLink: ShareLink) -> UIImage? {
        let data = shareLink.url.absoluteString.data(using: .utf8)

        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 10, y: 10)

            if let output = filter.outputImage?.transformed(by: transform) {
                let context = CIContext()
                if let cgImage = context.createCGImage(output, from: output.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
        }

        return nil
    }
}

enum SocialPlatform {
    case instagram
    case twitter
    case facebook
    case pinterest
}

extension ShareURLManager {
    func previewShareLink(_ linkId: String) async -> SharePreview? {
        do {
            let response: SharePreviewResponse = try await performAPIRequest(
                "/api/share/\(linkId)/preview",
                method: "GET"
            )
            return response.preview
        } catch {
            print("Failed to get share preview: \(error)")
            return nil
        }
    }

    func reportInappropriateContent(_ linkId: String, reason: String) async {
        do {
            let request = ReportContentRequest(linkId: linkId, reason: reason)
            let _: ReportContentResponse = try await performAPIRequest(
                "/api/share/report",
                method: "POST",
                body: request
            )
        } catch {
            print("Failed to report content: \(error)")
        }
    }
}

struct SharePreview: Codable {
    let title: String
    let description: String
    let thumbnailURL: URL
    let contentType: ShareContentType
    let isExpired: Bool
    let requiresAccessCode: Bool
}

struct SharePreviewResponse: Codable {
    let preview: SharePreview
}

struct ReportContentRequest: Codable {
    let linkId: String
    let reason: String
}

struct ReportContentResponse: Codable {
    let success: Bool
}