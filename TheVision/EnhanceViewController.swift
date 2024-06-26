import UIKit
import CoreML
import Vision

class EnhanceViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var doItForMeButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var uiLabel: UILabel!
    @IBOutlet weak var diffImageBtn: UIButton!
    @IBOutlet weak var selectImage: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        diffImageBtn.isHidden = true
        imageView.isHidden = true
    }

    @IBAction func selectPictureTapped(_ sender: UIButton) {
        presentImagePicker()
    }

    @IBAction func selectDifferentImageTapped(_ sender: UIButton) {
        presentImagePicker()
    }

    @IBAction func doItForMeButtonTapped(_ sender: UIButton) {
        enhanceImageAutomatically()
    }

    func enhanceImageAutomatically() {
        guard let image = imageView.image else { return }

        guard let pixelBuffer = image.toCVPixelBuffer() else { return }

        guard let model = try? VNCoreMLModel(for: aesrgan(configuration: MLModelConfiguration()).model) else {
            print("Failed to load model")
            return
        }

        let request = VNCoreMLRequest(model: model) { [weak self] (request, error) in
            if let results = request.results as? [VNPixelBufferObservation], let outputBuffer = results.first?.pixelBuffer {
                let outputImage = UIImage(pixelBuffer: outputBuffer)
                DispatchQueue.main.async {
                    self?.imageView.image = outputImage
                }
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    func presentImagePicker() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = .photoLibrary
        present(imagePickerController, animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let selectedImage = info[.originalImage] as? UIImage {
            imageView.image = selectedImage
            imageView.isHidden = false
            selectImage.isHidden = true
            diffImageBtn.isHidden = false
            uiLabel.isHidden = true
        }
        dismiss(animated: true, completion: nil)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}

/**
 Extension of UIImage to add function to convert Image to CVPixelBuffer, which is what the model needs to work with
 **/
extension UIImage {
    func toCVPixelBuffer() -> CVPixelBuffer? {
        // Get Image Dimensions
        let width = Int(self.size.width)
        let height = Int(self.size.height)

        // Create the buffer
        var pixelBuffer: CVPixelBuffer?

        // These attributes allow compatibility with Core Graphics and Core Video
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary

        // Creates the buffer with the width, height, pixel format and attributes
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, attributes, &pixelBuffer)

        // Protected assignment of buffer to our new pixel buffer
        guard let buffer = pixelBuffer else {
            return nil
        }

        // Lock the base address to ensure that memory is accessible, and then retrieve base address
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(buffer)

        // Create Core Graphics context using base address to match buffer's pixel format and dimensions
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

        // Adjust the coordinate system to match that of UIKit and draw in the UIImage
        context?.translateBy(x: 0, y: CGFloat(height))
        context?.scaleBy(x: 1.0, y: -1.0)
        UIGraphicsPushContext(context!)
        self.draw(in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        UIGraphicsPopContext()

        // Unlock the base address and return the buffer
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        return buffer
    }
}

/**
 Extension to convert the CVPixelBuffer back to a UIImage so we can display it
 **/
extension UIImage {
    convenience init?(pixelBuffer: CVPixelBuffer) {
        // Create CIImage from the buffer and a CIContext to render the CIImage to a CGImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        // Create a CGImage from the CIImage
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            // Initialize the UIImage
            self.init(cgImage: cgImage)
        } else {
            return nil
        }
    }
}

