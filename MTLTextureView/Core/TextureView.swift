//
//  TextureView.swift
//  TextureView
//
//  Created by Astemir Eleev on 02.04.2023.
//

import UIKit
import MetalKit

final class TextureView: UIView {
    
    // MARK: - Properties
    
    weak var mtkView: MTKView?
    private var metalRenderer: MetalRenderer?
    
    // MARK: - Initializers
    
    init(named name: String, in bundle: Bundle = .main) {
        super.init(frame: .zero)
        
        let metalView = MTKView(frame: bounds)
        metalView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(metalView)
        
        NSLayoutConstraint.activate([
            metalView.leadingAnchor.constraint(equalTo: leadingAnchor),
            metalView.trailingAnchor.constraint(equalTo: trailingAnchor),
            metalView.topAnchor.constraint(equalTo: topAnchor),
            metalView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        mtkView = metalView
        
        metalRenderer = MetalRenderer(
            mtkView: metalView,
            imageName: name,
            in: bundle
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Methods
    
    func setImage(named name: String, in bundle: Bundle = .main) {
        metalRenderer?.setImage(named: name, in: bundle)
    }
}
