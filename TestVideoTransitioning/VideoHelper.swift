//
//  VideoHelper.swift
//  TestVideoTransitioning
//
//  Created by Alexander Batalov on 4/14/20.
//  Copyright © 2020 Alexander Batalov. All rights reserved.
//

import UIKit
import MobileCoreServices
import AVFoundation

final class VideoHelper {

    static func startMediaBrowser(delegate: UIViewController & UINavigationControllerDelegate & UIImagePickerControllerDelegate, sourceType: UIImagePickerController.SourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else { return }

        let mediaUI = UIImagePickerController()
        mediaUI.sourceType = sourceType
        mediaUI.mediaTypes = [kUTTypeMovie as String]
        mediaUI.allowsEditing = true
        mediaUI.delegate = delegate
        delegate.present(mediaUI, animated: true, completion: nil)
}

    static func transform(avAsset: AVAsset, targetSize: CGSize) -> CGAffineTransform {
        let originalSize =  avAsset.g_correctSize
        var scale: CGFloat
        if originalSize.width < originalSize.height {
          scale = targetSize.height / originalSize.height
          print("portrait")
        } else {
          scale = targetSize.width / originalSize.width
          print("not portrait")
        }

        let scaledSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)

        print(originalSize, scaledSize)

        let topLeft = CGPoint(x: UIScreen.main.bounds.width * 0.5 - scaledSize.width * 0.5, y: UIScreen.main.bounds.height  * 0.5 - scaledSize.height * 0.5)

        print("top peft", topLeft)

        var orientationTransform = avAsset.tracks(withMediaType: .video)[0].preferredTransform

        if (orientationTransform.tx == originalSize.width || orientationTransform.tx == originalSize.height) {
          orientationTransform.tx = UIScreen.main.bounds.width
        }

        if (orientationTransform.ty == originalSize.width || orientationTransform.ty == originalSize.height) {
          orientationTransform.ty = UIScreen.main.bounds.height
        }

        let transform = CGAffineTransform(scaleX: scale, y: scale).concatenating(CGAffineTransform(translationX: topLeft.x, y: topLeft.y)).concatenating(orientationTransform)

        return transform
    }
}
