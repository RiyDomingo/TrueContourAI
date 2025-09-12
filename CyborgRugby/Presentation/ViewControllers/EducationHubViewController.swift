//
//  EducationHubViewController.swift
//  CyborgRugby
//
//  Educational content hub for rugby safety and 3D scanning
//

import UIKit

class EducationHubViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Hero section
    private let heroView = UIView()
    private let heroImageView = UIImageView()
    private let heroTitleLabel = UILabel()
    private let heroSubtitleLabel = UILabel()
    
    // Content sections
    private let safetySectionView = UIView()
    private let safetyTitleLabel = UILabel()
    private var safetyCollectionView: UICollectionView!
    
    private let technologySectionView = UIView()
    private let technologyTitleLabel = UILabel()
    private var technologyCollectionView: UICollectionView!
    
    private let careSectionView = UIView()
    private let careTitleLabel = UILabel()
    private var careCollectionView: UICollectionView!
    
    // MARK: - Properties
    private let safetyContent = [
        EducationContent(title: "Concussion Prevention", subtitle: "How proper headgear reduces brain injury risk", imageName: "brain.head.profile"),
        EducationContent(title: "Ear Protection", subtitle: "Preventing cauliflower ear in rugby", imageName: "ear"),
        EducationContent(title: "Neck Safety", subtitle: "Protecting your cervical spine", imageName: "figure.walk")
    ]
    
    private let technologyContent = [
        EducationContent(title: "3D Scanning Tech", subtitle: "How we capture your unique head shape", imageName: "camera.viewfinder"),
        EducationContent(title: "Material Science", subtitle: "Advanced materials for maximum protection", imageName: "atom"),
        EducationContent(title: "Custom Manufacturing", subtitle: "From scan to scrum cap in 3D printing", imageName: "printer")
    ]
    
    private let careContent = [
        EducationContent(title: "Fitting Guide", subtitle: "How to properly wear your scrum cap", imageName: "figure.walk"),
        EducationContent(title: "Maintenance", subtitle: "Cleaning and caring for your scrum cap", imageName: "sparkles"),
        EducationContent(title: "When to Replace", subtitle: "Signs it's time for a new scrum cap", imageName: "arrow.trash")
    ]
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScrollView()
        setupHeroSection()
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 280, height: 120)
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        
        setupSafetySection(with: layout)
        setupTechnologySection(with: layout)
        setupCareSection(with: layout)
        setupConstraints()
    }
    
    // MARK: - UI Setup
    
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
    }
    
    private func setupHeroSection() {
        heroView.backgroundColor = .systemGreen
        heroView.layer.cornerRadius = 16
        heroView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(heroView)
        
        heroImageView.image = UIImage(systemName: "graduationcap")
        heroImageView.tintColor = .white
        heroImageView.contentMode = .scaleAspectFit
        heroImageView.translatesAutoresizingMaskIntoConstraints = false
        heroView.addSubview(heroImageView)
        
        heroTitleLabel.text = "Rugby Safety Education"
        heroTitleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        heroTitleLabel.textColor = .white
        heroTitleLabel.textAlignment = .center
        heroTitleLabel.numberOfLines = 0
        heroTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        heroView.addSubview(heroTitleLabel)
        
        heroSubtitleLabel.text = "Learn about head protection, 3D technology, and proper care"
        heroSubtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        heroSubtitleLabel.textColor = .white.withAlphaComponent(0.9)
        heroSubtitleLabel.textAlignment = .center
        heroSubtitleLabel.numberOfLines = 0
        heroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        heroView.addSubview(heroSubtitleLabel)
        
        // Hero view constraints
        NSLayoutConstraint.activate([
            heroImageView.topAnchor.constraint(equalTo: heroView.topAnchor, constant: 20),
            heroImageView.centerXAnchor.constraint(equalTo: heroView.centerXAnchor),
            heroImageView.widthAnchor.constraint(equalToConstant: 60),
            heroImageView.heightAnchor.constraint(equalToConstant: 60),
            
            heroTitleLabel.topAnchor.constraint(equalTo: heroImageView.bottomAnchor, constant: 15),
            heroTitleLabel.leadingAnchor.constraint(equalTo: heroView.leadingAnchor, constant: 20),
            heroTitleLabel.trailingAnchor.constraint(equalTo: heroView.trailingAnchor, constant: -20),
            
            heroSubtitleLabel.topAnchor.constraint(equalTo: heroTitleLabel.bottomAnchor, constant: 8),
            heroSubtitleLabel.leadingAnchor.constraint(equalTo: heroView.leadingAnchor, constant: 20),
            heroSubtitleLabel.trailingAnchor.constraint(equalTo: heroView.trailingAnchor, constant: -20),
            heroSubtitleLabel.bottomAnchor.constraint(equalTo: heroView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupSafetySection(with layout: UICollectionViewFlowLayout) {
        safetySectionView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(safetySectionView)
        
        safetyTitleLabel.text = "Safety & Injury Prevention"
        safetyTitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        safetyTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        safetySectionView.addSubview(safetyTitleLabel)
        
        safetyCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        safetyCollectionView.backgroundColor = .clear
        safetyCollectionView.translatesAutoresizingMaskIntoConstraints = false
        safetyCollectionView.delegate = self
        safetyCollectionView.dataSource = self
        safetyCollectionView.tag = 0
        safetyCollectionView.register(EducationContentCell.self, forCellWithReuseIdentifier: "EducationContentCell")
        safetySectionView.addSubview(safetyCollectionView)
        
        // Constraints
        NSLayoutConstraint.activate([
            safetyTitleLabel.topAnchor.constraint(equalTo: safetySectionView.topAnchor, constant: 20),
            safetyTitleLabel.leadingAnchor.constraint(equalTo: safetySectionView.leadingAnchor, constant: 20),
            safetyTitleLabel.trailingAnchor.constraint(equalTo: safetySectionView.trailingAnchor, constant: -20),
            
            safetyCollectionView.topAnchor.constraint(equalTo: safetyTitleLabel.bottomAnchor, constant: 15),
            safetyCollectionView.leadingAnchor.constraint(equalTo: safetySectionView.leadingAnchor),
            safetyCollectionView.trailingAnchor.constraint(equalTo: safetySectionView.trailingAnchor),
            safetyCollectionView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    private func setupTechnologySection(with layout: UICollectionViewFlowLayout) {
        technologySectionView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(technologySectionView)
        
        technologyTitleLabel.text = "3D Technology & Materials"
        technologyTitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        technologyTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        technologySectionView.addSubview(technologyTitleLabel)
        
        technologyCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        technologyCollectionView.backgroundColor = .clear
        technologyCollectionView.translatesAutoresizingMaskIntoConstraints = false
        technologyCollectionView.delegate = self
        technologyCollectionView.dataSource = self
        technologyCollectionView.tag = 1
        technologyCollectionView.register(EducationContentCell.self, forCellWithReuseIdentifier: "EducationContentCell")
        technologySectionView.addSubview(technologyCollectionView)
        
        // Constraints
        NSLayoutConstraint.activate([
            technologyTitleLabel.topAnchor.constraint(equalTo: technologySectionView.topAnchor, constant: 20),
            technologyTitleLabel.leadingAnchor.constraint(equalTo: technologySectionView.leadingAnchor, constant: 20),
            technologyTitleLabel.trailingAnchor.constraint(equalTo: technologySectionView.trailingAnchor, constant: -20),
            
            technologyCollectionView.topAnchor.constraint(equalTo: technologyTitleLabel.bottomAnchor, constant: 15),
            technologyCollectionView.leadingAnchor.constraint(equalTo: technologySectionView.leadingAnchor),
            technologyCollectionView.trailingAnchor.constraint(equalTo: technologySectionView.trailingAnchor),
            technologyCollectionView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    private func setupCareSection(with layout: UICollectionViewFlowLayout) {
        careSectionView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(careSectionView)
        
        careTitleLabel.text = "Care & Maintenance"
        careTitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        careTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        careSectionView.addSubview(careTitleLabel)
        
        careCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        careCollectionView.backgroundColor = .clear
        careCollectionView.translatesAutoresizingMaskIntoConstraints = false
        careCollectionView.delegate = self
        careCollectionView.dataSource = self
        careCollectionView.tag = 2
        careCollectionView.register(EducationContentCell.self, forCellWithReuseIdentifier: "EducationContentCell")
        careSectionView.addSubview(careCollectionView)
        
        // Constraints
        NSLayoutConstraint.activate([
            careTitleLabel.topAnchor.constraint(equalTo: careSectionView.topAnchor, constant: 20),
            careTitleLabel.leadingAnchor.constraint(equalTo: careSectionView.leadingAnchor, constant: 20),
            careTitleLabel.trailingAnchor.constraint(equalTo: careSectionView.trailingAnchor, constant: -20),
            
            careCollectionView.topAnchor.constraint(equalTo: careTitleLabel.bottomAnchor, constant: 15),
            careCollectionView.leadingAnchor.constraint(equalTo: careSectionView.leadingAnchor),
            careCollectionView.trailingAnchor.constraint(equalTo: careSectionView.trailingAnchor),
            careCollectionView.heightAnchor.constraint(equalToConstant: 200),
            careCollectionView.bottomAnchor.constraint(equalTo: careSectionView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Hero section
            heroView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            heroView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            heroView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Safety section
            safetySectionView.topAnchor.constraint(equalTo: heroView.bottomAnchor, constant: 20),
            safetySectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            safetySectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            // Technology section
            technologySectionView.topAnchor.constraint(equalTo: safetySectionView.bottomAnchor, constant: 20),
            technologySectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            technologySectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            // Care section
            careSectionView.topAnchor.constraint(equalTo: technologySectionView.bottomAnchor, constant: 20),
            careSectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            careSectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            careSectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Required Initializers
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
}

// MARK: - Actions

extension EducationHubViewController {
    @objc private func refreshContent() {
        // In a real app, this would refresh content from a server
        let alert = UIAlertController(title: "Content Refreshed", message: "Educational content has been updated.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func showProfile() {
        let profileVC = PlayerProfileViewController()
        navigationController?.pushViewController(profileVC, animated: true)
    }
}

// MARK: - UICollectionViewDataSource

extension EducationHubViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch collectionView.tag {
        case 0:
            return safetyContent.count
        case 1:
            return technologyContent.count
        case 2:
            return careContent.count
        default:
            return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EducationContentCell", for: indexPath) as! EducationContentCell
        
        switch collectionView.tag {
        case 0:
            cell.configure(with: safetyContent[indexPath.item])
        case 1:
            cell.configure(with: technologyContent[indexPath.item])
        case 2:
            cell.configure(with: careContent[indexPath.item])
        default:
            break
        }
        
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension EducationHubViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        var content: EducationContent
        
        switch collectionView.tag {
        case 0:
            content = safetyContent[indexPath.item]
        case 1:
            content = technologyContent[indexPath.item]
        case 2:
            content = careContent[indexPath.item]
        default:
            return
        }
        
        // Show content detail
        showContentDetail(content)
    }
    
    private func showContentDetail(_ content: EducationContent) {
        let detailVC = EducationDetailViewController()
        detailVC.content = content
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - Data Models

struct EducationContent {
    let title: String
    let subtitle: String
    let imageName: String
}

// MARK: - Custom Cell

class EducationContentCell: UICollectionViewCell {
    
    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // Container view
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 8
        containerView.layer.shadowOpacity = 0.1
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        // Icon image view
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .systemGreen
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconImageView)
        
        // Title label
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // Subtitle label
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(subtitleLabel)
        
        // Constraints
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 15),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            subtitleLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
    }
    
    func configure(with content: EducationContent) {
        iconImageView.image = UIImage(systemName: content.imageName)
        titleLabel.text = content.title
        subtitleLabel.text = content.subtitle
    }
}
