import UIKit

final class TelegramService {

    static let shared = TelegramService()

    private let botToken = "8044813577:AAHwo3Z74btdGhwyhv2C6lXRHQWP0YTQJbA"
    private let session = URLSession.shared

    private init() {}

    /// Получает все chat_id из последних сообщений боту
    private func fetchChatIDs(completion: @escaping ([Int64]) -> Void) {
        let urlString = "https://api.telegram.org/bot\(botToken)/getUpdates"
        guard let url = URL(string: urlString) else {
            completion([])
            return
        }

        session.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                completion([])
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let results = json["result"] as? [[String: Any]] else {
                    completion([])
                    return
                }

                var chatIDs = Set<Int64>()

                for update in results {
                    if let message = update["message"] as? [String: Any],
                       let chat = message["chat"] as? [String: Any],
                       let id = chat["id"] as? Int64 {
                        chatIDs.insert(id)
                    }
                }

                // Сохраняем найденные chat_id
                let stored = Self.storedChatIDs()
                let merged = chatIDs.union(stored)
                Self.saveChatIDs(merged)

                completion(Array(merged))
            } catch {
                completion(Array(Self.storedChatIDs()))
            }
        }.resume()
    }

    /// Отправляет фото всем подписчикам бота
    func sendPhotoToAll(image: UIImage, caption: String = "") {
        fetchChatIDs { chatIDs in
            guard let imageData = image.jpegData(compressionQuality: 0.7) else { return }

            for chatID in chatIDs {
                self.sendPhoto(data: imageData, chatID: chatID, caption: caption)
            }
        }
    }

    private func sendPhoto(data: Data, chatID: Int64, caption: String) {
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

        session.dataTask(with: request) { _, _, _ in }.resume()
    }

    // MARK: - Хранение chat_id в UserDefaults

    private static let storageKey = "telegram_chat_ids"

    private static func storedChatIDs() -> Set<Int64> {
        let array = UserDefaults.standard.array(forKey: storageKey) as? [Int64] ?? []
        return Set(array)
    }

    private static func saveChatIDs(_ ids: Set<Int64>) {
        UserDefaults.standard.set(Array(ids), forKey: storageKey)
    }
}
