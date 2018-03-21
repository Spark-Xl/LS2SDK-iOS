//
//  LS2EncryptionProvider.swift
//  LS2SDK
//
//  Created by James Kizer on 2/28/18.
//

import UIKit
import Security
import CryptoSwift
import GZIP

open class LS2EncryptionProvider: NSObject {
    
    //message is encrypted w/
    public struct EncryptedMessage {
        //data
        let encryptedData: Data
        //metadata
        let isCompressed: Bool
        
        //info about data encryption
        //should IV and MAC go in dataEncryptionAlgorithm??
        let dataEncryptionAlgorithm: [String: Any]
        let mac: Data
        let initializationVector: Data
        
        
        //recipients
        //for each recipient, we will generate a different encryptedDEK
        //also need metadata
        
        let encryptedDEK: Data
        
        let keyEncryptionAlgorithm: [String: Any]
        
        
    }
    
    public static func generateRandomBytes(size: Int) throws -> Array<UInt8> {
        
        var randomData = Data(count: size)
        let result = randomData.withUnsafeMutableBytes {
            (mutableBytes: UnsafeMutablePointer<UInt8>) -> Int32 in
            SecRandomCopyBytes(kSecRandomDefault, randomData.count, mutableBytes)
        }
        if result == errSecSuccess {
            //            return keyData.base64EncodedString()
            return randomData.bytes
        } else {
            print("Problem generating random bytes")
            throw LS2EncryptionErrors.randomDataGenerationError
        }
    }
    
    //generates a random data encryption key, random IV, and encrypts data using AES 256 CBC w/ pkcs7 padding
    //encrypts the data encryption key using RSA + OAEP
    func encryptMessage(message:Data, publicKeyID: String, compressData: Bool) throws -> EncryptedMessage {
        
        let data: Data? = {
            if compressData {
                return (message as NSData).gzipped()
            }
            else {
                return message
            }
        }()
        
        guard let messageData = data else {
            throw LS2EncryptionErrors.dataCompressionError
        }
        
        let dataEncryptionKey: Array<UInt8> = try LS2EncryptionProvider.generateRandomBytes(size: 32)
        let iv: Array<UInt8> = try LS2EncryptionProvider.generateRandomBytes(size: AES.blockSize)
        let aes = try AES(key: dataEncryptionKey, blockMode: .CBC(iv: iv))
        let messageCipher = try aes.encrypt(messageData.bytes)
        
        //compute HMAC of messageCipher + iv w/ dataEncryptionKey
        //if this fails, message has been tampered with
        let dekHMAC = try HMAC(key: dataEncryptionKey, variant: .sha256).authenticate(messageCipher + iv)
        
        //how do we authenticate data encryption key has not been tampered with?
        //we could generate a keypair on the device and transmit to the server
        //this could be used for signing
        //on the other hand, this could be a bit overkill
        
        //encrypt DEK w/ recipients' public keys using RSA + OAEP
        
        
        let publicKey = try PublicKey(pemNamed: "public")
        let clear = try ClearMessage(string: "Clear Text", using: .utf8)
        let encrypted = try clear.encrypted(with: publicKey, padding: .PKCS1)
        let dataEncryptionKeyCipher =
        
        
        //256 bit key size
        guard let aesKey: Array<UInt8> = try LS2EncryptionProvider.generateRandomBytes(size: 32),
            let iv: Array<UInt8> = LS2EncryptionProvider.generateRandomBytes(size: AES.blockSize),
            let aes = try? AES(key: aesKey, blockMode: .CBC(iv: iv)),
            let messageCipher = try? aes.encrypt(messageData.bytes),
            let keyCipher = RSAUtils.encryptWithRSAKey(data: Data(aesKey), tagName: publicKeyName) else {
                return nil
        }
        
        debugPrint(aes.variant)
        
        //compute MAC of encryptedData + initialization vector using symetric key
        guard let mac = try? HMAC(key: aesKey, variant: .sha256).authenticate(messageCipher + iv) else {
            return nil
        }
        
        return EncryptedMessage(
            encryptedData: Data(messageCipher),
            cipherName: "aes-256-cbc",
            initializationVector: Data(iv),
            encryptedKey: Data(keyCipher),
            publicKeyName: publicKeyName,
            isCompressed: compressData,
            mac: Data(mac)
        )
        
    }
    
}
