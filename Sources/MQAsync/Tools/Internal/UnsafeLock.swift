import struct os.os_unfair_lock
import func os.os_unfair_lock_lock
import func os.os_unfair_lock_unlock

@usableFromInline internal typealias UnsafeLock = UnsafeMutablePointer<os_unfair_lock>

extension UnsafeLock {

	@_transparent @usableFromInline internal static func unsafe_init() -> Self {
		let ref: UnsafeLock = .allocate(capacity: 1)
		ref.initialize(to: .init())
		return ref
	}

	@_transparent @usableFromInline internal func unsafe_deinit() {
		self.deinitialize(count: 1)
		self.deallocate()
	}

	@_transparent @usableFromInline @Sendable internal func unsafe_lock() {
		os_unfair_lock_lock(self)
	}

	@_transparent @usableFromInline @Sendable internal func unsafe_unlock() {
		os_unfair_lock_unlock(self)
	}

	@_transparent @usableFromInline @Sendable internal func unsafe_with<Returned>(
		_ execute: () throws -> Returned
	) rethrows -> Returned {
		os_unfair_lock_lock(self)
		defer { os_unfair_lock_unlock(self) }
		return try execute()
	}
}
