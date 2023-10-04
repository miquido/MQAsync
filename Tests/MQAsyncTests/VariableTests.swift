import MQAsync
import MQAsyncTest

final class VariableTests: TestCase {

	// MARK: - Correctness

	func test_value_returnsImmediately() {
		verifyIf(
			Variable<Int>(42).value,
			isEqual: 42
		)
	}

	func test_value_isTheSameAsInState() {
		let variable: Variable<Int> = .init(42)
		verifyIf(
			try variable.state.value,
			isEqual: variable.value
		)
	}

	func test_generation_isTheSameAsInState() {
		let variable: Variable<Int> = .init(42)
		verifyIf(
			variable.state.generation,
			isEqual: variable.generation
		)
	}

	func test_value_updates_afterUpdate() {
		let variable: Variable<Int> = .init(42)
		variable.value = 99
		verifyIf(
			variable.value,
			isEqual: 99
		)
		variable.value += 1
		verifyIf(
			variable.value,
			isEqual: 100
		)
		variable.mutate { value in
			value = 0
		}
		verifyIf(
			variable.value,
			isEqual: 0
		)
	}

	func test_generation_isInitializedInitially() {
		let variable: Variable<Int> = .init(42)
		verifyIf(
			variable.generation,
			isGreaterThan: .uninitialized
		)
	}

	func test_generation_grows_afterUpdate() {
		let variable: Variable<Int> = .init(42)
		let firstGeneration: StateGeneration = variable.generation
		variable.mutate { value in
			value = 99
		}
		let secondGeneration: StateGeneration = variable.generation
		verifyIf(
			secondGeneration,
			isGreaterThan: firstGeneration
		)
		variable.value += 1
		let thirdGeneration: StateGeneration = variable.generation
		verifyIf(
			thirdGeneration,
			isGreaterThan: secondGeneration
		)
		variable.mutate { value in
			value = 0
		}
		let fourthGeneration: StateGeneration = variable.generation
		verifyIf(
			fourthGeneration,
			isGreaterThan: thirdGeneration
		)
	}

	func test_waitForUpdate_waitsForNextUpdate_whenRequestedWithCurrentGeneration() async throws {
		let variable: Variable<Int> = .init(42)
		let initialGeneration: StateGeneration = variable.generation
		try await withSerialTaskExecutor {
			Task.detached { variable.value = 11 }
			try await variable.waitForUpdate(from: initialGeneration)
			let updated: Int = variable.value
			await verifyIf(
				variable.generation,
				isGreaterThan: initialGeneration
			)

			await verifyIf(
				updated,
				isEqual: 11
			)
		}
	}

	func test_waitForUpdate_resumesAllWaitingFutures_whenUpdated() async throws {
		let variable: Variable<Int> = .init(42)
		let initialGeneration: StateGeneration = variable.generation
		try await withSerialTaskExecutor {
			try await withThrowingTaskGroup(of: Void.self) { group in
				for _ in 0 ..< 10 {
					group.addTask {
						try await variable.waitForUpdate(from: initialGeneration)
					}
				}
				Task.detached { variable.value = 11 }
				try await group.waitForAll()
			}
		}
		await verifyIf(
			variable.generation,
			isGreaterThan: initialGeneration
		)
		await verifyIf(
			variable.value,
			isEqual: 11
		)
	}

	func test_waitForUpdate_throwsCancelled_whenWaitingTaskIsCancelled() async throws {
		let variable: Variable<Int> = .init(42)
		try await withSerialTaskExecutor {
			let task: Task<Void, Error> = .detached {
				try await variable.waitForUpdate()
			}
			Task.detached { task.cancel() }
			await verifyIf(
				try await task.value,
				throws: CancellationError.self
			)
		}
	}

	func test_assign_executesWithoutIssues_concurrently() async throws {
		let variable: Variable<Int> = .init(42)
		await withTaskGroup(of: Void.self) { group in
			for _ in 0 ..< 10 {
				group.addTask {
					for i in 0 ..< 1_000 {
						variable.value = i
					}
				}
			}
			await group.waitForAll()
		}
	}

