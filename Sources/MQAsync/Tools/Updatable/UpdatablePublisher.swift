#if canImport(Combine)

import Combine

public final class UpdatablePublisher<Value>: Publisher
where Value: Sendable {

	public typealias Output = MomentaryState<Value>
	public typealias Failure = Never

	private let subject: UpdatableSubject<Value>
	private let publisher: Publishers.Share<Publishers.Autoconnect<UpdatableSubject<Value>>>

	public convenience init<Source>(
		for source: Source
	) where Source: Updatable, Value == Source.Value {
		self.init(
			beginUpdates: { @Sendable [source] (update: (MomentaryState<Value>) -> Void) async throws in
				for try await state: MomentaryState<Value> in source {
					update(state)
				}
			}
		)
	}

	private init(
		beginUpdates: @escaping @Sendable ((MomentaryState<Value>) -> Void) async throws -> Void
	) {
		self.subject = .init(beginUpdates)
		self.publisher = self.subject
			.autoconnect()
			.share()
	}

	public func receive<S>(
		subscriber: S
	) where S: Subscriber, S.Input == Output, S.Failure == Failure {
		self.publisher
			.receive(subscriber: subscriber)
	}
}

private final class UpdatableSubject<Value>: ConnectablePublisher
where Value: Sendable {

	fileprivate typealias Output = MomentaryState<Value>
	fileprivate typealias Failure = Never

	private let beginUpdates: @Sendable ((MomentaryState<Value>) -> Void) async throws -> Void
	// could be refined to custom subscription management
	private let subject: PassthroughSubject<MomentaryState<Value>, Failure>

	fileprivate init(
		_ beginUpdates: @escaping @Sendable ((MomentaryState<Value>) -> Void) async throws -> Void
	) {
		self.subject = .init()
		self.beginUpdates = beginUpdates
	}

	fileprivate func receive<S>(
		subscriber: S
	) where S: Subscriber, S.Input == Output, S.Failure == Failure {
		self.subject
			.receive(subscriber: subscriber)
	}

	fileprivate func connect() -> Cancellable {
		let task: Task<Void, Error> = .init(
			priority: .userInitiated,
			operation: { [subject, beginUpdates] in
				try await beginUpdates(subject.send(_:))
			}
		)
		return AnyCancellable(task.cancel)
	}
}

#endif
