import ARKit
import SwiftUI

struct ARSceneView: UIViewRepresentable {
    let playbutton = UIButton(type: .system)
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView()
        sceneView.delegate = context.coordinator
        sceneView.autoenablesDefaultLighting = true
        sceneView.showsStatistics = true

        // add play button
        playbutton.backgroundColor = .systemRed
        playbutton.setTitle("Play", for: .normal)
        playbutton.setTitleColor(.white, for: .normal)
        playbutton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 30)
        playbutton.layer.cornerRadius = 15
        playbutton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 32, bottom: 12, right: 32)
        playbutton.addTarget(context.coordinator, action: #selector(Coordinator.moveBallAboveracket), for: .touchUpInside)
        playbutton.translatesAutoresizingMaskIntoConstraints = false
        sceneView.addSubview(playbutton)

        // add stopwatch label
        let stopwatchLabel = UILabel()
        stopwatchLabel.textColor = .white
        stopwatchLabel.font = UIFont.systemFont(ofSize: 50)
        stopwatchLabel.textAlignment = .center
        stopwatchLabel.translatesAutoresizingMaskIntoConstraints = false
        sceneView.addSubview(stopwatchLabel)

        // Add constraints to center the button horizontally and position it at the bottom of the view
        NSLayoutConstraint.activate([
            playbutton.centerXAnchor.constraint(equalTo: sceneView.centerXAnchor),
            playbutton.bottomAnchor.constraint(equalTo: sceneView.bottomAnchor, constant: -20),
            stopwatchLabel.centerXAnchor.constraint(equalTo: sceneView.centerXAnchor),
            stopwatchLabel.topAnchor.constraint(equalTo: sceneView.topAnchor, constant: 20)
        ])

        context.coordinator.stopwatchLabel = stopwatchLabel // set the label as a property of the coordinator

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
        var stopwatchLabel: UILabel! // label to display the stopwatch time
        var stopwatchTimer: Timer? // timer for the stopwatch
        var elapsedSeconds: Int = 0 // number of seconds elapsed on the stopwatch
        var isBallDropped: Bool = false // flag to indicate if the ball has been dropped

        init(_ sceneView: ARSceneView) {
            self.sceneView = sceneView
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

            // Create a transparent ground
            let groundGeometry = SCNPlane(width: 5, height: 5)
            let groundMaterial = SCNMaterial()
            groundMaterial.diffuse.contents = UIColor.clear
            groundGeometry.materials = [groundMaterial]
            let groundNode = SCNNode(geometry: groundGeometry)
            groundNode.eulerAngles = SCNVector3(GLKMathDegreesToRadians(270), 0, 0)
            groundNode.position = SCNVector3(0, -2, -1)
            let groundPhysicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: groundGeometry, options: nil))
            groundNode.physicsBody = groundPhysicsBody
            groundNode.name = "ground"
            sceneView.scene.rootNode.addChildNode(groundNode)
        }

        func ballDropped() {
            // Stop the stopwatch
            stopwatchTimer?.invalidate()
            stopwatchTimer = nil

            // Remove the ball from the scene
            ballNode.removeFromParentNode()

            var message = resultMessage(seconds: elapsedSeconds / 10)

            // Show an alert message
            let alertController = UIAlertController(title: "Your Score: \(elapsedSeconds)",
                                                    message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            UIApplication.shared.windows.first?.rootViewController?.present(alertController, animated: true, completion: nil)

            // Reset the elapsed time and update the stopwatch label
            elapsedSeconds = 0
            updateStopwatchLabel()
        }

        func resultMessage(seconds: Int) -> String {
            if seconds < 5 {
                return "Nice try!"
            } else if seconds < 10 {
                return "Good Score!"
            } else if seconds < 20 {
                return "Excellent Work!"
            } else if seconds < 30 {
                return "wonderful!!"
            } else if seconds < 50 {
                return "Awesome!"
            } else {
                return "Brilliant!!"
            }
        }

        @objc func moveBallAboveracket(_ sender: UIButton) {
            // Check if ballNode is not nil before removing it from the parent node
            if ballNode != nil {
                ballNode.removeFromParentNode()
            }

            // Spawn a new ball node on the racket node
            let ballGeometry = SCNSphere(radius: ballRadius)
            ballGeometry.firstMaterial?.diffuse.contents = UIColor.white
            ballNode = SCNNode(geometry: ballGeometry)
            let ballPhysicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: ballGeometry, options: nil))
            ballPhysicsBody.restitution = 1 // Set the ball's bounciness
            ballNode.physicsBody = ballPhysicsBody
            ballNode.position = SCNVector3(0, 0.1, -0.3) // Set the z-coordinate of the ball to -0.03
            racketNode.addChildNode(ballNode)
            ballNode.name = "ball"

            // Start or reset the stopwatch timer
            if stopwatchTimer != nil {
                stopwatchTimer!.invalidate()
                elapsedSeconds = 0
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
        }

        func updateStopwatchLabel() {
            let minutes = (elapsedSeconds / 10) / 60
            let seconds = (elapsedSeconds / 10) % 60
            let comma = elapsedSeconds - seconds * 10 - minutes * 600
            stopwatchLabel.text = String(format: "%02d:%02d.%0d", minutes, seconds, comma)
        }

        // Physics contact delegate method to detect when the ball is dropped
        func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
            if contact.nodeA.name == "ball", contact.nodeB.name == "ground" {
                stopStopwatch()
            } else if contact.nodeA.name == "ground", contact.nodeB.name == "ball" {
                stopStopwatch()
            }
        }

        func stopStopwatch() {
            stopwatchTimer?.invalidate()
            stopwatchTimer = nil
        }
    }
}

struct ContentView: View {
    @State private var showHelp = false

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
