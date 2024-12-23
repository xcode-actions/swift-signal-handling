#if !canImport(SystemPackage) && !canImport(System)
import Foundation

public struct Errno : RawRepresentable, Error, Hashable, Codable {
	public let rawValue: CInt
	public init(rawValue: CInt) {
		self.rawValue = rawValue
	}
}

#endif
