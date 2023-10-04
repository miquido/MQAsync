import XCTest

@MainActor public protocol AsyncTestCase: XCTestCase {}

extension AsyncTestCase {

	@_transparent public nonisolated func verifyPerformance(
		iterationCount: Int = 10,
		@_inheritActorContext _ execution: () throws -> Void
	) {
		let options: XCTMeasureOptions = .default
		options.iterationCount = iterationCount
		measure(metrics: [XCTClockMetric()], options: options) {
			try? execution()
		}
	}

	@_disfavoredOverload
	@_transparent public func verifyPerformance(
		iterationCount: Int = 10,
		@_implicitSelfCapture _ execution: @escaping @Sendable () async throws -> Void
	) {
		let options: XCTMeasureOptions = .default
		options.iterationCount = iterationCount
		measure(metrics: [XCTClockMetric()], options: options) {
			let expectation: XCTestExpectation = expectation(description: "Finished")
			Task.detached { () -> Void in
				try? await execution()
				expectation.fulfill()
			}
			wait(for: [expectation])
		}
	}
}

extension AsyncTestCase {

	@_transparent public nonisolated func verifyMemoryUse(
		iterationCount: Int = 2,
		@_inheritActorContext _ execution: () throws -> Void
	) {
		let options: XCTMeasureOptions = .default
		options.iterationCount = iterationCount
		measure(metrics: [XCTMemoryMetric()], options: options) {
			try? execution()
		}
	}

	@_disfavoredOverload
	@_transparent public func verifyMemoryUse(
		iterationCount: Int = 2,
		@_implicitSelfCapture _ execution: @escaping @Sendable () async throws -> Void
	) {
		let options: XCTMeasureOptions = .default
		options.iterationCount = iterationCount
		measure(metrics: [XCTMemoryMetric()], options: options) {
			let expectation: XCTestExpectation = expectation(description: "Finished")
			Task.detached { () -> Void in
				try? await execution()
				expectation.fulfill()
			}
			wait(for: [expectation])
		}
	}
}

extension AsyncTestCase {

	@_transparent @Sendable public nonisolated func verificationFailure(
		@_inheritActorContext _ message: @autoclosure () -> String,
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	) {
		XCTFail(
			message(),
			file: file,
			line: line
		)
	}

