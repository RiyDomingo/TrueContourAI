//
//  PlayerProfileViewController.swift
//  CyborgRugby
//
//  Player profile and achievement tracking
//

import UIKit

class PlayerProfileViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Profile header
    private let profileHeaderView = UIView()
    private let profileImageView = UIImageView()
    private let playerNameLabel = UILabel()
    private let playerPositionLabel = UILabel()
    private let playerTeamLabel = UILabel()
    private let settingsButton = UIButton()
    
    // Stats section
    private let statsCardView = UIView()
    private let statsTitleLabel = UILabel()
    private let scansCountLabel = UILabel()
    private let achievementsCountLabel = UILabel()
    private let totalTimeLabel = UILabel()
    
    // Achievements section
    private let achievementsCardView = UIView()
    private let achievementsTitleLabel = UILabel()
    private let achievementsStackView = UIStackView()
    
    // Scan history section
    private let historyCardView = UIView()
    private let historyTitleLabel = UILabel()
    private let historyTableView = UITableView()
    
    // MARK: - Properties
    private let achievementManager = AchievementManager.shared
    private let playerProfile = PlayerProfile.shared
    private var scanHistory: [ScanHistoryItem] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadPlayerData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadPlayerData()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        title = "My Profile"
        view.backgroundColor = .systemBackground
        
        // Add education button to navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "graduationcap"),
            style: .plain,
            target: self,
            action: #selector(showEducationHub)
        )
        
        setupScrollView()
        setupProfileHeader()
        setupStatsSection()
        setupAchievementsSection()
        setupHistorySection()
        setupConstraints()
    }
    
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
    }
    
    private func setupProfileHeader() {
        profileHeaderView.backgroundColor = .systemGreen
        profileHeaderView.layer.cornerRadius = 16
        profileHeaderView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(profileHeaderView)
        
        profileImageView.image = UIImage(systemName: "person.fill")
        profileImageView.tintColor = .white
        profileImageView.contentMode = .scaleAspectFit
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        profileHeaderView.addSubview(profileImageView)
        
        playerNameLabel.text = "Player Name"
        playerNameLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        playerNameLabel.textColor = .white
        playerNameLabel.textAlignment = .center
        playerNameLabel.translatesAutoresizingMaskIntoConstraints = false
        profileHeaderView.addSubview(playerNameLabel)
        
        playerPositionLabel.text = "Position: Hooker"
        playerPositionLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        playerPositionLabel.textColor = .white.withAlphaComponent(0.9)
        playerPositionLabel.textAlignment = .center
        playerPositionLabel.translatesAutoresizingMaskIntoConstraints = false
        profileHeaderView.addSubview(playerPositionLabel)
        
        playerTeamLabel.text = "Team: Crusaders"
        playerTeamLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        playerTeamLabel.textColor = .white.withAlphaComponent(0.8)
        playerTeamLabel.textAlignment = .center
        playerTeamLabel.translatesAutoresizingMaskIntoConstraints = false
        profileHeaderView.addSubview(playerTeamLabel)
        
        // Settings button
        settingsButton.setImage(UIImage(systemName: "gear"), for: .normal)
        settingsButton.tintColor = .white
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.addTarget(self, action: #selector(showSettings), for: .touchUpInside)
        profileHeaderView.addSubview(settingsButton)
        
        // Constraints
        NSLayoutConstraint.activate([
            profileImageView.topAnchor.constraint(equalTo: profileHeaderView.topAnchor, constant: 20),
            profileImageView.centerXAnchor.constraint(equalTo: profileHeaderView.centerXAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 80),
            profileImageView.heightAnchor.constraint(equalToConstant: 80),
            
            playerNameLabel.topAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 15),
            playerNameLabel.leadingAnchor.constraint(equalTo: profileHeaderView.leadingAnchor, constant: 20),
            playerNameLabel.trailingAnchor.constraint(equalTo: profileHeaderView.trailingAnchor, constant: -20),
            
            playerPositionLabel.topAnchor.constraint(equalTo: playerNameLabel.bottomAnchor, constant: 8),
            playerPositionLabel.leadingAnchor.constraint(equalTo: profileHeaderView.leadingAnchor, constant: 20),
            playerPositionLabel.trailingAnchor.constraint(equalTo: profileHeaderView.trailingAnchor, constant: -20),
            
            playerTeamLabel.topAnchor.constraint(equalTo: playerPositionLabel.bottomAnchor, constant: 5),
            playerTeamLabel.leadingAnchor.constraint(equalTo: profileHeaderView.leadingAnchor, constant: 20),
            playerTeamLabel.trailingAnchor.constraint(equalTo: profileHeaderView.trailingAnchor, constant: -20),
            
            settingsButton.topAnchor.constraint(equalTo: profileHeaderView.topAnchor, constant: 20),
            settingsButton.trailingAnchor.constraint(equalTo: profileHeaderView.trailingAnchor, constant: -20),
            settingsButton.widthAnchor.constraint(equalToConstant: 30),
            settingsButton.heightAnchor.constraint(equalToConstant: 30),
            
            playerTeamLabel.bottomAnchor.constraint(equalTo: profileHeaderView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupStatsSection() {
        statsCardView.backgroundColor = .systemBackground
        statsCardView.layer.cornerRadius = 16
        statsCardView.layer.shadowColor = UIColor.black.cgColor
        statsCardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        statsCardView.layer.shadowRadius = 8
        statsCardView.layer.shadowOpacity = 0.1
        statsCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statsCardView)
        
        statsTitleLabel.text = "Statistics"
        statsTitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        statsTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        statsCardView.addSubview(statsTitleLabel)
        
        scansCountLabel.text = "Scans: 0"
        scansCountLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        scansCountLabel.translatesAutoresizingMaskIntoConstraints = false
        statsCardView.addSubview(scansCountLabel)
        
        achievementsCountLabel.text = "Achievements: 0/5"
        achievementsCountLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        achievementsCountLabel.translatesAutoresizingMaskIntoConstraints = false
        statsCardView.addSubview(achievementsCountLabel)
        
        totalTimeLabel.text = "Total Time: 0m"
        totalTimeLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        totalTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        statsCardView.addSubview(totalTimeLabel)
        
        // Constraints
        NSLayoutConstraint.activate([
            statsTitleLabel.topAnchor.constraint(equalTo: statsCardView.topAnchor, constant: 20),
            statsTitleLabel.leadingAnchor.constraint(equalTo: statsCardView.leadingAnchor, constant: 20),
            statsTitleLabel.trailingAnchor.constraint(equalTo: statsCardView.trailingAnchor, constant: -20),
            
            scansCountLabel.topAnchor.constraint(equalTo: statsTitleLabel.bottomAnchor, constant: 15),
            scansCountLabel.leadingAnchor.constraint(equalTo: statsCardView.leadingAnchor, constant: 20),
            scansCountLabel.trailingAnchor.constraint(equalTo: statsCardView.trailingAnchor, constant: -20),
            
            achievementsCountLabel.topAnchor.constraint(equalTo: scansCountLabel.bottomAnchor, constant: 10),
            achievementsCountLabel.leadingAnchor.constraint(equalTo: statsCardView.leadingAnchor, constant: 20),
            achievementsCountLabel.trailingAnchor.constraint(equalTo: statsCardView.trailingAnchor, constant: -20),
            
            totalTimeLabel.topAnchor.constraint(equalTo: achievementsCountLabel.bottomAnchor, constant: 10),
            totalTimeLabel.leadingAnchor.constraint(equalTo: statsCardView.leadingAnchor, constant: 20),
            totalTimeLabel.trailingAnchor.constraint(equalTo: statsCardView.trailingAnchor, constant: -20),
            totalTimeLabel.bottomAnchor.constraint(equalTo: statsCardView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupAchievementsSection() {
        achievementsCardView.backgroundColor = .systemBackground
        achievementsCardView.layer.cornerRadius = 16
        achievementsCardView.layer.shadowColor = UIColor.black.cgColor
        achievementsCardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        achievementsCardView.layer.shadowRadius = 8
        achievementsCardView.layer.shadowOpacity = 0.1
        achievementsCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(achievementsCardView)
        
        achievementsTitleLabel.text = "Achievements"
        achievementsTitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        achievementsTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        achievementsCardView.addSubview(achievementsTitleLabel)
        
        achievementsStackView.axis = .vertical
        achievementsStackView.spacing = 12
        achievementsStackView.alignment = .fill
        achievementsStackView.translatesAutoresizingMaskIntoConstraints = false
        achievementsCardView.addSubview(achievementsStackView)
        
        // Constraints
        NSLayoutConstraint.activate([
            achievementsTitleLabel.topAnchor.constraint(equalTo: achievementsCardView.topAnchor, constant: 20),
            achievementsTitleLabel.leadingAnchor.constraint(equalTo: achievementsCardView.leadingAnchor, constant: 20),
            achievementsTitleLabel.trailingAnchor.constraint(equalTo: achievementsCardView.trailingAnchor, constant: -20),
            
            achievementsStackView.topAnchor.constraint(equalTo: achievementsTitleLabel.bottomAnchor, constant: 15),
            achievementsStackView.leadingAnchor.constraint(equalTo: achievementsCardView.leadingAnchor, constant: 20),
            achievementsStackView.trailingAnchor.constraint(equalTo: achievementsCardView.trailingAnchor, constant: -20),
            achievementsStackView.bottomAnchor.constraint(equalTo: achievementsCardView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupHistorySection() {
        historyCardView.backgroundColor = .systemBackground
        historyCardView.layer.cornerRadius = 16
        historyCardView.layer.shadowColor = UIColor.black.cgColor
        historyCardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        historyCardView.layer.shadowRadius = 8
        historyCardView.layer.shadowOpacity = 0.1
        historyCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(historyCardView)
        
        historyTitleLabel.text = "Scan History"
        historyTitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        historyTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        historyCardView.addSubview(historyTitleLabel)
        
        historyTableView.translatesAutoresizingMaskIntoConstraints = false
        historyTableView.register(UITableViewCell.self, forCellReuseIdentifier: "HistoryCell")
        historyTableView.delegate = self
        historyTableView.dataSource = self
        historyCardView.addSubview(historyTableView)
        
        // Constraints
        NSLayoutConstraint.activate([
            historyTitleLabel.topAnchor.constraint(equalTo: historyCardView.topAnchor, constant: 20),
            historyTitleLabel.leadingAnchor.constraint(equalTo: historyCardView.leadingAnchor, constant: 20),
            historyTitleLabel.trailingAnchor.constraint(equalTo: historyCardView.trailingAnchor, constant: -20),
            
            historyTableView.topAnchor.constraint(equalTo: historyTitleLabel.bottomAnchor, constant: 15),
            historyTableView.leadingAnchor.constraint(equalTo: historyCardView.leadingAnchor),
            historyTableView.trailingAnchor.constraint(equalTo: historyCardView.trailingAnchor),
            historyTableView.bottomAnchor.constraint(equalTo: historyCardView.bottomAnchor, constant: -20),
            historyTableView.heightAnchor.constraint(equalToConstant: 200)
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
            
            // Profile header
            profileHeaderView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            profileHeaderView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            profileHeaderView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Stats section
            statsCardView.topAnchor.constraint(equalTo: profileHeaderView.bottomAnchor, constant: 20),
            statsCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statsCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Achievements section
            achievementsCardView.topAnchor.constraint(equalTo: statsCardView.bottomAnchor, constant: 20),
            achievementsCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            achievementsCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // History section
            historyCardView.topAnchor.constraint(equalTo: achievementsCardView.bottomAnchor, constant: 20),
            historyCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            historyCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            historyCardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func showSettings() {
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
    }
    
    @objc private func showEducationHub() {
        let educationVC = EducationHubViewController()
        navigationController?.pushViewController(educationVC, animated: true)
    }
    
    // MARK: - Data Loading
    
    private func loadPlayerData() {
        // Load player profile data
        playerNameLabel.text = playerProfile.name
        playerPositionLabel.text = "Position: \(playerProfile.position)"
        playerTeamLabel.text = "Team: \(playerProfile.team)"
        
        // Load scan history
        loadScanHistory()
        
        // Update UI
        updateStats()
        updateAchievements()
    }
    
    private func loadScanHistory() {
        // In a real app, this would load from persistent storage
        scanHistory = [
            ScanHistoryItem(date: Date(), quality: 0.95, duration: 120),
            ScanHistoryItem(date: Date().addingTimeInterval(-86400), quality: 0.87, duration: 150),
            ScanHistoryItem(date: Date().addingTimeInterval(-172800), quality: 0.92, duration: 135)
        ]
    }
    
    private func updateStats() {
        let scanCount = playerProfile.scanCount
        let unlockedCount = achievementManager.getUnlockedAchievements().count
        let totalCount = achievementManager.getAllAchievements().count
        let totalTime = playerProfile.totalScanTime
        
        scansCountLabel.text = "Scans: \(scanCount)"
        achievementsCountLabel.text = "Achievements: \(unlockedCount)/\(totalCount)"
        totalTimeLabel.text = "Total Time: \(totalTime / 60)m \(totalTime % 60)s"
    }
    
    private func updateAchievements() {
        // Clear existing achievements
        achievementsStackView.arrangedSubviews.forEach { view in
            achievementsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        // Add achievements
        let allAchievements = achievementManager.getAllAchievements()
        for achievement in allAchievements {
            let achievementView = createAchievementView(for: achievement)
            achievementsStackView.addArrangedSubview(achievementView)
        }
    }
    
    private func createAchievementView(for achievement: AchievementManager.Achievement) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)
        
        let iconImageView = UIImageView()
        iconImageView.image = UIImage(systemName: achievement.icon)
        iconImageView.tintColor = achievementManager.isUnlocked(achievement) ? .systemGreen : .systemGray3
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.widthAnchor.constraint(equalToConstant: 30).isActive = true
        iconImageView.heightAnchor.constraint(equalToConstant: 30).isActive = true
        stackView.addArrangedSubview(iconImageView)
        
        let textStackView = UIStackView()
        textStackView.axis = .vertical
        textStackView.alignment = .leading
        textStackView.spacing = 4
        textStackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(textStackView)
        
        let titleLabel = UILabel()
        titleLabel.text = achievement.title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = achievementManager.isUnlocked(achievement) ? .label : .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        textStackView.addArrangedSubview(titleLabel)
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = achievement.description
        descriptionLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        textStackView.addArrangedSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10)
        ])
        
        return containerView
    }
}

// MARK: - UITableViewDataSource

extension PlayerProfileViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return scanHistory.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell", for: indexPath)
        let scan = scanHistory[indexPath.row]
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        cell.textLabel?.text = formatter.string(from: scan.date)
        cell.detailTextLabel?.text = "Quality: \(Int(scan.quality * 100))%, Duration: \(scan.duration)s"
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension PlayerProfileViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // In a real app, this would show details for the selected scan
    }
}

// MARK: - Data Models

struct ScanHistoryItem {
    let date: Date
    let quality: Float
    let duration: Int
}