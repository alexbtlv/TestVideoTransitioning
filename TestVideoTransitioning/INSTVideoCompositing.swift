//
//  INSTVideoCompositing.swift
//  TestVideoTransitioning
//
//  Created by Alexander Batalov on 4/15/20.
//  Copyright © 2020 Alexander Batalov. All rights reserved.
//

import AVFoundation
import UIKit.UIImage

class INSTVideoCompositing: NSObject, AVVideoCompositing {
    
    private var renderContext: AVVideoCompositionRenderContext?
    private var secondVideoRenderedFrames: Int = 0
    
    var sourcePixelBufferAttributes: [String : Any]? {
        let key = String(kCVPixelBufferPixelFormatTypeKey)
        let val = kCVPixelFormatType_32BGRA
        return [key:val]
    }
    
    var requiredPixelBufferAttributesForRenderContext: [String : Any] {
        let key = String(kCVPixelBufferPixelFormatTypeKey)
        let val = kCVPixelFormatType_32BGRA
        return [key : val]
    }
    
    func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        if let destination = asyncVideoCompositionRequest.renderContext.newPixelBuffer() {
            if let frameOne = asyncVideoCompositionRequest.sourceFrame(byTrackID: 10) {
                if let frameTwo = asyncVideoCompositionRequest.sourceFrame(byTrackID: 20) {
                    CVPixelBufferLockBaseAddress(frameOne, CVPixelBufferLockFlags.readOnly)
                    CVPixelBufferLockBaseAddress(frameTwo, CVPixelBufferLockFlags.readOnly)
                    CVPixelBufferLockBaseAddress(destination, .init(rawValue: .zero))
                    render(frameOne: frameOne, with: frameTwo, to: destination, transform: asyncVideoCompositionRequest.renderContext.renderTransform, frameTwoProgress: secondVideoRenderedFrames)
                    CVPixelBufferUnlockBaseAddress(destination, .init(rawValue: .zero))
                    CVPixelBufferUnlockBaseAddress(frameTwo, CVPixelBufferLockFlags.readOnly)
                    CVPixelBufferUnlockBaseAddress(frameOne, CVPixelBufferLockFlags.readOnly)
                    secondVideoRenderedFrames += 1
                } else {
                    print("Render 1")
                    CVPixelBufferLockBaseAddress(frameOne, CVPixelBufferLockFlags.readOnly)
                    CVPixelBufferLockBaseAddress(destination, .init(rawValue: .zero))
                    render(buffer: frameOne, to: destination, with: asyncVideoCompositionRequest.renderContext.renderTransform)
                    CVPixelBufferUnlockBaseAddress(destination, .init(rawValue: .zero))
                    CVPixelBufferUnlockBaseAddress(frameOne, CVPixelBufferLockFlags.readOnly)
                }
            }
            //      print(asyncVideoCompositionRequest.compositionTime.seconds)
            asyncVideoCompositionRequest.finish(withComposedVideoFrame: destination)
        }
    }
    
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        renderContext = newRenderContext
    }
    
    private func render(buffer: CVPixelBuffer, to destination: CVPixelBuffer, with transform: CGAffineTransform) {
        let image = imageFromBuffer(buffer, preferredTransform: transform)
        let width = CVPixelBufferGetWidth(destination)
        let height = CVPixelBufferGetHeight(destination)
        let frame = CGRect(x: 0, y: 0, width: width, height: height)
        let gc = CGContext(data: CVPixelBufferGetBaseAddress(destination), width: width, height: height,
                           bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(destination),
                           space: image.colorSpace!, bitmapInfo: image.bitmapInfo.rawValue)
        gc?.draw(image, in: frame)
    }
    
    private func render(frameOne: CVPixelBuffer, with frameTwo: CVPixelBuffer, to destination: CVPixelBuffer, transform: CGAffineTransform, frameTwoProgress: Int) {
        let effectDurationInFrames: CGFloat = 40.0
        let progress1: CGFloat = min((CGFloat(frameTwoProgress) / effectDurationInFrames), 1.8)
        let progress2: CGFloat = progress1 < 0.5625 ? 0 : min((progress1-0.5625) , 1.0)
        let progress3: CGFloat = progress1 < 0.7 ? 0 : min((progress1-0.7), 1.0)
        let imageOne = imageFromBuffer(frameOne, preferredTransform: transform)
        let imageTwo = imageFromBuffer(frameTwo, preferredTransform: transform)
        let width = CVPixelBufferGetWidth(destination)
        let height = CVPixelBufferGetHeight(destination)
        let xOffset1: CGFloat!
        let xOffset2: CGFloat!
        let xOffset3: CGFloat!
        if progress1 < 1 {
            xOffset1 = Curve.exponential.easeInOut(progress1) * CGFloat(width)
        } else {
            xOffset1 = CGFloat(width)
        }
        if progress2 == 0 {
            xOffset2 = 0
        } else if progress2 < 1 {
            xOffset2 = Curve.quintic.easeOut(progress2) * CGFloat(width)
        } else {
            xOffset2 = CGFloat(width)
        }
        if progress3 == 0 {
            xOffset3 = 0
        } else if progress3 < 1 {
            xOffset3 = Curve.quintic.easeOut(progress3) * CGFloat(width)
        } else {
            xOffset3 = CGFloat(width)
        }
        let progressOffset1 = Int(CGFloat(width) - xOffset1)
        let progressOffset2 = Int(CGFloat(width) - xOffset2)
        let progressOffset3 = Int(CGFloat(width) - xOffset3)
        let frameOne = CGRect(x: 0, y: 0, width: width, height: height)
        let frameTwo = CGRect(x: 0 + progressOffset1, y: 0, width: width, height: height)
        let frameThree = CGRect(x: 0 + progressOffset2, y: 0, width: width, height: height)
        let frameFour = CGRect(x: 0 + progressOffset3, y: 0, width: width, height: height)
        let gc = CGContext(data: CVPixelBufferGetBaseAddress(destination), width: width, height: height,
                           bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(destination),
                           space: imageOne.colorSpace!, bitmapInfo: imageOne.bitmapInfo.rawValue)
        
        gc?.draw(imageOne, in: frameOne)
        gc?.setBlendMode(.hardLight)
        gc?.draw(imageTwo, in: frameTwo)
        gc?.setBlendMode(.normal)
        gc?.setBlendMode(.plusLighter)
        gc?.draw(imageTwo, in: frameThree)
        gc?.setBlendMode(.normal)
        gc?.setAlpha(1)
        gc?.draw(imageTwo, in: frameFour)
    }
    
    private func imageFromBuffer(_ buffer: CVPixelBuffer, preferredTransform: CGAffineTransform) -> CGImage {
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        guard let data = CVPixelBufferGetBaseAddress(buffer) else { preconditionFailure("Can not create data obj from pixel buffer") }
        let rgb = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(dataInfo: nil, data: data, size: height * stride, releaseData: {(_, _, _) in })
            else { preconditionFailure("Can not create CGDataProvider") }
        
        guard let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: stride, space: rgb,
                                  bitmapInfo: .byteOrder32Big, provider: provider,
                                  decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
                                    preconditionFailure("Can not create image")
        }
        
        
        // TODO: Figure out proper way to hanlde orientation
        guard let orientedImage = createMatchingBackingDataWithImage(imageRef: image, orienation: .left) else {
            preconditionFailure("Can not flip image")
        }
        
        return orientedImage
    }
    
    func createMatchingBackingDataWithImage(imageRef: CGImage?, orienation: UIImage.Orientation) -> CGImage? {
        var orientedImage: CGImage?
        
        if let imageRef = imageRef {
            let originalWidth = imageRef.width
            let originalHeight = imageRef.height
            let bitsPerComponent = imageRef.bitsPerComponent
            let bytesPerRow = imageRef.bytesPerRow
            
            let bitmapInfo = imageRef.bitmapInfo
            
            guard let colorSpace = imageRef.colorSpace else {
                return nil
            }
            
            var degreesToRotate: Double
            var swapWidthHeight: Bool
            var mirrored: Bool
            switch orienation {
            case .up:
                degreesToRotate = 0.0
                swapWidthHeight = false
                mirrored = false
                break
            case .upMirrored:
                degreesToRotate = 0.0
                swapWidthHeight = false
                mirrored = true
                break
            case .right:
                degreesToRotate = 90.0
                swapWidthHeight = true
                mirrored = false
                break
            case .rightMirrored:
                degreesToRotate = 90.0
                swapWidthHeight = true
                mirrored = true
                break
            case .down:
                degreesToRotate = 180.0
                swapWidthHeight = false
                mirrored = false
                break
            case .downMirrored:
                degreesToRotate = 180.0
                swapWidthHeight = false
                mirrored = true
                break
            case .left:
                degreesToRotate = -90.0
                swapWidthHeight = true
                mirrored = false
                break
            case .leftMirrored:
                degreesToRotate = -90.0
                swapWidthHeight = true
                mirrored = true
                break
            default:
                degreesToRotate = 0
                swapWidthHeight = false
                mirrored = false
                break
            }
            let radians = degreesToRotate * Double.pi / 180.0
            
            var width: Int
            var height: Int
            if swapWidthHeight {
                width = originalHeight
                height = originalWidth
            } else {
                width = originalWidth
                height = originalHeight
            }
            
            let contextRef = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
            contextRef?.translateBy(x: CGFloat(width) / 2.0, y: CGFloat(height) / 2.0)
            if mirrored {
                contextRef?.scaleBy(x: -1.0, y: 1.0)
            }
            contextRef?.rotate(by: CGFloat(radians))
            if swapWidthHeight {
                contextRef?.translateBy(x: -CGFloat(height) / 2.0, y: -CGFloat(width) / 2.0)
            } else {
                contextRef?.translateBy(x: -CGFloat(width) / 2.0, y: -CGFloat(height) / 2.0)
            }
            contextRef?.draw(imageRef, in: CGRect(x: 0.0, y: 0.0, width: CGFloat(originalWidth), height: CGFloat(originalHeight)))
            orientedImage = contextRef?.makeImage()
        }
        
        return orientedImage
    }
}

