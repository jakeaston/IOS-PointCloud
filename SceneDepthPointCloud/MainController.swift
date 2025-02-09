import UIKit
import Metal
import MetalKit
import ARKit
import WebKit
import CoreNFC

final class MainController: UIViewController, ARSessionDelegate, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate, NFCNDEFReaderSessionDelegate, URLSessionDownloadDelegate {
    private let isUIEnabled = true
    private var clearButton = UIButton(type: .system)
    private let confidenceControl = UISegmentedControl(items: ["Low", "Medium", "High"])
    private var rgbButton = UIButton(type: .system)
    private var showSceneButton = UIButton(type: .system)
    private var saveButton = UIButton(type: .system)
    private var toggleParticlesButton = UIButton(type: .system)
    private let session = ARSession()
    var renderer: Renderer!
    private var isPasued = false
    private var webView: WKWebView!
    private var scannerView: MTKView?  // New property to hold scanner view
    private var closeButton: UIButton?  // Add this property at the top with other UI elements
    private var loadingView: UIView?  // Add this property
    private var splashView: UIView?  // Add this property with other UI elements
    private var nfcSession: NFCNDEFReaderSession?
    private let depthSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0.1  // 10cm
        slider.maximumValue = 5.0  // 5m
        slider.value = 3.0         // Default 3m
        slider.transform = CGAffineTransform(rotationAngle: -CGFloat.pi/2) // Make vertical
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 200).isActive = true  // Reduced from 400 to 200 - this will be the vertical length after rotation
        slider.heightAnchor.constraint(equalToConstant: 30).isActive = true  // This will be the horizontal thickness after rotation
        return slider
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add splash screen first, before any other setup
        let splashView = UIView(frame: view.bounds)
        splashView.backgroundColor = UIColor(red: 16/255, green: 22/255, blue: 67/255, alpha: 1.0)
        view.addSubview(splashView)
        self.splashView = splashView
        
        // Add logo image
        let logoImageView = UIImageView(image: UIImage(named: "SplashLogo"))
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        splashView.addSubview(logoImageView)
        
        // Add activity indicator
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = .white
        activityIndicator.startAnimating()
        splashView.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: splashView.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: splashView.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 200),
            logoImageView.heightAnchor.constraint(equalToConstant: 200),
            
            activityIndicator.centerXAnchor.constraint(equalTo: splashView.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 20)
        ])
        
        // Delay the setup of WebView to allow splash screen to be visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { // Adjust delay time as needed
            self.setupWebView()
        }
    }
    
    private func setupWebView() {
        // Add loading view
        let loadingView = UIView(frame: view.bounds)
        loadingView.backgroundColor = UIColor(red: 16/255, green: 22/255, blue: 67/255, alpha: 1.0)
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingView)
        self.loadingView = loadingView
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        loadingView.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor)
        ])

        // Add header view
        let headerView = UIView()
        headerView.backgroundColor = UIColor(red: 16/255, green: 22/255, blue: 67/255, alpha: 1.0)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)
        
        // Configure for persistent storage
        // Configure for persistent storage and offline capabilities
        let webConfiguration = WKWebViewConfiguration()
        
        // Enable persistent data storage with increased size limits
        let dataStore = WKWebsiteDataStore.default()
        webConfiguration.websiteDataStore = dataStore
        
        // Set preferences
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        webConfiguration.defaultWebpagePreferences = preferences
        
        // Enhanced script to handle API request caching
        let script = WKUserScript(source: """
            // Increase storage limits
            window.webkitStorageInfo.requestQuota(
                PERSISTENT, 
                100 * 1024 * 1024, // 100MB
                function(grantedBytes) {
                    console.log('Granted storage:', grantedBytes);
                },
                function(error) {
                    console.log('Error requesting storage:', error);
                }
            );
            
            // Enable service worker if available
            if ('serviceWorker' in navigator) {
                window.addEventListener('load', function() {
                    navigator.serviceWorker.register('/service-worker.js')
                        .then(function(registration) {
                            console.log('ServiceWorker registration successful');
                            
                            // Setup API request caching
                            caches.open('api-cache').then(function(cache) {
                                // Intercept fetch requests
                                self.addEventListener('fetch', function(event) {
                                    // Check if request is an API call
                                    if (event.request.url.includes('shared.air-os.app')) {
                                        event.respondWith(
                                            fetch(event.request)
                                                .then(function(response) {
                                                    // Clone the response as it can only be consumed once
                                                    let responseClone = response.clone();
                                                    cache.put(event.request, responseClone);
                                                    return response;
                                                })
                                                .catch(function() {
                                                    // If fetch fails, try to get from cache
                                                    return cache.match(event.request);
                                                })
                                        );
                                    }
                                });
                            });
                        })
                        .catch(function(error) {
                            console.log('ServiceWorker registration failed:', error);
                        });
                });
            }
            
            // Setup XMLHttpRequest caching
            let originalXHR = window.XMLHttpRequest;
            window.XMLHttpRequest = function() {
                let xhr = new originalXHR();
                let send = xhr.send;
                let open = xhr.open;
                
                xhr.open = function(method, url) {
                    this._url = url;
                    this._method = method;
                    return open.apply(this, arguments);
                };
                
                xhr.send = function() {
                    if (this._url.includes('shared.air-os.app')) {
                        // Store response in cache
                        this.addEventListener('load', function() {
                            if (this.status === 200) {
                                caches.open('api-cache').then(function(cache) {
                                    let response = new Response(this.responseText, {
                                        headers: {
                                            'Content-Type': this.getResponseHeader('Content-Type')
                                        }
                                    });
                                    cache.put(this._url, response);
                                });
                            }
                        });
                    }
                    return send.apply(this, arguments);
                };
                
                return xhr;
            };
            
            // Setup fetch API caching
            let originalFetch = window.fetch;
            window.fetch = function(input, init) {
                return originalFetch(input, init)
                    .then(function(response) {
                        if (response.url.includes('shared.air-os.app')) {
                            let responseClone = response.clone();
                            caches.open('api-cache').then(function(cache) {
                                cache.put(input, responseClone);
                            });
                        }
                        return response;
                    })
                    .catch(function(error) {
                        if (typeof input === 'string' && input.includes('shared.air-os.app')) {
                            return caches.open('api-cache')
                                .then(cache => cache.match(input))
                                .then(response => response || Promise.reject(error));
                        }
                        return Promise.reject(error);
                    });
            };
        """, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        
        let contentController = WKUserContentController()
        contentController.addUserScript(script)
        contentController.add(self, name: "scannerBridge")
        contentController.add(self, name: "downloadBridge")
        webConfiguration.userContentController = contentController

        // Create WKWebView with configuration
        webView = WKWebView(frame: view.bounds, configuration: webConfiguration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        // Enable back/forward navigation cache
        webView.allowsBackForwardNavigationGestures = true
        
        // Add offline content handling
        webView.configuration.websiteDataStore = .default()
        webView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        // Add edge swipe gestures
        let leftSwipe = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleLeftSwipe(_:)))
        leftSwipe.edges = .left
        webView.addGestureRecognizer(leftSwipe)
        
        let rightSwipe = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleRightSwipe(_:)))
        rightSwipe.edges = .right
        webView.addGestureRecognizer(rightSwipe)
        
        // Add to view hierarchy and setup constraints
        view.addSubview(webView)
        
        // Update constraints to include header
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60), // Adjust height as needed
            
            webView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        if let url = URL(string: "https://s1.air-os.app") {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        // Update cookie storage code
        HTTPCookieStorage.shared.cookieAcceptPolicy = .always
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            cookies.forEach { cookie in
                HTTPCookieStorage.shared.setCookie(cookie)
            }
        }
    }
    
    @objc private func launchScanner() {
        // Check for Metal support
        guard let device = MTLCreateSystemDefaultDevice() else {
            showAlert(title: "Unsupported Device", 
                     message: "This device does not support Metal, which is required for the scanner.",
                     shouldDismiss: false)
            return
        }
        
        // Check for ARKit and depth sensing support
        guard ARWorldTrackingConfiguration.isSupported,
              ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth, .smoothedSceneDepth]) else {
            showAlert(title: "Unsupported Device", 
                     message: "This device does not support depth sensing. Please use an iPhone 12 Pro or newer, or an iPad Pro 2020 or newer.",
                     shouldDismiss: false)
            return
        }
        
        // Create and setup scanner view
        let mtkView = MTKView(frame: view.bounds, device: device)
        mtkView.backgroundColor = UIColor.black
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.contentScaleFactor = 1
        
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mtkView)
        
        NSLayoutConstraint.activate([
            mtkView.topAnchor.constraint(equalTo: view.topAnchor),
            mtkView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mtkView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mtkView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        scannerView = mtkView
        
        // Configure the renderer first
        renderer = Renderer(session: session, metalDevice: device, renderDestination: mtkView)
        
        // Set delegate after renderer is configured
        mtkView.delegate = self
        
        // Configure session
        session.delegate = self
        
        // Hide webView after setup is complete
        webView.isHidden = true
        
        // Update close scanner button creation
        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("Close Scanner", for: .normal)
        closeButton.addTarget(self, action: #selector(closeScanner), for: .touchUpInside)
        view.addSubview(closeButton)
        self.closeButton = closeButton  // Store reference
        
        NSLayoutConstraint.activate([
            closeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            closeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
        
        // Setup scanner UI
        setupScannerUI()
        
        // Start AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
        session.run(configuration)
        
        // Resize renderer after everything is set up
        if let renderer = renderer {
            renderer.drawRectResized(size: mtkView.bounds.size)
        }
    }
    
    @objc private func closeScanner() {
        // Stop AR session
        session.pause()
        
        // Remove scanner view and UI
        scannerView?.removeFromSuperview()
        scannerView = nil
        
        // Remove all scanner UI buttons
        clearButton.removeFromSuperview()
        saveButton.removeFromSuperview()
        showSceneButton.removeFromSuperview()
        toggleParticlesButton.removeFromSuperview()
        rgbButton.removeFromSuperview()
        
        // Show webView
        webView.isHidden = false
        
        // Remove close button
        closeButton?.removeFromSuperview()
        closeButton = nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Remove the AR session configuration from viewWillAppear
        // as we only want it to start when the scanner is launched
        
        // The screen shouldn't dim during AR experiences.
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    @objc
    func viewValueChanged(view: UIView) {
        switch view {
        case confidenceControl:
            renderer.confidenceThreshold = confidenceControl.selectedSegmentIndex
            
        case rgbButton:
            renderer.rgbOn = !renderer.rgbOn
            let iconName = renderer.rgbOn ? "eye.slash": "eye"
            rgbButton.setBackgroundImage(.init(systemName: iconName), for: .normal)
            
        case clearButton:
            renderer.isInViewSceneMode = true
            setShowSceneButtonStyle(isScanning: false)
            renderer.clearParticles()
            
        case saveButton:
            renderer.isInViewSceneMode = true
            setShowSceneButtonStyle(isScanning: false)
            goToSaveCurrentScanView()
        
        case showSceneButton:
            renderer.isInViewSceneMode = !renderer.isInViewSceneMode
            if !renderer.isInViewSceneMode {
                renderer.showParticles = true
                self.toggleParticlesButton.setBackgroundImage(.init(systemName: "circle.grid.hex.fill"), for: .normal)
                self.setShowSceneButtonStyle(isScanning: true)
            } else {
                self.setShowSceneButtonStyle(isScanning: false)
            }
            
        case toggleParticlesButton:
            renderer.showParticles = !renderer.showParticles
            if (!renderer.showParticles) {
                renderer.isInViewSceneMode = true
                self.setShowSceneButtonStyle(isScanning: false)
            }
            let iconName = "circle.grid.hex" + (renderer.showParticles ? ".fill" : "")
            self.toggleParticlesButton.setBackgroundImage(.init(systemName: iconName), for: .normal)
            
        default:
            break
        }
    }
    
    // Auto-hide the home indicator to maximize immersion in AR experiences.
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    // Hide the status bar to maximize immersion in AR experiences.
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user.
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                if let configuration = self.session.configuration {
                    self.session.run(configuration, options: .resetSceneReconstruction)
                }
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    private func setupScannerUI() {
        clearButton = createButton(mainView: self, iconName: "trash.circle.fill",
            tintColor: .red, hidden: !isUIEnabled)
        view.addSubview(clearButton)
        
        saveButton = createButton(mainView: self, iconName: "tray.and.arrow.down.fill",
            tintColor: .white, hidden: !isUIEnabled)
        view.addSubview(saveButton)
        
        showSceneButton = createButton(mainView: self, iconName: "livephoto",
            tintColor: .white, hidden: !isUIEnabled)
        view.addSubview(showSceneButton)
        
        toggleParticlesButton = createButton(mainView: self, iconName: "circle.grid.hex.fill",
            tintColor: .white, hidden: !isUIEnabled)
        view.addSubview(toggleParticlesButton)
        
        rgbButton = createButton(mainView: self, iconName: "eye",
            tintColor: .white, hidden: !isUIEnabled)
        view.addSubview(rgbButton)
        
        // Add depth slider - make sure it's added last so it's on top
        depthSlider.addTarget(self, action: #selector(depthSliderChanged), for: .valueChanged)
        view.addSubview(depthSlider)
        view.bringSubviewToFront(depthSlider)  // Ensure slider is on top
        
        NSLayoutConstraint.activate([
            clearButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 50),
            clearButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
            clearButton.widthAnchor.constraint(equalToConstant: 50),
            clearButton.heightAnchor.constraint(equalToConstant: 50),
            
            saveButton.widthAnchor.constraint(equalToConstant: 50),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            saveButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -50),
            saveButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
            
            showSceneButton.widthAnchor.constraint(equalToConstant: 60),
            showSceneButton.heightAnchor.constraint(equalToConstant: 60),
            showSceneButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50),
            showSceneButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            toggleParticlesButton.widthAnchor.constraint(equalToConstant: 50),
            toggleParticlesButton.heightAnchor.constraint(equalToConstant: 50),
            toggleParticlesButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 50),
            toggleParticlesButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50),
            
            rgbButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -50),
            rgbButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50),
            rgbButton.widthAnchor.constraint(equalToConstant: 60),
            rgbButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Update slider constraints
            depthSlider.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            depthSlider.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 85)  // This pushes it more to the right
        ])
        
        // Make sure user interaction is enabled
        depthSlider.isUserInteractionEnabled = true
        view.isUserInteractionEnabled = true
    }
    
    @objc private func depthSliderChanged() {
        renderer.maxDepth = depthSlider.value
    }
    
    // Add required method from WKScriptMessageHandler protocol
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "scannerBridge" {
            print("Received message: \(message.body)") // Debug print
            
            // Original scanner code - keep exactly as it was
            if let messageBody = message.body as? [String: Any] {
                launchScanner()
            }
            
            // Separate NFC handling
            if let messageBody = message.body as? String, 
               messageBody == "startNFCScanning" {
                startNFCScanning()
            }
        }
        
        if message.name == "downloadBridge" {
            if let downloadInfo = message.body as? [String: String],
               let urlString = downloadInfo["url"],
               let url = URL(string: urlString) {
                
                let config = URLSessionConfiguration.default
                let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
                let downloadTask = session.downloadTask(with: url)
                downloadTask.resume()
            }
        }
    }
    
    // Add new cleanup methods
    @objc private func cleanupWebViewOnMemoryWarning() {
        webView?.configuration.processPool = WKProcessPool()
        webView?.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            cookies.forEach { cookie in
                self.webView?.configuration.websiteDataStore.httpCookieStore.delete(cookie)
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "scannerBridge")
        webView?.stopLoading()
        webView = nil
    }
    
    private func startNFCScanning() {
        guard NFCNDEFReaderSession.readingAvailable else {
            // Notify web app that NFC is not available
            let script = "window.dispatchEvent(new CustomEvent('nfcError', { detail: 'NFC not available on this device' }))"
            webView?.evaluateJavaScript(script, completionHandler: nil)
            return
        }
        
        nfcSession = NFCNDEFReaderSession(delegate: self,
                                         queue: DispatchQueue.main,
                                         invalidateAfterFirstRead: true)
        nfcSession?.alertMessage = "Hold your iPhone near an NFC tag to scan it"
        nfcSession?.begin()
    }
    
    // MARK: - NFCNDEFReaderSessionDelegate Methods
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // Handle specific NFC errors
        if let readerError = error as? NFCReaderError {
            switch readerError.code {
            case .readerSessionInvalidationErrorFirstNDEFTagRead:
                // Expected case when tag is read successfully
                return
            case .readerSessionInvalidationErrorUserCanceled:
                // User canceled the scan
                let script = "window.dispatchEvent(new CustomEvent('nfcError', { detail: 'Scanning canceled' }))"
                DispatchQueue.main.async {
                    self.webView?.evaluateJavaScript(script, completionHandler: nil)
                }
            default:
                // Other errors
                let script = "window.dispatchEvent(new CustomEvent('nfcError', { detail: '\(error.localizedDescription)' }))"
                DispatchQueue.main.async {
                    self.webView?.evaluateJavaScript(script, completionHandler: nil)
                }
            }
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Process NFC data and send to web app
        for message in messages {
            for record in message.records {
                if let payload = String(data: record.payload, encoding: .utf8) {
                    let script = "window.dispatchEvent(new CustomEvent('nfcData', { detail: '\(payload)' }))"
                    DispatchQueue.main.async {
                        self.webView?.evaluateJavaScript(script, completionHandler: nil)
                    }
                }
            }
        }
    }
    
    // Add new download handling methods
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let originalURL = downloadTask.originalRequest?.url,
              let suggestedFilename = downloadTask.response?.suggestedFilename else {
            return
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsPath.appendingPathComponent(suggestedFilename)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)
            
            // Notify WebView that file is available offline
            DispatchQueue.main.async {
                let script = """
                    window.dispatchEvent(new CustomEvent('fileDownloaded', {
                        detail: {
                            originalUrl: '\(originalURL)',
                            localUrl: '\(destinationURL)',
                            filename: '\(suggestedFilename)'
                        }
                    }));
                """
                self.webView?.evaluateJavaScript(script, completionHandler: nil)
            }
        } catch {
            print("Error saving file: \(error)")
        }
    }
    
    // Add these new methods after setupWebView
    @objc private func handleLeftSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .ended {
            if webView.canGoBack {
                webView.goBack()
            }
        }
    }
    
    @objc private func handleRightSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .ended {
            if webView.canGoForward {
                webView.goForward()
            }
        }
    }
            if shouldDismiss {
                self.dismiss(animated: true, completion: nil)
            }
        }
        alertController.addAction(okAction)
        
        present(alertController, animated: true, completion: nil)
    }
}

