//
//  ContentView.swift
//  family time zones
//
//  Created by TJ Nielsen on 4/12/25.
//

import SwiftUI
import WidgetKit

struct ContentView: View {
    @StateObject private var viewModel = ContactViewModel()
    @State private var showingAddContact = false
    @State private var isEditingContact = false
    @State private var editingContactIndex: Int?
    @State private var newContactName = ""
    @State private var newContactTimeZone = TimeZone.current.identifier
    @State private var newContactColor = "blue"
    @State private var searchText = ""
    
    let availableColors = ["blue", "green", "red", "purple", "orange", "pink", "yellow"]
    
    var body: some View {
        NavigationView {
            contactListView
                .navigationTitle("Family Time Zones")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            prepareForAdding()
                        } label: {
                            Label("Add Contact", systemImage: "plus")
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton()
                    }
                }
                .sheet(isPresented: $showingAddContact) {
                    contactFormView
                }
        }
    }
    
    private var contactListView: some View {
        List {
            ForEach(viewModel.contacts) { contact in
                ContactRow(contact: contact)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let index = viewModel.contacts.firstIndex(where: { $0.id == contact.id }) {
                            prepareForEditing(contactIndex: index)
                        }
                    }
            }
            .onDelete(perform: viewModel.removeContact)
            .onMove(perform: viewModel.moveContact)
        }
    }
    
    private var contactFormView: some View {
        NavigationView {
            Form {
                Section(header: Text("Name")) {
                    TextField("Contact Name", text: $newContactName)
                }
                
                Section(header: Text("Color")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 10) {
                        ForEach(availableColors, id: \.self) { color in
                            colorCircleView(for: color)
                        }
                    }
                    .padding(.vertical, 5)
                }
                
                Section(header: Text("Time Zone")) {
                    TextField("Search Time Zones", text: $searchText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    timeZoneListView
                }
            }
            .navigationTitle(isEditingContact ? "Edit Contact" : "Add New Contact")
            .navigationBarItems(
                leading: Button("Cancel") {
                    showingAddContact = false
                    resetForm()
                },
                trailing: Button(isEditingContact ? "Save" : "Add") {
                    saveContactAction()
                }
                .disabled(newContactName.isEmpty)
            )
        }
    }
    
    private var timeZoneListView: some View {
        List {
            ForEach(filteredTimeZones, id: \.self) { timeZone in
                timeZoneRowView(for: timeZone)
            }
        }
    }
    
    private func timeZoneRowView(for timeZone: String) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(formatTimeZoneForDisplay(timeZone))
                    .fontWeight(newContactTimeZone == timeZone ? .bold : .regular)
                
                timeZoneDetailsView(for: timeZone)
            }
            
            Spacer()
            
            if newContactTimeZone == timeZone {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            newContactTimeZone = timeZone
        }
    }
    
    private func timeZoneDetailsView(for timeZone: String) -> some View {
        HStack {
            let tz = TimeZone(identifier: timeZone) ?? TimeZone.current
            let formatter = DateFormatter()
            formatter.timeZone = tz
            formatter.timeStyle = .short
            
            return Group {
                Text(formatter.string(from: Date()))
                    .font(.caption)
                
                Text(getTimeOffset(for: timeZone))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func colorCircleView(for color: String) -> some View {
        Circle()
            .fill(colorFromString(color))
            .frame(width: 40, height: 40)
            .overlay(
                Circle()
                    .stroke(Color.primary, lineWidth: newContactColor == color ? 2 : 0)
            )
            .padding(5)
            .onTapGesture {
                newContactColor = color
            }
    }
    
    // Helper function to convert string to Color
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        case "yellow": return .yellow
        case "gray", "grey": return .gray
        default: return .blue
        }
    }
    
    private func saveContactAction() {
        if isEditingContact, let index = editingContactIndex {
            viewModel.updateContact(
                at: index,
                name: newContactName,
                timeZoneIdentifier: newContactTimeZone,
                color: newContactColor
            )
        } else {
            viewModel.addContact(
                name: newContactName,
                timeZoneIdentifier: newContactTimeZone,
                color: newContactColor
            )
        }
        
        // Force widget refresh
        WidgetCenter.shared.reloadAllTimelines()
        print("App: Manually refreshed widget timelines after saving contact")
        
        showingAddContact = false
        resetForm()
    }
    
    private var filteredTimeZones: [String] {
        // Add common US time zones first
        let allTimeZones = viewModel.availableTimeZones()
        
        if searchText.isEmpty {
            // Add US time zones at the top when no search term is entered
            return commonUsTimeZones() + allTimeZones.filter { !isCommonUsTimeZone($0) }
        } else {
            let searchLower = searchText.lowercased()
            
            // Search by display name and common aliases
            return allTimeZones.filter { timeZone in
                let displayName = formatTimeZoneForDisplay(timeZone).lowercased()
                if displayName.contains(searchLower) {
                    return true
                }
                
                // Check for common aliases
                return timeZoneAliasMatches(timeZone: timeZone, searchText: searchLower)
            }
        }
    }
    
    private func isCommonUsTimeZone(_ identifier: String) -> Bool {
        let commonZones = ["America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles", "America/Phoenix", "America/Anchorage", "Pacific/Honolulu"]
        return commonZones.contains(identifier)
    }
    
    private func commonUsTimeZones() -> [String] {
        // Most common US time zones for quick access
        return [
            "America/New_York",     // Eastern
            "America/Chicago",      // Central
            "America/Denver",       // Mountain (includes Salt Lake City, Utah)
            "America/Phoenix",      // Arizona (Mountain without DST)
            "America/Los_Angeles",  // Pacific (includes Portland)
            "America/Anchorage",    // Alaska
            "Pacific/Honolulu"      // Hawaii
        ]
    }
    
    private func timeZoneAliasMatches(timeZone: String, searchText: String) -> Bool {
        // Map common location names to time zone identifiers
        let aliases: [String: [String]] = [
            "america/new_york": ["eastern", "est", "edt", "east coast"],
            "america/chicago": ["central", "cst", "cdt"],
            "america/denver": ["mountain", "mst", "mdt", "utah", "salt lake", "salt lake city", "colorado"],
            "america/phoenix": ["arizona", "mst"],
            "america/los_angeles": ["pacific", "pst", "pdt", "west coast", "portland", "oregon", "california"],
            "america/anchorage": ["alaska", "akst", "akdt"],
            "pacific/honolulu": ["hawaii", "hst", "hdt"]
        ]
        
        let timeZoneLower = timeZone.lowercased()
        if let aliasesForZone = aliases[timeZoneLower] {
            return aliasesForZone.contains { alias in
                alias.contains(searchText)
            }
        }
        
        // Also check if search term matches a known alias
        for (identifier, aliasesArray) in aliases {
            if aliasesArray.contains(where: { $0.contains(searchText) }) {
                return timeZoneLower == identifier
            }
        }
        
        return false
    }
    
    private func formatTimeZoneForDisplay(_ identifier: String) -> String {
        // Special handling for US time zones to show common names
        let usTimeZoneNames: [String: String] = [
            "America/New_York": "Eastern Time (New York)",
            "America/Chicago": "Central Time (Chicago)",
            "America/Denver": "Mountain Time (Denver, Salt Lake City)",
            "America/Phoenix": "Mountain Time - No DST (Phoenix)",
            "America/Los_Angeles": "Pacific Time (Los Angeles, Portland)",
            "America/Anchorage": "Alaska Time (Anchorage)",
            "Pacific/Honolulu": "Hawaii Time (Honolulu)"
        ]
        
        if let specialName = usTimeZoneNames[identifier] {
            return specialName
        }
        
        // Fall back to the standard formatting for other time zones
        let components = identifier.split(separator: "/")
        if components.count > 1 {
            let region = components.first?.replacingOccurrences(of: "_", with: " ") ?? ""
            let city = components.last?.replacingOccurrences(of: "_", with: " ") ?? ""
            return "\(city), \(region)"
        }
        return identifier
    }
    
    private func getTimeOffset(for identifier: String) -> String {
        guard let timeZone = TimeZone(identifier: identifier) else { return "" }
        let currentTimeZone = TimeZone.current
        let currentOffset = currentTimeZone.secondsFromGMT()
        let targetOffset = timeZone.secondsFromGMT()
        
        let differenceSeconds = targetOffset - currentOffset
        let hours = abs(differenceSeconds) / 3600
        let minutes = (abs(differenceSeconds) % 3600) / 60
        
        let sign = differenceSeconds >= 0 ? "+" : "-"
        return "\(sign)\(hours):\(minutes == 0 ? "00" : String(format: "%02d", minutes))"
    }
    
    private func prepareForEditing(contactIndex: Int) {
        let contact = viewModel.contacts[contactIndex]
        newContactName = contact.name
        newContactTimeZone = contact.timeZoneIdentifier
        newContactColor = contact.color
        editingContactIndex = contactIndex
        isEditingContact = true
        showingAddContact = true
    }
    
    private func prepareForAdding() {
        isEditingContact = false
        editingContactIndex = nil
        resetForm()
        showingAddContact = true
    }
    
    private func resetForm() {
        newContactName = ""
        newContactTimeZone = TimeZone.current.identifier
        newContactColor = "blue"
        searchText = ""
        isEditingContact = false
        editingContactIndex = nil
    }
}

struct ContactRow: View {
    let contact: Contact
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack {
            Circle()
                .fill(colorFromString(contact.color))
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.headline)
                
                HStack {
                    Text(contact.formattedTime(at: currentTime))
                        .font(.title2)
                        .monospacedDigit()
                    
                    Text(contact.timeOffset())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(contact.locationName())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    // Helper function to convert string to Color
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        case "yellow": return .yellow
        case "gray", "grey": return .gray
        default: return .blue
        }
    }
}

#Preview {
    ContentView()
} 