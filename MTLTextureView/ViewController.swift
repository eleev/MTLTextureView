//
//  ViewController.swift
//  MTLTextureView
//
//  Created by Astemir Eleev on 02.04.2023.
//

import UIKit
import Metal
import MetalKit
import os

class ViewController: UIViewController {
    let metalViewLog = OSLog(subsystem: "com.eleev.textureview", category: "Metal View Initialization")
    let imageNames: [String] = [
        "comic-magazine-cover-template",
        "barca"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let begin = OSSignpostID(log: metalViewLog)
        os_signpost(.begin, log: metalViewLog, name: "Init & Layout", signpostID: begin)
        
        // Instantiate the view
        let metalView = TextureView(named: imageNames[0])
        metalView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(metalView)
        
        // Add constraints
        NSLayoutConstraint.activate([
            metalView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            metalView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            metalView.topAnchor.constraint(equalTo: view.topAnchor),
            metalView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        
        func update(imageIndex: Int, delay: TimeInterval = 5) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                metalView.setImage(named: imageNames[imageIndex])
                update(imageIndex: (imageIndex + 1) % imageNames.count)
            }
        }
        update(imageIndex: 0)
        
        os_signpost(.end, log: metalViewLog, name: "Init & Layout", signpostID: begin)
    }
}
