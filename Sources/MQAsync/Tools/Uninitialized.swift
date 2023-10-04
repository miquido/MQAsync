public struct Uninitialized: Error {

	public static func error() -> Self {
		Self()
	}
}
