# UnionNumbers

A SwiftUI library for smoothly animating numeric values with slot-machine style digit transitions.

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.1+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/unionst/union-numbers.git", from: "1.0.0")
]
```

## Usage

```swift
import UnionNumbers
```

### Basic

```swift
AnimatedNumber(count)
    .font(.system(size: 48, weight: .bold))
    .monospacedDigit()
```

### Currency

```swift
AnimatedNumber(price, format: .currency(code: "USD"))
    .font(.system(size: 48))
```

### With Bounds

When the value exceeds the range, it reverts and shakes with haptic feedback:

```swift
AnimatedNumber(value: $price, in: 0...1000, format: .currency(code: "USD"))
    .font(.system(size: 48))
```

### Disable Haptic Feedback

Shake always occurs, but haptic can be disabled:

```swift
AnimatedNumber(value: $price, in: 0...1000)
    .hapticFeedback(false)
```

### Full Example

```swift
struct ContentView: View {
    @State private var price = 50.0

    var body: some View {
        VStack {
            AnimatedNumber(value: $price, in: 0...100, format: .currency(code: "USD"))
                .font(.system(size: 48, weight: .bold))
                .monospacedDigit()

            HStack {
                Button("-$10") { price -= 10 }
                Button("+$10") { price += 10 }
            }

            Text("Try going below $0 or above $100")
                .foregroundStyle(.secondary)
        }
    }
}
```

## API

### Display Only

```swift
AnimatedNumber(_ value: Double)
AnimatedNumber(_ value: Double, format: FormatStyle)
```

### With Bounds Validation

```swift
AnimatedNumber(value: Binding<Double>, in: ClosedRange<Double>)
AnimatedNumber(value: Binding<Double>, in: ClosedRange<Double>, format: FormatStyle)
```

### Modifiers

```swift
.hapticFeedback(false)  // Disable haptic on bounds error (shake still occurs)
```

## License

MIT
