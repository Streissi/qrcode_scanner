import Flutter
import UIKit
import AVFoundation

public class SwiftQrscanPlugin: NSObject, FlutterPlugin, AVCaptureMetadataOutputObjectsDelegate {
  var captureSession = AVCaptureSession()
  var videoPreviewLayer: AVCaptureVideoPreviewLayer?
  var qrCodeFrameView: UIView?
  var scanResult: FlutterResult

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "qr_scan", binaryMessenger: registrar.messenger())
    let instance = SwiftQrscanPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "generate_barcode" {
        let arguments = call.arguments as? [String:Any] ?? [String: Any]()
        guard let code = arguments["code"] as? String else {
            return
        }

        guard let data = code.data(using: String.Encoding.utf8) else {
            return
        }

        guard let qr_filter = CIFilter(name: "CIQRCodeGenerator", parameters: ["inputMessage": data, "inputCorrectionLevel": "M"]) else {
            return
        }

        guard let ciImage = qr_filter.outputImage else {
          return
        }

        let scale = 400.0 / ciImage.extent.height
        let sizeTransform = CGAffineTransform(scaleX:scale, y:scale)
        let qrImage = ciImage.transformed(by: sizeTransform)
        let uiImage = UIImage(ciImage: qrImage)
        guard let bytearray = uiImage.pngData() else {
            return
        }
        result(bytearray)
    } else if (call.method == "scan") {
      let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera], mediaType: AVMediaType.video, position: .back)

      guard let captureDevice = deviceDiscoverySession.devices.first else {
          result(nil)
          return
      }

      do {
          // Get an instance of the AVCaptureDeviceInput class using the previous device object.
          let input = try AVCaptureDeviceInput(device: captureDevice)

          // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
          let captureMetadataOutput = AVCaptureMetadataOutput()
          captureSession.addOutput(captureMetadataOutput)

          // Set the input device on the capture session.
          captureSession.addInput(input)

          // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
          videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
          videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
          videoPreviewLayer?.frame = view.layer.bounds
          view.layer.addSublayer(videoPreviewLayer!)
          
          // Move the message label and top bar to the front
          view.bringSubviewToFront(messageLabel)
          view.bringSubviewToFront(topbar)

          // Initialize QR Code Frame to highlight the QR code
          qrCodeFrameView = UIView()

          if let qrCodeFrameView = qrCodeFrameView {
              qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
              qrCodeFrameView.layer.borderWidth = 2
              view.addSubview(qrCodeFrameView)
              view.bringSubviewToFront(qrCodeFrameView)
          }

          // Start video capture.
          captureSession.startRunning()
      } catch {
          // If any error occurs, simply print it out and don't continue any more.
          result(nil)
          return
      }
    } else {
        result(nil)
    }
  }

  func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
    // Check if the metadataObjects array is not nil and it contains at least one object.
    if metadataObjects.count == 0 {
        qrCodeFrameView?.frame = CGRect.zero
        scanResult(nil);
        return
    }

    // Get the metadata object.
    let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject

    if metadataObj.type == AVMetadataObject.ObjectType.qr {
        // If the found metadata is equal to the QR code metadata then update the status label's text and set the bounds
        let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
        qrCodeFrameView?.frame = barCodeObject!.bounds

        if metadataObj.stringValue != nil {
            scanResult(metadataObj.stringValue)
        }
    }
  }
}
