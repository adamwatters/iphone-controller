//
//  ContentView.swift
//  controller
//
//  Created by Adam Watters on 3/6/24.
//

import SwiftUI
import MultipeerConnectivity
import simd

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

    override init() {
        var session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.none)
        self.mcSession = session
        self.mcBrowser = MCBrowserViewController(serviceType: "godot", session: session)
        super.init()
        self.mcSession.delegate = self
        self.mcBrowser!.delegate = self
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
    @State var joystickPosition = simd_float2(0,0)
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            MCBrowserView(appState: appState)
            HStack {
                HStack {
                    GeometryReader { geometry in
                        ZStack {
                            Circle().frame(width: 200, height: 200).foregroundColor(.red).gesture(DragGesture()
                                .onChanged { event in
                                    do {
                                        let center = simd_float2(x: Float(geometry.frame(in: .local).midX), y: Float(geometry.frame(in: .local).midY))
                                        let current = simd_float2(x: Float(event.location.x), y: Float(event.location.y))
                                        let delta = current - center
                                        let distance = sqrt(pow(delta.x, 2) + pow(delta.y, 2))
                                        if distance > 50 {
                                            let normalized = normalize(delta)
                                            joystickPosition = normalized * 50
                                        } else {
                                            joystickPosition = simd_float2(Float(delta.x), Float(delta.y))
                                        }
                                        let adjustedPosition = joystickPosition * simd_float2(1,-1) / 50
                                        var data = Data(adjustedPosition.x.bytes)
                                        data.append(Data(adjustedPosition.y.bytes))
                                        if !appState.peers.isEmpty {
                                            try appState.mcSession.send(data, toPeers: appState.peers, with: .unreliable)
                                        }
                                    } catch {
                                        print(error)
                                    }
                                }
                                .onEnded { event in
                                    joystickPosition = .zero
                                    do {
                                        if !appState.peers.isEmpty {
                                            var data = Data(joystickPosition.x.bytes)
                                            data.append(Data(joystickPosition.y.bytes))
                                            try appState.mcSession.send(Data(data), toPeers: appState.peers, with: .unreliable)
                                        }
                                    } catch {
                                        print(error)
                                    }
                                })
                            Circle().frame(width: 100, height: 100).foregroundColor(.white).allowsHitTesting(false).offset(x: CGFloat(joystickPosition.x), y: CGFloat(joystickPosition.y))
                        }
                    }
                }.frame(width: 200, height: 200)
                Spacer()
                HStack {
                    Circle().frame(width: 80, height: 80).foregroundColor(.yellow).offset(x: -20, y: 20)
                    Circle().frame(width: 80, height: 80).foregroundColor(.pink).offset(x: -0, y: -20)
                }.frame(width: 200, height: 200)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
