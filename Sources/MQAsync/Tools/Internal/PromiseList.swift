import protocol Atomics.AtomicReference

@usableFromInline internal final class PromiseList<Value>
where Value: Sendable {

	private let promise: Promise<Value>
	private let next: PromiseList?

	@usableFromInline internal init(
		promise: consuming Promise<Value>,
		next: consuming PromiseList?
	) {
		self.promise = promise
		self.next = next
	}

	@usableFromInline @inline(__always) internal func fulfill(
		with value: Value
	) {
		self.next?.fulfill(with: value)
		self.promise.fulfill(with: value)
	}

	@usableFromInline @inline(__always) internal func cancel() {
		self.next?.cancel()
		self.promise.cancel()
	}
}

extension PromiseList: Sendable {}

extension Optional {

	@_transparent @usableFromInline internal mutating func linkOrSet<Value>(
		_ promise: consuming Promise<Value>
	) where Value: Sendable, Wrapped == PromiseList<Value> {
		self = .some(
			PromiseList(
				promise: promise,
				next: self
			)
		)
	}
}

extension PromiseList: AtomicReference {}
