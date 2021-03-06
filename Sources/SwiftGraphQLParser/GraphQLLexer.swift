//
//  GraphQLLexer.swift
//  SwiftGraphQLParser
//
//  Created by Ryan Billard on 2018-12-06.
//

import Foundation

public enum TokenType: Equatable {
	case identifier(String)
	case intValue(String)
	case floatValue(String)
	case stringValue(StringValue)
	case exclamation
	case dollarSign
	case leftParentheses
	case rightParentheses
	case ellipses
	case colon
	case equalsSign
	case atSign
	case leftSquareBracket
	case rightSquareBracket
	case leftCurlyBrace
	case rightCurlyBrace
	case pipe
	case unrecognizedInput(String)
}

public struct Token: Equatable {
	let type: TokenType
	let range: Range<String.Index>
}

public enum StringValue: Equatable {
	case blockQuote(String)
	case singleQuote(String)
}

func tokenize(_ input: String) -> [Token] {
	var scalars = Substring(input).unicodeScalars
	var tokens: [Token] = []
	while let token = scalars.readToken() {
		tokens.append(token)
	}
	if !scalars.isEmpty {
		tokens.append(
			Token(
				type: .unrecognizedInput(String(scalars)),
				range: scalars.startIndex..<scalars.endIndex
		))
	}
	return tokens
}

extension String.Index {
	func lineAndColumn(in string: String) -> (line: Int, column: Int) {
		var line = 1, column = 1
		let linebreaks = CharacterSet.newlines
		let scalars = string.unicodeScalars
		var index = scalars.startIndex
		while index < self {
			if linebreaks.contains(scalars[index]) {
				line += 1
				column = 1
			} else {
				column += 1
			}
			index = scalars.index(after: index)
		}
		return (line: line, column: column)
	}
}

private extension Substring.UnicodeScalarView {
	mutating func readToken() -> Token? {
		skipIgnoredTokens()
		let startIndex = self.startIndex
		guard let tokenType = readPunctuator()
			?? readIdentifier()
			?? readFloatValue()
			?? readIntValue()
			?? readStringValue() else {
				return nil
		}
		let endIndex = self.startIndex
		return Token(type: tokenType, range: startIndex..<endIndex)
	}
	
	mutating func skipIgnoredTokens() {
		let whitespace = CharacterSet.whitespacesAndNewlines
		while let scalar = self.first {
			if whitespace.contains(scalar) {
				self.removeFirst()
			} else if scalar == "," {
				self.removeFirst()
			} else if scalar == "#" {
				self.removeFirst()
				while let next = self.first, CharacterSet.newlines.contains(next) == false {
					self.removeFirst()
				}
			} else {
				break
			}
		}
	}
	
	mutating func readPunctuator() -> TokenType? {
		let start = self
		switch self.popFirst() {
		case "!":
			return .exclamation
		case "$":
			return .dollarSign
		case "(":
			return .leftParentheses
		case ")":
			return .rightParentheses
		case ".":
			guard self.popFirst() == ".", self.popFirst() == "." else {
				break
			}
			return .ellipses
		case ":":
			return .colon
		case "=":
			return .equalsSign
		case "@":
			return .atSign
		case "[":
			return .leftSquareBracket
		case "]":
			return .rightSquareBracket
		case "{":
			return .leftCurlyBrace
		case "}":
			return .rightCurlyBrace
		case "|":
			return .pipe
		default:
			break
		}
		self = start
		return nil
	}
	
	mutating func readIdentifier() -> TokenType? {
		let start = self
		var identifier = ""
		let validFirstCharacters = CharacterSet.letters.union(CharacterSet(charactersIn: "_"))
		if let first = self.popFirst(), validFirstCharacters.contains(first) {
			identifier.append(String(first))
			let validSecondaryCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
			while let next = self.first, validSecondaryCharacters.contains(next) {
				identifier.append(String(self.removeFirst()))
			}
			return .identifier(identifier)
		}
		self = start
		return nil
	}
	
	mutating func readIntValue() -> TokenType? {
		if let integer = readIntegerPart() {
			return .intValue(integer)
		}
		return nil
	}
	
