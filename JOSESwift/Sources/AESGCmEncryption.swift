//
//  AESGCmEncryption.swift
//  JOSESwift
//
//  Created by Swetha Sreekanth on 16/12/20.
//

import Foundation
import CryptoSwift

struct AESGCMEncryption {
    
    private let contentEncryptionAlgorithm: ContentEncryptionAlgorithm
    private let contentEncryptionKey: Data
    
    init(contentEncryptionAlgorithm: ContentEncryptionAlgorithm, contentEncryptionKey: Data) {
        self.contentEncryptionAlgorithm = contentEncryptionAlgorithm
        self.contentEncryptionKey = contentEncryptionKey
    }
    
    func encrypt(_ plaintext: Data, additionalAuthenticatedData: Data) throws -> ContentEncryptionContext {
        print("AESGCMEncryption :::: encrypt ::: \(plaintext)")
        let iv = try SecureRandom.generate(count: contentEncryptionAlgorithm.initializationVectorLength)

        let keys = try contentEncryptionAlgorithm.retrieveKeys(from: contentEncryptionKey)
        let encryptionKey = keys.encryptionKey

        let gcm = GCM(iv: [UInt8](hex: iv.hexEncodedString()), mode: .combined)
        let aes = try! AES(key: [UInt8](hex: encryptionKey.hexEncodedString()), blockMode: gcm, padding: .noPadding)
        let ciphertext = try! aes.encrypt([UInt8](hex: plaintext.hexEncodedString()))
        let tag = gcm.authenticationTag!
        
        // Put together the input data for the HMAC. It consists of A || IV || E || AL.
        
        return ContentEncryptionContext(
            ciphertext: Data(ciphertext),
            authenticationTag: Data(tag),
            initializationVector: iv
        )
    }
    
    func decrypt(
        _ ciphertext: Data,
        initializationVector: Data,
        additionalAuthenticatedData: Data,
        authenticationTag: Data
    ) throws -> Data {
        print("AESGCMEncryption :::: decrypt ::: \(ciphertext)")
        // Check if the key length contains both HMAC key and the actual symmetric key.
        guard contentEncryptionAlgorithm.checkKeyLength(for: contentEncryptionKey) else {
            throw JWEError.keyLengthNotSatisfied
        }
        print("AESGCMEncryption :::: \(ciphertext)")
        // Get the two keys for the HMAC and the symmetric encryption.
        let keys = try contentEncryptionAlgorithm.retrieveKeys(from: contentEncryptionKey)
        print("AESGCMEncryption :::: keys ::: \(keys)")
        let decryptionKey = keys.encryptionKey
        print("AESGCMEncryption :::: decryptionKey ::: \(decryptionKey.hexEncodedString())")
        // Decrypt the cipher text with a symmetric decryption key, a symmetric algorithm and the initialization vector,
        // return the plaintext if no error occured.
        let gcm = GCM(iv:  [UInt8](hex: initializationVector.hexEncodedString()), mode: .combined)
        let aes = try AES(key: [UInt8](hex: decryptionKey.hexEncodedString()), blockMode: gcm, padding: .noPadding)
//        as per cryptoswift the authentication tag needs to be appended to the cipher text
        let plaintext =  try aes.decrypt([UInt8](hex: authenticationTag.hexEncodedString() + ciphertext.hexEncodedString()))
        print("AESGCMEncryption :::: plaintext ::: \(plaintext)")
        return Data(plaintext)
    }
}


extension AESGCMEncryption: ContentEncrypter {
    func encrypt(header: JWEHeader, payload: Payload) throws -> ContentEncryptionContext {
        let plaintext = payload.data()
        let additionalAuthenticatedData = header.data().base64URLEncodedData()
        return try encrypt(plaintext, additionalAuthenticatedData: additionalAuthenticatedData)
        
    }
}

extension AESGCMEncryption: ContentDecrypter {
    func decrypt(decryptionContext: ContentDecryptionContext) throws -> Data {
        return try decrypt(
            decryptionContext.ciphertext,
            initializationVector: decryptionContext.initializationVector,
            additionalAuthenticatedData: decryptionContext.additionalAuthenticatedData,
            authenticationTag: decryptionContext.authenticationTag
        )
    }
}