	@_transparent @Sendable public nonisolated func verify(
		@_inheritActorContext _ expression: @autoclosure () throws -> Bool?,
		@_inheritActorContext _ message: @autoclosure () -> String,
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	) {
		do {
			let result: Bool = try expression() ?? true
			XCTAssert(
				result,
				message(),
				file: file,
				line: line
			)
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}

	@_disfavoredOverload
	@_transparent @Sendable public func verify(
		@_inheritActorContext _ expression: @autoclosure () async throws -> Bool?,
		@_inheritActorContext _ message: @autoclosure () -> String,
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	) async {
		do {
			let result: Bool = try await expression() ?? true
			XCTAssert(
				result,
				message(),
				file: file,
				line: line
			)
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}
}

extension AsyncTestCase {

	@_transparent @Sendable public nonisolated func verifyIf<Expected>(
		@_inheritActorContext _ expression: @autoclosure () throws -> Expected?,
		isEqual expected: Expected,
		@_inheritActorContext _ message: @autoclosure () -> String = "Values are not equal!",
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	)
	where Expected: Equatable {
		do {
			let result: Expected? = try expression()
			XCTAssertEqual(
				result,
				expected,
				message(),
				file: file,
				line: line
			)
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}

	@_disfavoredOverload
	@_transparent @Sendable public func verifyIf<Expected>(
		@_inheritActorContext _ expression: @autoclosure () async throws -> Expected?,
		isEqual expected: Expected,
		@_inheritActorContext _ message: @autoclosure () -> String = "Values are not equal!",
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	) async
	where Expected: Equatable {
		do {
			let result: Expected? = try await expression()
			XCTAssertEqual(
				result,
				expected,
				message(),
				file: file,
				line: line
			)
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}

	@_transparent @Sendable public nonisolated func verifyIf<Expected>(
		@_inheritActorContext _ expression: @autoclosure () throws -> Expected?,
		isNotEqual expected: Expected,
		@_inheritActorContext _ message: @autoclosure () -> String = "Values are equal!",
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	)
	where Expected: Equatable {
		do {
			let result: Expected? = try expression()
			XCTAssertNotEqual(
				result,
				expected,
				message(),
				file: file,
				line: line
			)
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}

	@_disfavoredOverload
	@_transparent @Sendable public func verifyIf<Expected>(
		@_inheritActorContext _ expression: @autoclosure () async throws -> Expected?,
		isNotEqual expected: Expected,
		@_inheritActorContext _ message: @autoclosure () -> String = "Values are equal!",
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	) async
	where Expected: Equatable {
		do {
			let result: Expected? = try await expression()
			XCTAssertNotEqual(
				result,
				expected,
				message(),
				file: file,
				line: line
			)
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}
}

extension AsyncTestCase {

	@_transparent @Sendable public nonisolated func verifyIf<Expected>(
		@_inheritActorContext _ expression: @autoclosure () throws -> Expected,
		isGreaterThan expected: Expected,
		@_inheritActorContext _ message: @autoclosure () -> String = "Value is less than or equal!",
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	)
	where Expected: Comparable {
		do {
			let result: Expected = try expression()
			XCTAssertGreaterThan(
				result,
				expected,
				message(),
				file: file,
				line: line
			)
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}

	@_disfavoredOverload
	@_transparent @Sendable public func verifyIf<Expected>(
		@_inheritActorContext _ expression: @autoclosure () async throws -> Expected,
		isGreaterThan expected: Expected,
		@_inheritActorContext _ message: @autoclosure () -> String = "Value is less than or equal!",
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	) async
	where Expected: Comparable {
		do {
			let result: Expected = try await expression()
			XCTAssertGreaterThan(
				result,
				expected,
				message(),
				file: file,
				line: line
			)
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}

	@_transparent @Sendable public nonisolated func verifyIf<Expected>(
		@_inheritActorContext _ expression: @autoclosure () throws -> Expected,
		isGreaterThanOrEqual expected: Expected,
		@_inheritActorContext _ message: @autoclosure () -> String = "Value is less than!",
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	)
	where Expected: Comparable {
		do {
			let result: Expected = try expression()
			XCTAssertGreaterThanOrEqual(
				result,
				expected,
				message(),
				file: file,
				line: line
			)
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}

	@_disfavoredOverload
	@_transparent @Sendable public func verifyIf<Expected>(
		@_inheritActorContext _ expression: @autoclosure () async throws -> Expected,
		isGreaterThanOrEqual expected: Expected,
		@_inheritActorContext _ message: @autoclosure () -> String = "Value is less than!",
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	) async
	where Expected: Comparable {
		do {
			let result: Expected = try await expression()
			XCTAssertGreaterThanOrEqual(
				result,
				expected,
				message(),
				file: file,
				line: line
			)
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}

	@_transparent @Sendable public nonisolated func verifyIf<Expected>(
		@_inheritActorContext _ expression: @autoclosure () throws -> Expected,
		isLessThan expected: Expected,
		@_inheritActorContext _ message: @autoclosure () -> String = "Value is greater than or equal!",
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	)
	where Expected: Comparable {
		do {
			let result: Expected = try expression()
			XCTAssertLessThan(
				result,
				expected,
				message(),
				file: file,
				line: line
			)
		}
		catch {
			XCTFail(
				message(),
				file: file,
				line: line
			)
		}
	}

	@_disfavoredOverload
	@_transparent @Sendable public func verifyIf<Expected>(
		@_inheritActorContext _ expression: @autoclosure () async throws -> Expected,
		isLessThan expected: Expected,
		@_inheritActorContext _ message: @autoclosure () -> String = "Value is greater than or equal!",
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	) async
	where Expected: Comparable {
		do {
			let result: Expected = try await expression()
			XCTAssertLessThan(
				result,
				expected,
				message(),
				file: file,
				line: line
			)
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}

	@_transparent @Sendable public nonisolated func verifyIf<Expected>(
		@_inheritActorContext _ expression: @autoclosure () throws -> Expected,
		isLessThanOrEqual expected: Expected,
		@_inheritActorContext _ message: @autoclosure () -> String = "Value is greater than!",
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	)
	where Expected: Comparable {
		do {
			let result: Expected = try expression()
			XCTAssertLessThanOrEqual(
				result,
				expected,
				message(),
				file: file,
				line: line
			)
		}
		catch {
			XCTFail(
				message(),
				file: file,
				line: line
			)
		}
	}

	@_disfavoredOverload
	@_transparent @Sendable public func verifyIf<Expected>(
		@_inheritActorContext _ expression: @autoclosure () async throws -> Expected,
		isLessThanOrEqual expected: Expected,
		@_inheritActorContext _ message: @autoclosure () -> String = "Value is greater than!",
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	) async
	where Expected: Comparable {
		do {
			let result: Expected = try await expression()
			XCTAssertLessThanOrEqual(
				result,
				expected,
				message(),
				file: file,
				line: line
			)
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}
}

extension AsyncTestCase {

	@_transparent @Sendable public nonisolated func verifyIf<Expected, Returned>(
		@_inheritActorContext _ expression: @autoclosure () throws -> Returned,
		throws expected: Expected.Type,
		@_inheritActorContext _ message: @autoclosure () -> String = "Error not thrown!",
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	)
	where Expected: Error {
		do {
			_ = try expression()
			XCTFail(
				message(),
				file: file,
				line: line
			)
		}
		catch is Expected {
			// expected
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}

	@_disfavoredOverload
	@_transparent @Sendable public func verifyIf<Expected, Returned>(
		@_inheritActorContext _ expression: @autoclosure () async throws -> Returned,
		throws expected: Expected.Type,
		@_inheritActorContext _ message: @autoclosure () -> String = "Error not thrown!",
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	) async
	where Expected: Error {
		do {
			_ = try await expression()
			XCTFail(
				message(),
				file: file,
				line: line
			)
		}
		catch is Expected {
			// expected
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}
}

extension AsyncTestCase {

	@_transparent @Sendable public nonisolated func verifyIfNotThrows<Returned>(
		@_inheritActorContext _ expression: @autoclosure () throws -> Returned,
		@_inheritActorContext _ message: @autoclosure () -> String = "Error thrown!",
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	) {
		do {
			_ = try expression()
			// expected
		}
		catch {
			XCTFail(
				message(),
				file: file,
				line: line
			)
		}
	}

	@_disfavoredOverload
	@_transparent @Sendable public func verifyIfNotThrows<Returned>(
		@_inheritActorContext _ expression: @autoclosure () async throws -> Returned,
		@_inheritActorContext _ message: @autoclosure () -> String = "Error thrown!",
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	) async {
		do {
			_ = try await expression()
			// expected
		}
		catch {
			XCTFail(
				message(),
				file: file,
				line: line
			)
		}
	}
}

extension AsyncTestCase {

	@_transparent @Sendable public nonisolated func verifyIfIsNone<Expected>(
		@_inheritActorContext _ expression: @autoclosure () throws -> Expected?,
		@_inheritActorContext _ message: @autoclosure () -> String = "Value is not none!",
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	) {
		do {
			let result: Expected? = try expression()
			XCTAssertNil(
				result,
				message(),
				file: file,
				line: line
			)
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}

	@_disfavoredOverload
	@_transparent @Sendable public func verifyIfIsNone<Expected>(
		@_inheritActorContext _ expression: @autoclosure () async throws -> Expected?,
		@_inheritActorContext _ message: @autoclosure () -> String = "Value is not none!",
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	) async
	where Expected: Equatable {
		do {
			let result: Expected? = try await expression()
			XCTAssertNil(
				result,
				message(),
				file: file,
				line: line
			)
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}
}

extension AsyncTestCase {

	@_transparent @Sendable public nonisolated func verifyIfIsNotNone<Expected>(
		@_inheritActorContext _ expression: @autoclosure () throws -> Expected?,
		@_inheritActorContext _ message: @autoclosure () -> String = "Value is none!",
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	) {
		do {
			let result: Expected? = try expression()
			XCTAssertNotNil(
				result,
				message(),
				file: file,
				line: line
			)
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}

	@_disfavoredOverload
	@_transparent @Sendable public func verifyIfIsNotNone<Expected>(
		@_inheritActorContext _ expression: @autoclosure () async throws -> Expected?,
		@_inheritActorContext _ message: @autoclosure () -> String = "Value is none!",
		_ file: StaticString = #filePath,
		_ line: UInt = #line
	) async
	where Expected: Equatable {
		do {
			let result: Expected? = try await expression()
			XCTAssertNotNil(
				result,
				message(),
				file: file,
				line: line
			)
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}
}
// based on https://github.com/pointfreeco/swift-concurrency-extras/blob/main/Sources/ConcurrencyExtras/MainSerialExecutor.swift

extension AsyncTestCase {

	@MainActor public func withSerialTaskExecutor<Returned>(
		@_implicitSelfCapture operation: @MainActor @Sendable () async throws -> Returned
	) async rethrows -> Returned {
		swift_task_enqueueGlobal_hook = mainSerialExecutor
		defer { swift_task_enqueueGlobal_hook = .none }
		return try await operation()
	}

	public nonisolated func withSerialTaskExecutor<Returned>(
		operation: () throws -> Returned
	) rethrows -> Returned {
		swift_task_enqueueGlobal_hook = mainSerialExecutor
		defer { swift_task_enqueueGlobal_hook = .none }
		return try operation()
	}
}

private typealias TaskEnqueueHook = @convention(thin) (UnownedJob, @convention(thin) (UnownedJob) -> Void) -> Void

private var swift_task_enqueueGlobal_hook: TaskEnqueueHook? {
	get { swift_task_enqueueGlobal_hook_ptr.pointee }
	set { swift_task_enqueueGlobal_hook_ptr.pointee = newValue }
}

private let swift_task_enqueueGlobal_hook_ptr: UnsafeMutablePointer<TaskEnqueueHook?> =
	dlsym(
		dlopen(nil, 0),
		"swift_task_enqueueGlobal_hook"
	)
	.assumingMemoryBound(to: TaskEnqueueHook?.self)

private func mainSerialExecutor(
	job: UnownedJob,
	_: @convention(thin) (UnownedJob) -> Void
) {
	MainActor.shared.enqueue(job)
}
