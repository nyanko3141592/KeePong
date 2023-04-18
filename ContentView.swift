import ARKit
import AVFoundation
import SwiftUI

struct ARSceneView: UIViewRepresentable {
    var player: AVAudioPlayer?
    var playerpingPong: AVAudioPlayer?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView()
        sceneView.delegate = context.coordinator
        sceneView.autoenablesDefaultLighting = true
        sceneView.showsStatistics = true

        // add play button
        let playbutton = UIButton(type: .system)
        playbutton.backgroundColor = .systemRed
        playbutton.setTitle("  Play  ", for: .normal)
        playbutton.setTitleColor(.white, for: .normal)
        playbutton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 30)
        playbutton.layer.cornerRadius = 15
        playbutton.addTarget(context.coordinator, action: #selector(Coordinator.moveBallAboveracket), for: .touchUpInside)
        playbutton.translatesAutoresizingMaskIntoConstraints = false
        sceneView.addSubview(playbutton)

        // add stopwatch label
        let stopwatchLabel = UILabel()
        stopwatchLabel.textColor = .white
        stopwatchLabel.font = UIFont.systemFont(ofSize: 100)
        stopwatchLabel.textAlignment = .center
        stopwatchLabel.translatesAutoresizingMaskIntoConstraints = false
        sceneView.addSubview(stopwatchLabel)

        // Add constraints to center the button horizontally and position it at the bottom of the view
        NSLayoutConstraint.activate([
            playbutton.centerXAnchor.constraint(equalTo: sceneView.rightAnchor, constant: -60),
            playbutton.centerYAnchor.constraint(equalTo: sceneView.centerYAnchor),
            stopwatchLabel.centerXAnchor.constraint(equalTo: sceneView.centerXAnchor),
            stopwatchLabel.topAnchor.constraint(equalTo: sceneView.topAnchor, constant: 20)
        ])

        context.coordinator.liftingCountLabel = stopwatchLabel // set the label as a property of the coordinator
        context.coordinator.playButton = playbutton

        return sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        let configuration = ARWorldTrackingConfiguration()
        uiView.session.run(configuration)

        context.coordinator.setupracket(sceneView: uiView)
    }

    class Coordinator: NSObject, ARSCNViewDelegate, SCNPhysicsContactDelegate, SCNSceneRendererDelegate {
        var sceneView: ARSceneView
        var racketNode: SCNNode!
        let ballRadius: CGFloat = 0.1
        var ballNode: SCNNode!
        var liftingCountLabel: UILabel! // label to display the stopwatch time
        var stopwatchTimer: Timer? // timer for the stopwatch
        var elapsedSeconds: Int = 0 // number of seconds elapsed on the stopwatch
        var liftingCound: Int = 0 // number of seconds elapsed on the stopwatch
        var isBallDropped: Bool = false // flag to indicate if the ball has been dropped
        var contactSoundPlayer: AVAudioPlayer?
        var contactCounted: Bool = false
        var resultLabel: UILabel!
        var isPlaying: Bool = false
        var playButton: UIButton?

        init(_ sceneView: ARSceneView) {
            self.sceneView = sceneView
        }

        func togglePlayingState() {
            isPlaying.toggle()
            playButton?.isHidden = isPlaying
        }

        func loadContactSound() {
            guard let url = Bundle.main.url(forResource: "pingpong1", withExtension: "mp3") else { return }

            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)

                contactSoundPlayer = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
                contactSoundPlayer?.prepareToPlay()
            } catch {
                print(error.localizedDescription)
            }
        }

        func setupracket(sceneView: ARSCNView) {
            let racket1Scene = try! SCNScene(url: Bundle.main.url(forResource: "racket", withExtension: "usdz")!)
            racketNode = racket1Scene.rootNode.childNodes.first!

            racketNode.position = SCNVector3(0, -0.3, -0.8)
            racketNode.eulerAngles = SCNVector3(GLKMathDegreesToRadians(0), 0, 0)

            sceneView.pointOfView?.addChildNode(racketNode)

            // Enable physics on the racket node
            let racketPhysicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(node: racketNode))
            racketNode.physicsBody = racketPhysicsBody
            racketNode.name = "racket"

            // Set the category and contact bitmasks for the racket physics body
            racketPhysicsBody.categoryBitMask = 1
            racketPhysicsBody.contactTestBitMask = 2

            sceneView.scene.physicsWorld.contactDelegate = self

            // Load the contact sound
            loadContactSound()

            // add result label
            let resultLabel = UILabel()
            resultLabel.textColor = .white
            resultLabel.font = UIFont.boldSystemFont(ofSize: 50)
            resultLabel.textAlignment = .center
            resultLabel.numberOfLines = 0
            resultLabel.translatesAutoresizingMaskIntoConstraints = false
            sceneView.addSubview(resultLabel)
            NSLayoutConstraint.activate([
                resultLabel.centerXAnchor.constraint(equalTo: sceneView.centerXAnchor),
                resultLabel.centerYAnchor.constraint(equalTo: sceneView.centerYAnchor)
            ])
            self.resultLabel = resultLabel
        }

        func ballDropped() {
            // Stop the stopwatch
            stopwatchTimer?.invalidate()
            stopwatchTimer = nil

            // Remove the ball from the scene
            ballNode.removeFromParentNode()

            // Show the result label
            resultLabel.text = "Your Score: \(liftingCound)\n\(resultMessage(count: liftingCound))"
            resultLabel.isHidden = false

            // Reset the elapsed time and update the stopwatch label
            elapsedSeconds = 0
            updateStopwatchLabel()
            sceneView.playSound(file_name: "end")
            togglePlayingState() // show the Play button
        }

        func resultMessage(count: Int) -> String {
            if count < 5 {
                return "Nice try!"
            } else if count < 10 {
                return "Good Score!"
            } else if count < 20 {
                return "Excellent Work!"
            } else if count < 30 {
                return "wonderful!!"
            } else if count < 50 {
                return "Awesome!"
            } else {
                return "Brilliant!!"
            }
        }

        @objc func moveBallAboveracket(_ sender: UIButton) {
            liftingCound = 0
            togglePlayingState() // hide the Play button

            // Check if ballNode is not nil before removing it from the parent node
            if ballNode != nil {
                ballNode.removeFromParentNode()
            }

            // Spawn a new ball node on the racket node
            let ballGeometry = SCNSphere(radius: ballRadius)
            ballGeometry.firstMaterial?.diffuse.contents = UIColor.white
            ballNode = SCNNode(geometry: ballGeometry)
            let ballPhysicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: ballGeometry, options: nil))
            ballPhysicsBody.restitution = 2 // Set the ball's bounciness
            ballNode.physicsBody = ballPhysicsBody
            ballNode.position = SCNVector3(0, 0.3, -0.3) // Set the z-coordinate of the ball to -0.03
            racketNode.addChildNode(ballNode)
            ballNode.name = "ball"

            // Set the category and contact bitmasks for the ball physics body
            ballPhysicsBody.categoryBitMask = 2
            ballPhysicsBody.contactTestBitMask = 1

            // Start or reset the stopwatch timer
            if stopwatchTimer != nil {
                stopwatchTimer!.invalidate()
                elapsedSeconds = 0
                liftingCound = 0
            }
            stopwatchTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                self.elapsedSeconds += 1
                self.updateStopwatchLabel()
                // Check if the ball has dropped
                if self.ballNode.presentation.position.y < self.racketNode.presentation.position.y + 0.2 {
                    self.stopStopwatch()
                    self.ballDropped()
                }
            }
            // Hide the result label
            resultLabel.isHidden = true
        }

        func updateStopwatchLabel() {
            liftingCountLabel.text = String(format: "\(liftingCound) times")
        }

        func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
            // Ball has hit the racket
            contactSoundPlayer?.play()

            if !contactCounted {
                liftingCound += 1
                print("Contacts: \(liftingCound)")
                contactCounted = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.contactCounted = false
                }
            }
        }

        func stopStopwatch() {
            stopwatchTimer?.invalidate()
            stopwatchTimer = nil
        }
    }

    mutating func playSound(file_name: String) {
        guard let url = Bundle.main.url(forResource: file_name, withExtension: "mp3") else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)

            guard let player = player else { return }

            player.play()

        } catch {
            print(error.localizedDescription)
        }
    }
}

