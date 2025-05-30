import Foundation

// A simple utility to load YAML files without external dependencies
class YamlUtil {
    static func loadCityTimezoneMap(fromFile filename: String = "cities_timezones") -> [String: String] {
        var result: [String: String] = [:]
        
        // Get the path to the YAML file
        guard let path = Bundle.main.path(forResource: filename, ofType: "yaml") else {
            print("Could not find \(filename).yaml file in the bundle")
            return result
        }
        
        do {
            // Read the YAML file contents
            let yamlString = try String(contentsOfFile: path, encoding: .utf8)
            
            // Process the YAML manually since it's a simple key-value structure
            let lines = yamlString.components(separatedBy: .newlines)
            
            for line in lines {
                // Skip comments and empty lines
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                    continue
                }
                
                // Parse key-value pairs (City: Timezone)
                let components = trimmedLine.components(separatedBy: ":")
                if components.count >= 2 {
                    let key = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !key.isEmpty && !value.isEmpty {
                        result[key.lowercased()] = value
                    }
                }
            }
        } catch {
            print("Error loading YAML file: \(error)")
        }
        
        return result
    }
} 