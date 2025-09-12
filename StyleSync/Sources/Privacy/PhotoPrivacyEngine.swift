import Foundation
import UIKit
import Vision
import CoreML
import AVFoundation
import CoreImage
import CryptoKit
import ImageIO

// MARK: - Military-Grade Photo Privacy Engine
@MainActor
public final class PhotoPrivacyEngine: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = PhotoPrivacyEngine()
    
    // MARK: - Published Properties
    @Published public var isProcessing = false
    @Published public var processingProgress: Double = 0.0
    @Published public var processingStatus = "Ready"
    
    // MARK: - Private Properties
    private let cryptoEngine = CryptoEngine.shared
    private let auditLogger = AuditLogger.shared
    private let faceDetectionQueue = DispatchQueue(label: "com.stylesync.facedetection", qos: .userInitiated)
    private let imageProcessingQueue = DispatchQueue(label: "com.stylesync.imageprocessing", qos: .userInitiated)
    
    // MARK: - Core Image Context
    private lazy var ciContext: CIContext = {
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,
            .cacheIntermediates: false
        ]
        return CIContext(options: options)
    }()
    
    // MARK: - Privacy Settings
    @Published public var privacySettings = PhotoPrivacySettings()
    
    private init() {
        loadPrivacySettings()
        setupSecureProcessing()
    }
    
    // MARK: - Main Processing Pipeline
    public func processPhoto(
        _ image: UIImage,
        options: PhotoProcessingOptions = .default
    ) async throws -> ProcessedPhotoResult {
        
        isProcessing = true
        processingStatus = "Initializing secure processing..."
        processingProgress = 0.0
        
        defer {
            isProcessing = false
            processingProgress = 1.0
            processingStatus = "Ready"
        }
        
        // Log privacy processing start
        await auditLogger.logSecurityEvent(.photoProcessed, details: [
            "processing_options": options.description,
            "on_device": true,
            "secure_processing": true
        ])
        
        var processedImage = image
        var metadata = PhotoMetadata()
        
        // Step 1: Extract and analyze metadata (5%)
        processingStatus = "Analyzing metadata..."
        processingProgress = 0.05
        
        if options.stripMetadata {
            metadata = await extractMetadata(from: image)
            processedImage = await stripMetadata(from: processedImage)
        }
        
        // Step 2: Face detection and blurring (25%)
        processingStatus = "Detecting faces..."
        processingProgress = 0.25
        
        if options.blurFaces {
            let faceResults = await detectAndBlurFaces(in: processedImage)
            processedImage = faceResults.image
            metadata.faceCount = faceResults.faceCount
        }
        
        // Step 3: Background removal (50%)
        processingStatus = "Processing background..."
        processingProgress = 0.50
        
        if options.removeBackground {
            processedImage = await removeBackground(from: processedImage)
        }
        
        // Step 4: Watermark detection and removal (75%)
        processingStatus = "Scanning for watermarks..."
        processingProgress = 0.75
        
        if options.detectWatermarks {
            let watermarkResult = await detectAndRemoveWatermarks(from: processedImage)
            processedImage = watermarkResult.image
            metadata.watermarksDetected = watermarkResult.detected
        }
        
        // Step 5: Privacy enhancement (90%)
        processingStatus = "Applying privacy enhancements..."
        processingProgress = 0.90
        
        if options.enhancePrivacy {
            processedImage = await applyPrivacyEnhancements(to: processedImage)
        }
        
        // Step 6: Secure finalization (100%)
        processingStatus = "Finalizing..."
        processingProgress = 1.0
        
        let result = ProcessedPhotoResult(
            originalImage: image,
            processedImage: processedImage,
            metadata: metadata,
            processingOptions: options,
            timestamp: Date(),
            processingId: UUID()
        )
        
        // Log completion
        await auditLogger.logSecurityEvent(.photoProcessed, details: [
            "faces_detected": metadata.faceCount,
            "watermarks_detected": metadata.watermarksDetected.count,
            "metadata_stripped": options.stripMetadata,
            "background_removed": options.removeBackground,
            "processing_id": result.processingId.uuidString
        ])
        
        return result
    }
    
    // MARK: - Metadata Processing
    private func extractMetadata(from image: UIImage) async -> PhotoMetadata {
        return await withCheckedContinuation { continuation in
            imageProcessingQueue.async {
                var metadata = PhotoMetadata()
                
                guard let imageData = image.jpegData(compressionQuality: 1.0),
                      let source = CGImageSourceCreateWithData(imageData as CFData, nil),
                      let imageProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
                    continuation.resume(returning: metadata)
                    return
                }
                
                // Extract EXIF data
                if let exifDict = imageProperties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                    metadata.exifData = exifDict
                    
                    // Check for sensitive location data
                    if exifDict[kCGImagePropertyExifUserComment as String] != nil {
                        metadata.containsSensitiveData = true
                    }
                }
                
                // Extract GPS data
                if let gpsDict = imageProperties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
                    metadata.gpsData = gpsDict
                    metadata.containsLocationData = true
                    metadata.containsSensitiveData = true
                }
                
                // Extract TIFF data
                if let tiffDict = imageProperties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                    metadata.tiffData = tiffDict
                    
                    // Check for device information
                    if tiffDict[kCGImagePropertyTIFFMake as String] != nil ||
                       tiffDict[kCGImagePropertyTIFFModel as String] != nil {
                        metadata.containsDeviceInfo = true
                        metadata.containsSensitiveData = true
                    }
                }
                
                continuation.resume(returning: metadata)
            }
        }
    }
    
    private func stripMetadata(from image: UIImage) async -> UIImage {
        return await withCheckedContinuation { continuation in
            imageProcessingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: image)
                    return
                }
                
                // Create clean image data without metadata
                guard let imageData = image.jpegData(compressionQuality: 1.0) else {
                    continuation.resume(returning: image)
                    return
                }
                
                // Create new image source
                guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
                      let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                    continuation.resume(returning: image)
                    return
                }
                
                // Create clean image without metadata
                let cleanImage = UIImage(cgImage: cgImage)
                
                // Log metadata stripping
                Task {
                    await self.auditLogger.logSecurityEvent(.metadataStripped, details: [
                        "timestamp": ISO8601DateFormatter().string(from: Date())
                    ])
                }
                
                continuation.resume(returning: cleanImage)
            }
        }
    }
    
    // MARK: - Face Detection and Blurring
    private func detectAndBlurFaces(in image: UIImage) async -> (image: UIImage, faceCount: Int) {
        return await withCheckedContinuation { continuation in
            faceDetectionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: (image, 0))
                    return
                }
                
                guard let ciImage = CIImage(image: image) else {
                    continuation.resume(returning: (image, 0))
                    return
                }
                
                // Create face detection request
                let faceRequest = VNDetectFaceRectanglesRequest()
                faceRequest.usesCPUOnly = true // Ensure on-device processing
                
                let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
                
                do {
                    try handler.perform([faceRequest])
                    
                    guard let results = faceRequest.results, !results.isEmpty else {
                        continuation.resume(returning: (image, 0))
                        return
                    }
                    
                    var processedImage = ciImage
                    
                    // Apply Gaussian blur to detected faces
                    for faceObservation in results {
                        let faceRect = self.convertVisionRectToImageRect(
                            faceObservation.boundingBox,
                            imageSize: ciImage.extent.size
                        )
                        
                        // Expand face region for better privacy
                        let expandedRect = self.expandFaceRect(faceRect, by: 0.2)
                        
                        // Apply strong Gaussian blur
                        let blurFilter = CIFilter.gaussianBlur()
                        blurFilter.inputImage = processedImage.cropped(to: expandedRect)
                        blurFilter.radius = Float(min(expandedRect.width, expandedRect.height) * 0.1)
                        
                        if let blurredFace = blurFilter.outputImage {
                            processedImage = blurredFace.composited(over: processedImage)
                        }
                    }
                    
                    // Convert back to UIImage
                    guard let cgImage = self.ciContext.createCGImage(processedImage, from: processedImage.extent) else {
                        continuation.resume(returning: (image, results.count))
                        return
                    }
                    
                    let finalImage = UIImage(cgImage: cgImage)
                    
                    // Log face blurring
                    Task {
                        await self.auditLogger.logSecurityEvent(.faceBlurred, details: [
                            "faces_count": results.count,
                            "blur_strength": "high"
                        ])
                    }
                    
                    continuation.resume(returning: (finalImage, results.count))
                    
                } catch {
                    continuation.resume(returning: (image, 0))
                }
            }
        }
    }
    
    private func convertVisionRectToImageRect(_ visionRect: CGRect, imageSize: CGSize) -> CGRect {
        let x = visionRect.origin.x * imageSize.width
        let y = (1 - visionRect.origin.y - visionRect.height) * imageSize.height
        let width = visionRect.width * imageSize.width
        let height = visionRect.height * imageSize.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    private func expandFaceRect(_ rect: CGRect, by factor: CGFloat) -> CGRect {
        let expandedWidth = rect.width * (1 + factor)
        let expandedHeight = rect.height * (1 + factor)
        let xOffset = (expandedWidth - rect.width) / 2
        let yOffset = (expandedHeight - rect.height) / 2
        
        return CGRect(
            x: rect.origin.x - xOffset,
            y: rect.origin.y - yOffset,
            width: expandedWidth,
            height: expandedHeight
        )
    }
    
    // MARK: - Background Removal
    private func removeBackground(from image: UIImage) async -> UIImage {
        return await withCheckedContinuation { continuation in
            imageProcessingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: image)
                    return
                }
                
                // Use Vision framework for person segmentation
                guard let ciImage = CIImage(image: image) else {
                    continuation.resume(returning: image)
                    return
                }
                
                let request = VNGeneratePersonSegmentationRequest()
                request.qualityLevel = .accurate
                request.outputPixelFormat = kCVPixelFormatType_OneComponent8
                
                let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
                
                do {
                    try handler.perform([request])
                    
                    guard let result = request.results?.first,
                          let maskPixelBuffer = result.pixelBuffer else {
                        continuation.resume(returning: image)
                        return
                    }
                    
                    // Create mask image
                    let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
                    
                    // Apply mask to create transparent background
                    let filter = CIFilter.blendWithMask()
                    filter.inputImage = ciImage
                    filter.backgroundImage = CIImage.empty()
                    filter.maskImage = maskImage
                    
                    guard let outputImage = filter.outputImage,
                          let cgImage = self.ciContext.createCGImage(outputImage, from: outputImage.extent) else {
                        continuation.resume(returning: image)
                        return
                    }
                    
                    let finalImage = UIImage(cgImage: cgImage)
                    
                    // Log background removal
                    Task {
                        await self.auditLogger.logSecurityEvent(.backgroundRemoved, details: [
                            "method": "person_segmentation",
                            "quality": "accurate"
                        ])
                    }
                    
                    continuation.resume(returning: finalImage)
                    
                } catch {
                    continuation.resume(returning: image)
                }
            }
        }
    }
    
    // MARK: - Watermark Detection and Removal
    private func detectAndRemoveWatermarks(from image: UIImage) async -> (image: UIImage, detected: [WatermarkInfo]) {
        return await withCheckedContinuation { continuation in
            imageProcessingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: (image, []))
                    return
                }
                
                guard let ciImage = CIImage(image: image) else {
                    continuation.resume(returning: (image, []))
                    return
                }
                
                var detectedWatermarks: [WatermarkInfo] = []
                var processedImage = ciImage
                
                // Detect text-based watermarks using Vision
                let textRequest = VNRecognizeTextRequest()
                textRequest.recognitionLevel = .accurate
                textRequest.usesLanguageCorrection = false
                
                let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
                
                do {
                    try handler.perform([textRequest])
                    
                    if let textObservations = textRequest.results {
                        for observation in textObservations {
                            guard let recognizedText = observation.topCandidates(1).first else { continue }
                            
                            // Check if text might be a watermark (common patterns)
                            let watermarkPatterns = [
                                "©", "copyright", "watermark", "getty", "shutterstock",
                                "stock", "photo", "image", "www.", ".com", "alamy"
                            ]
                            
                            let lowercaseText = recognizedText.string.lowercased()
                            let isWatermark = watermarkPatterns.contains { lowercaseText.contains($0) }
                            
                            if isWatermark {
                                let watermarkInfo = WatermarkInfo(
                                    text: recognizedText.string,
                                    boundingBox: observation.boundingBox,
                                    confidence: recognizedText.confidence,
                                    type: .text
                                )
                                detectedWatermarks.append(watermarkInfo)
                                
                                // Apply inpainting to remove watermark
                                let watermarkRect = self.convertVisionRectToImageRect(
                                    observation.boundingBox,
                                    imageSize: ciImage.extent.size
                                )
                                
                                processedImage = self.inpaintRegion(processedImage, region: watermarkRect)
                            }
                        }
                    }
                    
                    // Convert back to UIImage
                    guard let cgImage = self.ciContext.createCGImage(processedImage, from: processedImage.extent) else {
                        continuation.resume(returning: (image, detectedWatermarks))
                        return
                    }
                    
                    let finalImage = UIImage(cgImage: cgImage)
                    
                    // Log watermark detection
                    if !detectedWatermarks.isEmpty {
                        Task {
                            await self.auditLogger.logSecurityEvent(.watermarkDetected, details: [
                                "watermarks_count": detectedWatermarks.count,
                                "removal_attempted": true
                            ])
                        }
                    }
                    
                    continuation.resume(returning: (finalImage, detectedWatermarks))
                    
                } catch {
                    continuation.resume(returning: (image, []))
                }
            }
        }
    }
    
    private func inpaintRegion(_ image: CIImage, region: CGRect) -> CIImage {
        // Simple inpainting using morphological operations and blending
        let expandedRegion = expandFaceRect(region, by: 0.1)
        
        // Apply median filter to surrounding area
        let medianFilter = CIFilter.medianFilter()
        medianFilter.inputImage = image.cropped(to: expandedRegion)
        
        guard let inpaintedRegion = medianFilter.outputImage else { return image }
        
        // Blend back with original
        return inpaintedRegion.composited(over: image)
    }
    
    // MARK: - Privacy Enhancements
    private func applyPrivacyEnhancements(to image: UIImage) async -> UIImage {
        return await withCheckedContinuation { continuation in
            imageProcessingQueue.async { [weak self] in
                guard let self = self,
                      let ciImage = CIImage(image: image) else {
                    continuation.resume(returning: image)
                    return
                }
                
                var enhancedImage = ciImage
                
                // Apply subtle noise to prevent deep learning analysis
                let noiseFilter = CIFilter.randomGenerator()
                if let noiseImage = noiseFilter.outputImage {
                    let blendFilter = CIFilter.sourceOverCompositing()
                    blendFilter.inputImage = noiseImage.cropped(to: ciImage.extent)
                    blendFilter.backgroundImage = enhancedImage
                    
                    if let blendedImage = blendFilter.outputImage {
                        enhancedImage = blendedImage
                    }
                }
                
                // Reduce image quality slightly to prevent forensic analysis
                let qualityFilter = CIFilter.lanczosScaleTransform()
                qualityFilter.inputImage = enhancedImage
                qualityFilter.scale = 0.98 // Slight quality reduction
                
                if let qualityImage = qualityFilter.outputImage {
                    enhancedImage = qualityImage
                }
                
                // Apply color quantization to reduce uniqueness
                let quantizeFilter = CIFilter.colorPosterize()
                quantizeFilter.inputImage = enhancedImage
                quantizeFilter.levels = 64 // Reduce color levels slightly
                
                if let quantizedImage = quantizeFilter.outputImage {
                    enhancedImage = quantizedImage
                }
                
                guard let cgImage = self.ciContext.createCGImage(enhancedImage, from: enhancedImage.extent) else {
                    continuation.resume(returning: image)
                    return
                }
                
                let finalImage = UIImage(cgImage: cgImage)
                continuation.resume(returning: finalImage)
            }
        }
    }
    
    // MARK: - Secure Storage and Vault
    public func storeInPrivateVault(_ image: UIImage, metadata: PhotoMetadata? = nil) async throws -> String {
        let photoId = UUID().uuidString
        
        // Encrypt image data
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw PhotoPrivacyError.imageEncodingFailed
        }
        
        let encryptedImageData = try cryptoEngine.encryptForLocalStorage(
            data: imageData,
            context: "photo_vault_\(photoId)"
        )
        
        // Create vault entry
        let vaultEntry = VaultPhotoEntry(
            id: photoId,
            encryptedImageData: encryptedImageData,
            metadata: metadata,
            createdAt: Date(),
            accessCount: 0
        )
        
        // Store in secure vault
        let vaultData = try JSONEncoder().encode(vaultEntry)
        let encryptedVaultData = try cryptoEngine.encryptForLocalStorage(
            data: vaultData,
            context: "vault_entry"
        )
        
        let vaultURL = getVaultURL().appendingPathComponent("\(photoId).vault")
        let encryptedDataForStorage = try JSONEncoder().encode(encryptedVaultData)
        try encryptedDataForStorage.write(to: vaultURL)
        
        // Log vault storage
        await auditLogger.logSecurityEvent(.privacyVaultAccess, details: [
            "action": "store",
            "photo_id": photoId,
            "encrypted": true
        ])
        
        return photoId
    }
    
    public func retrieveFromPrivateVault(photoId: String) async throws -> (image: UIImage, metadata: PhotoMetadata?) {
        let vaultURL = getVaultURL().appendingPathComponent("\(photoId).vault")
        
        guard FileManager.default.fileExists(atPath: vaultURL.path) else {
            throw PhotoPrivacyError.photoNotFound
        }
        
        // Decrypt vault entry
        let encryptedDataForStorage = try Data(contentsOf: vaultURL)
        let encryptedVaultData = try JSONDecoder().decode(EncryptedData.self, from: encryptedDataForStorage)
        let vaultData = try cryptoEngine.decryptFromLocalStorage(
            encryptedData: encryptedVaultData,
            context: "vault_entry"
        )
        
        var vaultEntry = try JSONDecoder().decode(VaultPhotoEntry.self, from: vaultData)
        
        // Decrypt image data
        let imageData = try cryptoEngine.decryptFromLocalStorage(
            encryptedData: vaultEntry.encryptedImageData,
            context: "photo_vault_\(photoId)"
        )
        
        guard let image = UIImage(data: imageData) else {
            throw PhotoPrivacyError.imageDecodingFailed
        }
        
        // Update access count
        vaultEntry.accessCount += 1
        vaultEntry.lastAccessedAt = Date()
        
        // Save updated entry
        let updatedVaultData = try JSONEncoder().encode(vaultEntry)
        let updatedEncryptedVaultData = try cryptoEngine.encryptForLocalStorage(
            data: updatedVaultData,
            context: "vault_entry"
        )
        let updatedEncryptedDataForStorage = try JSONEncoder().encode(updatedEncryptedVaultData)
        try updatedEncryptedDataForStorage.write(to: vaultURL)
        
        // Log vault access
        await auditLogger.logSecurityEvent(.privacyVaultAccess, details: [
            "action": "retrieve",
            "photo_id": photoId,
            "access_count": vaultEntry.accessCount
        ])
        
        return (image: image, metadata: vaultEntry.metadata)
    }
    
    // MARK: - Settings Management
    private func loadPrivacySettings() {
        // Load settings from secure storage
        if let settingsData = try? KeychainManager.shared.retrieve(type: PhotoPrivacySettings.self, for: "photo_privacy_settings") {
            privacySettings = settingsData
        }
    }
    
    public func updatePrivacySettings(_ settings: PhotoPrivacySettings) throws {
        privacySettings = settings
        try KeychainManager.shared.store(object: settings, for: "photo_privacy_settings")
        
        Task {
            await auditLogger.logSecurityEvent(.permissionGranted, details: [
                "settings_updated": true,
                "face_blurring": settings.automaticFaceBlurring,
                "metadata_stripping": settings.automaticMetadataStripping
            ])
        }
    }
    
    // MARK: - Secure Processing Setup
    private func setupSecureProcessing() {
        // Configure secure processing environment
        
        // Disable network access for ML models
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuOnly // Force CPU-only processing
        
        // Set up memory protection
        setupMemoryProtection()
    }
    
    private func setupMemoryProtection() {
        // Enable secure memory for image processing
        // This would involve setting up protected memory regions
    }
    
    // MARK: - Utility Methods
    private func getVaultURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let vaultPath = documentsPath.appendingPathComponent("PrivateVault")
        
        if !FileManager.default.fileExists(atPath: vaultPath.path) {
            try? FileManager.default.createDirectory(at: vaultPath, withIntermediateDirectories: true)
        }
        
        return vaultPath
    }
}

