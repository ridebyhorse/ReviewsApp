import UIKit

final class ReviewsViewController: UIViewController {

    private lazy var reviewsView = makeReviewsView()
    private let viewModel: ReviewsViewModel

    init(viewModel: ReviewsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = reviewsView
        title = "Отзывы"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewModel()
        viewModel.getReviews()
    }
    
    @objc private func refreshData() {
        viewModel.beginRefresh()
    }

}

// MARK: - Private

private extension ReviewsViewController {

    func makeReviewsView() -> ReviewsView {
        let reviewsView = ReviewsView()
        reviewsView.tableView.delegate = viewModel
        reviewsView.tableView.dataSource = viewModel
        return reviewsView
    }

    func setupViewModel() {
        viewModel.onStateChange = { [weak self] state in
            self?.reviewsView.tableView.reloadData()
            if !state.isRefreshing {
                DispatchQueue.main.async { [weak self] in
                    self?.reviewsView.tableView.refreshControl?.endRefreshing()
                }
            }
        }
        
        reviewsView.tableView.refreshControl?.addTarget(
            self,
            action: #selector(refreshData),
            for: .valueChanged
        )
    }

}
