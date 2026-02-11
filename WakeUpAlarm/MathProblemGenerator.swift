import Foundation

struct MathProblem {
    let question: String
    let answer: Int
}

final class MathProblemGenerator {

    static func generate() -> MathProblem {
        let type = Int.random(in: 0...2)

        switch type {
        case 0: // Сложение
            let a = Int.random(in: 10...99)
            let b = Int.random(in: 10...99)
            return MathProblem(question: "\(a) + \(b)", answer: a + b)

        case 1: // Вычитание (результат всегда положительный)
            let a = Int.random(in: 20...99)
            let b = Int.random(in: 1...a)
            return MathProblem(question: "\(a) − \(b)", answer: a - b)

        default: // Умножение
            let a = Int.random(in: 2...12)
            let b = Int.random(in: 2...12)
            return MathProblem(question: "\(a) × \(b)", answer: a * b)
        }
    }
}
