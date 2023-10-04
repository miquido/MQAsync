import MQAsync
import MQAsyncTest
import XCTest

final class FutureTests: TestCase {

	// MARK: - Correctness

	func test_returnsWithValue_whenFulfilledWithValue() async throws {
		let result: Result<Int, Error>
		do {
			try await result = .success(
				future { (promise: Promise<Int>) in
					promise.fulfill(with: 42)
				}
			)
		}
		catch {
			result = .failure(error)
		}

		await verifyIf(
			try result.get(),
			isEqual: 42
		)
	}

	func test_throwsError_whenFailedWithError() async throws {
		let result: Result<Int, Error>
		do {
			try await result = .success(
				future { (promise: Promise<Int>) in
					promise.fail(with: Uninitialized.error())
				}
			)
		}
		catch {
			result = .failure(error)
		}

		await verifyIf(
			try result.get(),
			throws: Uninitialized.self
		)
	}

	func test_throwsCancellationError_whenCancelled() async throws {
		let result: Result<Int, Error>
		do {
			try await result = .success(
				future { (promise: Promise<Int>) in
					promise.cancel()
				}
			)
		}
		catch {
			result = .failure(error)
		}

		await verifyIf(
			try result.get(),
			throws: CancellationError.self
		)
	}

	func test_finishesOnce_withoutIssues() async throws {
		let result: Result<Int, Error>
		do {
			try await result = .success(
				future { (promise: Promise<Int>) in
					promise.fulfill(with: 42)
					promise.fulfill(with: 99)
					promise.fail(with: Uninitialized.error())
					promise.cancel()
					promise.fulfill(with: 1)
				}
			)
		}
		catch {
			result = .failure(error)
		}

		await verifyIf(
			try result.get(),
			isEqual: 42
		)
	}

	func test_finishes_withoutIssuesConcurrently() async throws {
		let value: Int = try await future { (promise: Promise<Int>) in
			DispatchQueue.concurrentPerform(iterations: 50) { i in
				promise.fulfill(with: i)
			}
		}
		await verify(
			(0 ..< 50).contains(value),
			"Value has to be in range"
		)
	}

	func test_throwsCancellationError_whenRunningOnCancelledTask() async throws {
		let task: Task<Int, Error> = .detached {
			try await future { (_: Promise<Int>) in }
		}
		task.cancel()

		let result: Result<Int, Error>
		do {
			try await result = .success(task.value)
		}
		catch {
			result = .failure(error)
		}

		await verifyIf(
			try result.get(),
			throws: CancellationError.self
		)
	}

	// MARK: - Performance

	func test_fulfill_performance() {
		verifyPerformance {
			for _ in 0 ..< 1_000_000 {
				try await future(of: Void.self) {
					$0.fulfill(with: Void())
				}
			}
		}
	}

	func test_cancel_performance() {
		verifyPerformance {
			let task: Task<Void, Error> = .init {
				for _ in 0 ..< 1_000_000 {
					try? await future(of: Void.self) {
						$0.cancel()
					}
				}
			}
			await task.waitForCompletion()
		}
	}

	func test_cancelled_performance() {
		verifyPerformance {
			let task: Task<Void, Error> = .init {
				for _ in 0 ..< 1_000_000 {
					try? await future(of: Void.self) { _ in }
				}
			}
			task.cancel()
			await task.waitForCompletion()
		}
	}
}
