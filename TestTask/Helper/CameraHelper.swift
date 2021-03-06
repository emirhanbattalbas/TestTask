import UIKit
import AVFoundation

// MARK: CameraFeedManagerDelegate Declaration
protocol CameraFeedManagerDelegate: class {

    func didOutput(pixelBuffer: CVPixelBuffer)
    
    func presentCameraPermissionsDeniedAlert()
    
    func presentVideoConfigurationErrorAlert()
}

enum CameraConfiguration {
    
    case success
    case failed
    case permissionDenied
}

class CameraFeedManager: NSObject {
    
    // MARK: Camera Related Instance Variables
    private let session: AVCaptureSession = AVCaptureSession()
    private let previewView: PreviewView
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private var cameraConfiguration: CameraConfiguration = .failed
    private lazy var videoDataOutput = AVCaptureVideoDataOutput()
    private lazy var photoDataOutput = AVCapturePhotoOutput()
    private var isSessionRunning = false
    var photoTakeCompletion: ((UIImage?) -> (Void))?
    
    // MARK: CameraFeedManagerDelegate
    weak var delegate: CameraFeedManagerDelegate?
    
    // MARK: Initializer
    init(previewView: PreviewView) {
        self.previewView = previewView
        super.init()
        
        // Initializes the session
        session.sessionPreset = .high
        self.previewView.session = session
        self.previewView.previewLayer.connection?.videoOrientation = .portrait
        self.previewView.previewLayer.videoGravity = .resizeAspectFill
        self.attemptToConfigureSession()
    }
    
    func checkCameraConfigurationAndStartSession() {
        sessionQueue.async {
            switch self.cameraConfiguration {
            case .success:
                self.startSession()
            case .failed:
                DispatchQueue.main.async {
                    self.delegate?.presentVideoConfigurationErrorAlert()
                }
            case .permissionDenied:
                DispatchQueue.main.async {
                    self.delegate?.presentCameraPermissionsDeniedAlert()
                }
            }
        }
    }
    
    func stopSession() {
        self.removeObservers()
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
            }
        }
    }
    
    func resumeInterruptedSession(withCompletion completion: @escaping (Bool) -> ()) {
        sessionQueue.async {
            self.startSession()
            DispatchQueue.main.async {
                completion(self.isSessionRunning)
            }
        }
    }

    func startSession() {
        self.session.startRunning()
        self.isSessionRunning = self.session.isRunning
    }
    
    private func attemptToConfigureSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.cameraConfiguration = .success
        case .notDetermined:
            self.sessionQueue.suspend()
            self.requestCameraAccess(completion: { (granted) in
                self.sessionQueue.resume()
            })
        case .denied:
            self.cameraConfiguration = .permissionDenied
        default:
            break
        }
        
        self.sessionQueue.async {
            self.configureSession()
        }
    }
    
    private func requestCameraAccess(completion: @escaping (Bool) -> ()) {
        AVCaptureDevice.requestAccess(for: .video) { (granted) in
            if !granted {
                self.cameraConfiguration = .permissionDenied
            } else {
                self.cameraConfiguration = .success
            }
            completion(granted)
        }
    }
    
    private func configureSession() {
        
        guard cameraConfiguration == .success else {
            return
        }
        session.beginConfiguration()
        
        // Tries to add an AVCaptureDeviceInput.
        guard addVideoDeviceInput() == true else {
            self.session.commitConfiguration()
            self.cameraConfiguration = .failed
            return
        }
        
        // Tries to add an AVCaptureVideoDataOutput.
        guard addVideoDataOutput() else {
            self.session.commitConfiguration()
            self.cameraConfiguration = .failed
            return
        }
        
        session.commitConfiguration()
        self.cameraConfiguration = .success
    }
    
    private func addVideoDeviceInput() -> Bool {
        
        guard let camera  = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            fatalError("Cannot find camera")
        }
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                if session.canAddOutput(photoDataOutput) {
                    session.addOutput(photoDataOutput)
                }
                return true
            } else {
                return false
            }
        }
        catch {
            fatalError("Cannot create video device input")
        }
    }
    
    private func addVideoDataOutput() -> Bool {
        
        let sampleBufferQueue = DispatchQueue(label: "sampleBufferQueue")
        videoDataOutput.setSampleBufferDelegate(self, queue: sampleBufferQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [ String(kCVPixelBufferPixelFormatTypeKey) : kCMPixelFormat_32BGRA]
        
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            videoDataOutput.connection(with: .video)?.videoOrientation = .portrait
            return true
        }
        return false
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureSessionRuntimeError, object: session)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureSessionWasInterrupted, object: session)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureSessionInterruptionEnded, object: session)
    }
}

extension CameraFeedManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // Converts the CMSampleBuffer to a CVPixelBuffer.
        let pixelBuffer: CVPixelBuffer? = CMSampleBufferGetImageBuffer(sampleBuffer)
        
        guard let imagePixelBuffer = pixelBuffer else {
            return
        }
        
        delegate?.didOutput(pixelBuffer: imagePixelBuffer)
    }
}

extension CameraFeedManager: AVCapturePhotoCaptureDelegate {
    
    func handleTakePhoto() {
        let photoSettings = AVCapturePhotoSettings()
        if let photoPreviewType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoPreviewType]
            photoDataOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        let previewImage = UIImage(data: imageData)
        self.photoTakeCompletion?(previewImage)
    }
}
