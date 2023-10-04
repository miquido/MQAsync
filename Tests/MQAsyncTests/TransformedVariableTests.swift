import MQAsync
import MQAsyncTest

final class TransformedVariableTests: TestCase {

	// MARK: - Correctness

	func test_value_returnsTransformedSourceValue() async {
		let source: Variable<Int> = .init(42)
		let variable: any Updatable<String> = source.transformed { (update: MomentaryState<Int>) throws -> String in
			try String(update.value)
		}
		await verifyIf(
			try await variable.value,
			isEqual: "42"
		)
	}

	func test_value_isTheSameAsInState() async {
		let source: Variable<Int> = .init(42)
		let variable: any Updatable<String> = source.transformed { (update: MomentaryState<Int>) throws -> String in
			try String(update.value)
		}
		await verifyIf(
			try await variable.value,
			isEqual: try! variable.state.value
		)
	}

	func test_value_updates_afterSourceUpdate() async {
		let source: Variable<Int> = .init(42)
		let variable: any Updatable<String> = source.transformed { (update: MomentaryState<Int>) throws -> String in
			try String(update.value)
		}
		source.value = 99
		await verifyIf(
			try await variable.value,
			isEqual: "99"
		)
		source.value += 1
		await verifyIf(
			try await variable.value,
			isEqual: "100"
		)
		source.mutate { value in
			value = 0
		}
		await verifyIf(
			try await variable.value,
			isEqual: "0"
		)
	}

	func test_value_transform_executesWhenRequested() async {
		let source: Variable<Int> = .init(42)
		let counter: AtomicCounter = .init()
		let variable: any Updatable<String> = source.transformed { (update: MomentaryState<Int>) throws -> String in
			counter.increment()
			return try String(update.value)
		}
		await verifyIf(
			counter.value,
			isEqual: 0
		)
		source.value = 99
		await verifyIf(
			counter.value,
			isEqual: 0
		)
		source.value += 1
		await verifyIf(
			counter.value,
			isEqual: 0
		)
		source.mutate { value in
			value = 0
		}
		await verifyIf(
			try await variable.value,
			isEqual: "0"
		)
		await verifyIf(
			counter.value,
			isEqual: 1
		)
	}

	func test_generation_isEqualSourceGeneration() async {
		let source: Variable<Int> = .init(42)
		let variable: any Updatable<String> = source.transformed { (update: MomentaryState<Int>) throws -> String in
			try String(update.value)
		}
		await verifyIf(
			variable.generation,
			isEqual: source.generation
		)
		source.value = 99
		await verifyIf(
			variable.generation,
			isEqual: source.generation
		)
	}

	func test_generation_isTheSameAsInState() async {
		let source: Variable<Int> = .init(42)
		let variable: any Updatable<String> = source.transformed { (update: MomentaryState<Int>) throws -> String in
			try String(update.value)
		}
		await verifyIf(
			try await variable.state.generation,
			isEqual: variable.generation
		)
	}

	func test_generation_grows_afterSourceUpdate() async {
		let source: Variable<Int> = .init(42)
		let variable: any Updatable<String> = source.transformed { (update: MomentaryState<Int>) throws -> String in
			try String(update.value)
		}
		let firstGeneration: StateGeneration = variable.generation
		source.value = 99
		let secondGeneration: StateGeneration = variable.generation
		await verifyIf(
			secondGeneration,
			isGreaterThan: firstGeneration
		)
		source.value += 1
		let thirdGeneration: StateGeneration = variable.generation
		await verifyIf(
			thirdGeneration,
			isGreaterThan: secondGeneration
		)
		source.mutate { value in
			value = 0
		}
		let fourthGeneration: StateGeneration = variable.generation
		await verifyIf(
			fourthGeneration,
			isGreaterThan: thirdGeneration
		)
	}

	func test_update_waitsForNextUpdate_whenRequestedWithCurrentGeneration() async throws {
		let source: Variable<Int> = .init(42)
		let variable: any Updatable<String> = source.transformed { (update: MomentaryState<Int>) throws -> String in
			try String(update.value)
		}
		_ = try? await variable.state  // resolve initially to ensure waiting later
		let initialGeneration: StateGeneration = variable.generation
		try await withSerialTaskExecutor {
			Task.detached { source.value = 11 }
			try await variable.waitForUpdate(from: initialGeneration)
			let state: MomentaryState<String> = try await variable.state
			await verifyIf(
				state.generation,
				isGreaterThan: initialGeneration
			)

			await verifyIf(
				try state.value,
				isEqual: "11"
			)
		}
	}

