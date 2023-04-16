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

        // Add a pan gesture recognizer to the scene view
        let panGestureRecognizer = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePanGesture(_:)))
        sceneView.addGestureRecognizer(panGestureRecognizer)

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

        // Add properties for the spoon and ball nodes
        var spoonNode: SCNNode!
        var ballNode: SCNNode!

        init(_ sceneView: ARSceneView) {
            self.sceneView = sceneView
        }

        func setupSpoon(sceneView: ARSCNView) {
            let spoonScene = try! SCNScene(url: Bundle.main.url(forResource: "spoonModel", withExtension: "usdz")!)
            spoonNode = spoonScene.rootNode.childNodes.first!

            spoonNode.position = SCNVector3(0, -0.1, -0.8)
            spoonNode.eulerAngles = SCNVector3(GLKMathDegreesToRadians(0), 0, 0)

            sceneView.pointOfView?.addChildNode(spoonNode)

            // Enable physics on the spoon node
            let spoonPhysicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(node: spoonNode))
            spoonNode.physicsBody = spoonPhysicsBody
            spoonNode.name = "spoon"
        }

        func setupBall(sceneView: ARSCNView) {
            let ballGeometry = SCNSphere(radius: 0.03)
            ballGeometry.firstMaterial?.diffuse.contents = UIColor.red
            ballNode = SCNNode(geometry: ballGeometry)

            ballNode.position = SCNVector3(0, 0, -1)

            sceneView.scene.rootNode.addChildNode(ballNode)

            // Enable physics on the ball node
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
