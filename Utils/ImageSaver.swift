// Utils/ImageSaver.swift
import UIKit

class ImageSaver: NSObject {
    func writeToPhotoAlbum(image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
        self.completion = completion
    }
    
    private var completion: ((Bool, Error?) -> Void)?
    
    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        completion?(error == nil, error)
    }
}
