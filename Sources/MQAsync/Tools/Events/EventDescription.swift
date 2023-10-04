public protocol EventDescription: Sendable {

	associatedtype Payload: Sendable = Void

	static nonisolated var eventList: EventList<Self> { @Sendable get }
}

extension EventDescription {

	public typealias Subscription = EventSubscription<Self>

	@_transparent @Sendable public nonisolated static func send(
		_ event: consuming Self.Payload
	) {
		Self.eventList.send(event)
	}

	@_transparent @Sendable public nonisolated static func send()
	where Payload == Void {
		Self.eventList.send(Void())
	}

	@_transparent @Sendable public nonisolated static func next() async throws -> Self.Payload {
		try await Self.eventList.nextEvent().payload
	}

	@_transparent @Sendable public nonisolated static func subscribe() -> EventSubscription<Self> {
		Self.eventList.subscribe()
	}

	@_transparent @Sendable public nonisolated static func subscribe(
		_ handler: @escaping @Sendable (Self.Payload) async -> Void
	) async throws {
		var subscription: EventSubscription<Self> = Self.eventList.subscribe()
		while true {
			try Task.checkCancellation()
			try await handler(subscription.nextEvent())
		}
	}
}
