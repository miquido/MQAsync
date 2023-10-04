import Atomics

public struct EventList<ProcessedEvent>
where ProcessedEvent: EventDescription {

	@usableFromInline internal let futureEvent: UnsafeAtomic<FutureEvent>

	public init() {
		self.futureEvent = .create(FutureEvent())
	}
}

extension EventList: Sendable {}

extension EventList {

	@_transparent @usableFromInline @Sendable internal func send(
		_ eventPayload: consuming ProcessedEvent.Payload
	) {
		let nextEvent: FutureEvent = .init()
		let currentEvent: FutureEvent = self.futureEvent
			.exchange(
				nextEvent,
				ordering: .sequentiallyConsistent
			)
		currentEvent
			.deliver(
				eventPayload,
				with: nextEvent
			)
	}

	@_transparent @usableFromInline @Sendable internal func nextEvent() async throws -> Event {
		try await self.futureEvent
			.load(ordering: .relaxed)
			.futureEvent()
	}

	@_transparent @usableFromInline @Sendable internal func subscribe() -> EventSubscription<ProcessedEvent> {
		.init(
			futureEvent: self.futureEvent
				.load(ordering: .relaxed)
		)
	}
}

extension EventList {

	@usableFromInline internal struct Event: Sendable {

		@usableFromInline internal let payload: ProcessedEvent.Payload
		@usableFromInline internal let futureEvent: FutureEvent

		@usableFromInline internal init(
			payload: consuming ProcessedEvent.Payload,
			futureEvent: consuming FutureEvent
		) {
			self.payload = payload
			self.futureEvent = futureEvent
		}
	}

	@usableFromInline internal final class FutureEvent: @unchecked Sendable, AtomicReference {

		@usableFromInline internal let lock: UnsafeLock
		@usableFromInline internal var event: Event?
		@usableFromInline internal var waitingForUpdates: PromiseList<Event>?

		@usableFromInline internal init() {
			self.lock = .unsafe_init()
			self.event = .none
			self.waitingForUpdates = .none
		}

		deinit {
			self.lock.unsafe_deinit()
			self.waitingForUpdates?.cancel()
		}

		@usableFromInline internal var momentaryEvent: Event? {
			@Sendable @inline(__always) _read {
				self.lock.unsafe_lock()
				yield self.event
				self.lock.unsafe_unlock()
			}
		}

		@usableFromInline @inline(__always) @Sendable internal func deliver(
			_ eventPayload: consuming ProcessedEvent.Payload,
			with nextEvent: consuming FutureEvent
		) {
			let event: Event = .init(
				payload: eventPayload,
				futureEvent: nextEvent
			)
			self.lock.unsafe_lock()
			self.event = event
			let waitingForUpdates: PromiseList<Event>? = self.waitingForUpdates.take()
			self.lock.unsafe_unlock()
			waitingForUpdates?.fulfill(with: event)
		}

		@usableFromInline @inline(__always) @Sendable internal func futureEvent() async throws -> Event {
			self.lock.unsafe_lock()
			if let event: Event = self.event {
				self.lock.unsafe_unlock()
				return event
			}
			else {
				self.lock.unsafe_unlock()
				return try await future { [self] (promise: Promise<Event>) in
					self.lock.unsafe_lock()
					if let event: Event = self.event {
						self.lock.unsafe_unlock()
						return promise.fulfill(with: event)
					}
					else {
						self.waitingForUpdates.linkOrSet(promise)
						self.lock.unsafe_unlock()
					}
				}
			}
		}
	}
}