// MARK: - MTKViewDelegate
extension MainController: MTKViewDelegate {
    // Called whenever view changes orientation or layout is changed
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        guard let renderer = renderer else { return }
        renderer.drawRectResized(size: size)
    }
    
    // Called whenever the view needs to render
    func draw(in view: MTKView) {
        guard let renderer = renderer else { return }
        renderer.draw()
    }
}

// MARK: - Added controller functionality
extension MainController {
    private func setShowSceneButtonStyle(isScanning: Bool) -> Void {
        if isScanning {
            self.showSceneButton.setBackgroundImage(
                .init(systemName: "livephoto.slash"), for: .normal)
            self.showSceneButton.tintColor = .red
        } else {
            self.showSceneButton.setBackgroundImage(
                .init(systemName: "livephoto"), for: .normal)
            self.showSceneButton.tintColor = .white
        }
    }
    
    func onSaveError(error: XError) {
        displayErrorMessage(error: error)
        renderer.savingError = nil
    }
    
    func export(url: URL) -> Void {
        present(
            UIActivityViewController(
                activityItems: [url as Any],
                applicationActivities: .none),
            animated: true)
    }
    
    func afterSave() -> Void {
        let err = renderer.savingError
        if err == nil {
            return export(url: renderer.savedCloudURLs.last!)
        }
        try? FileManager.default.removeItem(at: renderer.savedCloudURLs.last!)
        renderer.savedCloudURLs.removeLast()
        onSaveError(error: err!)
    }
    
