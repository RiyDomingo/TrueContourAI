//
//  EducationDetailViewController.swift
//  CyborgRugby
//
//  Detailed view for educational content
//

import UIKit

class EducationDetailViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let headerView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    
    private let contentTextView = UITextView()
    
    // MARK: - Properties
    var content: EducationContent!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadContent()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        title = content.title
        view.backgroundColor = .systemBackground
        
        // Add profile button to navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "person.fill"),
            style: .plain,
            target: self,
            action: #selector(showProfile)
        )
        
        setupScrollView()
        setupHeader()
        setupContent()
        setupConstraints()
    }
    
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
    }
    
    private func setupHeader() {
        headerView.backgroundColor = .systemGreen
        headerView.layer.cornerRadius = 16
        headerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerView)
        
        iconImageView.image = UIImage(systemName: content.imageName)
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(iconImageView)
        
        titleLabel.text = content.title
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)
        
        // Constraints
        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            iconImageView.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 60),
            iconImageView.heightAnchor.constraint(equalToConstant: 60),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 15),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupContent() {
        contentTextView.isEditable = false
        contentTextView.isScrollEnabled = false
        contentTextView.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        contentTextView.textColor = .label
        contentTextView.backgroundColor = .clear
        contentTextView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(contentTextView)
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
            
            // Header
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Content
            contentTextView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            contentTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            contentTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            contentTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func showProfile() {
        let profileVC = PlayerProfileViewController()
        navigationController?.pushViewController(profileVC, animated: true)
    }
    
    // MARK: - Content Loading
    
    private func loadContent() {
        // In a real app, this would load from a data source
        let detailedContent = getDetailedContent(for: content.title)
        contentTextView.text = detailedContent
    }
    
    private func getDetailedContent(for title: String) -> String {
        switch title {
        case "Concussion Prevention":
            return """
            Concussions are a serious concern in rugby, and proper head protection is crucial for player safety.
            
            Our scrum caps are designed with advanced materials and engineering to reduce the risk of concussions:
            
            1. Multi-layer construction: Our caps feature multiple layers of specialized foam and padding that absorb and dissipate impact energy.
            
            2. Custom fit: The 3D scanning process ensures a perfect fit to your head shape, eliminating gaps that could allow dangerous movement during impact.
            
            3. Strategic padding: Extra padding is placed in high-risk areas identified through biomechanical research.
            
            4. Secure fastening: The chin strap and sizing system keep the cap firmly in place during play.
            
            While no headgear can completely eliminate concussion risk, studies show that properly fitted scrum caps can reduce the incidence of concussions by up to 30%.
            
            Remember to:
            - Replace your cap if it shows signs of wear
            - Ensure proper fit before each game
            - Report any head impacts to medical staff
            """
        case "Ear Protection":
            return """
            Cauliflower ear is a common injury in rugby caused by repeated trauma to the ear.
            
            How it happens:
            - Direct blows to the ear during tackles or rucks
            - Friction against the ground during falls
            - Compression between players' heads
            
            Our scrum caps protect your ears through:
            
            1. Integrated ear guards: Specialized padding that covers and cushions the ears.
            
            2. Form-fitting design: The 3D scan ensures the cap contours perfectly to your head, providing consistent protection.
            
            3. Breathable materials: Advanced fabrics that wick moisture while maintaining protection.
            
            4. Adjustable fit: Custom sizing ensures the cap stays in place during intense play.
            
            Prevention tips:
            - Always wear your scrum cap during contact
            - Check for proper fit before each game
            - Replace worn or damaged caps immediately
            - Seek medical attention for any ear trauma
            """
        case "Neck Safety":
            return """
            Neck injuries in rugby can be severe and even life-threatening. While scrum caps primarily protect the head, they can contribute to overall neck safety.
            
            How scrum caps help:
            
            1. Reduced head acceleration: By absorbing impact energy, caps reduce the forces transmitted to the neck.
            
            2. Proper weight distribution: Our lightweight design ensures the cap doesn't add unnecessary strain to neck muscles.
            
            3. Enhanced awareness: Better-fitting caps improve peripheral vision, helping players avoid dangerous situations.
            
            Neck safety best practices:
            
            - Strengthen neck muscles with targeted exercises
            - Learn proper tackling and falling techniques
            - Maintain proper head and neck alignment during contact
            - Use proper scrum engagement techniques
            - Report any neck pain or stiffness to medical staff
            
            Remember: Scrum caps are just one part of a comprehensive safety approach. Proper technique and conditioning are equally important.
            """
        case "3D Scanning Tech":
            return """
            Our revolutionary 3D scanning technology creates a precise digital model of your head for perfect-fitting scrum caps.
            
            How it works:
            
            1. TrueDepth Camera: Your iPhone's advanced camera system captures detailed depth information.
            
            2. Multiple angles: The scanning process captures your head from several positions for complete coverage.
            
            3. Real-time processing: Our algorithms process the data instantly to create a 3D model.
            
            4. Precision measurements: The system identifies key anatomical landmarks for optimal fit.
            
            Benefits:
            
            - Perfect fit every time
            - Eliminates guesswork in sizing
            - Accommodates unique head shapes
            - Improves comfort and performance
            - Enhances safety through proper fit
            
            The entire scanning process takes less than 3 minutes and is completely safe.
            """
        case "Material Science":
            return """
            Our scrum caps utilize cutting-edge materials engineered for maximum protection and comfort.
            
            Key materials:
            
            1. Advanced foam cores: Proprietary foam formulations that balance impact absorption with weight.
            
            2. High-strength polymers: Lightweight yet durable outer shells that resist cracking and deformation.
            
            3. Moisture-wicking fabrics: Inner linings that keep you cool and dry during intense play.
            
            4. Antimicrobial treatments: Special coatings that reduce odor and bacterial growth.
            
            Material properties:
            
            - Impact resistance: Tested to withstand forces exceeding rugby standards
            - Temperature stability: Maintains properties in extreme conditions
            - Durability: Designed for multi-season use with proper care
            - Recyclability: Environmentally conscious materials when possible
            
            All materials meet or exceed international safety standards for rugby equipment.
            """
        case "Custom Manufacturing":
            return """
            Each scrum cap is individually manufactured using precision 3D printing technology.
            
            The process:
            
            1. Data processing: Your scan data is analyzed and optimized for manufacturing.
            
            2. 3D printing: Specialized printers create the custom shell layer by layer.
            
            3. Quality control: Each cap undergoes rigorous testing before shipment.
            
            4. Assembly: Components are assembled with precision fitting.
            
            5. Final inspection: Every cap is individually inspected for quality.
            
            Benefits of custom manufacturing:
            
            - Perfect fit to your unique head shape
            - Optimized protection for your specific anatomy
            - Reduced pressure points and hot spots
            - Enhanced comfort during extended wear
            - Improved performance through better fit
            
            Manufacturing typically takes 2-3 weeks from order to delivery.
            """
        case "Fitting Guide":
            return """
            Proper fitting is essential for your scrum cap to provide optimal protection and comfort.
            
            Fitting steps:
            
            1. Clean your head: Ensure your hair is clean and dry.
            
            2. Position the cap: Place it on your head with the logo centered at the front.
            
            3. Adjust the size: Use the sizing system to achieve a snug but comfortable fit.
            
            4. Check the fit: The cap should sit level on your head without pinching.
            
            5. Secure the chin strap: Fasten it snugly under your chin without restricting breathing.
            
            Fit indicators:
            
            - Good: Even pressure around your head, no gaps
            - Too tight: Headache, pressure points, red marks
            - Too loose: Cap moves during head movement
            
            Perform a fit check before each game by shaking your head vigorously.
            """
        case "Maintenance":
            return """
            Proper care extends the life of your scrum cap and maintains its protective properties.
            
            Cleaning:
            
            1. Hand wash with mild soap and warm water
            2. Rinse thoroughly to remove all soap residue
            3. Air dry away from direct sunlight
            4. Do not use bleach or harsh chemicals
            
            Storage:
            
            - Store in a cool, dry place
            - Avoid crushing or deforming the cap
            - Use the provided storage bag when traveling
            - Keep away from extreme temperatures
            
            Inspection:
            
            - Check for cracks or damage before each use
            - Examine the chin strap for wear
            - Look for loose or missing padding
            - Replace immediately if damage is found
            
            With proper care, your scrum cap should last 2-3 seasons.
            """
        case "When to Replace":
            return """
            Knowing when to replace your scrum cap is crucial for maintaining protection.
            
            Replace immediately if you notice:
            
            - Cracks or splits in the shell
            - Compressed or damaged padding
            - Loose or broken chin strap attachments
            - Significant deformation from impact
            - Worn or frayed fabric components
            
            Replace periodically:
            
            - Every 2-3 seasons with regular use
            - After any significant impact, even if damage isn't visible
            - When fit becomes inconsistent
            - If comfort noticeably decreases
            
            Signs it may be time to replace:
            
            - Increased pressure points or hot spots
            - Decreased protection feeling
            - Visible wear patterns
            - Age over 3 years
            
            When in doubt, consult with your team's equipment manager or replace the cap.
            """
        default:
            return "Detailed content for \(title) coming soon."
        }
    }
}