import UIKit

extension String {
    func bkdrHash(seed: UInt64 = 100, seed2: UInt64 = 200) -> UInt64 {
        return UInt64(abs(self.hashValue))

//        var hash: UInt64 = 0;
//
//        var str = self
//        str += "x"
//
//        str.forEach { (char) in
//            if let code = char.asciiValue {
//                if hash >= UInt64.max / seed2 {
//                    hash = hash / seed2
//                } else {
//                    hash = hash * seed + UInt64(code)
//                }
//            }
//        }
//
//        return hash
    }
}

struct ColorRange {
    var min: UInt64 = 0
    var max: UInt64 = 360

    func randomValue() -> UInt64 {
        let meow = UInt64.random(in: min...max)
        return meow
    }
}

class ColorHash {
    var lightnessRange: ColorRange = ColorRange(min: 70, max: 90)
    var saturationRange: ColorRange = ColorRange(min: 70, max: 99)
    let hueRange: ColorRange = ColorRange(min: 0, max: 340)

    let brandColors = ["wordpress": UIColor.colorFromHex("0573AB"),
                       "google": UIColor.colorFromHex("0F9D58"),
                       "automattic": UIColor.colorFromHex("3499CD"),
                       "a8c": UIColor.colorFromHex("3499CD"),
    ]

    func generateColor(string: String) -> UIColor {
        if let meow = brandColors[string.lowercased()] {
            return meow
        }

        let hash = string.bkdrHash()

        let seed: UInt64 = 727
        let seed1: UInt64 = 300
        let seed2: UInt64 = 123

        let hue = CGFloat((hash % seed) * (hueRange.max - hueRange.min) / seed + hueRange.min) / 360.0
        let saturation = CGFloat((hash % seed1) * (saturationRange.max - saturationRange.min) / seed1 + saturationRange.min) / 100.0
        let lightness = CGFloat((hash % seed2) * (lightnessRange.max - lightnessRange.min) / seed2 + lightnessRange.min) / 100.0

//        print(string, hash, hue, saturation, lightness)
        return UIColor(hue: hue, saturation: saturation, brightness: lightness, alpha: 1)
    }
}

extension UIColor {

    static func contrastRatio(between color1: UIColor, and color2: UIColor) -> CGFloat {
        // https://www.w3.org/TR/WCAG20-TECHS/G18.html#G18-tests

        let luminance1 = color1.luminance()
        let luminance2 = color2.luminance()

        let luminanceDarker = min(luminance1, luminance2)
        let luminanceLighter = max(luminance1, luminance2)

        return (luminanceLighter + 0.05) / (luminanceDarker + 0.05)
    }

    func contrastRatio(with color: UIColor) -> CGFloat {
        return UIColor.contrastRatio(between: self, and: color)
    }

