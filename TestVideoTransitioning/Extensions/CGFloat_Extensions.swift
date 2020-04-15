//
//  CGFloat_Extensions.swift
//  TestVideoTransitioning
//
//  Created by Alexander Batalov on 4/15/20.
//  Copyright © 2020 Alexander Batalov. All rights reserved.
//

import CoreGraphics.CGGeometry

extension CGFloat: FloatingPointMath {

   public var sine: CGFloat {
      return sin(self)
   }

   public var cosine: CGFloat {
      return cos(self)
   }

   public var powerOfTwo: CGFloat {
      return pow(2, self)
   }
}
