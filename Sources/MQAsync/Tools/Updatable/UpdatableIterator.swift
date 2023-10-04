public struct UpdatableIterator<Value>: AsyncIteratorProtocol
where Value: Sendable {

	public typealias Element = MomentaryState<Value>

	private var generation: StateGeneration
	private let nextUpdate: (StateGeneration) async throws -> Element

	internal init<Source>(
		source: Source
	) where Source: Updatable, Source.Value == Value {
		self.generation = .uninitialized
		self.nextUpdate = { [source] (generation: StateGeneration) async throws in
			try await source.waitForUpdate(from: generation)
			return try await source.state
		}
	}

	public mutating func next() async throws -> Element? {
		let element: Element = try await self.nextUpdate(self.generation)
		self.generation = element.generation
		return element
	}
}
