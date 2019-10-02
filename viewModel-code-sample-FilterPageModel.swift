import ReactiveKit

public protocol FilterPageModeller {
    var title: String { get }
    var components: Property<[FilterCellModeller]> { get }
    var searchQuery: Property<String?> { get }
    
    func dropFilter()
    func close()
}

final class FilterPageModel: FilterPageModeller {
    
    let title = "Фильтр"
    let components = Property<[FilterCellModeller]>([])
    let searchQuery = Property<String?>(nil)
    
    private let router: Router
    private let originalComponents: Set<ProductComponent>
    private let filterStorage: ProductsFilterStorage
    private let cityId: Int
    private let categoryId: Int
    private let rBag = DisposeBag()
    
    init(
        categoryId: Int,
        cityStorage: CurrentCityStorage,
        productStorage: ProductStorage,
        filterStorage: ProductsFilterStorage,
        router: Router
        ) {
        self.router = router
        cityId = cityStorage.currentCity!.id
        self.categoryId = categoryId
        self.filterStorage = filterStorage
        
        if let products = productStorage.products(from: cityId, with: categoryId) {
            originalComponents = Set(products.reduce([ProductComponent]()) { $0 + $1.components })
        } else {
            originalComponents = Set()
        }
        
        searchQuery
            .map { [unowned self] in (self.originalComponents, $0) }
            .map(FilterPageModel.filter)
            .map { [unowned self] (components: Set<ProductComponent>) -> [FilterCellModeller] in
                components.sorted(by: { $0.title < $1.title }).map {
                    FilterCellModel(component: $0, cityId: self.cityId, categoryId: self.categoryId, filterStorage: self.filterStorage)
                }
            }
            .observeNext { [unowned self] in
                self.components.value = $0
            }
            .dispose(in: rBag)
    }
    
    func dropFilter() {
        let filter = filterStorage.filter(cityId, categoryId: categoryId)
        filterStorage.empty(filter: filter)
    }
    
    func close() {
        router.showPreviousPage()
    }
    
    private static func filter(_ components: Set<ProductComponent>, query: String?) -> Set<ProductComponent> {
        guard let query = query?.trim().lowercased(), query.length > 1 else { return components }
        let array = components.filter { $0.title.lowercased().contains(query) }
        return Set(array)
    }
}
