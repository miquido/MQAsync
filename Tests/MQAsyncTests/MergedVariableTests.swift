import MQAsync
import MQAsyncTest

final class MergedVariableTests: TestCase {

	// MARK: - Correctness

	func test_value_returnsMergedSourceValue() async {
		let sourceA: Variable<Int> = .init(42)
		let sourceB: Variable<Int> = .init(42)
		let variable: any Updatable<Int> = sourceA.merged(with: sourceB)
		await verifyIf(
			try await variable.value,
			isEqual: 42
		)
	}

	func test_value_isTheSameAsInState() async {
		let sourceA: Variable<Int> = .init(42)
		let sourceB: Variable<Int> = .init(42)
		let variable: any Updatable<Int> = sourceA.merged(with: sourceB)
		await verifyIf(
			try await variable.value,
			isEqual: try! variable.state.value
		)
	}

	func test_value_updates_afterSourceUpdate() async {
		let sourceA: Variable<Int> = .init(42)
		let sourceB: Variable<Int> = .init(42)
		let variable: any Updatable<Int> = sourceA.merged(with: sourceB)
		sourceA.value = 99
		await verifyIf(
			try await variable.value,
			isEqual: 99
		)
		sourceB.value += 1
		await verifyIf(
			try await variable.value,
			isEqual: 43
		)
		sourceA.mutate { value in
			value = 0
		}
		await verifyIf(
			try await variable.value,
			isEqual: 0
		)
	}

	func test_generation_isEqualHigherSourceGeneration() async {
		let sourceA: Variable<Int> = .init(42)
		let sourceB: Variable<Int> = .init(42)
		let variable: any Updatable<Int> = sourceA.merged(with: sourceB)
		await verifyIf(
			variable.generation,
			isEqual: Swift.max(
				sourceA.generation,
				sourceB.generation
			)
		)
		sourceA.value = 99
		await verifyIf(
			variable.generation,
			isEqual: Swift.max(
				sourceA.generation,
				sourceB.generation
			)
		)
	}

	func test_generation_isTheSameAsInLastUpdate() async {
		let sourceA: Variable<Int> = .init(42)
		let sourceB: Variable<Int> = .init(42)
		let variable: any Updatable<Int> = sourceA.merged(with: sourceB)
		await verifyIf(
			try await variable.state.generation,
			isEqual: variable.generation
		)
	}

	func test_generation_grows_afterEitherSourceUpdate() async {
		let sourceA: Variable<Int> = .init(42)
		let sourceB: Variable<Int> = .init(42)
		let variable: any Updatable<Int> = sourceA.merged(with: sourceB)
		let firstGeneration: StateGeneration = variable.generation
		sourceA.value = 99
		let secondGeneration: StateGeneration = variable.generation
		await verifyIf(
			secondGeneration,
			isGreaterThan: firstGeneration
		)
		sourceB.value += 1
		let thirdGeneration: StateGeneration = variable.generation
		await verifyIf(
			thirdGeneration,
			isGreaterThan: secondGeneration
		)
		sourceA.mutate { value in
			value = 0
		}
		let fourthGeneration: StateGeneration = variable.generation
		await verifyIf(
			fourthGeneration,
			isGreaterThan: thirdGeneration
		)
	}

	func test_update_waitsForEitherSourceNextUpdate_whenRequestedWithCurrentGeneration() async throws {
		let sourceA: Variable<Int> = .init(42)
		let sourceB: Variable<Int> = .init(42)
		let variable: any Updatable<Int> = sourceA.merged(with: sourceB)
		_ = try? await variable.state  // resolve initially to ensure waiting later
		let initialGeneration: StateGeneration = variable.generation
		try await withSerialTaskExecutor {
			Task.detached { sourceA.value = 11 }
			try await variable.waitForUpdate(from: initialGeneration)
			let updated: Int = try await variable.value
			await verifyIf(
				variable.generation,
				isGreaterThan: initialGeneration
			)

			await verifyIf(
				updated,
				isEqual: 11
			)

			let nextGeneration: StateGeneration = variable.generation
			Task.detached { sourceB.value = 22 }
			try await variable.waitForUpdate(from: initialGeneration)
			let updatedNext: Int = try await variable.value
			await verifyIf(
				variable.generation,
				isGreaterThan: nextGeneration
			)

			await verifyIf(
				updatedNext,
				isEqual: 22
			)
		}
	}

