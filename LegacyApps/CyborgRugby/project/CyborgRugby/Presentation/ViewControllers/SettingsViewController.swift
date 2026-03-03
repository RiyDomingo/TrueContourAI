//
//  SettingsViewController.swift
//  CyborgRugby
//
//  Settings and player profile management
//

import UIKit

class SettingsViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Profile section
    private let profileCardView = UIView()
    private let profileTitleLabel = UILabel()
    private let nameTextField = UITextField()
    private let positionTextField = UITextField()
    private let teamTextField = UITextField()
    private let saveButton = UIButton()
    
    // Account section
    private let accountCardView = UIView()
    private let accountTitleLabel = UILabel()
    private let resetDataButton = UIButton()
    
    // MARK: - Properties
    private let playerProfile = PlayerProfile.shared
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadProfileData()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        title = "Settings"
        view.backgroundColor = .systemBackground
        
        // Add profile button to navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "person.fill"),
            style: .plain,
            target: self,
            action: #selector(showProfile)
        )
        
        setupScrollView()
        setupProfileSection()
        setupAccountSection()
        setupConstraints()
    }
    
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
    }
    
    private func setupProfileSection() {
        profileCardView.backgroundColor = .systemBackground
        profileCardView.layer.cornerRadius = 16
        profileCardView.layer.shadowColor = UIColor.black.cgColor
        profileCardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        profileCardView.layer.shadowRadius = 8
        profileCardView.layer.shadowOpacity = 0.1
        profileCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(profileCardView)
        
        profileTitleLabel.text = "Player Profile"
        profileTitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        profileTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        profileCardView.addSubview(profileTitleLabel)
        
        setupTextField(nameTextField, placeholder: "Name", tag: 0)
        setupTextField(positionTextField, placeholder: "Position", tag: 1)
        setupTextField(teamTextField, placeholder: "Team", tag: 2)
        
        // Save button
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.title = "Save Profile"
            config.cornerStyle = .medium
            config.baseBackgroundColor = .systemGreen
            config.baseForegroundColor = .white
            saveButton.configuration = config
        } else {
            saveButton.setTitle("Save Profile", for: .normal)
            saveButton.setTitleColor(.white, for: .normal)
            saveButton.backgroundColor = .systemGreen
            saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
            saveButton.layer.cornerRadius = 12
        }
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.addTarget(self, action: #selector(saveProfile), for: .touchUpInside)
        profileCardView.addSubview(saveButton)
        
        // Constraints
        NSLayoutConstraint.activate([
            profileTitleLabel.topAnchor.constraint(equalTo: profileCardView.topAnchor, constant: 20),
            profileTitleLabel.leadingAnchor.constraint(equalTo: profileCardView.leadingAnchor, constant: 20),
            profileTitleLabel.trailingAnchor.constraint(equalTo: profileCardView.trailingAnchor, constant: -20),
            
            nameTextField.topAnchor.constraint(equalTo: profileTitleLabel.bottomAnchor, constant: 20),
            nameTextField.leadingAnchor.constraint(equalTo: profileCardView.leadingAnchor, constant: 20),
            nameTextField.trailingAnchor.constraint(equalTo: profileCardView.trailingAnchor, constant: -20),
            
            positionTextField.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 15),
            positionTextField.leadingAnchor.constraint(equalTo: profileCardView.leadingAnchor, constant: 20),
            positionTextField.trailingAnchor.constraint(equalTo: profileCardView.trailingAnchor, constant: -20),
            
            teamTextField.topAnchor.constraint(equalTo: positionTextField.bottomAnchor, constant: 15),
            teamTextField.leadingAnchor.constraint(equalTo: profileCardView.leadingAnchor, constant: 20),
            teamTextField.trailingAnchor.constraint(equalTo: profileCardView.trailingAnchor, constant: -20),
            
            saveButton.topAnchor.constraint(equalTo: teamTextField.bottomAnchor, constant: 20),
            saveButton.leadingAnchor.constraint(equalTo: profileCardView.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: profileCardView.trailingAnchor, constant: -20),
            saveButton.bottomAnchor.constraint(equalTo: profileCardView.bottomAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupTextField(_ textField: UITextField, placeholder: String, tag: Int) {
        textField.borderStyle = .roundedRect
        textField.placeholder = placeholder
        textField.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.tag = tag
        textField.delegate = self
        profileCardView.addSubview(textField)
    }
    
    private func setupAccountSection() {
        accountCardView.backgroundColor = .systemBackground
        accountCardView.layer.cornerRadius = 16
        accountCardView.layer.shadowColor = UIColor.black.cgColor
        accountCardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        accountCardView.layer.shadowRadius = 8
        accountCardView.layer.shadowOpacity = 0.1
        accountCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(accountCardView)
        
        accountTitleLabel.text = "Account"
        accountTitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        accountTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        accountCardView.addSubview(accountTitleLabel)
        
        // Reset data button
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.tinted()
            config.title = "Reset All Data"
            config.cornerStyle = .medium
            config.baseBackgroundColor = .systemRed
            config.baseForegroundColor = .white
            resetDataButton.configuration = config
        } else {
            resetDataButton.setTitle("Reset All Data", for: .normal)
            resetDataButton.setTitleColor(.systemRed, for: .normal)
            resetDataButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
            resetDataButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
            resetDataButton.layer.cornerRadius = 12
        }
        resetDataButton.translatesAutoresizingMaskIntoConstraints = false
        resetDataButton.addTarget(self, action: #selector(resetData), for: .touchUpInside)
        accountCardView.addSubview(resetDataButton)
        
        // Constraints
        NSLayoutConstraint.activate([
            accountTitleLabel.topAnchor.constraint(equalTo: accountCardView.topAnchor, constant: 20),
            accountTitleLabel.leadingAnchor.constraint(equalTo: accountCardView.leadingAnchor, constant: 20),
            accountTitleLabel.trailingAnchor.constraint(equalTo: accountCardView.trailingAnchor, constant: -20),
            
            resetDataButton.topAnchor.constraint(equalTo: accountTitleLabel.bottomAnchor, constant: 20),
            resetDataButton.leadingAnchor.constraint(equalTo: accountCardView.leadingAnchor, constant: 20),
            resetDataButton.trailingAnchor.constraint(equalTo: accountCardView.trailingAnchor, constant: -20),
            resetDataButton.bottomAnchor.constraint(equalTo: accountCardView.bottomAnchor, constant: -20),
            resetDataButton.heightAnchor.constraint(equalToConstant: 50)
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
            
            // Profile section
            profileCardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            profileCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            profileCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Account section
            accountCardView.topAnchor.constraint(equalTo: profileCardView.bottomAnchor, constant: 20),
            accountCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            accountCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            accountCardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Data Loading
    
    private func loadProfileData() {
        nameTextField.text = playerProfile.name
        positionTextField.text = playerProfile.position
        teamTextField.text = playerProfile.team
    }
    
    // MARK: - Actions
    
    @objc private func showProfile() {
        let profileVC = PlayerProfileViewController()
        navigationController?.pushViewController(profileVC, animated: true)
    }
    
    @objc private func saveProfile() {
        playerProfile.name = nameTextField.text ?? "Player Name"
        playerProfile.position = positionTextField.text ?? "Hooker"
        playerProfile.team = teamTextField.text ?? "Crusaders"
        
        // Show confirmation
        let alert = UIAlertController(title: "Profile Saved", message: "Your player profile has been updated successfully.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func resetData() {
        let alert = UIAlertController(title: "Reset All Data", message: "This will permanently delete all your scan history, achievements, and profile data. This action cannot be undone.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { _ in
            self.playerProfile.resetProfile()
            self.loadProfileData()
            
            // Show confirmation
            let confirmation = UIAlertController(title: "Data Reset", message: "All your data has been reset successfully.", preferredStyle: .alert)
            confirmation.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(confirmation, animated: true)
        })
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension SettingsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField.tag {
        case 0:
            positionTextField.becomeFirstResponder()
        case 1:
            teamTextField.becomeFirstResponder()
        case 2:
            teamTextField.resignFirstResponder()
            saveProfile()
        default:
            textField.resignFirstResponder()
        }
        return true
    }
}