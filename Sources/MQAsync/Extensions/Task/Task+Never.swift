extension Task
where Failure == Never {

	/// Wait until cancelled or forever.
	@inlinable @Sendable public static func never() async throws -> Success {
		try await future { (_: Promise<Success>) in /* never fulfill */ }
	}
}
