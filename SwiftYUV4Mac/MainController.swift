//
//  MainController.swift
//  SwiftYUV
//
//  Created by VislaNiap on 2021/4/16.
//

import Foundation
import Cocoa

class MainController:NSViewController{
    private  var uiimage:NSImageView = {
        return NSImageView(frame: CGRect(x: 0, y: 0, width: 640 , height: 360))
    }();
    private  var renderingView: AgoraMetalRender = {
        let rect = CGRect(x: 0, y: 0, width: 640 , height: 360)
        let view = AgoraMetalRender()
        view.bounds = rect;
        view.shouldInitialize()
        view.shouldStart()
        return view
    }()
    
    private  var button:NSButton = {
        return NSButton(frame: CGRect(x: 0, y: 360, width: 120 , height: 80))
    }();
    
    override func viewDidLoad() {
        view.addSubview(renderingView)
        //view.addSubview(button)
        button.title = "click"
    }
   
    override func viewDidAppear() {
        let reader  = ReadYuvFile()
        reader.read(self)
        //self.view.addSubview(uiimage);
    }
    @objc public func render(pixcelBuffer:CVPixelBuffer) {
        renderingView.renderPixelBuffer(pixcelBuffer, rotation: .rotationNone)
    }
    
    @objc public func renderImage(image:NSImage) {
        uiimage.image = image
    }
}
