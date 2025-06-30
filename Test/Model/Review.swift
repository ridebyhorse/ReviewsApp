/// Модель отзыва.
struct Review: Decodable {

    /// URL аватара пользователя.
    let avatarUrl: String?
    /// Имя пользователя.
    let firstName: String
    /// Фамилия пользователя.
    let lastName: String
    /// Рейтинг.
    let rating: Int
    /// Текст отзыва.
    let text: String
    /// Время создания отзыва.
    let created: String
    /// Массив URL с фото отзыва.
    let photoUrls: [String]

    
    enum CodingKeys: String, CodingKey {
        case avatarUrl = "avatar_url"
        case firstName = "first_name"
        case lastName = "last_name"
        case rating
        case text
        case created
        case photoUrls = "photo_urls"
    }
    
}