    func goToSaveCurrentScanView() {
        let saveContoller = SaveController()
        saveContoller.mainController = self
        present(saveContoller, animated: true, completion: nil)
    }
    
    func goToExportView() -> Void {
        let exportController = ExportController()
        exportController.mainController = self
        present(exportController, animated: true, completion: nil)
    }
    
    func displayErrorMessage(error: XError) -> Void {
        var title: String
        switch error {
            case .alreadySavingFile: title = "Save in Progress Please Wait."
            case .noScanDone: title = "No scan to Save."
            case.savingFailed: title = "Failed To Write File."
        }
        
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        present(alert, animated: true, completion: nil)
        let when = DispatchTime.now() + 1.75
        DispatchQueue.main.asyncAfter(deadline: when) {
            alert.dismiss(animated: true, completion: nil)
        }
    }
    
    // Add method to check for cached files
    private func checkCachedFiles() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, 
                includingPropertiesForKeys: nil)
            
            let filesInfo = files.map { url -> [String: String] in
                return [
                    "url": url.absoluteString,
                    "filename": url.lastPathComponent
                ]
            }
            
            // Send cached files info to WebView
            if let jsonData = try? JSONSerialization.data(withJSONObject: filesInfo),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                let script = "window.dispatchEvent(new CustomEvent('cachedFiles', { detail: \(jsonString) }));"
                webView?.evaluateJavaScript(script, completionHandler: nil)
            }
        } catch {
            print("Error checking cached files: \(error)")
        }
    }
    
    // Move these methods inside MainController
    private func loadOfflineCache() -> String? {
        let dataStore = WKWebsiteDataStore.default()
        var cachedHTML: String? = nil
        
        // Try to load from cache
        if let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let cacheFile = cachesURL.appendingPathComponent("offline.html")
            cachedHTML = try? String(contentsOf: cacheFile, encoding: .utf8)
        }
        
        return cachedHTML
    }
    
    private func cacheCurrentPage() {
        webView?.evaluateJavaScript("document.documentElement.outerHTML") { (result, error) in
            if let html = result as? String,
               let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                let cacheFile = cachesURL.appendingPathComponent("offline.html")
                try? html.write(to: cacheFile, atomically: true, encoding: .utf8)
            }
        }
    }
}

