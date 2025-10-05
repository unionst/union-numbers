import SwiftUI
import UnionNumbers

struct ContentView: View {
    @State private var amount: String = "0"
    @State private var shake = false
    @State private var min: Decimal = 5
    @State private var max: Decimal = 10
    
    private let step: Double = 1.50

    private func adjust(by delta: Double) {
        let current = Decimal(string: amount) ?? 0
        let result = current + Decimal(delta)
        amount = "\(result)"
    }
    
    var body: some View {
        VStack {
            Text("Placeholder")
                .numberCounting(amount)
                .animationStyle(
                    $amount,
                    shake: $shake,
                    min: $min,
                    max: $max
                )
                .currency(.USD)
                .font(.system(size: 50, weight: .medium), size: 50)
                .foregroundColor(
                    Color(
                        red: 0.5,
                        green: 0.5,
                        blue: 0.5
                    )
                )
                .monospacedDigit()
                .padding(.bottom, 50)
            
            HStack {
                Button("Subtract") {
                    adjust(by: -step)
                }
                
                Button("Add") {
                    adjust(by: step)
                }
            }.padding(10)
            
            Text("Min amount is $\(min)").padding(10)
            Text("Max amount is $\(max)").padding(10)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
