import AVFoundation
import UIKit

final class CameraManager: NSObject {

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var completion: ((UIImage?) -> Void)?

    func takePhoto(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion

        let session = AVCaptureSession()
        session.sessionPreset = .photo

        // Фронтальная камера
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else {
            completion(nil)
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        self.captureSession = session
        self.photoOutput = output

        // Запуск сессии в фоне
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()

            // Небольшая задержка чтобы камера успела инициализироваться
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let settings = AVCapturePhotoSettings()
                output.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    private func cleanup() {
        captureSession?.stopRunning()
        captureSession = nil
        photoOutput = nil
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        defer { cleanup() }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion?(nil)
            return
        }

        completion?(image)
    }
}