	func test_mutate_executesWithoutIssues_concurrently() async throws {
		let variable: Variable<Int> = .init(42)
		await withTaskGroup(of: Void.self) { group in
			for _ in 0 ..< 10 {
				group.addTask {
					for i in 0 ..< 1_000 {
						variable.mutate { $0 = i }
					}
				}
			}
			await group.waitForAll()
		}
	}

	func test_mutation_executesWithoutIssues_concurrently() async throws {
		let variable: Variable<Int> = .init(42)
		await withTaskGroup(of: Void.self) { group in
			for _ in 0 ..< 10 {
				group.addTask {
					for i in 0 ..< 1_000 {
						variable.value += i
					}
				}
			}
			await group.waitForAll()
		}
	}

	func test_value_executesWithoutIssues_concurrently() async throws {
		let variable: Variable<Int> = .init(42)
		await withTaskGroup(of: Void.self) { group in
			for _ in 0 ..< 10 {
				group.addTask {
					for _ in 0 ..< 1_000 {
						_ = variable.value
					}
				}
			}
			await group.waitForAll()
		}
	}

	func test_continuousAccess_executesWithoutIssues_concurrently() async throws {
		let variable: Variable<Int> = .init(42)
		await withTaskGroup(of: Void.self) { group in
			for i in 0 ..< 20 {
				if i.isMultiple(of: 2) {
					group.addTask {
						for j in 0 ..< 1_000 {
							variable.value += j
						}
					}
				}
				else {
					group.addTask {
						for _ in 0 ..< 1_000 {
							_ = variable.value
						}
					}
				}
			}
			await group.waitForAll()
		}
	}

	// MARK: - Performance

	func test_value_performance_withoutUpdates() {
		let variable: Variable<Int> = .init(0)
		verifyPerformance {
			for _ in 0 ..< 1_000_000 {
				let _ = variable.value
			}
		}
	}

	func test_value_performance_withContinuousUpdates() {
		let variable: Variable<Int> = .init(0)
		let task: Task = .detached {
			while !Task.isCancelled {
				await Task.yield()
				variable.value = .random(in: .min ... .max)
			}
		}
		verifyPerformance {
			for _ in 0 ..< 1_000_000 {
				let _ = variable.value
			}
		}
		task.cancel()
	}

	func test_waitForUpdate_performance_withoutUpdates() {
		let variable: Variable<Int> = .init(0)
		verifyPerformance {
			for _ in 0 ..< 1_000_000 {
				try? await variable.waitForUpdate(from: .uninitialized)
			}
		}
	}

	func test_mutation_performance_withoutDellivery() {
		let variable: Variable<Int> = .init(0)
		verifyPerformance {
			for i in 0 ..< 1_000_000 {
				variable.value = i
			}
		}
	}

	func test_mutation_performance_withContinuousDellivery() {
		let variable: Variable<Int> = .init(0)
		let task: Task = .detached {
			while !Task.isCancelled {
				_ = variable.value
				await Task.yield()
				_ = try await variable.waitForUpdate()
			}
		}
		verifyPerformance {
			for i in 0 ..< 1_000_000 {
				variable.value = i
			}
		}
		task.cancel()
	}

	func test_mutate_performance_withoutDellivery() {
		let variable: Variable<Int> = .init(0)
		verifyPerformance {
			for i in 0 ..< 1_000_000 {
				variable.mutate { $0 = i }
			}
		}
	}

	func test_mutate_performance_withContinuousDellivery() {
		let variable: Variable<Int> = .init(0)
		let task: Task = .detached {
			while !Task.isCancelled {
				_ = variable.value
				await Task.yield()
				_ = try await variable.waitForUpdate()
			}
		}
		verifyPerformance {
			for i in 0 ..< 100_000 {
				variable.mutate { $0 = i }
			}
		}
		task.cancel()
	}
}