	mutating func readIntegerPart() -> String? {
		let start = self
		var intValue = ""
		if self.first == "-", let first = self.popFirst() {
			intValue.append(String(first))
		}
		if let zero = readZeroDigit(), readNonZeroDigit() == nil {
			intValue.append(String(zero))
			return intValue
		} else if let nonZero = readNonZeroDigit() {
			intValue.append(String(nonZero))
			while let next = readDigit() {
				intValue.append(String(next))
			}
			return intValue
		}
		self = start
		return nil
	}
	
	
	mutating func readZeroDigit() -> String? {
		let start = self
		if let first = self.popFirst(), first == "0" {
			return "0"
		}
		self = start
		return nil
	}
	
	mutating func readNonZeroDigit() -> String? {
		let start = self
		if let first = self.popFirst(), CharacterSet.decimalDigits.contains(first), first != "0" {
			return String(first)
		}
		self = start
		return nil
	}
	
	mutating func readDigit() -> String? {
		let start = self
		if let first = self.popFirst(), CharacterSet.decimalDigits.contains(first) {
			return String(first)
		}
		self = start
		return nil
	}
	
	mutating func readFloatValue() -> TokenType? {
		let start = self
		
		guard let integerPart = readIntegerPart() else {
			self = start
			return nil
		}
		
		var floatValue = integerPart
		let fractionalPart = readFractionalPart()
		let exponentPart = readExponentPart()
		
		guard fractionalPart != nil || exponentPart != nil else {
			self = start
			return nil
		}
		
		if let fractionalPart = fractionalPart {
			floatValue.append(fractionalPart)
		}
		
		if let exponentPart = exponentPart {
			floatValue.append(exponentPart)
		}
		return .floatValue(floatValue)
	}
	
	mutating func readFractionalPart() -> String? {
		let start = self
		
		if let decimal = self.popFirst(), decimal == ".", let firstDigit = self.popFirst(), CharacterSet.decimalDigits.contains(firstDigit) {
			var fractionalPart = ""
			fractionalPart.append(String(decimal))
			fractionalPart.append(String(firstDigit))
			while let next = self.readDigit() {
				fractionalPart.append(next)
			}
			return fractionalPart
		}
		
		self = start
		return nil
	}
	
	mutating func readExponentPart() -> String? {
		let start = self
		let exponentIndicators = CharacterSet.init(charactersIn: "eE")
		guard let exponentIndicator = self.popFirst(), exponentIndicators.contains(exponentIndicator) else {
			self = start
			return nil
		}
		var exponentPart = ""
		exponentPart.append(String(exponentIndicator))
		
		if let sign = readSign() {
			exponentPart.append(sign)
		}
		
		guard let firstDigit = self.readDigit() else {
			self = start
			return nil
		}
		
		exponentPart.append(firstDigit)
		while let next = self.readDigit() {
			exponentPart.append(next)
		}
		
		self = start
		return nil
	}
	
	mutating func readSign() -> String? {
		let start = self
		
		let signs = CharacterSet.init(charactersIn: "+-")
		if let first = self.popFirst(), signs.contains(first) {
			return String(first)
		}
		
		self = start
		return nil
	}
	
	mutating func readStringValue() -> TokenType? {
		let start = self
		
		if let _ = readBlockQuote() {
			var stringValue = ""
			
			while let _ = self.first {
				guard String(self.prefix(3)) != "\"\"\"" else {
					break
				}
				stringValue.append(String(self.removeFirst()))
			}
			
			guard let _ = readBlockQuote() else {
				self = start
				return nil
			}
			return .stringValue(.blockQuote(stringValue))
		} else if let _ = readSingleQuote() {
			var stringValue = ""
			while let next = self.first, CharacterSet.newlines.contains(next) == false && next != "\"" {
				stringValue.append(String(self.removeFirst()))
			}
			guard let _ = readSingleQuote() else {
				self = start
				return nil
			}
			return .stringValue(.singleQuote(stringValue))
		}
		
		self = start
		return nil
	}
	
	mutating func readSingleQuote() -> String? {
		let start = self
		
		if let singleQuote = self.popFirst(), singleQuote == "\"" {
			return String(singleQuote)
		}
		
		self = start
		return nil
	}
	
	mutating func readBlockQuote() -> String? {
		let start = self
		
		let blockQuote = String(self.dropFirst(3))
		if blockQuote == "\"\"\"" {
			return blockQuote
		}
		
		self = start
		return nil
	}
}