// MARK: - RenderDestinationProvider
protocol RenderDestinationProvider {
    var currentRenderPassDescriptor: MTLRenderPassDescriptor? { get }
    var currentDrawable: CAMetalDrawable? { get }
    var colorPixelFormat: MTLPixelFormat { get set }
    var depthStencilPixelFormat: MTLPixelFormat { get set }
    var sampleCount: Int { get set }
}

extension SCNNode {
    func cleanup() {
        for child in childNodes {
            child.cleanup()
        }
        self.geometry = nil
    }
}

func createButton(mainView: MainController, iconName: String, tintColor: UIColor, hidden: Bool) -> UIButton {
    let button = UIButton(type: .system)
    button.isHidden = hidden
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setBackgroundImage(.init(systemName: iconName), for: .normal)
    button.tintColor = tintColor
    button.addTarget(mainView, action: #selector(mainView.viewValueChanged), for: .touchUpInside)
    return button
}

extension MTKView: RenderDestinationProvider {
    
}

// MARK: - WKNavigationDelegate
extension MainController {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Cache the page for offline use
        self.cacheCurrentPage()
        
        // Check if the page is fully loaded using JavaScript
        webView.evaluateJavaScript("document.readyState") { (result, error) in
            if let readyState = result as? String, readyState == "complete" {
                // Remove both loading view and splash screen with animation
                DispatchQueue.main.async {
                    UIView.animate(withDuration: 0.3) {
                        self.loadingView?.alpha = 0
                        self.splashView?.alpha = 0
                    } completion: { _ in
                        self.loadingView?.removeFromSuperview()
                        self.loadingView = nil
                        self.splashView?.removeFromSuperview()
                        self.splashView = nil
                    }
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Handle error if needed
        self.loadingView?.removeFromSuperview()
        self.loadingView = nil
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Preserve web storage during page refresh
        if navigationAction.navigationType == .reload {
            decisionHandler(.allow)
            return
        }
        decisionHandler(.allow)
    }
    
    // Add new WKNavigationDelegate method to handle offline loading
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorNotConnectedToInternet {
            // Try to load cached version
            if let offlineHTML = loadOfflineCache() {
                webView.loadHTMLString(offlineHTML, baseURL: URL(string: "https://s1.air-os.app"))
            } else {
                // Show offline message
                let offlinePage = """
                <html>
                    <body style="font-family: -apple-system; text-align: center; padding: 50px;">
                        <h2>Currently Offline</h2>
                        <p>Please check your internet connection and try again.</p>
                    </body>
                </html>
                """
                webView.loadHTMLString(offlinePage, baseURL: nil)
            }
        }
    }
}

// Add new extension for WKUIDelegate
extension MainController {
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
        webView.configuration.allowsInlineMediaPlayback = true
        webView.configuration.mediaTypesRequiringUserActionForPlayback = []
    }
}

// Helper extension
extension SIMD4 {
    var xyz: SIMD3<Scalar> {
        SIMD3(x: x, y: y, z: z)
    }
}
