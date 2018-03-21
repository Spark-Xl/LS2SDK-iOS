//
//  LS2Encryption.swift
//  LS2SDK
//
//  Created by James Kizer on 2/28/18.
//

import Foundation
import OMHClient
import GZIP
import CryptoSwift

//public extension OMHDataPointBuilder {
//    
//    private func encryptBody(bodyDict: [String: Any], compressData: Bool) throws -> EncryptedMessage {
//        
//        let bodyData = try JSONSerialization.data(withJSONObject: bodyDict, options: [])
//        
//        let data: Data? = {
//            if compressData {
//                return (bodyData as NSData).gzipped()
//            }
//            else {
//                return bodyData
//            }
//        }()
//        
//        guard let clearData = data else {
//            throw LS2EncryptionErrors.dataCompressionError
//        }
//        
//        //256 bit key size
//        guard let aesKey: Array<UInt8> = self.generateRandomBytes(size: 32),
//        let iv: Array<UInt8> = self.generateRandomBytes(size: AES.blockSize),
//        let aes = try? AES(key: aesKey, blockMode: .CBC(iv: iv)),
//        let messageCipher = try? aes.encrypt(messageData.bytes),
//        
//        
//        
//        
//    }
//    
//    private func generateRandomBytes(size: Int) -> Array<UInt8>? {
//        
//        var keyData = Data(count: size)
//        let result = keyData.withUnsafeMutableBytes {
//            (mutableBytes: UnsafeMutablePointer<UInt8>) -> Int32 in
//            SecRandomCopyBytes(kSecRandomDefault, keyData.count, mutableBytes)
//        }
//        if result == errSecSuccess {
//            //            return keyData.base64EncodedString()
//            return keyData.bytes
//        } else {
//            print("Problem generating random bytes")
//            return nil
//        }
//    }
//    
//    public func toEncryptedDict() -> OMHDataPointDictionary? {
//        
//        return [
//            "header": self.header,
//            "encrypted_body": self.body
//        ]
//    }
//    
//}

