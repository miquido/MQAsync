import struct Atomics.AtomicStoreOrdering
import protocol Atomics.AtomicValue
import struct Atomics.UnsafeAtomic
import func os.mach_continuous_time

public struct StateGeneration: RawRepresentable, AtomicValue {

	public static let uninitialized: Self = .init(rawValue: 0)

	@_transparent
	public static func next() -> StateGeneration {
		// clock that increments monotonically in CPU ticks
		StateGeneration(rawValue: mach_continuous_time())
	}

	public typealias RawValue = UInt64

	public let rawValue: RawValue

	@_transparent
	public init(
		rawValue: consuming RawValue
	) {
		self.rawValue = rawValue
	}
}

extension StateGeneration: Sendable {}

extension StateGeneration: Equatable {

	@_transparent public static func == (
		_ lhs: StateGeneration,
		_ rhs: StateGeneration
	) -> Bool {
		lhs.rawValue == rhs.rawValue
	}

	@_transparent public static func != (
		_ lhs: StateGeneration,
		_ rhs: StateGeneration
	) -> Bool {
		lhs.rawValue != rhs.rawValue
	}
}

extension StateGeneration: Hashable {

	@_transparent public func hash(
		into hasher: inout Hasher
	) {
		hasher.combine(self.rawValue)
	}
}

extension StateGeneration: Comparable {

	@_transparent public static func < (
		_ lhs: StateGeneration,
		_ rhs: StateGeneration
	) -> Bool {
		lhs.rawValue < rhs.rawValue
	}

	@_transparent public static func <= (
		_ lhs: StateGeneration,
		_ rhs: StateGeneration
	) -> Bool {
		lhs.rawValue <= rhs.rawValue
	}

	@_transparent public static func > (
		_ lhs: StateGeneration,
		_ rhs: StateGeneration
	) -> Bool {
		lhs.rawValue > rhs.rawValue
	}

	@_transparent public static func >= (
		_ lhs: StateGeneration,
		_ rhs: StateGeneration
	) -> Bool {
		lhs.rawValue >= rhs.rawValue
	}
}

@usableFromInline internal typealias AtomicStateGeneration = UnsafeAtomic<StateGeneration>

extension AtomicStateGeneration {

	@_transparent @usableFromInline internal func current() -> StateGeneration {
		self.load(ordering: .acquiring)
	}

	@_transparent @usableFromInline internal func update() {
		self.store(.next(), ordering: .releasing)
	}

	@_transparent @usableFromInline internal func update(
		to generation: consuming StateGeneration
	) {
		self.store(generation, ordering: .releasing)
	}
}
