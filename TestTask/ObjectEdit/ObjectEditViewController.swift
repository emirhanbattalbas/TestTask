import UIKit

protocol ObjectEditViewControllerDelegate: AnyObject {
    func didDismissTapped()
}

class ObjectEditViewController: UIViewController {

    @IBOutlet var objectImageView: UIImageView!
    
    var image = UIImage(named: "")
    weak var delegate: ObjectEditViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        objectImageView.image = image
        objectImageView.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi/2))
    }
    
    @IBAction func dismissButtonTapped(_ sender: UIButton) {
        self.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.delegate?.didDismissTapped()
        }
    }
}
