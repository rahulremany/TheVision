import UIKit
import CoreML
import Vision
import Photos

class ObjectRemovalViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var selectImageButton: UIButton!
    @IBOutlet weak var removeObjectButton: UIButton!
    @IBOutlet weak var replaceBackgroundButton: UIButton!
    @IBOutlet weak var undoButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var selectNewButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var selectNewBackgroundButton: UIButton!
    @IBOutlet weak var blackLabel: UILabel!
    
    // MARK: - Properties
    var originalImage: UIImage?
    var currentImage: UIImage?
    var isObjectRemoval: Bool = false

    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupInitialView()
            
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        imageView.addGestureRecognizer(tapGestureRecognizer)
        imageView.isUserInteractionEnabled = true
    }
    
    // MARK: - Handle Tap for Object Removal
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        let point = sender.location(in: imageView)
        if isObjectRemoval {
            removeObject(at: point)
        }
    }
        
    // MARK: - Setup Initial View
    func setupInitialView() {
        imageView.isHidden = true
        selectNewButton.isHidden = true
        saveButton.isHidden = true
        cancelButton.isHidden = true
        removeObjectButton.isHidden = true
        replaceBackgroundButton.isHidden = true
        undoButton.isHidden = true
        blackLabel.isHidden = false
        selectNewBackgroundButton.isHidden = true
    }
    
    @IBAction func selectImageTapped(_ sender: Any) {
        presentImagePicker()
    }
    
    @IBAction func removeObjectTapped(_ sender: Any) {
        isObjectRemoval = true
        saveButton.isHidden = false
        cancelButton.isHidden = false
        undoButton.isHidden = false
        removeObjectButton.isHidden = true
        replaceBackgroundButton.isHidden = true
        selectNewBackgroundButton.isHidden = true
    }
    
    @IBAction func replaceBackgroundTapped(_ sender: Any) {
        isObjectRemoval = false
        presentBackgroundImagePicker()
        saveButton.isHidden = false
        cancelButton.isHidden = false
        selectNewButton.isHidden = false
        selectNewBackgroundButton.isHidden = false
        removeObjectButton.isHidden = true
        replaceBackgroundButton.isHidden = true
        undoButton.isHidden = false
    }
    
    @IBAction func undoButtonTapped(_ sender: Any) {
        undoLastAction()
    }
    
    @IBAction func saveButtonTapped(_ sender: Any) {
        saveImageToPhotoLibrary()
    }
    
    @IBAction func cancelButtonTapped(_ sender: Any) {
        setupInitialView()
        imageView.image = originalImage
        selectImageButton.isHidden = false
    }
    
    @IBAction func selectNewImageTapped(_ sender: Any) {
        presentImagePicker()
    }
    
    @IBAction func selectNewBackgroundTapped(_ sender: Any) {
        presentBackgroundImagePicker()
    }
    
    func presentImagePicker() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = .photoLibrary
        present(imagePickerController, animated: true, completion: nil)
    }

    func presentBackgroundImagePicker() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = .photoLibrary
        present(imagePickerController, animated: true, completion: nil)
    }

    // MARK: - UIImagePickerControllerDelegate Methods
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let selectedImage = info[.originalImage] as? UIImage {
                originalImage = selectedImage
                currentImage = selectedImage
                imageView.image = selectedImage
                
                // Update UI based on image selection
                imageView.isHidden = false
                selectImageButton.isHidden = true
                removeObjectButton.isHidden = false
                replaceBackgroundButton.isHidden = false
                selectNewButton.isHidden = false
                undoButton.isHidden = true
                saveButton.isHidden = true
                cancelButton.isHidden = true
                selectNewBackgroundButton.isHidden = true
                blackLabel.isHidden = true
            }
            dismiss(animated: true, completion: nil)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss(animated: true, completion: nil)
        }

    // MARK: - Undo Last Action
    func undoLastAction() {
        imageView.image = currentImage
    }

    // MARK: - Save Image to Photo Library
    func saveImageToPhotoLibrary() {
        guard let image = imageView.image else { return }
            
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }) { success, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.showAlert(title: "Save error", message: error.localizedDescription)
                        } else {
                            self.showAlert(title: "Saved!", message: "Your altered image has been saved to your photos.")
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.showAlert(title: "Save error", message: "Permission to access the photo library was denied.")
                }
            }
        }
    }

    // MARK: - Show Alert
    func showAlert(title: String, message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }

    // MARK: - Object Removal
    func removeObject(at point: CGPoint) {
        guard let image = imageView.image else { return }

        // Convert image to CVPixelBuffer
        guard let pixelBuffer = image.toCVPixelBuffer() else { return }

        // Load CoreML model
        guard let model = try? VNCoreMLModel(for: aesrgan(configuration: MLModelConfiguration()).model) else {
            print("Failed to load model")
            return
        }

        // Create Vision request
        let request = VNCoreMLRequest(model: model) { [weak self] (request, error) in
            if let results = request.results as? [VNPixelBufferObservation], let outputBuffer = results.first?.pixelBuffer {
                let outputImage = UIImage(pixelBuffer: outputBuffer)
                DispatchQueue.main.async {
                    self?.currentImage = self?.imageView.image
                    self?.imageView.image = outputImage
                }
            }
        }

        // Perform Vision request
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    // MARK: - Background Replacement
    func replaceBackground(with backgroundImage: UIImage) {
        guard let foregroundImage = imageView.image else { return }

        // Combine foregroundImage and backgroundImage using CoreImage or any other image processing method
        let combinedImage = combineImages(foreground: foregroundImage, background: backgroundImage)
        imageView.image = combinedImage
    }

    func combineImages(foreground: UIImage, background: UIImage) -> UIImage {
        let size = background.size
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        
        background.draw(in: CGRect(origin: .zero, size: size))
        foreground.draw(in: CGRect(origin: .zero, size: size), blendMode: .normal, alpha: 1.0)
        
        let combinedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return combinedImage ?? background
    }
}
