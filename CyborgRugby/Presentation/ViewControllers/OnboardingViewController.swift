//
//  OnboardingViewController.swift
//  CyborgRugby
//
//  Premium onboarding experience for rugby scrum cap fitting
//

import UIKit

class OnboardingViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let pageControl = UIPageControl()
    private let nextButton = UIButton()
    private let skipButton = UIButton()
    
    // MARK: - Properties  
    private lazy var onboardingPages = [
        OnboardingPage(
            title: "🏉 Welcome to CyborgRugby",
            subtitle: "Professional 3D scanning for perfect scrum cap fit",
            imageName: "sportscourt",
            description: "Our AI-powered technology creates a custom-fitted scrum cap based on your unique head shape and ear dimensions."
        ),
        OnboardingPage(
            title: "🔍 How It Works",
            subtitle: "Simple 3D scanning in just a few minutes",
            imageName: "camera.viewfinder",
            description: "Using your iPhone's TrueDepth camera, we'll capture precise measurements of your head and ears for optimal protection."
        ),
        OnboardingPage(
            title: "🛡️ Professional Protection",
            subtitle: "Rugby-specific safety analysis",
            imageName: "shield.lefthalf.filled",
            description: "Our system analyzes your unique anatomy to recommend the perfect scrum cap for your playing position and style."
        ),
        OnboardingPage(
            title: "🏆 Track Your Progress",
            subtitle: "Achievements and player profile",
            imageName: "rosette",
            description: "Track your scanning progress, unlock achievements, and view your player profile with statistics and history."
        )
    ]
    
    private var pageViews: [UIView] = []
    
    private var currentPage = 0 {
        didSet {
            updateUI()
        }
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add skip button to navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Skip",
            style: .plain,
            target: self,
            action: #selector(skipButtonTapped)
        )
        
        setupScrollView()
        setupPageControl()
        setupButtons()
        setupConstraints()
        
        updateUI()
    }
    
    private func setupScrollView() {
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Create onboarding pages with memory optimization
        var previousPageView: UIView?
        pageViews.reserveCapacity(onboardingPages.count)
        
        for (index, page) in onboardingPages.enumerated() {
            let pageView = createPageView(for: page, at: index)
            pageView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(pageView)
            pageViews.append(pageView)
            
            NSLayoutConstraint.activate([
                pageView.topAnchor.constraint(equalTo: contentView.topAnchor),
                pageView.leadingAnchor.constraint(equalTo: index == 0 ? contentView.leadingAnchor : previousPageView!.trailingAnchor),
                pageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
                pageView.heightAnchor.constraint(equalTo: contentView.heightAnchor)
            ])
            
            previousPageView = pageView
        }
    }
    
    private func createPageView(for page: OnboardingPage, at index: Int) -> UIView {
        let containerView = UIView()
        
        // Icon
        let iconImageView = UIImageView()
        iconImageView.image = UIImage(systemName: page.imageName)
        iconImageView.tintColor = .systemGreen
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconImageView)
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = page.title
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = page.subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = .systemGreen
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(subtitleLabel)
        
        // Description
        let descriptionLabel = UILabel()
        descriptionLabel.text = page.description
        descriptionLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        descriptionLabel.textAlignment = .center
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(descriptionLabel)
        
        // Constraints
        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor, constant: 80),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 100),
            iconImageView.heightAnchor.constraint(equalToConstant: 100),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 30),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -30),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 30),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -30),
            
            descriptionLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            
            containerView.bottomAnchor.constraint(greaterThanOrEqualTo: descriptionLabel.bottomAnchor, constant: 50)
        ])
        
        return containerView
    }
    
    private func setupPageControl() {
        pageControl.numberOfPages = onboardingPages.count
        pageControl.currentPage = 0
        pageControl.currentPageIndicatorTintColor = .systemGreen
        pageControl.pageIndicatorTintColor = .systemGray3
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageControl)
    }
    
    private func setupButtons() {
        // Next button
        nextButton.setTitle("Next", for: .normal)
        nextButton.setTitleColor(.systemGreen, for: .normal)
        nextButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nextButton)
        
        // Skip button
        skipButton.setTitle("Skip", for: .normal)
        skipButton.setTitleColor(.systemGray, for: .normal)
        skipButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        skipButton.addTarget(self, action: #selector(skipButtonTapped), for: .touchUpInside)
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(skipButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -20),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            
            // Page control
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -20),
            
            // Buttons
            nextButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nextButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            skipButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            skipButton.centerYAnchor.constraint(equalTo: nextButton.centerYAnchor)
        ])
        
        // Set content size dynamically
        if let lastPageView = contentView.subviews.last {
            contentView.trailingAnchor.constraint(equalTo: lastPageView.trailingAnchor).isActive = true
        }
    }
    
    // MARK: - UI Updates
    
    private func updateUI() {
        pageControl.currentPage = currentPage
        nextButton.setTitle(currentPage == onboardingPages.count - 1 ? "Get Started" : "Next", for: .normal)
    }
    
    // MARK: - Actions
    
    @objc private func nextButtonTapped() {
        if currentPage < onboardingPages.count - 1 {
            currentPage += 1
            scrollToPage(currentPage)
        } else {
            // Move to main app
            presentMainViewController()
        }
    }
    
    @objc private func skipButtonTapped() {
        presentMainViewController()
    }
    
    private func scrollToPage(_ page: Int) {
        let xOffset = scrollView.bounds.width * CGFloat(page)
        scrollView.setContentOffset(CGPoint(x: xOffset, y: 0), animated: true)
    }
    
    private func presentMainViewController() {
        let mainVC = MainViewController()
        let navController = UINavigationController(rootViewController: mainVC)
        
        // Customize navigation bar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemGreen
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navController.navigationBar.standardAppearance = appearance
        navController.navigationBar.scrollEdgeAppearance = appearance
        navController.navigationBar.tintColor = .white
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = navController
            window.makeKeyAndVisible()
        }
    }
}

// MARK: - UIScrollViewDelegate

extension OnboardingViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let pageWidth = scrollView.bounds.width
        guard pageWidth > 0 else { return }
        let currentPage = Int(scrollView.contentOffset.x / pageWidth)
        self.currentPage = currentPage
    }
}

// MARK: - Data Models

struct OnboardingPage {
    let title: String
    let subtitle: String
    let imageName: String
    let description: String
}