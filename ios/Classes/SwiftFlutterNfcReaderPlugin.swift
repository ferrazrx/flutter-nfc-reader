import Flutter
import Foundation
import CoreNFC
import VYNFCKit

@available(iOS 13.0, *)
public class SwiftFlutterNfcReaderPlugin: NSObject, FlutterPlugin {
    
    fileprivate var nfcSession: NFCNDEFReaderSession? = nil
    fileprivate var nfcTagSession: NFCTagReaderSession? = nil
    
    fileprivate var instruction: String? = nil
    fileprivate var resulter: FlutterResult? = nil
    fileprivate var readResult: FlutterResult? = nil
    
    private var eventSink: FlutterEventSink?
    
    fileprivate let kId = "nfcId"
    fileprivate let kContent = "nfcContent"
    fileprivate let kStatus = "nfcStatus"
    fileprivate let kError = "nfcError"
    
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_nfc_reader", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "it.matteocrippa.flutternfcreader.flutter_nfc_reader", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterNfcReaderPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch(call.method) {
        case "NfcRead":
            let map = call.arguments as? Dictionary<String, String>
            instruction = map?["instruction"] ?? ""
            readResult = result
            print("read")
            activateNFC(instruction)
        case "NfcStop":
            resulter = result
            disableNFC()
        case "NfcWrite":
            var alertController = UIAlertController(title: nil, message: "IOS does not support NFC tag writing", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            UIApplication.shared.keyWindow?.rootViewController?.present(alertController, animated: true)
        default:
            result("iOS " + UIDevice.current.systemVersion)
        }
    }
}

// MARK: - NFC Actions
@available(iOS 13.0, *)
extension SwiftFlutterNfcReaderPlugin {
    func activateNFC(_ instruction: String?) {
        print("activate")
        
        nfcTagSession = NFCTagReaderSession(pollingOption: .iso14443, delegate: self)
        
        // then setup a new session
               if let instruction = instruction {
                   nfcTagSession?.alertMessage = instruction
               }

        // start
        if let nfcTagSession = nfcTagSession {
            nfcTagSession.begin()
        }
    }
    
    func disableNFC() {
        //nfcSession?.invalidate()
        let data = [kId: "", kContent: "", kError: "", kStatus: "stopped"]
        
        resulter?(data)
        resulter = nil
    }
    
    func sendNfcEvent(data: [String: String]){
        guard let eventSink = eventSink else {
            return
        }
        eventSink(data)
    }
}

// MARK: - NFCDelegate
@available(iOS 13.0, *)
extension SwiftFlutterNfcReaderPlugin : NFCTagReaderSessionDelegate  {
    public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("Tag reader did become active")
    }
    
    public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print(error.localizedDescription)
        let data = [kId: "", kContent: "", kError: error.localizedDescription, kStatus: "error"]
        resulter?(data)
        disableNFC()
    }
    
    public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        
        var uidString = "0x"
        var content = ""
        if case let NFCTag.miFare(tag) = tags.first! {
          
            let tagUIDData = tag.identifier
            var byteData: [UInt8] = []
            tagUIDData.withUnsafeBytes { byteData.append(contentsOf: $0) }
            
            for byte in byteData {
                let decimalNumber = String(byte, radix: 10)
                let hexNumber = String(byte, radix: 16)
                if (Int(decimalNumber) ?? 0) < 10 { // add leading zero
                    uidString.append("0\(hexNumber)")
                    
                } else {
                    uidString.append(hexNumber)
                }
            }
            
            for byte in byteData {
                
                let decimalNumber = String(byte, radix: 10)
                content.append(decimalNumber)
               
            }
            
            debugPrint("\(byteData) converted to Tag UID: \(uidString)")
            
            session.connect(to: tags.first!) { (error: Error?) in
               if error != nil {
                   session.invalidate(errorMessage: "Connection error. Please try again.")
                   return
               }
            }
            session.invalidate()
        }
        
       
        
        let data = [kId: uidString, kContent: content, kError: "", kStatus: "reading"]
        sendNfcEvent(data: data);
        readResult?(data)
        readResult=nil
    }
    
}

@available(iOS 13.0, *)
extension SwiftFlutterNfcReaderPlugin: FlutterStreamHandler {
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
}
