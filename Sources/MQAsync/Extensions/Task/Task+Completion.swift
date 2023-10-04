extension Task {

	/// Wait for task completion regardless of success of failure.
	@inlinable public func waitForCompletion() async {
		_ = try? await self.value
	}

	/// Wait for task completion regardless of success of failure
	/// but cancel the task if waiting becomes cancelled.
	@inlinable public func waitForCompletionWithTaskCancellation() async {
		await withTaskCancellationHandler(
			operation: {
				_ = try? await self.value
			},
			onCancel: {
				self.cancel()
			}
		)
	}
}