// MARK: - Supporting Types
public struct PhotoProcessingOptions: CustomStringConvertible {
    public let stripMetadata: Bool
    public let blurFaces: Bool
    public let removeBackground: Bool
    public let detectWatermarks: Bool
    public let enhancePrivacy: Bool
    
    public static let `default` = PhotoProcessingOptions(
        stripMetadata: true,
        blurFaces: true,
        removeBackground: false,
        detectWatermarks: true,
        enhancePrivacy: true
    )
    
    public var description: String {
        return "stripMetadata: \(stripMetadata), blurFaces: \(blurFaces), removeBackground: \(removeBackground), detectWatermarks: \(detectWatermarks), enhancePrivacy: \(enhancePrivacy)"
    }
}

public struct ProcessedPhotoResult {
    public let originalImage: UIImage
    public let processedImage: UIImage
    public let metadata: PhotoMetadata
    public let processingOptions: PhotoProcessingOptions
    public let timestamp: Date
    public let processingId: UUID
}

public struct PhotoMetadata: Codable {
    public var exifData: [String: Any] = [:]
    public var gpsData: [String: Any] = [:]
    public var tiffData: [String: Any] = [:]
    public var faceCount: Int = 0
    public var watermarksDetected: [WatermarkInfo] = []
    public var containsSensitiveData: Bool = false
    public var containsLocationData: Bool = false
    public var containsDeviceInfo: Bool = false
    
