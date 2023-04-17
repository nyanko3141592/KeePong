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

        // Add a button to move the ball above the racket
        let button = UIButton(type: .system)
        button.backgroundColor = .blue
        button.setTitle("Play", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
        button.layer.cornerRadius = 15
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 32, bottom: 12, right: 32)
        button.addTarget(context.coordinator, action: #selector(Coordinator.moveBallAboveracket), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        sceneView.addSubview(button)

        // Add constraints to center the button horizontally and position it at the bottom of the view
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: sceneView.centerXAnchor),
            button.bottomAnchor.constraint(equalTo: sceneView.bottomAnchor, constant: -20)
        ])

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
            ballPhysicsBody.restitution = 0.8 // Set the ball's bounciness
            ballNode.physicsBody = ballPhysicsBody
            ballNode.position = SCNVector3(0, 0.1, -0.3) // Set the z-coordinate of the ball to -0.03
            racketNode.addChildNode(ballNode)
            ballNode.name = "ball"
        }

        func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
            if (contact.nodeA.name == "racket" && contact.nodeB.name == "ball") ||
                (contact.nodeA.name == "ball" && contact.nodeB.name == "racket")
            {
                // Add some force to the ball node in the direction of the racket node's z-axis
                let force = SCNVector3(racketNode.presentation.worldTransform.m31,
                                       racketNode.presentation.worldTransform.m32,
                                       racketNode.presentation.worldTransform.m33)

                let position = SCNVector3(contact.contactPoint.x, contact.contactPoint.y, contact.contactPoint.z)
                ballNode.physicsBody?.applyForce(force, at: position, asImpulse: true)
            }
        }

        @objc func handlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
            // Move the racket node along the x and y axes based on the pan gesture
            let translation = gestureRecognizer.translation(in: gestureRecognizer.view!)
            var newPosition = racketNode.position
            newPosition.x += Float(translation.x) / 100
            newPosition.y -= Float(translation.y) / 100
            racketNode.position = newPosition
            gestureRecognizer.setTranslation(CGPoint.zero, in: gestureRecognizer.view)
        }
    }
}

struct ContentView: View {
    var body: some View {
        ARSceneView()
            .edgesIgnoringSafeArea(.all)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