	func test_update_resumesAllWaitingFutures_whenSourceUpdates() async throws {
		let source: Variable<Int> = .init(42)
		let variable: any Updatable<String> = source.transformed { (update: MomentaryState<Int>) throws -> String in
			try String(update.value)
		}
		_ = try? await variable.state  // resolve initially to ensure waiting later
		let initialGeneration: StateGeneration = variable.generation
		try await withSerialTaskExecutor {
			try await withThrowingTaskGroup(of: Void.self) { group in
				for _ in 0 ..< 10 {
					group.addTask {
						try await variable.waitForUpdate(from: initialGeneration)
					}
				}
				Task.detached { source.value = 11 }
				try await group.waitForAll()
			}
		}
		await verifyIf(
			variable.generation,
			isGreaterThan: initialGeneration
		)
		await verifyIf(
			try await variable.value,
			isEqual: "11"
		)
	}

	func test_update_throwsCancelled_whenWaitingTaskIsCancelled() async throws {
		let source: Variable<Int> = .init(42)
		let variable: any Updatable<String> = source.transformed { (update: MomentaryState<Int>) throws -> String in
			try String(update.value)
		}
		_ = try? await variable.state  // resolve initially to ensure waiting later
		try await withSerialTaskExecutor {
			let task: Task<Void, Error> = .detached {
				_ = try await variable.waitForUpdate()
			}
			Task.detached { task.cancel() }
			await verifyIf(
				try await task.value,
				throws: CancellationError.self
			)
		}
	}

	func test_sourceUpdates_executesWithoutIssues_concurrently() async throws {
		let source: Variable<Int> = .init(42)
		let variable: any Updatable<String> = source.transformed { (update: MomentaryState<Int>) throws -> String in
			try String(update.value)
		}
		await withTaskGroup(of: Void.self) { group in
			for _ in 0 ..< 10 {
				group.addTask {
					for i in 0 ..< 1_000 {
						source.value = i
					}
				}
			}
			await group.waitForAll()
		}
		_ = try await variable.value
	}

	func test_value_executesWithoutIssues_concurrently() async throws {
		let source: Variable<Int> = .init(42)
		let variable: any Updatable<String> = source.transformed { (update: MomentaryState<Int>) throws -> String in
			try String(update.value)
		}
		await withTaskGroup(of: Void.self) { group in
			for _ in 0 ..< 10 {
				group.addTask {
					for _ in 0 ..< 1_000 {
						_ = try? await variable.value
					}
				}
			}
			await group.waitForAll()
		}
	}

	func test_continuousAccess_executesWithoutIssues_concurrently() async throws {
		let source: Variable<Int> = .init(42)
		let variable: any Updatable<String> = source.transformed { (update: MomentaryState<Int>) throws -> String in
			try String(update.value)
		}
		await withTaskGroup(of: Void.self) { group in
			for i in 0 ..< 20 {
				if i.isMultiple(of: 2) {
					group.addTask {
						for j in 0 ..< 1_000 {
							source.value += j
						}
					}
				}
				else {
					group.addTask {
						for _ in 0 ..< 1_000 {
							_ = try? await variable.value
						}
					}
				}
			}
			await group.waitForAll()
		}
	}

	// MARK: - Performance

	func test_value_performance_withoutUpdates() async throws {
		let source: Variable<Int> = .init(42)
		let variable: any Updatable<String> =
			source
			.transformed { (update: MomentaryState<Int>) throws -> String in
				try String(update.value)
			}
		verifyPerformance {
			for _ in 0 ..< 1_000_000 {
				let _ = try await variable.value
			}
		}
	}

	func test_value_performance_withContinuousUpdates() {
		let source: Variable<Int> = .init(42)
		let variable: any Updatable<String> = source.transformed { (update: MomentaryState<Int>) throws -> String in
			try String(update.value)
		}
		let task: Task = .detached {
			while !Task.isCancelled {
				await Task.yield()
				source.value = .random(in: .min ... .max)
			}
		}
		verifyPerformance {
			for _ in 0 ..< 1_000_000 {
				let _ = try await variable.value
			}
		}
		task.cancel()
	}
}
