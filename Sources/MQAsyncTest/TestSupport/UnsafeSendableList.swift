import class Atomics.ManagedAtomic

public final class UnsafeSendableList<Value>: @unchecked Sendable {

	private let pointer: UnsafeMutablePointer<Value?>
	private let capacity: Int
	private let currentIndex: ManagedAtomic<Int>

	public init(
		capacity: Int
	) {
		self.pointer = .allocate(capacity: capacity)
		self.pointer.initialize(repeating: .none, count: capacity)
		self.capacity = capacity
		self.currentIndex = .init(0)
	}

	deinit {
		self.pointer.deallocate()
	}

	@Sendable public func set(
		_ value: Value,
		at index: Int
	) {
		guard index < self.capacity
		else { return assertionFailure("Index out of bounds") }
		self.pointer.advanced(by: index).pointee = value
	}

	@Sendable public func append(
		_ value: Value
	) {
		let index: Int = self.currentIndex.loadThenWrappingIncrement(ordering: .relaxed)
		guard index < self.capacity
		else { return assertionFailure("Index out of bounds") }
		self.pointer.advanced(by: index).pointee = value
	}

	public var array: Array<Value> {
		var result: Array<Value> = .init()
		result.reserveCapacity(self.capacity)
		for i in (0 ..< self.capacity) {
			guard let value: Value = self.pointer.advanced(by: i).pointee
			else { continue }
			result.append(value)
		}
		return result
	}

	public var rawArray: Array<Value?> {
		var result: Array<Value?> = .init()
		result.reserveCapacity(self.capacity)
		for i in (0 ..< self.capacity) {
			result.append(self.pointer.advanced(by: i).pointee)
		}
		return result
	}
}
