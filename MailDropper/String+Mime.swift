//
//  String+Mime.swift
//  MimeKit
//
//  Created by Ben Gottlieb on 8/31/17.
//  Copyright © 2017 Stand Alone, inc. All rights reserved.
//
//
//  Taken from https://github.com/bengottlieb/marcel/blob/master/Source/Marcel/String%2BMime.swift, MIT licensed as of March 11, 2024

import Foundation

extension String {
    var decodedFromUTF8Wrapping: String {
        var result = self
        let utf = "=?utf-8?q?"
        let base64 = "=?utf-8?b?"
        let utfEnd = "?="
        var done = false
        var lastUpperBound: Int?
        
//        while let range = result.range(of: utf, options: .caseInsensitive),
//            let endRange = result.range(of: utfEnd, options: .caseInsensitive, range: range.upperBound..<(self.index(before: self.endIndex)), locale: nil) {

        while let range = result.range(of: utf, options: .caseInsensitive), let endRange = result.range(of: utfEnd), range.upperBound < endRange.lowerBound, !done {
            var upperBound = endRange.lowerBound
            if let lineBreak = result.range(of: "\n", options: [], range: range.upperBound..<result.endIndex, locale: nil), lineBreak.lowerBound < upperBound {
                upperBound = lineBreak.lowerBound
                done = true
            }
            let innerRange = range.upperBound..<upperBound
            let innerChunk = String(result[innerRange])
            let convertedFiller = innerChunk.convertedFromEmailHeaderField
            result = result.replacingCharacters(in: range.lowerBound..<endRange.upperBound, with: convertedFiller)
            lastUpperBound = result.distance(from: result.startIndex, to: range.lowerBound) + convertedFiller.count
        }

        while let range = result.range(of: base64, options: .caseInsensitive), let endRange = result.range(of: utfEnd), range.upperBound < endRange.lowerBound, !done {
            var upperBound = endRange.lowerBound
            if let lineBreak = result.range(of: "\n", options: [], range: range.upperBound..<result.endIndex, locale: nil), lineBreak.lowerBound < upperBound {
                upperBound = lineBreak.lowerBound
                done = true
            }
            let innerRange = range.upperBound..<upperBound
            let innerChunk = String(result[innerRange])
            guard let base64Data = Data(base64Encoded: innerChunk), let convertedFiller = String(data: base64Data, encoding: .utf8) else { continue }
            result = result.replacingCharacters(in: range.lowerBound..<endRange.upperBound, with: convertedFiller)
            lastUpperBound = result.distance(from: result.startIndex, to: range.lowerBound) + convertedFiller.count
        }

        if let endLimit = lastUpperBound {
            result = String(result[..<result.index(result.startIndex, offsetBy: endLimit)])
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var convertedFromEmailHeaderField: String {
        var result = self.replacingOccurrences(of: "_", with: " ")
        
        while let range = result.range(of: "=") {
            if range.upperBound > result.index(result.endIndex, offsetBy: -2) { break }
            let ascii = UInt8(String(result[range.upperBound..<result.index(range.upperBound, offsetBy: 2)]), radix: 16) ?? 20
            let replacement = String(UnicodeScalar(ascii))
            result = result.replacingCharacters(in: range.lowerBound..<result.index(range.upperBound, offsetBy: 2), with: replacement)
        }
        
        return result
    }
}
