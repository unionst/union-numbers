import SwiftUI

struct AnimatedNumberText: View, Animatable {
    var value: Double
    let format: (Int) -> String
    
    init(_ value: Double, format: @escaping (Int) -> String = { "\($0)" }) {
        self.value = value
        self.format = format
    }
    
    init(_ value: Int, format: @escaping (Int) -> String = { "\($0)" }) {
        self.value = Double(value)
        self.format = format
    }
    
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }
    
    var body: some View {
        Text(format(Int(value)))
            .contentTransition(.numericText())
    }
}

private struct NumberCountingModifier: ViewModifier {
    let enabled: Bool
    let step: Double?
    let maxSteps: Int?
    
    func body(content: Content) -> some View {
        if enabled {
            content
                .contentTransition(.numericText())
                .animation(.default, value: content)
        } else {
            content
        }
    }
}

public extension View {
    func numberCounting(
        _ enabled: Bool = true,
        step: Double? = nil,
        maxSteps: Int? = nil
    ) -> some View {
        self.modifier(NumberCountingModifier(
            enabled: enabled,
            step: step,
            maxSteps: maxSteps
        ))
    }
}