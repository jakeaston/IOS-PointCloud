class ViewController: UIViewController {
    private let depthSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0.1  // 10cm
        slider.maximumValue = 5.0  // 5m
        slider.value = 3.0         // Default 3m
        slider.transform = CGAffineTransform(rotationAngle: -CGFloat.pi/2) // Make vertical
        return slider
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add slider
        view.addSubview(depthSlider)
        depthSlider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            depthSlider.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            depthSlider.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20),
            depthSlider.heightAnchor.constraint(equalToConstant: 200) // Length of slider
        ])
        
        depthSlider.addTarget(self, action: #selector(depthSliderChanged), for: .valueChanged)
    }
    
    @objc private func depthSliderChanged() {
        renderer.maxDepth = depthSlider.value
    }
} 