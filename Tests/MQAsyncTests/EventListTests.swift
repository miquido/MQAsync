import MQAsync
import MQAsyncTest
import XCTest

final class EventListTests: TestCase {

	// MARK: - Correctness

	func test_nextEvent_deliversLatestEventAfterWaiting() async throws {
		enum TestEvent: EventDescription {

			typealias Payload = Int

			nonisolated static let eventList: EventList<TestEvent> = .init()
		}

		try await withSerialTaskExecutor {
			TestEvent.send(0)
			Task.detached {
				await Task.yield()
				TestEvent.send(42)
			}
			try await verifyIf(
				await TestEvent.next(),
				isEqual: 42
			)
		}
	}

	func test_subscription_nextEvent_deliversLatestEventAfterWaiting() async throws {
		enum TestEvent: EventDescription {

			typealias Payload = Int

			nonisolated static let eventList: EventList<TestEvent> = .init()
		}

		try await withSerialTaskExecutor {
			TestEvent.send(0)
			var subscription: EventSubscription = TestEvent.subscribe()
			Task.detached {
				await Task.yield()
				TestEvent.send(42)
			}
			try await verifyIf(
				await subscription.nextEvent(),
				isEqual: 42
			)
		}
	}

	func test_subscription_nextEvent_deliversLatestEventAfterSubscribing() async throws {
		enum TestEvent: EventDescription {

			typealias Payload = Int

			nonisolated static let eventList: EventList<TestEvent> = .init()
		}

		try await withSerialTaskExecutor {
			TestEvent.send(0)
			var subscription: EventSubscription = TestEvent.subscribe()
			TestEvent.send(42)
			try await verifyIf(
				await subscription.nextEvent(),
				isEqual: 42
			)
		}
	}

	func test_subscription_nextEvent_deliversAllEventsAfterSubscribing() async throws {
		enum TestEvent: EventDescription {

			typealias Payload = Int

			nonisolated static let eventList: EventList<TestEvent> = .init()
		}

		try await withSerialTaskExecutor {
			TestEvent.send(0)
			var subscription: EventSubscription = TestEvent.subscribe()
			for i in 1 ..< 100 {
				TestEvent.send(i)
			}
			for i in 1 ..< 100 {
				try await verifyIf(
					await subscription.nextEvent(),
					isEqual: i
				)
			}
		}
	}

	func test_subscription_flushEvents_skipsAllPendingEvents() async throws {
		enum TestEvent: EventDescription {

			typealias Payload = Int

			nonisolated static let eventList: EventList<TestEvent> = .init()
		}

		try await withSerialTaskExecutor {
			var subscription: EventSubscription = TestEvent.subscribe()
			for i in 1 ..< 100 {
				TestEvent.send(i)
			}
			subscription.flushEvents()
			TestEvent.send(0)
			try await verifyIf(
				await subscription.nextEvent(),
				isEqual: 0
			)
		}
	}

	func test_continuousAccess_executesWithoutIssues_concurrently() async throws {
		enum TestEvent: EventDescription {

			typealias Payload = Int

			nonisolated static let eventList: EventList<TestEvent> = .init()
		}

		await withTaskGroup(of: Void.self) { group in
			for i in 0 ..< 1_000 {
				if i.isMultiple(of: 3) {
					if i.isMultiple(of: 2) {
						group.addTask {
							var subscription: TestEvent.Subscription =
								TestEvent
								.subscribe()
							subscription.flushEvents()
						}
					}
					else {
						group.addTask {
							try? await TestEvent.subscribe { _ in }
						}
					}
				}
				else if i.isMultiple(of: 2) {
					group.addTask {
						_ = try? await TestEvent.next()
					}
				}
				else {
					group.addTask {
						var subscription: TestEvent.Subscription =
							TestEvent
							.subscribe()
						while !Task.isCancelled {
							_ = try? await subscription.nextEvent()
						}
					}
				}
			}
			await Task {
				for i in 0 ..< 10_000 {
					try await Task.sleep(nanoseconds: 100)
					TestEvent.send(i)
				}
			}
			.waitForCompletion()
			group.cancelAll()
			await group.waitForAll()
		}
	}

	func test_subscription_nextEvent_deliversAllEventsToAllSubscriptions() async throws {
		enum TestEvent: EventDescription {

			typealias Payload = Int

			nonisolated static let eventList: EventList<TestEvent> = .init()
		}

		try await withSerialTaskExecutor {
			TestEvent.send(0)
			var subscriptions: Array<TestEvent.Subscription> = .init()
			for _ in 0 ..< 100 {
				subscriptions.append(TestEvent.subscribe())
			}

			for i in 1 ..< 100 {
				TestEvent.send(i)
			}
			for var subscription in subscriptions {
				for i in 1 ..< 100 {
					try await verifyIf(
						await subscription.nextEvent(),
						isEqual: i
					)
				}
			}
		}
	}

	// MARK: - Performance

	func test_send_memoryUse_withoutSubscriptions() {
		enum TestEvent: EventDescription {

			typealias Payload = Int

			nonisolated static let eventList: EventList<TestEvent> = .init()
		}

		verifyMemoryUse {
			for i in 0 ..< 1_000_000 {
				TestEvent.send(i)
			}
		}
	}

	func test_send_performance_withoutSubscriptions() {
		enum TestEvent: EventDescription {

			typealias Payload = Int

			nonisolated static let eventList: EventList<TestEvent> = .init()
		}

		verifyPerformance {
			for i in 0 ..< 1_000_000 {
				TestEvent.send(i)
			}
		}
	}

