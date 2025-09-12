import SwiftUI
import AVFoundation
import UIKit

struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onImageCaptured = onImageCaptured
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        // No updates needed
    }
}

class CameraViewController: UIViewController {
    var onImageCaptured: ((UIImage) -> Void)?
    
    private var captureSession: AVCaptureSession!
    private var stillImageOutput: AVCapturePhotoOutput!
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    
    // UI Elements
    private var previewView: UIView!
    private var captureButton: UIButton!
    private var flipCameraButton: UIButton!
    private var flashButton: UIButton!
    private var closeButton: UIButton!
    private var gridOverlay: GridOverlayView!
    private var focusView: UIView!
    
    // Camera settings
    private var isFlashEnabled = false
    private var isGridEnabled = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCamera()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startCaptureSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCaptureSession()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        // Preview view
        previewView = UIView()
        previewView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewView)
        
        // Grid overlay
        gridOverlay = GridOverlayView()
        gridOverlay.translatesAutoresizingMaskIntoConstraints = false
        gridOverlay.isHidden = !isGridEnabled
        previewView.addSubview(gridOverlay)
        
        // Focus view
        focusView = UIView()
        focusView.layer.borderColor = UIColor.systemYellow.cgColor
        focusView.layer.borderWidth = 2
        focusView.frame = CGRect(x: 0, y: 0, width: 80, height: 80)
        focusView.isHidden = true
        previewView.addSubview(focusView)
        
        // Close button
        closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 20
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        
        // Flash button
        flashButton = UIButton(type: .system)
        flashButton.setImage(UIImage(systemName: "bolt.slash"), for: .normal)
        flashButton.tintColor = .white
        flashButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        flashButton.layer.cornerRadius = 20
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.addTarget(self, action: #selector(flashTapped), for: .touchUpInside)
        view.addSubview(flashButton)
        
        // Flip camera button
        flipCameraButton = UIButton(type: .system)
        flipCameraButton.setImage(UIImage(systemName: "camera.rotate"), for: .normal)
        flipCameraButton.tintColor = .white
        flipCameraButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        flipCameraButton.layer.cornerRadius = 20
        flipCameraButton.translatesAutoresizingMaskIntoConstraints = false
        flipCameraButton.addTarget(self, action: #selector(flipCameraTapped), for: .touchUpInside)
        view.addSubview(flipCameraButton)
        
        // Capture button
        captureButton = UIButton(type: .system)
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 35
        captureButton.layer.borderWidth = 4
        captureButton.layer.borderColor = UIColor.white.cgColor
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        view.addSubview(captureButton)
        
        setupConstraints()
        setupGestures()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Preview view
            previewView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            
            // Grid overlay
            gridOverlay.topAnchor.constraint(equalTo: previewView.topAnchor),
            gridOverlay.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
            gridOverlay.trailingAnchor.constraint(equalTo: previewView.trailingAnchor),
            gridOverlay.bottomAnchor.constraint(equalTo: previewView.bottomAnchor),
            
            // Close button
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Flash button
            flashButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            flashButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            flashButton.widthAnchor.constraint(equalToConstant: 40),
            flashButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Flip camera button
            flipCameraButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            flipCameraButton.trailingAnchor.constraint(equalTo: flashButton.leadingAnchor, constant: -12),
            flipCameraButton.widthAnchor.constraint(equalToConstant: 40),
            flipCameraButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Capture button
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70)
        ])
    }
    
    private func setupGestures() {
        // Tap to focus
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(focusTapped(_:)))
        previewView.addGestureRecognizer(tapGesture)
        
        // Pinch to zoom
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(pinchToZoom(_:)))
        previewView.addGestureRecognizer(pinchGesture)
    }
    
    // MARK: - Camera Setup
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Unable to access back camera")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            
            stillImageOutput = AVCapturePhotoOutput()
            
            if captureSession.canAddInput(input) && captureSession.canAddOutput(stillImageOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(stillImageOutput)
                
                setupLivePreview()
            }
        } catch {
            print("Error setting up camera: \(error)")
        }
    }
    
    private func setupLivePreview() {
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.connection?.videoOrientation = .portrait
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.previewView.layer.addSublayer(self.videoPreviewLayer)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoPreviewLayer?.frame = previewView.bounds
    }
    
    private func startCaptureSession() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    private func stopCaptureSession() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
    
    // MARK: - Camera Actions
    @objc private func captureTapped() {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        
        // Configure flash
        if isFlashEnabled {
            settings.flashMode = .on
        } else {
            settings.flashMode = .off
        }
        
        // Add capture animation
        animateCaptureButton()
        
        stillImageOutput.capturePhoto(with: settings, delegate: self)
    }
    
    @objc private func flipCameraTapped() {
        let newPosition: AVCaptureDevice.Position = (currentCameraPosition == .back) ? .front : .back
        
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            return
        }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            
            captureSession.beginConfiguration()
            
            // Remove existing input
            if let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput {
                captureSession.removeInput(currentInput)
            }
            
            // Add new input
            if captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)
                currentCameraPosition = newPosition
            }
            
            captureSession.commitConfiguration()
            
            // Animate flip
            UIView.transition(with: previewView, duration: 0.3, options: .transitionFlipFromLeft, animations: nil)
            
        } catch {
            print("Error switching camera: \(error)")
        }
    }
    
    @objc private func flashTapped() {
        isFlashEnabled.toggle()
        let imageName = isFlashEnabled ? "bolt" : "bolt.slash"
        flashButton.setImage(UIImage(systemName: imageName), for: .normal)
        
        // Animate button
        UIView.animate(withDuration: 0.2) {
            self.flashButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                self.flashButton.transform = .identity
            }
        }
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func focusTapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: previewView)
        focusAt(point: point)
    }
    
    @objc private func pinchToZoom(_ gesture: UIPinchGestureRecognizer) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) else {
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            let maxZoomFactor = device.activeFormat.videoMaxZoomFactor
            let pinchVelocityDividerFactor: CGFloat = 5.0
            
            if gesture.state == .changed {
                let desiredZoomFactor = device.videoZoomFactor + atan2(gesture.velocity, pinchVelocityDividerFactor)
                device.videoZoomFactor = max(1.0, min(desiredZoomFactor, maxZoomFactor))
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error adjusting zoom: \(error)")
        }
    }
    
    // MARK: - Camera Features
    private func focusAt(point: CGPoint) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) else {
            return
        }
        
        // Convert point to camera coordinates
        let focusPoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = focusPoint
                device.focusMode = .autoFocus
            }
            
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = focusPoint
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
            
            // Show focus animation
            showFocusAnimation(at: point)
            
        } catch {
            print("Error focusing camera: \(error)")
        }
    }
    
    private func showFocusAnimation(at point: CGPoint) {
        focusView.center = point
        focusView.isHidden = false
        focusView.alpha = 1.0
        focusView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        
        UIView.animate(withDuration: 0.3) {
            self.focusView.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 0.5) {
                self.focusView.alpha = 0.0
            } completion: { _ in
                self.focusView.isHidden = true
            }
        }
    }
    
    private func animateCaptureButton() {
        UIView.animate(withDuration: 0.1) {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        } completion: { _ in
            UIView.animate(withDuration: 0.1) {
                self.captureButton.transform = .identity
            }
        }
        
        // Flash effect
        let flashView = UIView(frame: view.bounds)
        flashView.backgroundColor = .white
        flashView.alpha = 0.0
        view.addSubview(flashView)
        
        UIView.animate(withDuration: 0.1) {
            flashView.alpha = 0.8
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                flashView.alpha = 0.0
            } completion: { _ in
                flashView.removeFromSuperview()
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Error capturing photo: \(error?.localizedDescription ?? "Unknown error")")
            return
        }
        
        // Apply orientation correction
        let correctedImage = image.fixOrientation()
        
        // Call completion handler
        onImageCaptured?(correctedImage)
        
        // Dismiss camera
        dismiss(animated: true)
    }
}

// MARK: - Grid Overlay View
class GridOverlayView: UIView {
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(0.5)
        
        let width = rect.width
        let height = rect.height
        
        // Vertical lines
        let verticalSpacing = width / 3
        for i in 1..<3 {
            let x = CGFloat(i) * verticalSpacing
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: height))
        }
        
        // Horizontal lines
        let horizontalSpacing = height / 3
        for i in 1..<3 {
            let y = CGFloat(i) * horizontalSpacing
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: width, y: y))
        }
        
        context.strokePath()
    }
}

// MARK: - UIImage Extension
extension UIImage {
    func fixOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? self
    }
}

// MARK: - Image Picker (for photo library)
struct ImagePicker: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageSelected: (UIImage) -> Void
        
        init(onImageSelected: @escaping (UIImage) -> Void) {
            self.onImageSelected = onImageSelected
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                onImageSelected(editedImage)
            } else if let originalImage = info[.originalImage] as? UIImage {
                onImageSelected(originalImage)
            }
            
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}