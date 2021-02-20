import UIKit
import AVFoundation
import TensorFlowLite
import TensorFlowLiteC

class MainViewController: UIViewController {
    
    // MARK: Storyboards Connections
    @IBOutlet weak var previewView: PreviewView!
    @IBOutlet weak var overlayView: OverlayView!

    // MARK: Constants
    private let displayFont = UIFont.systemFont(ofSize: 14.0, weight: .medium)
    private let edgeOffset: CGFloat = 2.0
    private let delayBetweenInferencesMs: Double = 200
        
    // Holds the results at any time
    private var result: Result?
    private var previousInferenceTimeMs: TimeInterval = Date.distantPast.timeIntervalSince1970 * 1000
    
    // MARK: Controllers that manage functionality
    private lazy var cameraFeedManager = CameraFeedManager(previewView: previewView)
    private var modelDataHandler: ModelDataHandler? = ModelDataHandler(modelFileInfo: MobileNetSSD.modelInfo, labelsFileInfo: MobileNetSSD.labelsInfo)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard modelDataHandler != nil else {
            fatalError("Failed to load model")
        }
        cameraFeedManager.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraFeedManager.checkCameraConfigurationAndStartSession()
    }
}

// MARK: CameraFeedManagerDelegate Methods
extension MainViewController: CameraFeedManagerDelegate {
    
    func didOutput(pixelBuffer: CVPixelBuffer) {
        runModel(onPixelBuffer: pixelBuffer)
    }
    
    func presentVideoConfigurationErrorAlert() {
        
        let alertController = UIAlertController(title: "Configuration Failed",
                                                message: "Configuration of camera has failed.",
                                                preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
        alertController.addAction(okAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    func presentCameraPermissionsDeniedAlert() {
        
        let alertController = UIAlertController(title: "Camera Permissions Denied",
                                                message: "Camera permissions have been denied for this app. You can change this by going to Settings",
                                                preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let settingsAction = UIAlertAction(title: "Settings", style: .default) { (action) in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(settingsAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    @objc  func runModel(onPixelBuffer pixelBuffer: CVPixelBuffer) {
                
        let currentTimeMs = Date().timeIntervalSince1970 * 1000
        guard  (currentTimeMs - previousInferenceTimeMs) >= delayBetweenInferencesMs else {
            return
        }
        
        previousInferenceTimeMs = currentTimeMs
        result = self.modelDataHandler?.runModel(onFrame: pixelBuffer)
        
        guard let displayResult = result else {
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        DispatchQueue.main.async {
            self.drawAfterPerformingCalculations(onInferences: displayResult.inferences,
                                                 withImageSize: CGSize(width: CGFloat(width), height: CGFloat(height)))
        }
    }
    
    func drawAfterPerformingCalculations(onInferences inferences: [Inference], withImageSize imageSize: CGSize) {
        
        self.overlayView.objectOverlays = []
        self.overlayView.setNeedsDisplay()
        
        guard !inferences.isEmpty else {
            return
        }
        
        var objectOverlays: [ObjectOverlay] = []
        
        for inference in inferences {
            
            var convertedRect = inference.rect.applying(CGAffineTransform(scaleX: self.overlayView.bounds.size.width / imageSize.width, y: self.overlayView.bounds.size.height / imageSize.height))
            
            if convertedRect.origin.x < 0 {
                convertedRect.origin.x = self.edgeOffset
            }
            
            if convertedRect.origin.y < 0 {
                convertedRect.origin.y = self.edgeOffset
            }
            
            if convertedRect.maxY > self.overlayView.bounds.maxY {
                convertedRect.size.height = self.overlayView.bounds.maxY - convertedRect.origin.y - self.edgeOffset
            }
            
            if convertedRect.maxX > self.overlayView.bounds.maxX {
                convertedRect.size.width = self.overlayView.bounds.maxX - convertedRect.origin.x - self.edgeOffset
            }
            
            let confidenceValue = Int(inference.confidence * 100.0)
            let string = "\(inference.className)  (\(confidenceValue)%)"
            
            let size = string.size(usingFont: self.displayFont)
            
            let objectOverlay = ObjectOverlay(name: string,
                                              borderRect: convertedRect,
                                              nameStringSize: size,
                                              color: inference.displayColor,
                                              font: self.displayFont)
            objectOverlays.append(objectOverlay)
        }
        
        self.draw(objectOverlays: objectOverlays)
    }
    
    func draw(objectOverlays: [ObjectOverlay]) {
        
        self.overlayView.objectOverlays = objectOverlays
        self.overlayView.setNeedsDisplay()
    }
}
