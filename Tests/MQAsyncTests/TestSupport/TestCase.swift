import MQAsyncTest

@MainActor internal class TestCase: XCTestCase, AsyncTestCase {

	open func commonPrepare() {
		// to be overriden
	}

	open func commonCleanup() {
		// to be overriden
	}

	final override public class func setUp() {
		super.setUp()
	}

	public final override func setUp() {
		// noop
	}

	public final override func setUp() async throws {
		// casting to specify correct method to be called
		(super.setUp as () -> Void)()
		try await super.setUp()
		self.commonPrepare()
	}

	public final override func tearDown() {
		// noop
	}

	public final override func tearDown() async throws {
		try await super.tearDown()
		// casting to specify correct method to be called
		(super.tearDown as () -> Void)()
		self.commonCleanup()
	}
}
