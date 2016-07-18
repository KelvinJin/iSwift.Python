//
//  SHA256.swift
//  CryptoCoin
//
//  Created by Sjors Provoost on 07-07-14.
//
//  Swift wrapper for CCHmac

import Foundation
import CommonCrypto

extension UInt8 {
    private static let allHexits: [Character] = "0123456789abcdef".characters.flatMap { $0 }
    
    func toHex() -> String {
        let nybbles = [ Int(self >> 4), Int(self & 0x0F) ]
        let hexits = nybbles.map { nybble in UInt8.allHexits[nybble] }
        return String(hexits)
    }
}

public class SHA256 {
    private let key: String
    private var bytes: [UInt8] = []
    
    init(key: String) {
        self.key = key
    }
    
    func update(_ bytes: [UInt8]) {
        self.bytes.append(contentsOf: bytes)
    }
    
    func digest() -> [UInt8] {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        let keyStr = key.utf8.map { Int8($0) }
        
        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyStr, keyStr.count, bytes, bytes.count, &hash)
        
        return hash
    }
    
    // Takes a string representation of a hexadecimal number
    func hexDigest() -> String {
        return digest().map { $0.toHex() }.reduce("", combine: +)
    }
}
