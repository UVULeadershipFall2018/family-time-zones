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
    @State private var useLocationTracking = false
    @State private var selectedAppleIdEmail: String?
    @State private var hasAvailabilityWindow = false
    @State private var availableStartTime = 0
    @State private var availableEndTime = 24
    @State private var myTimeZone = TimeZone.current.identifier
    @State private var showLocationSharingSheet = false
    @State private var showEditSheet = false
    @State private var messageConfirmationText = ""
    
    let availableColors = ["blue", "green", "red", "purple", "orange", "pink", "yellow"]
    
    var filteredTimeZones: [String] {
        return TimeZone.knownTimeZoneIdentifiers.filter { identifier in
            searchText.isEmpty || identifier.localizedCaseInsensitiveContains(searchText)
        }.sorted()
    }
    
    func formatTimeZoneForDisplay(_ identifier: String) -> String {
        guard let timeZone = TimeZone(identifier: identifier) else {
            return identifier
        }
        
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "z"
        let abbreviation = formatter.string(from: Date())
        
        let offset = timeZone.secondsFromGMT() / 3600
        let offsetString = offset >= 0 ? "GMT+\(offset)" : "GMT\(offset)"
        
        return "\(identifier.replacingOccurrences(of: "_", with: " ")) (\(offsetString), \(abbreviation))"
    }
    
    var body: some View {
        NavigationView {
            List {
                // Location Permission Section
                Section(header: Text("Location Services")) {
                    if !viewModel.locationManager.isLocationServicesEnabled {
                        HStack {
                            Image(systemName: "location.slash.fill")
                                .foregroundColor(.red)
                            Text("Location Services Disabled")
                                .foregroundColor(.red)
                        }
                        
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Open Settings")
                        }
                    } else {
                        switch viewModel.locationManager.permissionStatus {
                        case .notDetermined:
                            HStack {
                                Image(systemName: "location.circle")
                                    .foregroundColor(.orange)
                                Text("Location permission not determined")
                            }
                            
                            Button(action: {
                                viewModel.locationManager.requestLocationPermission()
                            }) {
                                Text("Allow Location Access")
                            }
                            
                        case .restricted, .denied:
                            HStack {
                                Image(systemName: "location.slash.fill")
                                    .foregroundColor(.red)
                                Text("Location access denied")
                                    .foregroundColor(.red)
                            }
                            
                            Button(action: {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("Open Settings to Enable Location")
                            }
                            
                        case .authorizedWhenInUse:
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.green)
                                Text("Location access granted when app is in use")
                                    .foregroundColor(.green)
                            }
                            
                            Button(action: {
                                viewModel.locationManager.requestAlwaysPermission()
                            }) {
                                Text("Request Background Location Access")
                            }
                            
                        case .authorizedAlways:
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.green)
                                Text("Full location access granted")
                                    .foregroundColor(.green)
                            }
                            
                        @unknown default:
                            Text("Unknown location permission status")
                        }
                    }
                }
                
                // My Location Section
                Section(header: Text("My Location")) {
                    Toggle("Use My Location for Time Zone", isOn: Binding(
                        get: { viewModel.useMyLocationForTimeZone },
                        set: { viewModel.setUseMyLocationForTimeZone($0) }
                    ))
                    
                    if viewModel.useMyLocationForTimeZone {
                        HStack {
                            Text("Current Time Zone:")
                            Spacer()
                            Text(formatTimeZoneForDisplay(viewModel.myTimeZone))
                                .foregroundColor(.secondary)
                        }
                        
                        // Only show this if location permission is granted
                        if viewModel.locationManager.permissionStatus == .authorizedWhenInUse || 
                           viewModel.locationManager.permissionStatus == .authorizedAlways {
                            Button(action: {
                                viewModel.updateUserTimeZone()
                            }) {
                                Text("Update My Time Zone")
                            }
                        }
                    } else {
                        Picker("My Time Zone", selection: Binding(
                            get: { myTimeZone },
                            set: { 
                                myTimeZone = $0
                                viewModel.setManualTimeZone($0)
                            }
                        )) {
                            ForEach(filteredTimeZones, id: \.self) { timeZone in
                                Text(formatTimeZoneForDisplay(timeZone)).tag(timeZone)
                            }
                        }
                    }
                }
                
                // Location Sharing Section
                Section(header: Text("Location Sharing")) {
                    Button(action: {
                        showLocationSharingSheet = true
                    }) {
                        Label("Manage Location Sharing", systemImage: "location.fill")
                    }
                    
                    if !viewModel.getLocationSharingContacts().isEmpty {
                        ForEach(viewModel.getLocationSharingContacts()) { contact in
                            HStack {
                                Text(contact.name)
                                Spacer()
                                if let lastUpdate = contact.lastLocationUpdate {
                                    Text("Updated \(formatRelativeTime(lastUpdate))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Pending")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }
                
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
        .sheet(isPresented: $showEditSheet) {
            ContactEditView(contact: $editingContact, isNewContact: editingContact.id.isEmpty, viewModel: viewModel, onSave: saveContact, onDelete: deleteContact)
        }
        .sheet(isPresented: $showLocationSharingSheet) {
            LocationSharingInvitationView(locationManager: viewModel.locationManager)
        }
        .alert(isPresented: $showingMessageConfirmation) {
            Alert(
                title: Text("Send Message"),
                message: Text(messageConfirmationText),
                primaryButton: .default(Text("Send")) {
                    sendMessageToContact()
                },
                secondaryButton: .cancel()
            )
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
                
                Section(header: Text("Location Tracking")) {
                    Toggle("Use Location for Time Zone", isOn: $useLocationTracking)
                    
                    if useLocationTracking {
                        Text("Select the person who shares their location with you:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        FindMyContactPicker(viewModel: viewModel, selectedEmail: $selectedAppleIdEmail)
                    }
                }
                
                Section(header: Text("Availability Window")) {
                    Toggle("Set Availability Hours", isOn: $hasAvailabilityWindow)
                    
                    if hasAvailabilityWindow {
                        HStack {
                            Text("Start Time")
                            Spacer()
                            TimePicker(minutes: $availableStartTime)
                        }
                        
                        HStack {
                            Text("End Time")
                            Spacer()
                            TimePicker(minutes: $availableEndTime)
                        }
                        
                        Text("Contact's local time (\(formatTimeZoneForDisplay(newContactTimeZone)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        let isCurrentlyAvailable = checkAvailability()
                        HStack {
                            Text("Current Status:")
                            Text(isCurrentlyAvailable ? "Available" : "Unavailable")
                                .foregroundColor(isCurrentlyAvailable ? .green : .red)
                                .fontWeight(.bold)
                        }
                    }
                }
                
                Section(header: Text("Time Zone")) {
                    if !useLocationTracking {
                        TextField("Search Time Zones", text: $searchText)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        timeZoneListView
                    } else if let email = selectedAppleIdEmail, 
                              let contact = viewModel.locationManager.locationSharedContacts.first(where: { $0.email == email }),
                              let timeZone = contact.timeZone {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(formatTimeZoneForDisplay(timeZone.identifier))
                                    .fontWeight(.bold)
                                Text("Automatically set based on location")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                        }
                    } else if useLocationTracking {
                        Text("Select a contact who shares their location with you")
                            .foregroundColor(.secondary)
                    }
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
                .disabled(newContactName.isEmpty || (useLocationTracking && selectedAppleIdEmail == nil))
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
        // Get the correct time zone based on selection
        var timeZoneIdentifier = newContactTimeZone
        if useLocationTracking,
           let email = selectedAppleIdEmail,
           let contact = viewModel.locationManager.locationSharedContacts.first(where: { $0.email == email }),
           let timeZone = contact.timeZone {
            timeZoneIdentifier = timeZone.identifier
        }
        
        if isEditingContact, let index = editingContactIndex {
            // Update the existing contact
            var updatedContact = viewModel.contacts[index]
            updatedContact.name = newContactName
            updatedContact.timeZoneIdentifier = timeZoneIdentifier
            updatedContact.color = newContactColor
            updatedContact.useLocationForTimeZone = useLocationTracking
            updatedContact.email = selectedAppleIdEmail ?? ""
            // Handle availability window
            updatedContact.availableStartTime = hasAvailabilityWindow ? availableStartTime : 0
            updatedContact.availableEndTime = hasAvailabilityWindow ? availableEndTime : 24 * 60
            
            viewModel.contacts[index] = updatedContact
            viewModel.saveContacts()
        } else {
            // Add new contact
            let newContact = Contact(
                name: newContactName,
                timeZoneIdentifier: timeZoneIdentifier,
                color: newContactColor,
                useLocationTracking: useLocationTracking,
                appleIdEmail: selectedAppleIdEmail,
                lastLocationUpdate: nil,
                hasAvailabilityWindow: hasAvailabilityWindow,
                availableStartTime: hasAvailabilityWindow ? availableStartTime : 0,
                availableEndTime: hasAvailabilityWindow ? availableEndTime : 24 * 60
            )
            viewModel.contacts.append(newContact)
            viewModel.saveContacts()
        }
        
        // Force widget refresh
        WidgetCenter.shared.reloadAllTimelines()
        print("App: Manually refreshed widget timelines after saving contact")
        
        showingAddContact = false
        resetForm()
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
        useLocationTracking = contact.useLocationForTimeZone
        selectedAppleIdEmail = contact.email
        hasAvailabilityWindow = contact.hasAvailabilityWindow
        availableStartTime = contact.availableStartTime
        availableEndTime = contact.availableEndTime
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
        useLocationTracking = false
        selectedAppleIdEmail = nil
        hasAvailabilityWindow = false
        availableStartTime = 8 * 60 // 8:00 AM
        availableEndTime = 22 * 60 // 10:00 PM
        myTimeZone = TimeZone.current.identifier
    }
    
    private func checkAvailability() -> Bool {
        // Create a temporary contact with the current form values to check availability
        let tempContact = Contact(
            name: newContactName,
            timeZoneIdentifier: newContactTimeZone,
            color: newContactColor,
            useLocationTracking: false,
            appleIdEmail: nil as String?,
            lastLocationUpdate: nil as Date?,
            hasAvailabilityWindow: hasAvailabilityWindow,
            availableStartTime: availableStartTime,
            availableEndTime: availableEndTime
        )
        
        return tempContact.isAvailable()
    }
    
    // Helper function to format relative times
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ContactRow: View {
    let contact: Contact
    @State private var currentTime = Date()
    @State private var showingMessageConfirmation = false
    @State private var messageText = ""
    @State private var showingMessageComposer = false
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading) {
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
                        
                        if contact.useLocationForTimeZone {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                        
                        if contact.hasAvailabilityWindow {
                            Spacer()
                            availabilityBadge
                        }
                    }
                    
                    HStack {
                        Text(contact.locationName())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if contact.useLocationForTimeZone {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(contact.locationTrackingStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if contact.hasAvailabilityWindow {
                            Spacer()
                            Text(contact.formattedAvailabilityWindow())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    initiateMessage()
                }) {
                    Image(systemName: "message.fill")
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.vertical, 4)
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .alert(isPresented: $showingMessageConfirmation) {
            Alert(
                title: Text("Outside Availability Window"),
                message: Text("\(contact.name) is not available right now. They are usually available between \(contact.formattedAvailabilityWindow()). Would you still like to send a message?"),
                primaryButton: .default(Text("Send Anyway")) {
                    composeMessage()
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showingMessageComposer) {
            MessageComposerView(contact: contact, message: $messageText)
        }
    }
    
    private func initiateMessage() {
        // Check if contact is available
        if contact.hasAvailabilityWindow && !contact.isAvailable() {
            // Show confirmation alert if outside availability window
            showingMessageConfirmation = true
        } else {
            // Directly proceed to messaging if available
            composeMessage()
        }
    }
    
    private func composeMessage() {
        showingMessageComposer = true
    }
    
    private var availabilityBadge: some View {
        let isAvailable = contact.isAvailable(at: currentTime)
        return Text(isAvailable ? "Available" : "Unavailable")
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isAvailable ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
            .foregroundColor(isAvailable ? .green : .red)
            .cornerRadius(4)
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

struct MessageComposerView: View {
    let contact: Contact
    @Binding var message: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                Text("To: \(contact.name)")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                
                TextEditor(text: $message)
                    .padding()
                    .frame(minHeight: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .padding()
                
                if contact.hasAvailabilityWindow && !contact.isAvailable() {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Note: \(contact.name) is outside their usual availability hours.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationBarTitle("New Message", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Send") {
                    sendMessage()
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(message.isEmpty)
            )
        }
    }
    
    private func sendMessage() {
        // In a real app, this would integrate with messaging APIs
        print("Sending message to \(contact.name): \(message)")
        message = ""
    }
}

// TimePicker component for selecting hours and minutes
struct TimePicker: View {
    @Binding var minutes: Int
    @State private var hourValue: Int
    @State private var minuteValue: Int
    
    init(minutes: Binding<Int>) {
        self._minutes = minutes
        let initialValue = minutes.wrappedValue
        self._hourValue = State(initialValue: initialValue / 60)
        self._minuteValue = State(initialValue: initialValue % 60)
    }
    
    var body: some View {
        HStack {
            Picker("Hour", selection: $hourValue) {
                ForEach(0..<24) { hour in
                    Text("\(hour)").tag(hour)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(width: 60)
            .clipped()
            .onChange(of: hourValue) { newValue in
                minutes = (newValue * 60) + minuteValue
            }
            
            Text(":")
                .font(.headline)
            
            Picker("Minute", selection: $minuteValue) {
                ForEach(0..<60) { minute in
                    Text(String(format: "%02d", minute)).tag(minute)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(width: 60)
            .clipped()
            .onChange(of: minuteValue) { newValue in
                minutes = (hourValue * 60) + newValue
            }
        }
    }
}

#Preview {
    ContentView()
} 