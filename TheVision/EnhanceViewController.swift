import UIKit
import CoreML
import Vision
import Photos

class EnhanceViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // Outlets for all of the views on the page
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var doItForMeButton: UIButton!
    @IBOutlet weak var uiLabel: UILabel!
    @IBOutlet weak var diffImageBtn: UIButton!
    @IBOutlet weak var brightnessSlider: UISlider!
    @IBOutlet weak var saturationSlider: UISlider!
    @IBOutlet weak var contrastSlider: UISlider!
    @IBOutlet weak var selectImage: UIButton!
    @IBOutlet weak var brightnessLabel: UILabel!
    @IBOutlet weak var saturationLabel: UILabel!
    @IBOutlet weak var contrastLabel: UILabel!
    @IBOutlet weak var saveLabel: UILabel!
    @IBOutlet weak var revertButton: UIButton!
    
    // Global variable for our original image in the case of revertion
    var originalImage: UIImage?

    // Initial view function that hides everything except the label at the top and the select image label
    override func viewDidLoad() {
        super.viewDidLoad()
        diffImageBtn.isHidden = true
        imageView.isHidden = true
        brightnessSlider.isHidden = true
        saturationSlider.isHidden = true
        contrastSlider.isHidden = true
        brightnessLabel.isHidden = true
        saturationLabel.isHidden = true
        contrastLabel.isHidden = true
        doItForMeButton.isHidden = true
        saveLabel.isHidden = true
        revertButton.isHidden = true
        
        // Set default slider values
        brightnessSlider.value = 0
        contrastSlider.value = 1
        saturationSlider.value = 1
    }

    /**
     Following functions serve as the action handlers for all the buttons on the screen
     They call external functions in the app
     **/
    @IBAction func selectPictureTapped(_ sender: UIButton) {
        presentImagePicker()
    }

    @IBAction func selectDifferentImageTapped(_ sender: UIButton) {
        presentImagePicker()
    }

    @IBAction func doItForMeButtonTapped(_ sender: UIButton) {
        enhanceImageAutomatically()
    }
    
    @IBAction func brightnessSliderChanged(_ sender: UISlider) {
        applyFilters()
    }
    
    @IBAction func saturationSliderChanged(_ sender: UISlider) {
        applyFilters()
    }
    
    @IBAction func contrastSliderChanged(_ sender: UISlider) {
        applyFilters()
    }
    
    @IBAction func revertButtonTapped(_ sender: UIButton) {
        revertToOriginalImage()
    }

    // Code to generate any alert boxes required
    func showAlert(title: String, message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
    
    //
    func applyFilters() {
        // Ensure there's an original image to work with
        guard let originalImage = originalImage else { return }
        
        // Get the CGImage from the original UIIMage
        guard let cgImage = originalImage.cgImage else { return }
        
        // Create a CIImage from the CGImage considering the orientation
        let inputImage = CIImage(cgImage: cgImage, options: [CIImageOption.applyOrientationProperty: true])
        
        // Get the values for the sliders
        let brightness = brightnessSlider.value // range: -1.0 to 1.0
        let contrast = contrastSlider.value * 2.0 // range: 0.0 to 4.0 (Slider 0.0 to 2.0)
        let saturation = saturationSlider.value * 2.0 // range: 0.0 to 2.0
        
        // Create the CIFilter that controls the color controls
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(inputImage, forKey: kCIInputImageKey)
        filter?.setValue(brightness, forKey: kCIInputBrightnessKey)
        filter?.setValue(contrast, forKey: kCIInputContrastKey)
        filter?.setValue(saturation, forKey: kCIInputSaturationKey)
        
        // Create a CIContext to render the filtered image
        let context = CIContext(options: nil)
        if let outputImage = filter?.outputImage,
           let cgOutputImage = context.createCGImage(outputImage, from: outputImage.extent) {
            imageView.image = UIImage(cgImage: cgOutputImage, scale: originalImage.scale, orientation: originalImage.imageOrientation)
        }
    }
    
    // Function to handle the "Do it for me" button that uses the AI model to enhance the image using Super Resolution
    func enhanceImageAutomatically() {
        // Ensure we have an image
        guard let image = imageView.image else { return }

        // Create a pixel buffer to write the new image to
        guard let pixelBuffer = image.toCVPixelBuffer() else { return }

        // Ensure we can load the model
        guard let model = try? VNCoreMLModel(for: aesrgan(configuration: MLModelConfiguration()).model) else {
            print("Failed to load model")
            return
        }

        // Create a request to the AESRGAN model and get the result as an output buffer and then push it into an image
        let request = VNCoreMLRequest(model: model) { [weak self] (request, error) in
            if let results = request.results as? [VNPixelBufferObservation], let outputBuffer = results.first?.pixelBuffer {
                let outputImage = UIImage(pixelBuffer: outputBuffer)
                DispatchQueue.main.async {
                    self?.imageView.image = outputImage
                }
            }
        }

        // Define a handler for the request and let it perform the request
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    // Function to open the image selector
    func presentImagePicker() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = .photoLibrary
        present(imagePickerController, animated: true, completion: nil)
    }

    // Controller that handles the state of the screen once an image is selected
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let selectedImage = info[.originalImage] as? UIImage {
            originalImage = selectedImage // Store the original image
            imageView.image = selectedImage
            imageView.isHidden = false
            selectImage.isHidden = true
            diffImageBtn.isHidden = false
            uiLabel.isHidden = true
            revertButton.isHidden = false // Show the revert button after an image is selected
            brightnessSlider.isHidden = false
            saturationSlider.isHidden = false
            contrastSlider.isHidden = false
            brightnessLabel.isHidden = false
            saturationLabel.isHidden = false
            contrastLabel.isHidden = false
            saveLabel.isHidden = false
            doItForMeButton.isHidden = false
            
        }
        dismiss(animated: true, completion: nil)
    }

    // Function to close the picker once an image is selected
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    // Function to revert back to the original image
    func revertToOriginalImage() {
        imageView.image = originalImage
        brightnessSlider.value = 0
        contrastSlider.value = 1
        saturationSlider.value = 1
    }
}

/**
 Extension of UIImage to add function to convert Image to CVPixelBuffer, which is what the model needs to work with
 Got off online
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

