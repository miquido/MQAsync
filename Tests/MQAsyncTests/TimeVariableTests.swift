import MQAsync
import MQAsyncTest

final class TimeVariableTests: TestCase {

	// MARK: - Correctness

	func test_waitingTime() async throws {
		let timeNow: UnsafeSendable<TimeNano> = .init()
		timeNow.value = 0
		let requestedWait: UnsafeSendable<Swift.Duration> = .init()
		requestedWait.value = .zero
		let timeVariable: TimeVariable = .init(
			period: .nanoseconds(10_000_000),
			startImmediately: false,
			wait: { requestedWait.unwrappedValue += $0 },
			timeNow: { timeNow.unwrappedValue }
		)

		_ = try await timeVariable.waitForUpdate()

		await verifyIf(
			requestedWait.unwrappedValue,
			isGreaterThanOrEqual: .nanoseconds(10_000_000)
		)
		await verifyIf(
			requestedWait.unwrappedValue,
			isLessThan: .nanoseconds(15_000_000)
		)
		timeNow.value = 10_000_000
		requestedWait.value = .zero
		_ = try await timeVariable.waitForUpdate()
		await verifyIf(
			requestedWait.unwrappedValue,
			isGreaterThanOrEqual: .nanoseconds(10_000_000)
		)
		await verifyIf(
			requestedWait.unwrappedValue,
			isLessThan: .nanoseconds(15_000_000)
		)
		timeNow.value = 25_000_000
		requestedWait.value = .zero
		_ = try await timeVariable.waitForUpdate()
		await verifyIf(
			requestedWait.unwrappedValue,
			isGreaterThanOrEqual: .nanoseconds(5_000_000)
		)
		await verifyIf(
			requestedWait.unwrappedValue,
			isLessThan: .nanoseconds(10_000_000)
		)
		timeNow.value = 30_000_000
		requestedWait.value = .zero
		for _ in 0 ..< 10 {
			_ = try await timeVariable.waitForUpdate()
			timeNow.unwrappedValue = timeNow.unwrappedValue + 10_000_000
		}
		await verifyIf(
			requestedWait.unwrappedValue,
			isGreaterThanOrEqual: .nanoseconds(100_000_000)
		)
		await verifyIf(
			requestedWait.unwrappedValue,
			isLessThan: .nanoseconds(150_000_000)
		)
	}

	func test_generationUpdates() {
		let timeNow: UnsafeSendable<TimeNano> = .init()
		timeNow.value = 0
		let timeVariable: TimeVariable = .init(
			period: .nanoseconds(100),
			wait: { _ in },
			timeNow: { timeNow.unwrappedValue }
		)
		let initialGeneration: StateGeneration = timeVariable.generation
		verifyIf(
			timeVariable.generation,
			isEqual: initialGeneration
		)
		verifyIf(
			timeVariable.generation,
			isEqual: initialGeneration
		)
		verifyIf(
			timeVariable.generation,
			isEqual: initialGeneration
		)
		timeNow.value = 50
		verifyIf(
			timeVariable.generation,
			isEqual: initialGeneration
		)
		timeNow.value = 100
		let updatedGeneration: StateGeneration = timeVariable.generation
		verifyIf(
			updatedGeneration,
			isGreaterThan: initialGeneration
		)
		timeNow.value = 150
		verifyIf(
			timeVariable.generation,
			isEqual: updatedGeneration
		)
		timeNow.value = 200
		verifyIf(
			timeVariable.generation,
			isGreaterThan: updatedGeneration
		)
	}
}
