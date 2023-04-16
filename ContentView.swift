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
        return sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        let configuration = ARWorldTrackingConfiguration()
        uiView.session.run(configuration)
        context.coordinator.setupSpoon(sceneView: uiView)
    }

    class Coordinator: NSObject, ARSCNViewDelegate {
        var sceneView: ARSceneView

        init(_ sceneView: ARSceneView) {
            self.sceneView = sceneView
        }

        func setupSpoon(sceneView: ARSCNView) {
            let spoonScene = try! SCNScene(url: Bundle.main.url(forResource: "spoonModel", withExtension: "usdz")!)
            let spoonNode = spoonScene.rootNode.childNodes.first!

            spoonNode.position = SCNVector3(0, -0.1, -0.8) // Adjust the position to your preference
            spoonNode.eulerAngles = SCNVector3(GLKMathDegreesToRadians(0), 0, 0) // Adjust the rotation if necessary

            let sphereNode = createSphereNode(radius: 0.03) // Adjust the radius to fit your spoon model
            sphereNode.position = SCNVector3(0, 0.05, 0) // Adjust the position to place the sphere on the spoon

            spoonNode.addChildNode(sphereNode)
            sceneView.pointOfView?.addChildNode(spoonNode)
        }

        func createSphereNode(radius: CGFloat) -> SCNNode {
            let sphere = SCNSphere(radius: radius)
            let sphereNode = SCNNode(geometry: sphere)

            let material = SCNMaterial()
            material.diffuse.contents = UIColor.red // Set the sphere color
            sphere.materials = [material]

            return sphereNode
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
