
import UIKit
import ReactiveKit
import Bond
import CocoaExtensions
import Device

public final class MainMenuPage: UIViewController, UITableViewDelegate {
    
    let viewModel: MainMenuPageModeller
    
    var dBag = DisposeBag()
    
    let tvMargin: CGFloat = 10.0
    
    let menuItemCellId = "menuItemCellId"
    let specialOfferCellId = "specialOfferCellId"
    
    var preloaderView: TableViewPreloader!
    lazy var selectedIndexPath: SafeSignal<IndexPath?> = selectedIndexPathSubject.toSignal()
    lazy var selectedIndex: SafeSignal<Int?> = selectedIndexPath.map { $0?.item }
    
    private let selectedIndexPathSubject = SafePublishSubject<IndexPath?>()
    
    private typealias SectionMetadata = (type: MainMenuPageCategorySection.SectionType, title: String)
    
    private let categories = MutableObservableArray2D(Array2D<SectionMetadata, MainMenuItemCellModeller>(sectionsWithItems: [
        ]))
    private let isCompactSize = Device.size() < .screen4_7Inch
    
    init(viewModel: MainMenuPageModeller, searchButton: UIBarButtonItem) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        self.title = viewModel.title
        self.navigationItem.rightBarButtonItem = searchButton
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: UITableView.Style.grouped)
        tableView.allowsSelection = true
        tableView.allowsMultipleSelection = false
        tableView.backgroundColor = ASStyle.color.grayWindowBackground
        tableView.estimatedSectionHeaderHeight = 80
        tableView.separatorStyle = .none
        tableView.tableFooterView = UIView()
        tableView.sectionFooterHeight = 0
        tableView.register(MainMenuItemCell.self, forCellReuseIdentifier: menuItemCellId)
        tableView.register(MainMenuSpecialOfferCell.self, forCellReuseIdentifier: specialOfferCellId)
        return tableView
    }()
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(60)) { [weak self] in
            self?.view.addSubview(self!.preloaderView)
            self?.preloaderView.snp.makeConstraints {
                $0.size.equalTo(self!.view)
                $0.center.equalTo(self!.view)
            }
        }
        view.backgroundColor = ASStyle.color.grayWindowBackground
        preloaderView = TableViewPreloader()
        preloaderView.isHidden = true
        preloaderView.contentView.backgroundColor = tableView.backgroundColor
        setupTableView()
        bindViews()
    }
    
    func bindViews() {
        viewModel.categories
            .observeNext { [weak categories] in
                let sections = $0
                    .map { (($0.type, $0.title), $0.categories) as (SectionMetadata, [MainMenuItemCellModeller]) }
                    .map{
                        ($0.0, $0.1)
                }
                let array = Array2D<SectionMetadata, MainMenuItemCellModeller>(sectionsWithItems: sections)
                categories?.replace(with: array)
            }
            .dispose(in: reactive.bag)
        
        self.categories.bind(to: tableView, animated: false, rowAnimation: UITableView.RowAnimation.automatic) { [unowned self] (categories, path, tableView) -> UITableViewCell in
            
            let cellModel = categories
                .children[path.section]
                .children[path.item].item
            
            guard let sectionMetadata = categories
                .children[path.section]
                .section?.metadata else {
                    return UITableViewCell()
            }
            
            switch sectionMetadata.type {
            case .specialOffers:
                let cell: MainMenuSpecialOfferCell = tableView.dequeueReusableCell(withIdentifier: self.specialOfferCellId, for: path) as! MainMenuSpecialOfferCell
                cell.viewModel = cellModel
                return cell
            case .main:
                let cell: MainMenuItemCell = tableView.dequeueReusableCell(withIdentifier: self.menuItemCellId, for: path) as! MainMenuItemCell
                cell.viewModel = cellModel
                return cell
            }
        }
        
        selectedIndexPath
            .observeOn(.main)
            .observeNext { [weak self] temp in
                self?.viewModel.showCategory(temp!)
            }.dispose(in: dBag)
        
        viewModel.isBusy.map(!).bind(to: preloaderView.reactive.isHidden)
        self.tableView.reactive.delegate.forwardTo = self
    }
    
    
    private func setupTableView(){
        view.addSubview(tableView)
        tableView.snp.makeConstraints{
            $0.leading.trailing.top.bottom.equalToSuperview()
        }
        
        if #available(iOS 11.0, *) {
            tableView.contentInsetAdjustmentBehavior = .never
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }
        
        let margin: CGFloat = self.isCompactSize ? 7 : 12
        let btmHeight = self.tabBarController?.tabBar.height ?? 0
        tableView.contentInset = UIEdgeInsets(top: margin, left: 0, bottom: btmHeight - margin, right: 0)
        tableView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 85, right: 0)
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.allowsSelection = false
        selectedIndexPathSubject.next(indexPath)
        tableView.allowsSelection = true
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension MainMenuPage: UITableViewDataSource {
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let section = categories.collection.children[indexPath.section].section?.metadata
        guard let sectionType = section?.type else { return 0 }
        let mainMenuItemCellHeight: CGFloat = self.isCompactSize ? 80 : 95
        return sectionType == .specialOffers ? 54 + tvMargin: mainMenuItemCellHeight + tvMargin
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return UITableViewCell()
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let frame = CGRect(x: 0, y: 0, width: tableView.frame.width, height: 42)
        let headerView = UIView(frame: frame)
        let titleLabel = UILabel()
        titleLabel.apply {
            $0.font = ASStyle.font(.heavy, size: 13)
            $0.textColor = ASStyle.color.grayLightText
            $0.backgroundColor = .clear
        }
        let headerText = self.categories.collection.children[section].section?.metadata.title
        titleLabel.text = headerText
        headerView.addSubview(titleLabel)
        let margin: CGFloat = self.isCompactSize ? 7 : 12
        titleLabel.frame = CGRect(x: margin, y: 42 - 15 - 2 - margin, width: tableView.frame.width, height: 15)
        titleLabel.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        return headerView
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard self.categories.collection.children[section].children.count > 1 else { return 0 }
        return 42
    }
    
    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
}
