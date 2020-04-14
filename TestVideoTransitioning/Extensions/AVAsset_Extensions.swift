//
//  AVAsset_Extensions.swift
//  TestVideoTransitioning
//
//  Created by Alexander Batalov on 4/14/20.
//  Copyright © 2020 Alexander Batalov. All rights reserved.
//

import UIKit
import AVFoundation

extension AVAsset {

  private var g_naturalSize: CGSize {
    return tracks(withMediaType: AVMediaType.video).first?.naturalSize ?? .zero
  }

  var g_correctSize: CGSize {
    return g_isPortrait ? CGSize(width: g_naturalSize.height, height: g_naturalSize.width) : g_naturalSize
  }

  var g_isPortrait: Bool {
    let portraits: [UIInterfaceOrientation] = [.portrait, .portraitUpsideDown]
    return portraits.contains(g_orientation)
  }

  // Same as UIImageOrientation
  var g_orientation: UIInterfaceOrientation {
    guard let transform = tracks(withMediaType: AVMediaType.video).first?.preferredTransform else {
      return .portrait
    }

    switch (transform.tx, transform.ty) {
    case (0, 0):
      return .landscapeRight
    case (g_naturalSize.width, g_naturalSize.height):
      return .landscapeLeft
    case (0, g_naturalSize.width):
      return .portraitUpsideDown
    default:
      return .portrait
    }
  }
}
