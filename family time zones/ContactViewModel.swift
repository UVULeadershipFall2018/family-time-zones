import Foundation
import SwiftUI
import Combine
import WidgetKit

class ContactViewModel: ObservableObject {
    @Published var contacts: [Contact] = []
    
    init() {
        loadContacts()
    }
    
    func addContact(name: String, timeZoneIdentifier: String, color: String) {
        let newContact = Contact(
            name: name,
            timeZoneIdentifier: timeZoneIdentifier,
            color: color
        )
        contacts.append(newContact)
        saveContacts()
    }
    
    func updateContact(at index: Int, name: String, timeZoneIdentifier: String, color: String) {
        guard index >= 0 && index < contacts.count else { return }
        
        // Preserve the existing ID but update all other properties
        let id = contacts[index].id
        contacts[index] = Contact(
            id: id,
            name: name,
            timeZoneIdentifier: timeZoneIdentifier,
            color: color
        )
        saveContacts()
    }
    
    func removeContact(at indices: IndexSet) {
        contacts.remove(atOffsets: indices)
        saveContacts()
        
        // Force widget refresh
        WidgetCenter.shared.reloadAllTimelines()
        print("Removed contact and refreshed widget")
    }
    
    func moveContact(from source: IndexSet, to destination: Int) {
        contacts.move(fromOffsets: source, toOffset: destination)
        saveContacts()
        
        // Force widget refresh
        WidgetCenter.shared.reloadAllTimelines()
        print("Reordered contacts and refreshed widget")
    }
    
    private func saveContacts() {
        SharedStorage.saveContacts(contacts)
    }
    
    private func loadContacts() {
        contacts = SharedStorage.loadContacts()
    }
    
    // Helper function to get available time zones
    func availableTimeZones() -> [String] {
        return TimeZone.knownTimeZoneIdentifiers.sorted()
    }
} 