import UIKit

/// Класс, описывающий бизнес-логику экрана отзывов.
final class ReviewsViewModel: NSObject {

    /// Замыкание, вызываемое при изменении `state`.
    var onStateChange: ((State) -> Void)?

    private var state: State
    private let reviewsProvider: ReviewsProvider
    private let imagesProvider: ImagesProvider
    private let ratingRenderer: RatingRenderer
    private let decoder: JSONDecoder

    init(
        state: State = State(),
        reviewsProvider: ReviewsProvider = ReviewsProvider(),
        imagesProvider: ImagesProvider = ImagesProvider(),
        ratingRenderer: RatingRenderer = RatingRenderer(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.state = state
        self.reviewsProvider = reviewsProvider
        self.imagesProvider = imagesProvider
        self.ratingRenderer = ratingRenderer
        self.decoder = decoder
    }

}

// MARK: - Internal

extension ReviewsViewModel {

    typealias State = ReviewsViewModelState

    /// Метод получения отзывов.
    func getReviews() {
        guard state.shouldLoad else { return }
        state.shouldLoad = false
        reviewsProvider.getReviews(
            offset: state.offset,
            completion: { [weak self] reviews in self?.gotReviews(reviews) }
        )
    }

}

// MARK: - Private

private extension ReviewsViewModel {

    /// Метод обработки получения отзывов.
    func gotReviews(_ result: ReviewsProvider.GetReviewsResult) {
        defer {
            if state.isRefreshing {
                endRefresh()
            }
        }
        
        do {
            let data = try result.get()
            let reviews = try decoder.decode(Reviews.self, from: data)
            var avatarUrls: [UUID: String?] = [:]
            var photoUrls: [UUID: [String]] = [:]
            let newItems = reviews.items.map { review in
                let item = makeReviewItem(review)
                avatarUrls[item.id] = review.avatarUrl
                photoUrls[item.id] = review.photoUrls
                return item
            }
            state.items += newItems
            avatarUrls.forEach { avatarUrl in
                loadAvatarImage(urlString: avatarUrl.value, for: avatarUrl.key) { [weak self] in
                    self?.loadReviewPhotos(urls: photoUrls[avatarUrl.key] ?? [], for: avatarUrl.key)
                }
            }
            state.offset += state.limit
            state.shouldLoad = state.offset < reviews.count
            
            if state.shouldLoad == false {
                state.items.append(makeReviewsCountItem(reviews.count))
            }
        } catch {
            state.shouldLoad = true
        }
        
        onStateChange?(state)
    }
    
    private func loadAvatarImage(urlString: String?, for reviewId: UUID, completion: (() -> Void)? = nil) {
        imagesProvider.getImageAndCache(urlString: urlString) { [weak self] result in
            guard
                let self,
                let index = state.items.firstIndex(where: { ($0 as? ReviewItem)?.id == reviewId }),
                var item = state.items[index] as? ReviewItem
            else { return }
            
            switch result {
            case .success(let image):
                item.avatarImageView = image
            case .failure:
                item.avatarImageView = UIImage(resource: .avatarPlaceholder)
            }
            
            DispatchQueue.main.async {
                self.state.items[index] = item
                self.onStateChange?(self.state)
                completion?()
            }
        }
    }
    
    private func loadReviewPhotos(urls: [String], for reviewId: UUID) {
        imagesProvider.getImagesAndCache(urls: urls) { [weak self] result in
            guard
                let self,
                let index = state.items.firstIndex(where: { ($0 as? ReviewItem)?.id == reviewId }),
                var item = state.items[index] as? ReviewItem
            else { return }
            
            switch result {
            case .success(let photos):
                item.photos = photos
            case .failure:
                item.photos = []
            }
            
            DispatchQueue.main.async {
                self.state.items[index] = item
                self.onStateChange?(self.state)
            }
        }
    }

    /// Метод, вызываемый при нажатии на кнопку "Показать полностью...".
    /// Снимает ограничение на количество строк текста отзыва (раскрывает текст).
    func showMoreReview(with id: UUID) {
        guard
            let index = state.items.firstIndex(where: { ($0 as? ReviewItem)?.id == id }),
            var item = state.items[index] as? ReviewItem
        else { return }
        item.maxLines = .zero
        state.items[index] = item
        onStateChange?(state)
    }

}

// MARK: - Items

private extension ReviewsViewModel {

    typealias ReviewItem = ReviewCellConfig
    typealias ReviewsCountItem = ReviewsCountCellConfig

    func makeReviewItem(_ review: Review) -> ReviewItem {
        let avatarPlaceholder = UIImage(resource: .avatarPlaceholder)
        let username = (review.firstName + " " + review.lastName).attributed(font: .username)
        let ratingImageView = ratingRenderer.ratingImage(review.rating)
        let reviewText = review.text.attributed(font: .text)
        let created = review.created.attributed(font: .created, color: .created)
        let item = ReviewItem(
            avatarImageView: avatarPlaceholder,
            username: username,
            ratingImageView: ratingImageView,
            photos: [],
            reviewText: reviewText,
            created: created,
            onTapShowMore: { [weak self] id in self?.showMoreReview(with: id) }
        )
        return item
    }
    
    func makeReviewsCountItem(_ count: Int) -> ReviewsCountItem {
        let reviewsCountText = String(
            format: NSLocalizedString("Reviews", comment: "Number of reviews"),
            count
        )
        .attributed(font: .reviewCount, color: .reviewCount)
        
        let item = ReviewsCountItem(reviewsCountText: reviewsCountText)
        return item
    }

}

// MARK: - UITableViewDataSource

extension ReviewsViewModel: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        state.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let config = state.items[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: config.reuseId, for: indexPath)
        config.update(cell: cell)
        return cell
    }

}

// MARK: - UITableViewDelegate

extension ReviewsViewModel: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        state.items[indexPath.row].height(with: tableView.bounds.size)
    }

    /// Метод дозапрашивает отзывы, если до конца списка отзывов осталось два с половиной экрана по высоте.
    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        if shouldLoadNextPage(scrollView: scrollView, targetOffsetY: targetContentOffset.pointee.y) {
            getReviews()
        }
    }

    private func shouldLoadNextPage(
        scrollView: UIScrollView,
        targetOffsetY: CGFloat,
        screensToLoadNextPage: Double = 2.5
    ) -> Bool {
        let viewHeight = scrollView.bounds.height
        let contentHeight = scrollView.contentSize.height
        let triggerDistance = viewHeight * screensToLoadNextPage
        let remainingDistance = contentHeight - viewHeight - targetOffsetY
        return remainingDistance <= triggerDistance
    }

}

extension ReviewsViewModel {
    func beginRefresh() {
        state.items = []
        state.offset = 0
        state.shouldLoad = true
        state.isRefreshing = true
        
        onStateChange?(state)
        getReviews()
    }
    
    func endRefresh() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            state.isRefreshing = false
            onStateChange?(state)
        }
    }
}
