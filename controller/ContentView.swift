//
//  ContentView.swift
//  controller
//
//  Created by Adam Watters on 3/6/24.
//

import SwiftUI
import MultipeerConnectivity
import simd
import CoreMotion

struct MCBrowserView: UIViewControllerRepresentable {
    var appState: AppState
    
    func makeUIViewController(context: Context) -> MCBrowserViewController {
        return appState.mcBrowser!
    }
    
    func updateUIViewController(_ uiViewController: MCBrowserViewController, context: Context) {
        print("updating")
    }
}

class AppState: NSObject, ObservableObject, MCSessionDelegate, MCBrowserViewControllerDelegate {
    var peerID: MCPeerID = MCPeerID(displayName: UIDevice.current.name)
    @Published var mcSession: MCSession
    @Published var peers: [MCPeerID] = []
    var mcBrowser: MCBrowserViewController?
    let motionManager = CMMotionManager()
    var gasPressed = false
    var brakePressed = false
    var previousSteeringInput = 0.0
    
    override init() {
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.none)
        self.mcSession = session
        self.mcBrowser = MCBrowserViewController(serviceType: "godot", session: session)
        super.init()
        self.mcSession.delegate = self
        self.mcBrowser!.delegate = self
        
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.01
            motionManager.startDeviceMotionUpdates(to: .main) { (data, error) in
                guard let data = data, error == nil else {
                    return
                }
                let rotation = atan2(data.gravity.x,
                                     data.gravity.y)
                let adjustedToZeroCenter = rotation * -1 - .pi / 2
                let stretched = adjustedToZeroCenter * 1.4
                var output = min(max(stretched, -1), 1)
                
                // prevent switching to complete left turn on over-steer to the right
                if output == -1.0 && self.previousSteeringInput == 1.0 {
                    output = self.previousSteeringInput
                }
                self.previousSteeringInput = output
                do {
                    if !self.peers.isEmpty {
                        var data = Data(Float(output).bytes)
                        data.append(Swift.withUnsafeBytes(of: self.gasPressed, { Data($0) }))
                        data.append(Swift.withUnsafeBytes(of: self.brakePressed, { Data($0) }))
                        try self.mcSession.send(Data(data), toPeers: self.peers, with: .unreliable)
                    }
                } catch {
                    print(error)
                }
            }
        }
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case MCSessionState.connected:
            peers.append(peerID)
            print("Connected: \(peerID.displayName)")

        case MCSessionState.connecting:
            print("Connecting: \(peerID.displayName)")

        case MCSessionState.notConnected:
            peers.removeAll(where: { id in
                id == peerID
            })
            print("Not Connected: \(peerID.displayName)")
            
        @unknown default:
            fatalError("unknown MCSessionState value \(state)")
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        print("data")
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print("stream")
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        print("resource start")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        print("resource finished")
    }
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        print("cancelled")
//        dismiss(animated: true)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        print("cancelled")
//        dismiss(animated: true)
    }
    
    // your view controller here
}

extension Float {
   var bytes: [UInt8] {
       withUnsafeBytes(of: self, Array.init)
   }
}

struct ContentView: View {
//    @ObservedObject var appState = AppState()
    var appState = AppState()
    
    @GestureState private var gasPressGestureActive = false
    var gasPressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
                    .updating($gasPressGestureActive) { (_, isPressed, _) in
                        appState.gasPressed = true
                        isPressed = true
                    }.onEnded({ ended in
                        appState.gasPressed = false
                    })
    }
    
    @State var brakePressed = false
    @GestureState private var brakePressGestureActive = false
    var breakPressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
                    .updating($brakePressGestureActive) { (_, isPressed, _) in
                        appState.brakePressed = true
                        isPressed = true
                    }.onEnded({ ended in
                        appState.brakePressed = false
                    })
    }
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            MCBrowserView(appState: appState)
            HStack {
                Rectangle().fill(Color.red).gesture(breakPressGesture)
                Rectangle().fill(Color.blue).gesture(gasPressGesture)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
