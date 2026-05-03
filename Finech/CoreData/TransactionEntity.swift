import CoreData

@objc(TransactionEntity)
final class TransactionEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var amount: Double
    @NSManaged var currency: String?
    @NSManaged var type: String?
    @NSManaged var category: String?
    @NSManaged var note: String?
    @NSManaged var date: Date?
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var hasLocation: Bool
}