struct ContentView: View {
    @State private var showHelp = true

    var body: some View {
        ZStack {
            // Your ARSceneView
            ARSceneView()

            // Help button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showHelp = true
                    }, label: {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding()
                    })
                    .background(Color.blue)
                    .cornerRadius(20)
                    .padding()
                }
                Spacer()
            }
        }
        .edgesIgnoringSafeArea(.all)
        .sheet(isPresented: $showHelp, content: {
            HelpOverlayView(showHelp: $showHelp)
        })
    }
}

struct HelpOverlayView: View {
    @Binding var showHelp: Bool

    var body: some View {
        ZStack {
            List {
                Image(uiImage: #imageLiteral(resourceName: "title.PNG"))
                    .resizable()
                    .scaledToFit()
                Section(header: Text("How to Play").font(.title)) {
                    Text("Hold the device vertically from the ground with both hands. The racket visible on the screen will move in sync with the device.")
                    Text("Press the play button to start the game. Ping pong balls will fall down.")
                    Text("While tilting the device, try to maintain a good balance. The higher the score, the longer you can avoid dropping the balls.")
                }

                Section(header: Text("Why this App was Created").font(.title)) {
                    Text("My grandmother developed dementia this year. Her decline in motor skills and lack of balance are also due to aging, and she suffered a major injury two years ago. I hope this app will help improve her concentration and balance even a little bit. My grandmother's score is 1 minute and 10 seconds.")
                }
                Section(header: Text("Application Information").font(.title)) {
                    Text("Author: Naoki Takahashi")
                }
                Image(uiImage: #imageLiteral(resourceName: "icons.PNG"))
                    .resizable()
                    .scaledToFit()
            }
            .listStyle(InsetGroupedListStyle())

            VStack {
                HStack {
                    Spacer()
                    // Add a close button
                    Button(action: {
                        showHelp = false
                    }, label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.gray)
                    })
                    .padding(.trailing, 20)
                    .padding(.top, 50)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                Spacer()
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

struct ContentView_Previews: PreviewProvider { static var previews: some View { ContentView() } }