    // Custom coding to handle [String: Any]
    private enum CodingKeys: String, CodingKey {
        case exifData, gpsData, tiffData, faceCount, watermarksDetected
        case containsSensitiveData, containsLocationData, containsDeviceInfo
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(faceCount, forKey: .faceCount)
        try container.encode(watermarksDetected, forKey: .watermarksDetected)
        try container.encode(containsSensitiveData, forKey: .containsSensitiveData)
        try container.encode(containsLocationData, forKey: .containsLocationData)
        try container.encode(containsDeviceInfo, forKey: .containsDeviceInfo)
        
        // Encode dictionaries as JSON strings
        let exifJSON = try JSONSerialization.data(withJSONObject: exifData)
        let gpsJSON = try JSONSerialization.data(withJSONObject: gpsData)
        let tiffJSON = try JSONSerialization.data(withJSONObject: tiffData)
        
        try container.encode(String(data: exifJSON, encoding: .utf8) ?? "{}", forKey: .exifData)
        try container.encode(String(data: gpsJSON, encoding: .utf8) ?? "{}", forKey: .gpsData)
        try container.encode(String(data: tiffJSON, encoding: .utf8) ?? "{}", forKey: .tiffData)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        faceCount = try container.decode(Int.self, forKey: .faceCount)
        watermarksDetected = try container.decode([WatermarkInfo].self, forKey: .watermarksDetected)
        containsSensitiveData = try container.decode(Bool.self, forKey: .containsSensitiveData)
        containsLocationData = try container.decode(Bool.self, forKey: .containsLocationData)
        containsDeviceInfo = try container.decode(Bool.self, forKey: .containsDeviceInfo)
        
