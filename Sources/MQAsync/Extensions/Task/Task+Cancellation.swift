extension Task {

	/// Wait for task value or cancel that task if waiting
	/// becomes cancelled.
	@inlinable public var valueWithTaskCancellation: Success {
		get async throws {
			try await withTaskCancellationHandler(
				operation: {
					try await self.value
				},
				onCancel: {
					self.cancel()
				}
			)
		}
	}
}
