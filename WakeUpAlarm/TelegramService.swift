import UIKit

final class TelegramService {

    static let shared = TelegramService()

    private let botToken = "8044813577:AAHwo3Z74btdGhwyhv2C6lXRHQWP0YTQJbA"
    private let session = URLSession.shared

    private init() {}

    /// Получает все chat_id из последних сообщений боту
    private func fetchChatIDs(completion: @escaping ([Int]) -> Void) {
        let urlString = "https://api.telegram.org/bot\(botToken)/getUpdates"
        guard let url = URL(string: urlString) else {
            print("[TG] Ошибка: неверный URL")
            completion([])
            return
        }

        session.dataTask(with: url) { data, _, error in
            if let error = error {
                print("[TG] Ошибка сети: \(error)")
                completion(Array(Self.storedChatIDs()))
                return
            }

            guard let data = data else {
                print("[TG] Нет данных")
                completion(Array(Self.storedChatIDs()))
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("[TG] Невалидный JSON")
                    completion([])
                    return
                }

                print("[TG] Ответ getUpdates: ok=\(json["ok"] ?? "nil")")

                guard let results = json["result"] as? [[String: Any]] else {
                    print("[TG] Нет result в ответе")
                    completion([])
                    return
                }

                print("[TG] Найдено \(results.count) обновлений")

                var chatIDs = Set<Int>()

                for update in results {
                    if let message = update["message"] as? [String: Any],
                       let chat = message["chat"] as? [String: Any],
                       let id = chat["id"] as? Int {
                        chatIDs.insert(id)
                        print("[TG] Найден chat_id: \(id)")
                    }
                }

                // Сохраняем найденные chat_id
                let stored = Self.storedChatIDs()
                let merged = chatIDs.union(stored)
                Self.saveChatIDs(merged)

                print("[TG] Всего chat_id для отправки: \(merged.count)")
                completion(Array(merged))
            } catch {
                print("[TG] Ошибка парсинга: \(error)")
                completion(Array(Self.storedChatIDs()))
            }
        }.resume()
    }

    /// Отправляет фото всем подписчикам бота
    func sendPhotoToAll(image: UIImage, caption: String = "") {
        fetchChatIDs { chatIDs in
            print("[TG] Отправка фото в \(chatIDs.count) чатов")

            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                print("[TG] Ошибка: не удалось конвертировать фото")
                return
            }

            for chatID in chatIDs {
                self.sendPhoto(data: imageData, chatID: chatID, caption: caption)
            }
        }
    }

    private func sendPhoto(data: Data, chatID: Int, caption: String) {
        let urlString = "https://api.telegram.org/bot\(botToken)/sendPhoto"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // chat_id
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(chatID)\r\n".data(using: .utf8)!)

        // caption
        if !caption.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"caption\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(caption)\r\n".data(using: .utf8)!)
        }

        // photo
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"shame.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)

        // end
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[TG] Ошибка отправки фото в \(chatID): \(error)")
                return
            }
            if let data = data, let result = String(data: data, encoding: .utf8) {
                print("[TG] Ответ sendPhoto для \(chatID): \(result)")
            }
        }.resume()
    }

    // MARK: - Хранение chat_id в UserDefaults

    private static let storageKey = "telegram_chat_ids"

    private static func storedChatIDs() -> Set<Int> {
        let array = UserDefaults.standard.array(forKey: storageKey) as? [Int] ?? []
        return Set(array)
    }

    private static func saveChatIDs(_ ids: Set<Int>) {
        UserDefaults.standard.set(Array(ids), forKey: storageKey)
    }
}
