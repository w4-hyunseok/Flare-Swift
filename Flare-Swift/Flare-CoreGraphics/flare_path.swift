//
//  flare_path.swift
//  Flare-Swift
//
//  Created by Umberto Sonnino on 2/22/19.
//  Copyright © 2019 2Dimensions. All rights reserved.
//

import Foundation
import CoreGraphics

protocol FlarePath: class {
    var _path: CGMutablePath { get set }
    var path: CGMutablePath { get }
    var _isValid: Bool { get set }
    var isClosed: Bool { get }
    var deformedPoints: [PathPoint]? { get }
    
    func makePath() -> CGMutablePath
}

extension FlarePath {
    var path: CGMutablePath {
        if _isValid {
            return _path
        }
        return self.makePath()
    }
    
    func makePath()  -> CGMutablePath {
        _isValid = true
        
        guard let pts = self.deformedPoints else {
            self._path = CGMutablePath()
            return self._path
        }
        
        if pts.count == 0 {
            self._path = CGMutablePath()
            return self._path
        }
        
        var renderPoints = [PathPoint]()
        let pc = pts.count
        
        let arcConstant: Float32 = 0.55
        let iarcConstant = 1.0 - arcConstant
        var previous = isClosed ? pts.last : nil
        
        for i in 0 ..< pc {
            let point = pts[i]
            switch point.type {
            case .Straight:
                let straightPoint = point as! StraightPathPoint
                let radius = straightPoint.radius
                if radius > 0 {
                    if !isClosed && (i == 0 || i == pc - 1) {
                        renderPoints.append(point)
                        previous = point
                    } else {
                        let next = pts[(i+1)%pc]
                        let prevPoint = previous is CubicPathPoint ? (previous as! CubicPathPoint).outPoint : previous!.translation
                        let nextPoint = next is CubicPathPoint ? (next as! CubicPathPoint).inPoint : next.translation
                        let pos = point.translation
                        
                        let toPrev = Vec2D.subtract(Vec2D(), prevPoint, pos)
                        let toPrevLength = Vec2D.length(toPrev)
                        toPrev[0] /= toPrevLength
                        toPrev[1] /= toPrevLength
                        
                        let toNext = Vec2D.subtract(Vec2D(), nextPoint, pos)
                        let toNextLength = Vec2D.length(toNext)
                        toNext[0] /= toNextLength
                        toNext[1] /= toNextLength
                        
                        let renderRadius = min(toPrevLength, min(toNextLength, Float32(radius)))
                        var translation = Vec2D.scaleAndAdd(Vec2D(), pos, toPrev, renderRadius)
                        renderPoints.append(CubicPathPoint.init(fromValues: translation, translation, Vec2D.scaleAndAdd(Vec2D(), pos, toPrev, iarcConstant * renderRadius)))
                        
                        translation = Vec2D.scaleAndAdd(Vec2D(), pos, toNext, renderRadius)
                        renderPoints.append(CubicPathPoint.init(fromValues: translation, Vec2D.scaleAndAdd(Vec2D(), pos, toNext, iarcConstant * renderRadius), translation))
                        renderPoints.append(previous!)
                    }
                } else {
                    renderPoints.append(point)
                    previous = point
                }
                break
            default:
                renderPoints.append(point)
                previous = point
                break
            }
        }
        
        let firstPoint = renderPoints.first!
        self._path.move(to: CGPoint(x: firstPoint.translation[0], y: firstPoint.translation[1]))
        
        let c = isClosed ? renderPoints.count : renderPoints.count - 1
        let rpc = renderPoints.count
        
        for i in 0 ..< c {
            let point = renderPoints[i]
            let nextPoint = renderPoints[(i+1)%rpc]
            var cin = nextPoint is CubicPathPoint ? (nextPoint as! CubicPathPoint).inPoint : nil
            var cout = nextPoint is CubicPathPoint ? (nextPoint as! CubicPathPoint).outPoint : nil
            if cin == nil && cout == nil {
                let x = Double(nextPoint.translation[0])
                let y = Double(nextPoint.translation[1])
                _path.addLine(to: CGPoint(x: x, y: y))
            } else {
                if cout == nil {
                    cout = point.translation
                }
                if cin == nil {
                    cin = nextPoint.translation
                }
                let CGTo = CGPoint(x: nextPoint.translation[0], y: nextPoint.translation[1])
                let CGCin = CGPoint(x: cin![0], y: cin![1])
                let CGCout = CGPoint(x: cout![0], y: cout![1])
                _path.addCurve(to: CGTo, control1: CGCin, control2: CGCout)
            }
        }
        
        if isClosed {
            _path.closeSubpath()
        }
        
        return _path
    }
    
}

extension CGPoint {
    init(x: Float32, y: Float32) {
        self.x = CGFloat(x)
        self.y = CGFloat(y)
    }
}