	func test_send_memoryUse_withIdleSubscription() {
		enum TestEvent: EventDescription {

			typealias Payload = Int

			nonisolated static let eventList: EventList<TestEvent> = .init()
		}

		verifyMemoryUse {
			var subscription: TestEvent.Subscription = TestEvent.subscribe()
			for i in 0 ..< 1_000_000 {
				TestEvent.send(i)
			}
			subscription.flushEvents()
		}
	}

	func test_send_performance_withIdleSubscription() async throws {
		enum TestEvent: EventDescription {

			typealias Payload = Int

			nonisolated static let eventList: EventList<TestEvent> = .init()
		}

		var subscription: TestEvent.Subscription?
		verifyPerformance {
			subscription = TestEvent.subscribe()
			for i in 0 ..< 1_000_000 {
				TestEvent.send(i)
			}
		}
		subscription = .none
		subscription?.flushEvents()  // silence warning
	}

	func test_send_memoryUse_withActiveSubscription() async throws {
		enum TestEvent: EventDescription {

			typealias Payload = Int

			nonisolated static let eventList: EventList<TestEvent> = .init()
		}

		verifyMemoryUse {
			let subscriptionTask: Task<Void, Error> = .detached {
				try await TestEvent.subscribe { _ in }
			}

			for i in 0 ..< 1_000_000 {
				TestEvent.send(i)
			}

			subscriptionTask.cancel()
		}
	}

	func test_send_performance_withActiveSubscription() async throws {
		enum TestEvent: EventDescription {

			typealias Payload = Int

			nonisolated static let eventList: EventList<TestEvent> = .init()
		}

		var subscriptionTask: Task<Void, Error>?
		verifyPerformance {
			subscriptionTask = .detached {
				try await TestEvent.subscribe { _ in }
			}
			for i in 0 ..< 1_000_000 {
				TestEvent.send(i)
			}
		}
		subscriptionTask = .none
		subscriptionTask?.cancel()  // silence warning
	}

	func test_send_memoryUse_withMultipleIdleSubscriptions() {
		enum TestEvent: EventDescription {

			typealias Payload = Int

			nonisolated static let eventList: EventList<TestEvent> = .init()
		}

		verifyMemoryUse {
			var subscriptions: Array<TestEvent.Subscription> = .init()
			for _ in 0 ..< 1_000 {
				subscriptions.append(TestEvent.subscribe())
			}
			for i in 0 ..< 1_000_000 {
				TestEvent.send(i)
			}
			subscriptions.removeAll()  // silence warning
		}
	}

	func test_send_performance_withMultipleIdleSubscriptions() async throws {
		enum TestEvent: EventDescription {

			typealias Payload = Int

			nonisolated static let eventList: EventList<TestEvent> = .init()
		}

		var subscriptions: Array<TestEvent.Subscription> = .init()
		verifyPerformance {
			for _ in 0 ..< 1_000 {
				subscriptions.append(TestEvent.subscribe())
			}

			for i in 0 ..< 1_000_000 {
				TestEvent.send(i)
			}
		}
		subscriptions.removeAll()  // silence warning
	}

	func test_send_memoryUse_withMultipleActiveSubscriptions() async throws {
		enum TestEvent: EventDescription {

			typealias Payload = Int

			nonisolated static let eventList: EventList<TestEvent> = .init()
		}

		verifyMemoryUse {
			var subscriptions: Array<Task<Void, Error>> = .init()
			for _ in 0 ..< 1_000 {
				subscriptions.append(
					.detached {
						try await TestEvent.subscribe { _ in }
					}
				)
			}

			for i in 0 ..< 1_000_000 {
				TestEvent.send(i)
			}

			subscriptions.forEach { $0.cancel() }
		}
	}

	func test_send_performance_withMultipleActiveSubscriptions() async throws {
		enum TestEvent: EventDescription {

			typealias Payload = Int

			nonisolated static let eventList: EventList<TestEvent> = .init()
		}

		var subscriptions: Array<Task<Void, Error>> = .init()
		verifyPerformance {
			for _ in 0 ..< 1_000 {
				subscriptions.append(
					.detached {
						try await TestEvent.subscribe { _ in }
					}
				)
			}

			for i in 0 ..< 1_000_000 {
				TestEvent.send(i)
			}

			subscriptions.forEach { $0.cancel() }
		}
	}

	func test_sendAndConsume_memoryUse_withSubscription() async throws {
		enum TestEvent: EventDescription {

			typealias Payload = Int

			nonisolated static let eventList: EventList<TestEvent> = .init()
		}

		verifyMemoryUse {
			var subscription: TestEvent.Subscription = TestEvent.subscribe()
			for i in 0 ..< 1_000_000 {
				TestEvent.send(i)
				_ = try await subscription.nextEvent()
			}
		}
	}

	func test_sendAndConsume_performance_withSubscription() async throws {
		enum TestEvent: EventDescription {

			typealias Payload = Int

			nonisolated static let eventList: EventList<TestEvent> = .init()
		}

		verifyPerformance {
			var subscription: TestEvent.Subscription = TestEvent.subscribe()
			for i in 0 ..< 1_000_000 {
				TestEvent.send(i)
				_ = try await subscription.nextEvent()
			}
		}
	}
}