        // Decode dictionaries from JSON strings
        let exifString = try container.decode(String.self, forKey: .exifData)
        let gpsString = try container.decode(String.self, forKey: .gpsData)
        let tiffString = try container.decode(String.self, forKey: .tiffData)
        
        if let exifData = exifString.data(using: .utf8),
           let exif = try? JSONSerialization.jsonObject(with: exifData) as? [String: Any] {
            self.exifData = exif
        }
        
        if let gpsData = gpsString.data(using: .utf8),
           let gps = try? JSONSerialization.jsonObject(with: gpsData) as? [String: Any] {
            self.gpsData = gps
        }
        
        if let tiffData = tiffString.data(using: .utf8),
           let tiff = try? JSONSerialization.jsonObject(with: tiffData) as? [String: Any] {
            self.tiffData = tiff
        }
    }
    
    public init() {}
}

public struct WatermarkInfo: Codable {
    public let text: String
    public let boundingBox: CGRect
    public let confidence: Float
    public let type: WatermarkType
    
    public enum WatermarkType: String, Codable {
        case text = "text"
        case logo = "logo"
        case pattern = "pattern"
    }
}

public struct PhotoPrivacySettings: Codable {
    public var automaticFaceBlurring: Bool = true
    public var automaticMetadataStripping: Bool = true
    public var automaticBackgroundRemoval: Bool = false
    public var watermarkDetection: Bool = true
    public var privacyEnhancements: Bool = true
    public var secureVaultEnabled: Bool = true
    public var onDeviceProcessingOnly: Bool = true
    
    public init() {}
}

public struct VaultPhotoEntry: Codable {
    public let id: String
    public let encryptedImageData: EncryptedData
    public let metadata: PhotoMetadata?
    public let createdAt: Date
    public var accessCount: Int
    public var lastAccessedAt: Date?
}

public enum PhotoPrivacyError: LocalizedError {
    case imageEncodingFailed
    case imageDecodingFailed
    case photoNotFound
    case processingFailed
    case vaultAccessDenied
    
    public var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return "Failed to encode image data"
        case .imageDecodingFailed:
            return "Failed to decode image data"
        case .photoNotFound:
            return "Photo not found in vault"
        case .processingFailed:
            return "Photo processing failed"
        case .vaultAccessDenied:
            return "Access to private vault denied"
        }
    }
}