//
//  BrokenGlassEffectView.swift
//  BrokenGlassEffect
//
//  Created by wang yang on 2017/8/21.
//  Copyright © 2017年 ocean. All rights reserved.
//

import Foundation
import Metal
import MetalKit
import UIKit
import GLKit

// 需要传递给Shader的全局变量
struct Uniforms {
    var pointTexcoordScaleX: Float!
    var pointTexcoordScaleY: Float!
    var pointSizeInPixel: Float!
    
    func data() -> [Float] {
        return [pointTexcoordScaleX, pointTexcoordScaleY, pointSizeInPixel]
    }
    
    static func sizeInBytes() -> Int {
        return 3 * MemoryLayout<Float>.size
    }
}

struct PointMoveInfo {
    var xSpeed: Float
    var ySpeed: Float
    var xAccelerate: Float
    var yAccelerate: Float
    var originCenterX: Float
    var originCenterY: Float
    var translateX: Float
    var translateY: Float
    
    static func defaultMoveInfo(centerX: Float, centerY: Float) -> PointMoveInfo {
        let xSpeed = (Float(arc4random()) / Float(RAND_MAX) - 0.5) * 0.7
        let yAccelerate = (-Float(arc4random()) / Float(RAND_MAX)) * 1.5 - 3.0
        let moveInfo = PointMoveInfo.init(xSpeed: xSpeed, ySpeed: 0, xAccelerate: 0, yAccelerate: yAccelerate, originCenterX: centerX, originCenterY: centerY, translateX: 0, translateY: 0)
        return moveInfo
    }
}

class BrokenGlassEffectView: MetalBaseView {
    
    // 渲染
    var imageTexture: MTLTexture!
    var vertexArray: [Float]!
    var vertexBuffer: MTLBuffer!
    var uniforms: Uniforms!
    
    // 运动管理
    var pointTransforms: [matrix_float4x4]!
    var pointMoveInfo: [PointMoveInfo]!
    var maxYSpeed: Float = -6.0
    
    // 是否破碎
    var isBroking: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    deinit {
        
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        commonInit()
    }
    
    func commonInit() {
        self.metalLayer.isOpaque = false
        self.backgroundColor = UIColor.clear
        setupRenderAssets()
        enableAniamtionTimer()
    }
    
    // 配置渲染相关资源
    func setupRenderAssets() {
        self.uniforms = Uniforms.init()
        
        // 构建顶点
        self.vertexArray = buildPointData()
        let vertexBufferSize = MemoryLayout<Float>.size * self.vertexArray.count
        self.vertexBuffer = device.makeBuffer(bytes: self.vertexArray, length: vertexBufferSize, options: MTLResourceOptions.cpuCacheModeWriteCombined)
        
        self.imageTexture = createTexture(image: UIImage.init(named: "texture.jpg")!)
    }
    
    func setImageForBroke(image: UIImage) {
        self.imageTexture = createTexture(image: image)
    }
    
    func beginBroke() {
        isBroking = true
    }
    
    func reset() {
        for i in 0..<pointTransforms.count {
            pointTransforms[i] = GLKMatrix4Identity.toFloat4x4()
            let originMoveInfo = pointMoveInfo[i]
            pointMoveInfo[i] = PointMoveInfo.defaultMoveInfo(centerX: originMoveInfo.originCenterX, centerY: originMoveInfo.originCenterY)
        }
        isBroking = false
    }
    
    // MARK: Metal View Basic Funcs
    // 更新逻辑
    override func update(deltaTime: TimeInterval, elapsedTime: TimeInterval) {
        if isBroking {
            for i in 0..<pointTransforms.count {
                pointMoveInfo[i].ySpeed += Float(deltaTime) * pointMoveInfo[i].yAccelerate
                if pointMoveInfo[i].ySpeed < maxYSpeed {
                    pointMoveInfo[i].ySpeed = maxYSpeed
                }
                pointMoveInfo[i].translateX += Float(deltaTime) * pointMoveInfo[i].xSpeed
                pointMoveInfo[i].translateY += Float(deltaTime) * pointMoveInfo[i].ySpeed
                let newMatrix = GLKMatrix4MakeTranslation(pointMoveInfo[i].translateX, pointMoveInfo[i].translateY, 0)
                pointTransforms[i] = newMatrix.toFloat4x4()
                
                let realY = pointMoveInfo[i].translateY + pointMoveInfo[i].originCenterY
                let realX = pointMoveInfo[i].translateX + pointMoveInfo[i].originCenterX
//                if realY <= -1.0 {
//                    pointMoveInfo[i].ySpeed = -pointMoveInfo[i].ySpeed * 0.6
//                    if fabs(pointMoveInfo[i].ySpeed) < 0.01 {
//                        pointMoveInfo[i].ySpeed = 0
//                    }
//                }
                if realX <= -1.0 || realX >= 1.0 {
                    pointMoveInfo[i].xSpeed = -pointMoveInfo[i].xSpeed * 0.6
                    if fabs(pointMoveInfo[i].xSpeed) < 0.01 {
                        pointMoveInfo[i].xSpeed = 0
                    }
                }
            }
        }
    }
    
    // 渲染
    override func draw(renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.setVertexBuffer(self.vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(self.imageTexture, index: 0)
        
        let uniformBuffer = device.makeBuffer(bytes: self.uniforms.data(), length: Uniforms.sizeInBytes(), options: MTLResourceOptions.cpuCacheModeWriteCombined)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        
        let transformsBufferSize = MemoryLayout<matrix_float4x4>.size * pointTransforms.count
        let transformsBuffer = device.makeBuffer(bytes: pointTransforms, length: transformsBufferSize, options: MTLResourceOptions.cpuCacheModeWriteCombined)
        renderEncoder.setVertexBuffer(transformsBuffer, offset: 0, index: 2)
        
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: self.vertexArray.count / 5)
    }
    
    // MARK: Private Methods
    private func buildPointData() -> [Float] {
        var vertexDataArray: [Float] = []
        let pointSize: Float = 2
        let viewWidth: Float = Float(UIScreen.main.bounds.width)
        let viewHeight: Float = Float(UIScreen.main.bounds.height)
        let rowCount = Int(viewHeight / pointSize) + 1
        let colCount = Int(viewWidth / pointSize) + 1
        let sizeXInMetalTexcoord: Float = pointSize / viewWidth * 2.0
        let sizeYInMetalTexcoord: Float = pointSize / viewHeight * 2.0
        pointTransforms = [matrix_float4x4].init()
        pointMoveInfo = [PointMoveInfo].init()
        for row in 0..<rowCount {
            for col in 0..<colCount {
                let centerX = Float(col) * sizeXInMetalTexcoord + sizeXInMetalTexcoord / 2.0 - 1.0
                let centerY = Float(row) * sizeYInMetalTexcoord + sizeYInMetalTexcoord / 2.0 - 1.0
                vertexDataArray.append(centerX)
                vertexDataArray.append(centerY)
                vertexDataArray.append(0.0)
                vertexDataArray.append(Float(col) / Float(colCount))
                vertexDataArray.append(Float(row) / Float(rowCount))
                
                pointTransforms.append(GLKMatrix4Identity.toFloat4x4())
                pointMoveInfo.append(PointMoveInfo.defaultMoveInfo(centerX: centerX, centerY: centerY))
            }
        }
        
        uniforms.pointTexcoordScaleX = sizeXInMetalTexcoord / 2.0
        uniforms.pointTexcoordScaleY = sizeYInMetalTexcoord / 2.0
        uniforms.pointSizeInPixel = pointSize
        return vertexDataArray
    }
}
