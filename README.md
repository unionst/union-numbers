# UnionNumbers

A SwiftUI library for smoothly animating numeric values with a simple modifier API.

## Requirements

- iOS 17.0+ / macOS 10.15+
- Swift 6.1+

## Installation

### Swift Package Manager

Add UnionNumbers to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/unionst/union-numbers.git", from: "0.0.1")
]
```

## Usage

Import the package in your SwiftUI file:

```swift
import UnionNumbers
```

### Using the numberCounting Modifier

Apply the `numberCounting` modifier to any Text view to enable smooth number animations:

```swift
Text("\(count)")
    .numberCounting()
    .animation(.spring(), value: count)
    .monospacedDigit()
```

## Examples

### Simple Counter

```swift
struct CounterView: View {
    @State private var count = 0
    
    var body: some View {
        VStack {
            Text("\(count)")
                .font(.system(size: 48, weight: .bold))
                .numberCounting()
                .animation(.spring(), value: count)
                .monospacedDigit()
            
            HStack {
                Button("Subtract") {
                    count -= 10
                }
                
                Button("Add") {
                    count += 10
                }
            }
        }
        .padding()
    }
}
```

### Conditional Animation

```swift
struct ConditionalAnimationView: View {
    @State private var score = 0
    @State private var animateNumbers = true
    
    var body: some View {
        VStack {
            Text("Score: \(score)")
                .numberCounting(animateNumbers)
                .animation(.default, value: score)
            
            Toggle("Animate Numbers", isOn: $animateNumbers)
                .padding()
            
            Button("Increase Score") {
                score += 100
            }
        }
    }
}
```

### With Step Values

```swift
struct SteppedCounterView: View {
    @State private var value = 0.0
    
    var body: some View {
        VStack {
            Text("\(Int(value))")
                .font(.largeTitle)
                .numberCounting(
                    true,
                    step: 5,
                    maxSteps: 20
                )
                .animation(.easeInOut, value: value)
                .monospacedDigit()
            
            Slider(value: $value, in: 0...200)
                .padding()
        }
    }
}
```

## API Reference

### numberCounting Modifier

```swift
func numberCounting(
    _ enabled: Bool = true,
    step: Double? = nil,
    maxSteps: Int? = nil
) -> some View
```

#### Parameters

- `enabled`: Whether to enable number animation (default: `true`)
- `step`: Optional step size for rounding animated values
- `maxSteps`: Optional maximum number of steps to animate

## Features

- ✨ Simple modifier-based API
- 🎯 Smooth animations between numeric values
- 🎨 Fully customizable text styling
- 🚀 Optimized for SwiftUI's animation system
- 📱 Support for iOS 17+ content transitions
- 🔢 Works with both Int and Double values

## License

MIT