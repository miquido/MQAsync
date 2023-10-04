# MQAsync

[![Platforms](https://img.shields.io/badge/platform-iOS%20|%20iPadOS%20|%20macOS-gray.svg?style=flat)]()
[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![SwiftVersion](https://img.shields.io/badge/Swift-5.9-brightgreen.svg)]()

## What is inside?

MQAsync is a library providing tools and extensions to work with Swift concurrency. It includes:
- `future` - safe and easy way to connect to a preconcurrency asynchronous code including task cancelation handling
- `UpdatesSource` - simply solution to ensure state correctness and propagation in asynchronous code, no reactive stuff just always latest value with few useful implementations and transformations.
- `EventList` - minimalist event bus solution allowing to deliver and reveive events never missing a one, optimized to send quickly and scale
- Task extensions allowing to wait indefinitely or wait with cancellation built in

## License

Copyright 2023 Miquido

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
