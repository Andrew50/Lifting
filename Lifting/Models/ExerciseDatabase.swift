import SQLite
import Foundation

class ExerciseDatabase {
    static let shared = ExerciseDatabase()
    var db: Connection?
    
    let exercises = Table("exercises")
    let id = Expression<Int64>("id")
    let name = Expression<String>("name")
    
    // UserDefaults key for version tracking
    let versionKey = "exerciseDatabaseVersion"
    
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
            
            // Check version and update if needed
            checkAndUpdateDatabase()
            
        } catch {
            print("Database setup error: \(error)")
        }
    }
    
    func checkAndUpdateDatabase() {
        guard let jsonVersion = getJSONVersion() else {
            print("Could not read JSON version")
            return
        }
        
        let savedVersion = UserDefaults.standard.string(forKey: versionKey) ?? "0.0.0"
        
        print("Saved version: \(savedVersion)")
        print("JSON version: \(jsonVersion)")
        
        if jsonVersion != savedVersion {
            print("Version mismatch! Updating database...")
            clearAndReloadDatabase()
            UserDefaults.standard.set(jsonVersion, forKey: versionKey)
            print("Database updated to version \(jsonVersion)")
        } else {
            print("Database is up to date (version \(jsonVersion))")
        }
    }
    
    func getJSONVersion() -> String? {
        guard let path = Bundle.main.path(forResource: "strong", ofType: "json"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["version"] as? String else {
            return nil
        }
        return version
    }
    
    func clearAndReloadDatabase() {
        guard let db = db else { return }
        
        do {
            // Clear existing data
            try db.run(exercises.delete())
            print("Cleared old exercises")
            
            // Load new data
            loadExercisesFromJSON()
            
        } catch {
            print("Error updating database: \(error)")
        }
    }
    
    func loadExercisesFromJSON() {
        guard let db = db else { return }
    
        if let path = Bundle.main.path(forResource: "strong", ofType: "json"),
            let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let exerciseList = json["exercises"] as? [[String: String]] {
       
       var count = 0
       for exercise in exerciseList {
            if let exerciseName = exercise["Exercise Name"] {  // Changed this line
                try? db.run(exercises.insert(or: .ignore, name <- exerciseName))
                count += 1
            }
       }
       print("Loaded \(count) exercises into database")
    }
    }
    
    func getAllExercises() -> [String] {
        guard let db = db else { return [] }
        
        var exerciseList: [String] = []
        
        do {
            for exercise in try db.prepare(exercises) {
                exerciseList.append(exercise[name])
            }
            return exerciseList
        } catch {
            print("Query error: \(error)")
            return []
        }
    }
}