    func luminance() -> CGFloat {
        // https://www.w3.org/TR/WCAG20-TECHS/G18.html#G18-tests

        let ciColor = CIColor(color: self)

        func adjust(colorComponent: CGFloat) -> CGFloat {
            return (colorComponent < 0.04045) ? (colorComponent / 12.92) : pow((colorComponent + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * adjust(colorComponent: ciColor.red) + 0.7152 * adjust(colorComponent: ciColor.green) + 0.0722 * adjust(colorComponent: ciColor.blue)
    }
}


enum ReaderTopicCollectionViewState {
    case collapsed
    case expanded
}

protocol ReaderTopicCollectionViewCoordinatorDelegate: AnyObject {
    func coordinator(_ coordinator: ReaderTopicCollectionViewCoordinator, didSelectTopic topic: String)
    func coordinator(_ coordinator: ReaderTopicCollectionViewCoordinator, didChangeState: ReaderTopicCollectionViewState)
}


/// The topics coordinator manages the layout and configuration of a topics chip group collection view.
/// When created it will link to a collectionView and perform all the necessary configuration to
/// display the group with expanding/collapsing support.
///
class ReaderTopicCollectionViewCoordinator: NSObject {
    private struct Constants {
        static let reuseIdentifier = ReaderInterestsCollectionViewCell.classNameWithoutNamespaces()
        static let overflowReuseIdentifier = "OverflowItem"

        static let interestsLabelMargin: CGFloat = 8

        static let cellCornerRadius: CGFloat = 4
        static let cellSpacing: CGFloat = 6
        static let cellHeight: CGFloat = 26
        static let maxCellWidthMultiplier: CGFloat = 0.8
    }

    private struct Strings {
        static let collapseButtonTitle: String = NSLocalizedString("Hide", comment: "Title of a button used to collapse a group")
    }

    weak var delegate: ReaderTopicCollectionViewCoordinatorDelegate?

    let collectionView: UICollectionView
    var topics: [String] {
        didSet {
            reloadData()
        }
    }

    deinit {
        guard let layout = collectionView.collectionViewLayout as? ReaderInterestsCollectionViewFlowLayout else {
            return
        }

        layout.isExpanded = false
        layout.invalidateLayout()
    }

    init(collectionView: UICollectionView, topics: [String]) {
        self.collectionView = collectionView
        self.topics = topics

        super.init()

        configureCollectionView()
    }

    func reloadData() {
        collectionView.reloadData()
        collectionView.invalidateIntrinsicContentSize()
    }

    func changeState(_ state: ReaderTopicCollectionViewState) {
        guard let layout = collectionView.collectionViewLayout as? ReaderInterestsCollectionViewFlowLayout else {
            return
        }

        layout.isExpanded = state == .expanded
    }

    private func configureCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self

        collectionView.contentInset = .zero

        let nib = UINib(nibName: String(describing: ReaderInterestsCollectionViewCell.self), bundle: nil)

        // Register the main cell
        collectionView.register(nib, forCellWithReuseIdentifier: Constants.reuseIdentifier)

        // Register the overflow item type
        collectionView.register(nib, forSupplementaryViewOfKind: ReaderInterestsCollectionViewFlowLayout.overflowItemKind, withReuseIdentifier: Constants.overflowReuseIdentifier)

        // Configure Layout
        guard let layout = collectionView.collectionViewLayout as? ReaderInterestsCollectionViewFlowLayout else {
            return
        }

        layout.delegate = self
        layout.maxNumberOfDisplayedLines = 1
        layout.itemSpacing = Constants.cellSpacing
        layout.cellHeight = Constants.cellHeight
        layout.allowsCentering = false
    }

    private func sizeForCell(title: String) -> CGSize {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: ReaderInterestsStyleGuide.compactCellLabelTitleFont
        ]


        let title: NSString = title as NSString

        var size = title.size(withAttributes: attributes)

        // Prevent 1 token from being too long
        let maxWidth = collectionView.bounds.width * Constants.maxCellWidthMultiplier
        let width = min(size.width, maxWidth)
        size.width = width + (Constants.interestsLabelMargin * 2)

        return size
    }

    private func configure(cell: ReaderInterestsCollectionViewCell, with title: String, isMeow: Bool = false) {
        ReaderInterestsStyleGuide.applyCompactCellLabelStyle(label: cell.label)

        cell.layer.cornerRadius = Constants.cellCornerRadius
        cell.label.text = title

        guard !isMeow else {
            return
        }


        let colorHash = ColorHash()
        let color = colorHash.generateColor(string: title)
        let titleContrast = color.contrastRatio(with: .text)

        cell.label.textColor = .white
        cell.backgroundColor = color
    }

    private func string(for remainingItems: Int?) -> String {
        guard let items = remainingItems else {
            return Strings.collapseButtonTitle
        }

        return "\(items)+"
    }
}

extension ReaderTopicCollectionViewCoordinator: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return topics.count
    }
}

extension ReaderTopicCollectionViewCoordinator: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Constants.reuseIdentifier,
                                                          for: indexPath) as? ReaderInterestsCollectionViewCell else {
            fatalError("Expected a ReaderInterestsCollectionViewCell for identifier: \(Constants.reuseIdentifier)")
        }

        configure(cell: cell, with: topics[indexPath.row])

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let overflowKind = ReaderInterestsCollectionViewFlowLayout.overflowItemKind

        guard
            kind == overflowKind,
            let cell = collectionView.dequeueReusableSupplementaryView(ofKind: overflowKind, withReuseIdentifier: Constants.overflowReuseIdentifier, for: indexPath) as? ReaderInterestsCollectionViewCell,
            let layout = collectionView.collectionViewLayout as? ReaderInterestsCollectionViewFlowLayout
        else {
            fatalError("Expected a ReaderInterestsCollectionViewCell for identifier: \(Constants.overflowReuseIdentifier) with kind: \(overflowKind)")
        }

        let remainingItems = layout.remainingItems
        let title = string(for: remainingItems)

        configure(cell: cell, with: title, isMeow: true)


        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(toggleExpanded))
        cell.addGestureRecognizer(tapGestureRecognizer)

        return cell
    }

    @objc func toggleExpanded(_ sender: ReaderInterestsCollectionViewCell) {
        guard let layout = collectionView.collectionViewLayout as? ReaderInterestsCollectionViewFlowLayout else {
            return
        }

        layout.isExpanded = !layout.isExpanded
        layout.invalidateLayout()

        WPAnalytics.track(.readerChipsMoreToggled)

        delegate?.coordinator(self, didChangeState: layout.isExpanded ? .expanded: .collapsed)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return sizeForCell(title: topics[indexPath.row])
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // We create a remote service because we need to convert the topic to a slug an this contains the
        // code to do that
        let service = ReaderTopicServiceRemote(wordPressComRestApi: WordPressComRestApi.defaultApi())
        guard let topic = service.slug(forTopicName: topics[indexPath.row]) else {
            return
        }

        delegate?.coordinator(self, didSelectTopic: topic)
    }
}

extension ReaderTopicCollectionViewCoordinator: ReaderInterestsCollectionViewFlowLayoutDelegate {
    func collectionView(_ collectionView: UICollectionView, layout: ReaderInterestsCollectionViewFlowLayout, sizeForOverflowItem at: IndexPath, remainingItems: Int?) -> CGSize {

        let title = string(for: remainingItems)
        return sizeForCell(title: title)
    }
}
