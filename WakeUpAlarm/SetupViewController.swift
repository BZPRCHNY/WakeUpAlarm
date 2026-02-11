import UIKit

class SetupViewController: UIViewController {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "WakeUp!"
        label.font = .systemFont(ofSize: 42, weight: .black)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Будильник, от которого не сбежишь"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .lightGray
        label.textAlignment = .center
        return label
    }()

    private let timePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        picker.setValue(UIColor.white, forKeyPath: "textColor")
        picker.overrideUserInterfaceStyle = .dark
        return picker
    }()

    private let setAlarmButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("УСТАНОВИТЬ БУДИЛЬНИК", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = .systemGreen
        button.layer.cornerRadius = 16
        return button
    }()

    private let instructionLabel: UILabel = {
        let label = UILabel()
        label.text = """
        Как использовать:
        1. Выбери время будильника
        2. Нажми "Установить"
        3. Включи Guided Access (тройной клик боковой кнопки)
        4. Положи телефон и спи

        Guided Access не даст выйти из приложения!

        Настройка Guided Access:
        Настройки → Универсальный доступ → Экскурсия → Включить
        """
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .gray
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .systemOrange
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    private var alarmTimer: Timer?
    private var alarmDate: Date?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupUI()
    }

    private func setupUI() {
        let stack = UIStackView(arrangedSubviews: [
            titleLabel, subtitleLabel, timePicker, setAlarmButton, statusLabel, instructionLabel
        ])
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),

            setAlarmButton.heightAnchor.constraint(equalToConstant: 56),
        ])

        setAlarmButton.addTarget(self, action: #selector(setAlarmTapped), for: .touchUpInside)
    }

    @objc private func setAlarmTapped() {
        // Вычисляем время до будильника
        let now = Date()
        let calendar = Calendar.current

        var alarmComponents = calendar.dateComponents([.hour, .minute], from: timePicker.date)
        alarmComponents.second = 0

        var targetDate = calendar.nextDate(
            after: now,
            matching: alarmComponents,
            matchingPolicy: .nextTime
        ) ?? timePicker.date

        // Если время уже прошло сегодня — ставим на завтра
        if targetDate <= now {
            targetDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
        }

        self.alarmDate = targetDate

        let timeInterval = targetDate.timeIntervalSince(now)
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60

        statusLabel.text = "Будильник через \(hours)ч \(minutes)мин"
        statusLabel.isHidden = false

        setAlarmButton.setTitle("БУДИЛЬНИК УСТАНОВЛЕН", for: .normal)
        setAlarmButton.backgroundColor = .systemOrange
        setAlarmButton.isEnabled = false

        // Запускаем тихий фоновый звук чтобы приложение не убивалось системой
        AlarmSoundPlayer.shared.startSilentBackground()

        // Таймер на время будильника
        alarmTimer?.invalidate()
        alarmTimer = Timer.scheduledTimer(
            timeInterval: timeInterval,
            target: self,
            selector: #selector(alarmFired),
            userInfo: nil,
            repeats: false
        )

        // Обновление статуса каждую минуту
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] timer in
            guard let self = self, let alarmDate = self.alarmDate else {
                timer.invalidate()
                return
            }
            let remaining = alarmDate.timeIntervalSince(Date())
            if remaining <= 0 {
                timer.invalidate()
                return
            }
            let h = Int(remaining) / 3600
            let m = (Int(remaining) % 3600) / 60
            self.statusLabel.text = "Будильник через \(h)ч \(m)мин"
        }
    }

    @objc private func alarmFired() {
        // Останавливаем тихий фон
        AlarmSoundPlayer.shared.stopSilentBackground()

        // Показываем экран будильника
        let alarmVC = AlarmViewController()
        alarmVC.modalPresentationStyle = .fullScreen
        alarmVC.modalTransitionStyle = .crossDissolve
        alarmVC.onComplete = { [weak self] in
            self?.resetUI()
        }
        present(alarmVC, animated: true)
    }

    private func resetUI() {
        setAlarmButton.setTitle("УСТАНОВИТЬ БУДИЛЬНИК", for: .normal)
        setAlarmButton.backgroundColor = .systemGreen
        setAlarmButton.isEnabled = true
        statusLabel.isHidden = true
        alarmDate = nil
    }
}
