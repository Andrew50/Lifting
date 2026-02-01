import SQLite

let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! // 1. Typo + need .first!
let db = try Connection("\(documentsPath)/exercises.db")

let exercises = Table("exercises")
let id = Expression<Int64>("id")
let name = Expression<String>("name")

// Creating Table
try db.run(exercises.create(ifNotExists: true) { t in
    t.column(id, primaryKey: .autoincrement)
    t.column(name, unique: true)
})

// Reading through JSON and insert
if let path = Bundle.main.path(forResource: "exercises", ofType: "json"),
   let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
   let json = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] { // 2. Missing opening brace
   
   for exercise in json {
        if let exerciseName = exercise["Exercise Name"] {
            try? db.run(exercises.insert(name <- exerciseName))
        }
   }
}