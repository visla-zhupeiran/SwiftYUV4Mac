//
//  MainController.swift
//  SwiftYUV
//
//  Created by VislaNiap on 2021/4/16.
//

import Foundation
import Cocoa

class MainController:NSViewController{
    private lazy var uiimage:NSImageView = {
        return NSImageView(frame: CGRect(x: 0, y: 100, width: 300 , height: 300))
    }();
    private lazy var renderingView: AgoraMetalRender = {
        let rect = CGRect(x: 0, y: 0, width: 500, height: 303)
        let view = AgoraMetalRender(frame: rect)
        view.bounds = rect;
        let _ = view.shouldInitialize()
        view.shouldStart()
        return view
    }()
    override func viewDidLoad() {
        self.view.addSubview(renderingView)
        let reader  = ReadYuvFile()
        reader.read(self)
        self.view.addSubview(uiimage);
    }
    @objc public func render(pixcelBuffer:CVPixelBuffer) {
        renderingView.renderPixelBuffer(pixcelBuffer, rotation: .rotationNone)
    }
    
    @objc public func renderImage(image:NSImage) {
        uiimage.image = image
    }
}
