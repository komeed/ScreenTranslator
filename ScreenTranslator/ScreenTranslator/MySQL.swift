/*
 Why do I need a mysql to store pinyin if I have translation framework?
 At this time, I don't think Apple's translation framework has pronounciation functionalities. So, I have to use a mysql to store a database of the chinese dictionary, and iterate through each character and retrieve the pinyin of that character.
 Unfortunately, because of 多音字 most words have more than one pronounciations, which makes the pinyin not very precise.
 
 Instead of using Apple's built in SQLite3 package I outsourced a SQLite package that makes everything generally more simplified and easier to use
 
 */

import Foundation
import SQLite

struct MySequel{
    //I need language
    func access(word: String, language: String) -> ChineseData?{
        var traditional = false
        if(language == "zh-Hant"){
            traditional = true
        }
        do{
            if let bundlePath = Bundle.main.path(forResource: "chinese_dict", ofType: "db") {
                let dbFilePath = URL(fileURLWithPath: bundlePath)
                let db = try Connection(dbFilePath.path)
                let entries = Table("words")
                let ttext = SQLite.Expression<String>("tword")
                let stext = SQLite.Expression<String>("sword")
                let pinyin = SQLite.Expression<String>("pinyin")
                var upinyin:String = ""
                for c in word {
                    let filteredEntries = entries.filter((traditional ? ttext : stext) == c.description)
                    var tempPinyin = ""
                    for entry in try db.prepare(filteredEntries){
                        tempPinyin = entry[pinyin]
                    }
                    upinyin += tempPinyin + " "
                }
                return ChineseData(pinyin: upinyin)
            } else {
                print("Error: Database file not found in bundle")
            }
        }
        catch{
             print("error: " + String(describing: error))
            return nil
        }
        return nil
    }
}


struct ChineseData{
    var pinyin: String
    init(pinyin: String){
        self.pinyin = pinyin
    }
}
