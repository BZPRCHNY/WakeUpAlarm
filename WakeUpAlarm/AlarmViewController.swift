import UIKit
import AVFoundation

class AlarmViewController: UIViewController {

    var onComplete: (() -> Void)?

    private let totalProblems = 10
    private var solvedCount = 0
    private var currentProblem: MathProblem!
    private let cameraManager = CameraManager()

    // MARK: - UI

    private let progressLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 20, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let problemLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 52, weight: .black)
        label.textColor = .white
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        return label
    }()

    private let equalsLabel: UILabel = {
        let label = UILabel()
        label.text = "= ?"
        label.font = .systemFont(ofSize: 36, weight: .bold)
        label.textColor = .gray
        label.textAlignment = .center
        return label
    }()

    private let answerField: UITextField = {
        let field = UITextField()
        field.font = .monospacedDigitSystemFont(ofSize: 36, weight: .bold)
        field.textColor = .white
        field.textAlignment = .center
        field.keyboardType = .numberPad
        field.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 2
        field.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        field.attributedPlaceholder = NSAttributedString(
            string: "ответ",
            attributes: [.foregroundColor: UIColor.gray]
        )
        return field
    }()

    private let submitButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("ОТВЕТИТЬ", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .black)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 16
        return button
    }()

    private let feedbackLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    private let flashView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.alpha = 0
        return view
    }()

    // Яркость до будильника — восстановим после
    private var originalBrightness: CGFloat = 0.5

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        originalBrightness = UIScreen.main.brightness
        view.backgroundColor = UIColor(red: 0.05, green: 0.0, blue: 0.1, alpha: 1.0)
        setupUI()
        nextProblem()

        // Запуск звука будильника
        AlarmSoundPlayer.shared.startAlarm()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        answerField.becomeFirstResponder()
    }

    // Блокируем закрытие
    override var isModalInPresentation: Bool {
        get { true }
        set {}
    }

    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var prefersStatusBarHidden: Bool { true }

    // MARK: - UI Setup

    private func setupUI() {
        let stack = UIStackView(arrangedSubviews: [
            progressLabel, problemLabel, equalsLabel, answerField, submitButton, feedbackLabel
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        view.addSubview(flashView)

        flashView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),

            answerField.heightAnchor.constraint(equalToConstant: 64),
            submitButton.heightAnchor.constraint(equalToConstant: 56),

            flashView.topAnchor.constraint(equalTo: view.topAnchor),
            flashView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            flashView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            flashView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
    }

    // MARK: - Logic

    private func nextProblem() {
        currentProblem = MathProblemGenerator.generate()
        problemLabel.text = currentProblem.question
        equalsLabel.text = "= ?"
        progressLabel.text = "\(solvedCount) / \(totalProblems)"
        answerField.text = ""
        feedbackLabel.isHidden = true

        answerField.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
    }

    @objc private func submitTapped() {
        guard let text = answerField.text, let answer = Int(text) else {
            shakeField()
            return
        }

        if answer == currentProblem.answer {
            handleCorrectAnswer()
        } else {
            handleWrongAnswer()
        }
    }

    private func handleCorrectAnswer() {
        solvedCount += 1
        progressLabel.text = "\(solvedCount) / \(totalProblems)"

        feedbackLabel.text = "Правильно!"
        feedbackLabel.textColor = .systemGreen
        feedbackLabel.isHidden = false

        answerField.layer.borderColor = UIColor.systemGreen.cgColor

        if solvedCount >= totalProblems {
            // Все задачи решены — свобода!
            alarmComplete()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                self?.nextProblem()
            }
        }
    }

    private func handleWrongAnswer() {
        feedbackLabel.text = "Неправильно!"
        feedbackLabel.textColor = .systemRed
        feedbackLabel.isHidden = false

        answerField.layer.borderColor = UIColor.systemRed.cgColor
        answerField.text = ""
        shakeField()

        // 1. СЛЕПИМ — белый экран + максимальная яркость
        flashWhite()

        // 2. ФОТКАЕМ с фронталки
        cameraManager.takePhoto { [weak self] image in
            guard let image = image else { return }

            // 3. Отправляем позорное фото в Telegram
            let caption = "Не может проснуться! Неправильный ответ на задачу."
            TelegramService.shared.sendPhotoToAll(image: image, caption: caption)
        }
    }

    private func flashWhite() {
        // Яркость на максимум
        UIScreen.main.brightness = 1.0

        // Белая вспышка
        flashView.alpha = 1.0
        view.bringSubviewToFront(flashView)

        UIView.animate(withDuration: 2.0, delay: 1.0, options: [], animations: {
            self.flashView.alpha = 0
        }) { _ in
            // Яркость остаётся высокой — пусть мучается
        }
    }

    private func shakeField() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.5
        animation.values = [-12, 12, -10, 10, -6, 6, -3, 3, 0]
        answerField.layer.add(animation, forKey: "shake")
    }

    private func alarmComplete() {
        // Стоп звук
        AlarmSoundPlayer.shared.stopAlarm()

        // Восстанавливаем яркость
        UIScreen.main.brightness = originalBrightness

        // Поздравление
        problemLabel.text = "Доброе утро!"
        equalsLabel.text = "Все задачи решены"
        answerField.isHidden = true
        submitButton.isHidden = true
        feedbackLabel.isHidden = true
        progressLabel.text = "\(totalProblems) / \(totalProblems)"

        // Закрываем через 3 секунды
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.dismiss(animated: true) {
                self?.onComplete?()
            }
        }
    }
}
