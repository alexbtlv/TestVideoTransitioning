//
//  ViewController.swift
//  TestVideoTransitioning
//
//  Created by Alexander Batalov on 4/14/20.
//  Copyright © 2020 Alexander Batalov. All rights reserved.
//

import UIKit
import MobileCoreServices
import MediaPlayer
import Photos

final class MainViewController: UIViewController {
    
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet private weak var firstAssetCheckmark: UIImageView!
    @IBOutlet private weak var secondAssetCheckmark: UIImageView!
    
    private var firstAsset: AVAsset? {
        didSet {
            firstAssetCheckmark.isHidden = firstAsset == nil
        }
    }
    private var secondAsset: AVAsset? {
        didSet {
            secondAssetCheckmark.isHidden = secondAsset == nil
        }
    }
    private var audioAsset: AVAsset?
    private var loadingAssetOne = false
    private var isSavedPhotosAvailable: Bool {
        guard !UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) else { return true }
        
        let alert = UIAlertController(title: "Not Available", message: "No Saved Album found", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.cancel, handler: nil))
        present(alert, animated: true, completion: nil)
        return false
    }
    
    @IBAction func loadAssetOne(_ sender: AnyObject) {
      if isSavedPhotosAvailable {
        loadingAssetOne = true
        VideoHelper.startMediaBrowser(delegate: self, sourceType: .savedPhotosAlbum)
      }
    }
    
    @IBAction func loadAssetTwo(_ sender: AnyObject) {
      if isSavedPhotosAvailable {
        loadingAssetOne = false
        VideoHelper.startMediaBrowser(delegate: self, sourceType: .savedPhotosAlbum)
      }
    }
    
    @IBAction func merge(_ sender: AnyObject) {
        guard let firstAsset = firstAsset, let secondAsset = secondAsset else {
            return
        }

        activityIndicator.startAnimating()

        // 1 - Create AVMutableComposition object. This object will hold AVMutableCompositionTrack instances.
        let mixComposition = AVMutableComposition()
        var instructions = [AVMutableVideoCompositionLayerInstruction]()
        var lastTime = CMTime.zero
        // Create Track One

        guard let videoTrackOne = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: 10) else {
            return
        }
        
        // Setup AVAsset 1
        let timeRange = CMTimeRangeMake(start: CMTime.zero, duration: firstAsset.duration)

        do {
            try videoTrackOne.insertTimeRange(timeRange, of: firstAsset.tracks(withMediaType: .video)[0], at: lastTime)
        } catch {
            print(error)
        }
        
        // Setup Layer Instruction 1

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrackOne)
        let duration = CMTime(seconds: 1, preferredTimescale: 30)
        let transitTime = CMTime(seconds: 1, preferredTimescale: 30)
        let insertTime = CMTimeSubtract(firstAsset.duration, transitTime)
        let targetWidth = floor(UIScreen.main.bounds.size.width / 16) * 16
        let targetHeight = floor(UIScreen.main.bounds.size.height / 16) * 16
        let targetSize = CGSize(width: targetWidth, height: targetHeight)
        mixComposition.naturalSize = targetSize
        
        let transform = VideoHelper.transform(avAsset: firstAsset, targetSize: targetSize)
        layerInstruction.setTransform(transform, at: CMTime.zero)
        instructions.append(layerInstruction)
        
        lastTime = CMTimeAdd(lastTime, firstAsset.duration)
        
        // Create Track Two

        guard let videoTrackTwo = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: 20) else {
            return
        }

        let transitionTime = CMTime(seconds: 2, preferredTimescale: 60)
        let newLastTime = CMTimeSubtract(firstAsset.duration, transitionTime)

        let timeRangeTwo = CMTimeRangeMake(start: CMTime.zero, duration: secondAsset.duration)

        do {
            try videoTrackTwo.insertTimeRange(timeRangeTwo, of: secondAsset.tracks(withMediaType: .video)[0], at: newLastTime)
        } catch {
           print(error)
        }

        // Setup Layer Instruction 2

        let layerInstructionTwo = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrackTwo)
        let assetTrackTwo = secondAsset.tracks(withMediaType: .video)[0]
        let transformTwo = VideoHelper.transform(avAsset: secondAsset, targetSize: targetSize)
        layerInstructionTwo.setTransform(transformTwo, at: CMTime.zero)
        instructions.append(layerInstructionTwo)
        
        // Setup Video Composition
        
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: CMTimeAdd(newLastTime, secondAsset.duration))
        mainInstruction.layerInstructions = instructions
        
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        mainComposition.renderSize = targetSize
//        mainComposition.customVideoCompositorClass = INSTVideoCompositing.self
        
        // 4 - Get path
      guard let documentDirectory = FileManager.default.urls(for: .documentDirectory,
                                                             in: .userDomainMask).first else {
        return
      }
      let dateFormatter = DateFormatter()
      dateFormatter.dateStyle = .long
      dateFormatter.timeStyle = .short
      let date = dateFormatter.string(from: Date())
      let url = documentDirectory.appendingPathComponent("mergeVideo-\(date).mov")

      // 5 - Create Exporter
      guard let exporter = AVAssetExportSession(asset: mixComposition,
                                                presetName: AVAssetExportPresetHighestQuality) else {
        return
      }
      exporter.outputURL = url
      exporter.outputFileType = AVFileType.mov
      exporter.shouldOptimizeForNetworkUse = true
      exporter.videoComposition = mainComposition

      // 6 - Perform the Export
      exporter.exportAsynchronously() {
        DispatchQueue.main.async {
          self.exportDidFinish(exporter)
        }
      }

    }
    
    private func exportDidFinish(_ session: AVAssetExportSession) {
        activityIndicator.stopAnimating()
        firstAsset = nil
        secondAsset = nil
        
        guard session.status == AVAssetExportSession.Status.completed, let outputURL = session.outputURL else {
            return
        }
        
        let saveVideoToPhotos = {
        PHPhotoLibrary.shared().performChanges({
          PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
        }) { saved, error in
          let success = saved && (error == nil)
          let title = success ? "Success" : "Error"
          let message = success ? "Video saved" : "Failed to save video"
          
          DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
          }
          
        }
      }
      
      // Ensure permission to access Photo Library
      if PHPhotoLibrary.authorizationStatus() != .authorized {
        PHPhotoLibrary.requestAuthorization { status in
          if status == .authorized {
            saveVideoToPhotos()
          }
        }
      } else {
        saveVideoToPhotos()
      }
    }
}

extension MainViewController : UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        dismiss(animated: true) { [weak self] in
          guard let self = self else { return }
          DispatchQueue.main.async {
            guard let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String,
              mediaType == (kUTTypeMovie as String),
                let url = info[UIImagePickerController.InfoKey.mediaURL] as? URL
              else { return }
            
            let avAsset = AVAsset(url: url)
            var message = ""
            if self.loadingAssetOne {
              message = "Video one loaded"
              self.firstAsset = avAsset
            } else {
              message = "Video two loaded"
              self.secondAsset = avAsset
            }
            let alert = UIAlertController(title: "Asset Loaded", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
          }
        }
        
    }
}

extension MainViewController: UINavigationControllerDelegate {
  
}

extension MainViewController: MPMediaPickerControllerDelegate {
  
}
