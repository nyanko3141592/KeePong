import ARKit
import SwiftUI

struct ARSceneView: UIViewRepresentable {
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
        stopwatchLabel.font = UIFont.systemFont(ofSize: 30)
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

    class Coordinator: NSObject, ARSCNViewDelegate {
        var sceneView: ARSceneView
        var racketNode: SCNNode!
        let ballRadius: CGFloat = 0.1
        var ballNode: SCNNode!
        var stopwatchLabel: UILabel! // label to display the stopwatch time
        var stopwatchTimer: Timer? // timer for the stopwatch
        var elapsedSeconds: Int = 0 // number of seconds elapsed on the stopwatch

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
        }

        @objc func moveBallAboveracket() {
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
            stopwatchTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                self.elapsedSeconds += 1
                self.updateStopwatchLabel()
            }
        }

        func updateStopwatchLabel() {
            let minutes = elapsedSeconds / 60
            let seconds = elapsedSeconds % 60
            stopwatchLabel.text = "TIME: " + String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

struct ContentView: View { var body: some View { ARSceneView().edgesIgnoringSafeArea(.all) } }

struct ContentView_Previews: PreviewProvider { static var previews: some View { ContentView() } }
