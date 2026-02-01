import SQLite

class ExerciseDatabase {
    static let shared = ExerciseDatabase()
    var db: Connection?
    
    let exercises = Table("exercises")
    let id = Expression<Int64>("id")
    let name = Expression<String>("name")
    
    private init() {
        setupDatabase()
    }
    
    func setupDatabase() {
        do {
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
            db = try Connection("\(documentsPath)/exercises.db")
            
            guard let db = db else { return }
            
            // Creating Table
            try db.run(exercises.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(name, unique: true)
            })
            
            // Check if data already exists
            let count = try db.scalar(exercises.count)
            if count == 0 {
                loadExercisesFromJSON()
            }
            
            print("Database setup complete. \(count) exercises loaded.")
            
        } catch {
            print("Database setup error: \(error)")
        }
    }
    
    func loadExercisesFromJSON() {
        guard let db = db else { return }
        
        if let path = Bundle.main.path(forResource: "exercises", ofType: "json"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
           
           for exercise in json {
                if let exerciseName = exercise["Exercise Name"] {
                    try? db.run(exercises.insert(or: .ignore, name <- exerciseName))
                }
           }
        }
    }
}