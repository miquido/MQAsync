import struct Atomics.UnsafeAtomic
import struct Foundation.Date
import struct Foundation.TimeInterval
import let os.CLOCK_MONOTONIC_RAW
import func os.clock_gettime_nsec_np

public typealias TimeNano = UInt64

public final class TimeVariable: @unchecked Sendable {

	public typealias Value = TimeNano

	@usableFromInline internal let atomicGeneration: AtomicStateGeneration
	@usableFromInline internal let period: TimeNano
	@usableFromInline internal let updateTime: UnsafeAtomic<TimeNano>
	@usableFromInline internal let timeNow: @Sendable () -> TimeNano
	@usableFromInline internal let wait: @Sendable (Swift.Duration) async throws -> Void

	public convenience init(
		period: consuming Swift.Duration,
		startImmediately: Bool = true
	) {
		self.init(
			period: period,
			startImmediately: startImmediately,
			wait: wait(_:),
			timeNow: timeNano
		)
	}

	public init(
		period: consuming Swift.Duration,
		startImmediately: Bool = true,
		wait: @escaping @Sendable (Swift.Duration) async throws -> Void,
		timeNow: @escaping @Sendable () -> TimeNano
	) {
		self.atomicGeneration = .create(.next())
		let (seconds, attoseconds): (seconds: Int64, attoseconds: Int64) = period.components
		// convert duration to nanoseconds
		self.period = TimeNano(
			seconds &* 1_000_000_000
				+ attoseconds / 1_000_000_000
		)
		self.timeNow = timeNow
		self.wait = wait
		self.updateTime = .create(
			startImmediately
				? self.timeNow()
				: self.timeNow() + self.period
		)
	}

	deinit {
		self.atomicGeneration.destroy()
		self.updateTime.destroy()
	}
}

extension TimeVariable: Updatable {

	public var generation: StateGeneration {
		@Sendable _read {
			let updateTime: TimeNano = self.updateTime.load(
				ordering: .acquiring
			)
			let timeNow: TimeNano = self.timeNow()

			if updateTime > timeNow {
				yield self.atomicGeneration.current()
			}
			else {
				let updatedGeneration: StateGeneration = .next()
				self.atomicGeneration.update(to: updatedGeneration)

				var nextUpdateTime: TimeNano = updateTime + self.period
				while nextUpdateTime < timeNow {
					nextUpdateTime = nextUpdateTime + self.period
				}
				self.updateTime.store(
					nextUpdateTime,
					ordering: .releasing
				)

				yield updatedGeneration
			}
		}
	}

	public var value: Value {
		@_transparent @Sendable _read {
			yield self.timeNow()
		}
	}

	public var state: MomentaryState<Value> {
		@_transparent @Sendable _read {
			yield .value(
				self.value,
				generation: self.generation
			)
		}
	}

	public func notifyOnUpdate(
		_ promise: Promise<Void>,
		from generation: StateGeneration
	) {
		guard generation >= self.atomicGeneration.current()
		else { return promise.fulfill() }

		let updateTime: TimeNano = self.updateTime.load(
			ordering: .acquiring
		)
		let timeNow: TimeNano = self.timeNow()

		if updateTime > timeNow {
			let waitNano: TimeNano = updateTime - timeNow
			let waitingTask: Task<Void, Error> = .detached { [wait, waitNano] in
				try await wait(.nanoseconds(waitNano))
				promise.fulfill()
				// ignore errors
			}
			// if promise becomes cancelled cancel the task as well
			promise.setCancelationHandler {
				waitingTask.cancel()
			}
		}
		else {
			self.atomicGeneration.update(to: .next())

			var nextUpdateTime: TimeNano = updateTime + self.period
			while nextUpdateTime < timeNow {
				nextUpdateTime = nextUpdateTime + self.period
			}
			self.updateTime.store(
				nextUpdateTime,
				ordering: .releasing
			)

			promise.fulfill()
		}
	}
}

private let clock: ContinuousClock = .continuous

@Sendable private func wait(
	_ duration: Swift.Duration
) async throws {
	try await clock.sleep(for: duration)
}

@Sendable private func timeNano() -> TimeNano {
	clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
}
