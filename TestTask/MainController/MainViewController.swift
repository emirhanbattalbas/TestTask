import UIKit
import AVFoundation
import TensorFlowLite
import TensorFlowLiteC

class MainViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        showCamera()
    }
    
    private func showCamera() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = .camera
        present(imagePickerController, animated: true, completion: nil)
    }
}

// MARK: - UIImagePickerControllerDelegate
extension MainViewController: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) { }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { }
}

// MARK: - UINavigationControllerDelegate
extension MainViewController: UINavigationControllerDelegate { }
