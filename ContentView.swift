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

        // Add a button to move the ball above the spoon
        let button = UIButton(type: .system)
        button.backgroundColor = .blue
        button.setTitle("Move Ball", for: .normal)
        button.addTarget(context.coordinator, action: #selector(Coordinator.moveBallAboveSpoon), for: .touchUpInside)
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

        context.coordinator.setupSpoon(sceneView: uiView)
        context.coordinator.setupBall(sceneView: uiView)
    }

    class Coordinator: NSObject, ARSCNViewDelegate {
        var sceneView: ARSceneView
        var spoonNode: SCNNode!
        var spoonNode: SCNNode!
        var ballNode: SCNNode!

        init(_ sceneView: ARSceneView) {
            self.sceneView = sceneView
        }

        func setupSpoon(sceneView: ARSCNView) {
            let spoon1Scene = try! SCNScene(url: Bundle.main.url(forResource: "spoonModel", withExtension: "usdz")!)
            spoonNode = spoon1Scene.rootNode.childNodes.first!

            spoonNode.position = SCNVector3(0, -0.3, -0.8)
            spoonNode.eulerAngles = SCNVector3(GLKMathDegreesToRadians(0), 0, 0)

            sceneView.pointOfView?.addChildNode(spoonNode)

            // Enable physics on the spoon node
            let spoonPhysicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(node: spoonNode))
            spoonNode.physicsBody = spoonPhysicsBody
            spoonNode.name = "spoon"
        }

        @objc func moveBallAboveSpoon() {
            // Remove the current ball node from the scene
            ballNode.removeFromParentNode()

            // Spawn a new ball node on the spoon node
            let ballGeometry = SCNSphere(radius: 0.12)
            ballGeometry.firstMaterial?.diffuse.contents = UIColor.red
            ballNode = SCNNode(geometry: ballGeometry)
            ballNode.position = SCNVector3(0, 0.1, -0.5) // Set the z-coordinate of the ball to -0.03
            spoonNode.addChildNode(ballNode)

            // Enable physics on the new ball node
            let ballPhysicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: ballGeometry, options: nil))
            ballNode.physicsBody = ballPhysicsBody
            ballNode.name = "ball"
        }

        func setupBall(sceneView: ARSCNView) {
            // Remove the current ball node from the scene

            // Spawn a new ball node on the spoon node
            let ballGeometry = SCNSphere(radius: 0.12)
            ballGeometry.firstMaterial?.diffuse.contents = UIColor.red
            ballNode = SCNNode(geometry: ballGeometry)
            ballNode.position = SCNVector3(0, 0.1, -0.5) // Set the z-coordinate of the ball to -0.03
            spoonNode.addChildNode(ballNode)

            // Enable physics on the new ball node
            let ballPhysicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: ballGeometry, options: nil))
            ballNode.physicsBody = ballPhysicsBody
            ballNode.name = "ball"
        }

        func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
            if (contact.nodeA.name == "spoon" && contact.nodeB.name == "ball") ||
                (contact.nodeA.name == "ball" && contact.nodeB.name == "spoon")
            {
                // Add some force to the ball node in the direction of the spoon node's z-axis
                let force = SCNVector3(spoonNode.presentation.worldTransform.m31,
                                       spoonNode.presentation.worldTransform.m32,
                                       spoonNode.presentation.worldTransform.m33)

                let position = SCNVector3(contact.contactPoint.x, contact.contactPoint.y, contact.contactPoint.z)
                ballNode.physicsBody?.applyForce(force, at: position, asImpulse: true)
            }
        }

        @objc func handlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
            // Move the spoon node along the x and y axes based on the pan gesture
            let translation = gestureRecognizer.translation(in: gestureRecognizer.view!)
            var newPosition = spoonNode.position
            newPosition.x += Float(translation.x) / 100
            newPosition.y -= Float(translation.y) / 100
            spoonNode.position = newPosition
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