	func test_update_resumesAllWaitingFutures_whenEitherSourceUpdates() async throws {
		let sourceA: Variable<Int> = .init(42)
		let sourceB: Variable<Int> = .init(42)
		let variable: any Updatable<Int> = sourceA.merged(with: sourceB)
		_ = try? await variable.state  // resolve initially to ensure waiting later
		let initialGeneration: StateGeneration = variable.generation
		try await withSerialTaskExecutor {
			try await withThrowingTaskGroup(of: Void.self) { group in
				for _ in 0 ..< 10 {
					group.addTask {
						try await variable.waitForUpdate(from: initialGeneration)
					}
				}
				Task.detached { sourceA.value = 11 }
				try await group.waitForAll()
			}
		}
		await verifyIf(
			variable.generation,
			isGreaterThan: initialGeneration
		)
		await verifyIf(
			try await variable.value,
			isEqual: 11
		)
		let nextGeneration: StateGeneration = variable.generation
		try await withSerialTaskExecutor {
			try await withThrowingTaskGroup(of: Void.self) { group in
				for _ in 0 ..< 10 {
					group.addTask {
						try await variable.waitForUpdate(from: nextGeneration)
					}
				}
				Task.detached { sourceB.value = 22 }
				try await group.waitForAll()
			}
		}
		await verifyIf(
			variable.generation,
			isGreaterThan: nextGeneration
		)
		await verifyIf(
			try await variable.value,
			isEqual: 22
		)
	}

	func test_update_throwsCancelled_whenWaitingTaskIsCancelled() async throws {
		let sourceA: Variable<Int> = .init(42)
		let sourceB: Variable<Int> = .init(42)
		let variable: any Updatable<Int> = sourceA.merged(with: sourceB)
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
		let sourceA: Variable<Int> = .init(42)
		let sourceB: Variable<Int> = .init(42)
		let variable: any Updatable<Int> = sourceA.merged(with: sourceB)
		await withTaskGroup(of: Void.self) { group in
			for _ in 0 ..< 10 {
				group.addTask {
					for i in 0 ..< 1_000 {
						if i.isMultiple(of: 2) {
							sourceA.value = i
						}
						else {
							sourceB.value = i
						}
					}
				}
			}
			await group.waitForAll()
		}
		_ = try await variable.value
	}

	func test_value_executesWithoutIssues_concurrently() async throws {
		let sourceA: Variable<Int> = .init(42)
		let sourceB: Variable<Int> = .init(42)
		let variable: any Updatable<Int> = sourceA.merged(with: sourceB)
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
		_ = try await variable.value
	}

	func test_continuousAccess_executesWithoutIssues_concurrently() async throws {
		let sourceA: Variable<Int> = .init(42)
		let sourceB: Variable<Int> = .init(42)
		let variable: any Updatable<Int> = sourceA.merged(with: sourceB)
		await withTaskGroup(of: Void.self) { group in
			for i in 0 ..< 20 {
				if i.isMultiple(of: 2) {
					group.addTask {
						for j in 0 ..< 1_000 {
							if j.isMultiple(of: 2) {
								sourceA.value += j
							}
							else {
								sourceB.value += j
							}
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

	func test_value_performance_withoutUpdates() {
		let sourceA: Variable<Int> = .init(42)
		let sourceB: Variable<Int> = .init(42)
		let variable: any Updatable<Int> = sourceA.merged(with: sourceB)
		verifyPerformance {
			for _ in 0 ..< 1_000_000 {
				let _ = try await variable.value
			}
		}
	}

	func test_value_performance_withContinuousUpdates() {
		let sourceA: Variable<Int> = .init(42)
		let sourceB: Variable<Int> = .init(42)
		let variable: any Updatable<Int> = sourceA.merged(with: sourceB)
		let task: Task = .detached {
			while !Task.isCancelled {
				sourceA.value = .random(in: .min ... .max)
				await Task.yield()
				sourceB.value = .random(in: .min ... .max)
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
