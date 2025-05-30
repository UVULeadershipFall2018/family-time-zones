//
//  ContentView.swift
//  family time zones
//
//  Created by TJ Nielsen on 4/12/25.
//

import SwiftUI
import WidgetKit
import Contacts
import ContactsUI
import UIKit
import MessageUI

struct ContentView: View {
    @StateObject private var viewModel = ContactViewModel()
    @StateObject private var state = ContentViewState()
    
    // For editing existing contacts
    @State private var isEditingContact = false
    @State private var editingContactIndex: Int?
    @State private var searchText = ""
    @State private var myTimeZone = TimeZone.current.identifier
    @State private var messageConfirmationText = ""
    @State private var showingMessageConfirmation = false
    @State private var messageRecipient: Contact?
    @State private var showingMessageComposer = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, phoneNumber, search
    }
    
    enum ActiveSheet: Identifiable {
        case addContact
        case editContact
        case locationSharing
        case contactPicker
        
        var id: Int {
            switch self {
            case .addContact: return 0
            case .editContact: return 1
            case .locationSharing: return 2
            case .contactPicker: return 3
            }
        }
    }
    
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
                // Contacts Section - Always shown
                contactListView
                
                // Settings Link Section
                Section {
                    NavigationLink(destination: SettingsView(viewModel: viewModel)) {
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(.blue)
                            Text("Settings")
                        }
                    }
                }
            }
            .navigationTitle("Family Time Zones")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarAddButton
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(item: $state.activeSheet) { item in
                switch item {
                case .addContact:
                    contactFormView
                case .editContact:
                    ContactEditView(
                        viewModel: viewModel,
                        isShowing: Binding(
                            get: { state.activeSheet == .editContact },
                            set: { if !$0 { state.activeSheet = nil } }
                        ),
                        isEditing: $isEditingContact,
                        editingIndex: $editingContactIndex,
                        name: $state.newContactName,
                        timeZoneIdentifier: $state.newContactTimeZone,
                        color: $state.newContactColor,
                        useLocationTracking: $state.useLocationTracking,
                        selectedAppleIdEmail: $state.selectedAppleIdEmail,
                        hasAvailabilityWindow: $state.hasAvailabilityWindow,
                        availableStartTime: $state.availableStartTime,
                        availableEndTime: $state.availableEndTime,
                        searchText: $searchText,
                        phoneNumber: $state.newContactPhoneNumber
                    )
                case .locationSharing:
                    LocationSharingInvitationView(
                        viewModel: viewModel,
                        confirmationMessage: $messageConfirmationText
                    )
                case .contactPicker:
                    NavigationView {
                        RealContactPickerViewController(selectedContact: Binding<CNContact?>(
                            get: { nil },
                            set: { contact in
                                if let contact = contact {
                                    // Populate the form with contact info
                                    let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                                    state.newContactName = fullName.isEmpty ? contact.organizationName : fullName
                                    
                                    // Find Apple ID email if available (typically ends with @icloud.com)
                                    if !contact.emailAddresses.isEmpty {
                                        let appleEmail = contact.emailAddresses.first { 
                                            ($0.value as String).lowercased().contains("@icloud.com") 
                                        }
                                        state.selectedAppleIdEmail = (appleEmail?.value as String?) ?? 
                                                                   (contact.emailAddresses.first?.value as String?) ?? ""
                                    }
                                    
                                    // Mark that we've got contact data and are ready to show the form
                                    state.readyToShowForm = true
                                    
                                    // First dismiss this picker
                                    state.activeSheet = nil
                                }
                            }
                        ))
                        .ignoresSafeArea()
                        .navigationBarItems(leading: Button("Cancel") {
                            state.activeSheet = nil
                        })
                    }
                }
            }
            .alert(isPresented: $showingMessageConfirmation) {
                Alert(
                    title: Text("Send Message"),
                    message: Text(messageConfirmationText),
                    primaryButton: .default(Text("Send")) {
                        if let index = editingContactIndex, index < viewModel.contacts.count {
                            let contact = viewModel.contacts[index]
                            sendMessageToContact(contact)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .onReceive(state.$readyToShowForm) { readyToShow in
                if readyToShow {
                    // Only proceed if no sheet is currently showing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if state.activeSheet == nil {
                            state.activeSheet = .addContact
                            state.readyToShowForm = false
                        }
                    }
                }
            }
            .onReceive(viewModel.$showLocationSharingInvitation) { show in
                if show {
                    state.activeSheet = .locationSharing
                    viewModel.showLocationSharingInvitation = false
                }
            }
        }
        .environmentObject(state)
    }
    
    private var contactListView: some View {
        Section(header: Text("Contacts")) {
            ForEach(viewModel.contacts) { contact in
                ContactRow(contact: contact)
                    .contextMenu {
                        Button(action: {
                            if let index = viewModel.contacts.firstIndex(where: { $0.id == contact.id }) {
                                prepareForEditing(contactIndex: index)
                                state.activeSheet = .editContact
                            }
                        }) {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button(action: {
                            if let index = viewModel.contacts.firstIndex(where: { $0.id == contact.id }) {
                                viewModel.contacts.remove(at: index)
                                viewModel.saveContacts()
                            }
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .onTapGesture {
                        if let index = viewModel.contacts.firstIndex(where: { $0.id == contact.id }) {
                            prepareForEditing(contactIndex: index)
                            state.activeSheet = .editContact
                        }
                    }
            }
            .onDelete(perform: deleteContact)
            
            Button(action: {
                prepareForAdding()
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Select Contact to Add")
                }
            }
        }
    }
    
    private var contactFormView: some View {
        Form {
            Section(header: Text("Contact Information")) {
                if !isEditingContact {
                    Text("This contact was selected from your address book. You can customize additional details below.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)
                }
                
                VStack(alignment: .leading) {
                    Text("Contact Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Contact Name", text: $state.newContactName)
                        .font(.body)
                }
                
                VStack(alignment: .leading) {
                    Text("Phone Number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Phone Number", text: $state.newContactPhoneNumber)
                        .font(.body)
                        .keyboardType(.phonePad)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .phoneNumber)
                        .onChange(of: focusedField) { oldValue, newValue in
                            if newValue != .phoneNumber {
                                // Ensure value is saved when focus moves away
                                state.newContactPhoneNumber = state.newContactPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                        .onSubmit {
                            // Explicitly commit the value when focus changes
                            state.newContactPhoneNumber = state.newContactPhoneNumber
                            focusedField = nil
                        }
                }
                
                if !state.selectedAppleIdEmail.isNilOrEmpty {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(state.selectedAppleIdEmail ?? "")
                            .foregroundColor(.secondary)
                    }
                }
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
                Toggle("Use Location for Time Zone", isOn: $state.useLocationTracking)
                
                if state.useLocationTracking {
                    Text("Select the person who shares their location with you:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    FindMyContactPicker(viewModel: viewModel, selectedEmail: $state.selectedAppleIdEmail)
                }
            }
            
            Section(header: Text("Availability Window")) {
                Toggle("Set Availability Hours", isOn: $state.hasAvailabilityWindow)
                
                if state.hasAvailabilityWindow {
                    HStack {
                        Text("Start Time")
                        Spacer()
                        TimePicker(minutes: $state.availableStartTime)
                    }
                    
                    HStack {
                        Text("End Time")
                        Spacer()
                        TimePicker(minutes: $state.availableEndTime)
                    }
                    
                    Text("Contact's local time (\(formatTimeZoneForDisplay(state.newContactTimeZone)))")
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
                if !state.useLocationTracking {
                    TextField("Search Time Zones", text: $searchText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    timeZoneListView
                } else if let email = state.selectedAppleIdEmail, 
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
                } else if state.useLocationTracking {
                    Text("Select a contact who shares their location with you")
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                Button(isEditingContact ? "Cancel Edit" : "Cancel Adding Contact") {
                    state.activeSheet = nil
                    resetForm()
                }
                .foregroundColor(.red)
                
                Button(isEditingContact ? "Save Changes" : "Add to Family Time Zones") {
                    saveContactAction()
                }
                .disabled(state.newContactName.isEmpty || (state.useLocationTracking && state.selectedAppleIdEmail == nil))
            }
        }
        .navigationTitle(isEditingContact ? "Edit Contact" : "New Contact")
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
                    .fontWeight(state.newContactTimeZone == timeZone ? .bold : .regular)
                
                timeZoneDetailsView(for: timeZone)
            }
            
            Spacer()
            
            if state.newContactTimeZone == timeZone {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            state.newContactTimeZone = timeZone
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
                    .stroke(Color.primary, lineWidth: state.newContactColor == color ? 2 : 0)
            )
            .padding(5)
            .onTapGesture {
                state.newContactColor = color
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
        var timeZoneIdentifier = state.newContactTimeZone
        if state.useLocationTracking,
           let email = state.selectedAppleIdEmail,
           let contact = viewModel.locationManager.locationSharedContacts.first(where: { $0.email == email }),
           let timeZone = contact.timeZone {
            timeZoneIdentifier = timeZone.identifier
        }
        
        if isEditingContact, let index = editingContactIndex {
            // Update the existing contact
            var updatedContact = viewModel.contacts[index]
            updatedContact.name = state.newContactName
            updatedContact.timeZoneIdentifier = timeZoneIdentifier
            updatedContact.color = state.newContactColor
            updatedContact.useLocationForTimeZone = state.useLocationTracking
            updatedContact.email = state.selectedAppleIdEmail ?? ""
            updatedContact.phoneNumber = state.newContactPhoneNumber
            // Handle availability window
            updatedContact.availableStartTime = state.hasAvailabilityWindow ? state.availableStartTime : 0
            updatedContact.availableEndTime = state.hasAvailabilityWindow ? state.availableEndTime : 24 * 60
            
            viewModel.contacts[index] = updatedContact
            viewModel.saveContacts()
        } else {
            // Add new contact
            let newContact = Contact(
                name: state.newContactName,
                timeZoneIdentifier: timeZoneIdentifier,
                color: state.newContactColor,
                useLocationTracking: state.useLocationTracking,
                appleIdEmail: state.selectedAppleIdEmail,
                phoneNumber: state.newContactPhoneNumber,
                lastLocationUpdate: nil,
                hasAvailabilityWindow: state.hasAvailabilityWindow,
                availableStartTime: state.hasAvailabilityWindow ? state.availableStartTime : 0,
                availableEndTime: state.hasAvailabilityWindow ? state.availableEndTime : 24 * 60
            )
            viewModel.contacts.append(newContact)
            viewModel.saveContacts()
        }
        
        // Force widget refresh
        WidgetCenter.shared.reloadAllTimelines()
        print("App: Manually refreshed widget timelines after saving contact")
        
        state.activeSheet = nil
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
        state.newContactName = contact.name
        state.newContactTimeZone = contact.timeZoneIdentifier
        state.newContactColor = contact.color
        state.useLocationTracking = contact.useLocationForTimeZone
        state.selectedAppleIdEmail = contact.email
        state.newContactPhoneNumber = contact.phoneNumber
        state.hasAvailabilityWindow = contact.hasAvailabilityWindow
        state.availableStartTime = contact.availableStartTime
        state.availableEndTime = contact.availableEndTime
        editingContactIndex = contactIndex
        isEditingContact = true
    }
    
    private func prepareForAdding() {
        // Reset state and prepare
        isEditingContact = false
        editingContactIndex = nil
        state.resetForm()
        
        // Make sure no sheets are currently presented
        if state.activeSheet != nil {
            state.activeSheet = nil
            
            // Wait to ensure the sheet is fully dismissed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                state.activeSheet = .contactPicker
            }
        } else {
            // No sheet currently presented, show picker immediately
            state.activeSheet = .contactPicker
        }
    }
    
    private func resetForm() {
        state.newContactName = ""
        state.newContactTimeZone = TimeZone.current.identifier
        state.newContactColor = "blue"
        searchText = ""
        isEditingContact = false
        editingContactIndex = nil
        state.useLocationTracking = false
        state.selectedAppleIdEmail = nil
        state.hasAvailabilityWindow = false
        state.availableStartTime = 8 * 60 // 8:00 AM
        state.availableEndTime = 22 * 60 // 10:00 PM
        myTimeZone = TimeZone.current.identifier
    }
    
    private func checkAvailability() -> Bool {
        // Create a temporary contact with the current form values to check availability
        let tempContact = Contact(
            name: state.newContactName,
            timeZoneIdentifier: state.newContactTimeZone,
            color: state.newContactColor,
            useLocationTracking: state.useLocationTracking,
            appleIdEmail: state.selectedAppleIdEmail,
            phoneNumber: state.newContactPhoneNumber,
            lastLocationUpdate: nil as Date?,
            hasAvailabilityWindow: state.hasAvailabilityWindow,
            availableStartTime: state.availableStartTime,
            availableEndTime: state.availableEndTime
        )
        
        return tempContact.isAvailable()
    }
    
    // Helper function to format relative times
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    func sendMessageToContact(_ contact: Contact) {
        // Check if contact is available
        if contact.hasAvailabilityWindow && !contact.isAvailable() {
            // Show confirmation dialog
            showingMessageConfirmation = true
            messageConfirmationText = "\(contact.name) is outside their usual availability hours. Would you still like to send a message?"
        } else {
            // Directly proceed to messaging
            // This would normally open a messaging interface
            print("Sending message to \(contact.name)")
        }
    }
    
    func deleteContact(at offsets: IndexSet) {
        viewModel.removeContact(at: offsets)
    }
    
    // Additional method to handle showing edit view
    func editingContact(_ contact: Contact) {
        if let index = viewModel.contacts.firstIndex(where: { $0.id == contact.id }) {
            prepareForEditing(contactIndex: index)
        }
    }
    
    // Method to delete a specific contact
    func deleteContact(contact: Contact) {
        if let index = viewModel.contacts.firstIndex(where: { $0.id == contact.id }) {
            viewModel.contacts.remove(at: index)
            viewModel.saveContacts()
            
            // Force widget refresh
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    // Method to handle location sharing for a contact
    func showLocationSharingInvitationView() {
        state.activeSheet = .locationSharing
    }
    
    // Update toolbar button action
    private var toolbarAddButton: some View {
        Button {
            prepareForAdding()
        } label: {
            Label("Select Contact", systemImage: "plus")
        }
    }
}

// Replace the MessageUI placeholder with proper MFMessageComposeViewController wrapper
struct MessageUI: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    let recipient: String
    let body: String
    
    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        var parent: MessageUI
        
        init(_ parent: MessageUI) {
            self.parent = parent
        }
        
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            // Dismiss the message compose view controller
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        if MFMessageComposeViewController.canSendText() {
            let controller = MFMessageComposeViewController()
            controller.messageComposeDelegate = context.coordinator
            
            // If the recipient is a phone number, add it
            if !recipient.isEmpty {
                controller.recipients = [recipient]
            }
            
            // Add body text if provided
            if !body.isEmpty {
                controller.body = body
            }
            
            return controller
        } else {
            // Fallback if the device can't send text messages
            let controller = UIViewController()
            let label = UILabel()
            label.text = "Text messaging is not available on this device"
            label.textAlignment = .center
            label.frame = controller.view.bounds
            controller.view.addSubview(label)
            return controller
        }
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Nothing to update
    }
}

// Fix ContactRow to properly handle phone numbers and messaging
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
                    openSystemMessaging()
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showingMessageComposer) {
            // Use the phone number or email for messaging
            let recipientInfo = getPhoneNumber() ?? contact.email
            MessageUI(recipient: recipientInfo, body: "")
        }
    }
    
    private func initiateMessage() {
        // Check if contact is available
        if contact.hasAvailabilityWindow && !contact.isAvailable() {
            // Show confirmation alert if outside availability window
            showingMessageConfirmation = true
        } else {
            // Directly proceed to messaging if available
            openSystemMessaging()
        }
    }
    
    private func openSystemMessaging() {
        // Check if MFMessageComposeViewController can be used
        if MFMessageComposeViewController.canSendText() {
            showingMessageComposer = true
        } else {
            // Fallback to URL scheme if MessageUI isn't available
            if let phoneNumber = getPhoneNumber() {
                // Format the phone number by removing non-numeric characters
                let formattedNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if !formattedNumber.isEmpty, let url = URL(string: "sms:\(formattedNumber)") {
                    UIApplication.shared.open(url)
                }
            } else if !contact.email.isEmpty {
                // Try to message using email
                showingMessageComposer = true
            }
        }
    }
    
    // Helper function to get a valid phone number from the contact's email
    // In a real app, you'd look up the phone number from the contact
    private func getPhoneNumber() -> String? {
        // Return the phone number from the contact if it's not empty
        return contact.phoneNumber.isEmpty ? nil : contact.phoneNumber
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
            .onChange(of: hourValue) { oldValue, newValue in
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
            .onChange(of: minuteValue) { oldValue, newValue in
                minutes = (hourValue * 60) + newValue
            }
        }
    }
}

// Add ContactEditView after ContentView
struct ContactEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: ContactViewModel
    @Binding var isShowing: Bool
    @Binding var isEditing: Bool
    @Binding var editingIndex: Int?
    
    // Contact properties
    @Binding var name: String
    @Binding var timeZoneIdentifier: String
    @Binding var color: String
    @Binding var useLocationTracking: Bool
    @Binding var selectedAppleIdEmail: String?
    @Binding var hasAvailabilityWindow: Bool
    @Binding var availableStartTime: Int
    @Binding var availableEndTime: Int
    @Binding var searchText: String
    @Binding var phoneNumber: String
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, phoneNumber
    }
    
    let availableColors = ["blue", "green", "red", "purple", "orange", "pink", "yellow"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Contact Info")) {
                    TextField("Name", text: $name)
                    
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .phoneNumber)
                        .onChange(of: focusedField) { oldValue, newValue in
                            if newValue != .phoneNumber {
                                // Ensure value is saved when focus moves away
                                phoneNumber = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                        .onSubmit {
                            // Explicitly commit the value when focus changes
                            phoneNumber = phoneNumber
                            focusedField = nil
                        }
                    
                    if !useLocationTracking {
                        ZStack {
                            NavigationLink(destination: TimeZoneSelectionView(
                                selectedTimeZone: $timeZoneIdentifier,
                                searchText: $searchText,
                                viewModel: viewModel
                            )) {
                                HStack {
                                    Text("Time Zone")
                                    Spacer()
                                    Text(formatTimeZoneForDisplay(timeZoneIdentifier))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Location Tracking")) {
                    Toggle("Use Location Tracking", isOn: $useLocationTracking)
                    
                    if useLocationTracking {
                        Picker("Select Contact", selection: $selectedAppleIdEmail) {
                            Text("None").tag(nil as String?)
                            ForEach(viewModel.locationManager.locationSharedContacts, id: \.id) { contact in
                                Text(contact.name).tag(contact.email as String?)
                            }
                        }
                        
                        if selectedAppleIdEmail != nil {
                            if let contact = viewModel.locationManager.locationSharedContacts.first(where: { $0.email == selectedAppleIdEmail }),
                               let timeZone = contact.timeZone {
                                HStack {
                                    Text("Time Zone:")
                                    Spacer()
                                    Text(formatTimeZoneForDisplay(timeZone.identifier))
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("No location data available")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section(header: Text("Availability Window")) {
                    Toggle("Set Availability Window", isOn: $hasAvailabilityWindow)
                    
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
                        
                        HStack {
                            Text("Status:")
                            Spacer()
                            if checkAvailability() {
                                Text("Currently Available")
                                    .foregroundColor(.green)
                            } else {
                                Text("Currently Unavailable")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                Section(header: Text("Color")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(availableColors, id: \.self) { colorName in
                                colorCircleView(for: colorName)
                            }
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
            .navigationBarTitle(isEditing ? "Edit Contact" : "Add Contact", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isShowing = false
                },
                trailing: Button(isEditing ? "Save" : "Add") {
                    saveContactAction()
                }
                .disabled(name.isEmpty)
            )
            .onAppear {
                // Load the phone number when the view appears
                if let index = editingIndex, index < viewModel.contacts.count {
                    phoneNumber = viewModel.contacts[index].phoneNumber
                }
            }
        }
    }
    
    private func colorCircleView(for color: String) -> some View {
        Circle()
            .fill(colorFromString(color))
            .frame(width: 40, height: 40)
            .overlay(
                Circle()
                    .stroke(Color.primary, lineWidth: self.color == color ? 2 : 0)
            )
            .padding(5)
            .onTapGesture {
                self.color = color
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
    
    private func formatTimeZoneForDisplay(_ identifier: String) -> String {
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
    
    private func saveContactAction() {
        // Call the saveContactAction from ContentView
        if isEditing, let index = editingIndex {
            // Update the existing contact
            var updatedContact = viewModel.contacts[index]
            updatedContact.name = name
            updatedContact.timeZoneIdentifier = timeZoneIdentifier
            updatedContact.color = color
            updatedContact.useLocationTracking = useLocationTracking
            updatedContact.appleIdEmail = selectedAppleIdEmail
            updatedContact.phoneNumber = phoneNumber
            // Handle availability window
            updatedContact.availableStartTime = hasAvailabilityWindow ? availableStartTime : 0
            updatedContact.availableEndTime = hasAvailabilityWindow ? availableEndTime : 24 * 60
            
            viewModel.contacts[index] = updatedContact
            viewModel.saveContacts()
        } else {
            // Add new contact
            let newContact = Contact(
                name: name,
                timeZoneIdentifier: timeZoneIdentifier,
                color: color,
                useLocationTracking: useLocationTracking,
                appleIdEmail: selectedAppleIdEmail,
                phoneNumber: phoneNumber,
                lastLocationUpdate: nil as Date?,
                hasAvailabilityWindow: hasAvailabilityWindow,
                availableStartTime: hasAvailabilityWindow ? availableStartTime : 0,
                availableEndTime: hasAvailabilityWindow ? availableEndTime : 24 * 60
            )
            viewModel.contacts.append(newContact)
            viewModel.saveContacts()
        }
        
        // Force widget refresh
        WidgetCenter.shared.reloadAllTimelines()
        
        // Dismiss this view
        isShowing = false
    }
    
    private func checkAvailability() -> Bool {
        // Create a temporary contact with the current form values to check availability
        let tempContact = Contact(
            name: name,
            timeZoneIdentifier: timeZoneIdentifier,
            color: color,
            useLocationTracking: useLocationTracking,
            appleIdEmail: selectedAppleIdEmail,
            phoneNumber: phoneNumber,
            lastLocationUpdate: nil as Date?,
            hasAvailabilityWindow: hasAvailabilityWindow,
            availableStartTime: availableStartTime,
            availableEndTime: availableEndTime
        )
        
        return tempContact.isAvailable()
    }
}

// Add TimeZoneSelectionView
struct TimeZoneSelectionView: View {
    @Binding var selectedTimeZone: String
    @Binding var searchText: String
    @ObservedObject var viewModel: ContactViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var filteredTimeZones: [String] {
        return TimeZone.knownTimeZoneIdentifiers.filter { identifier in
            searchText.isEmpty || identifier.localizedCaseInsensitiveContains(searchText)
        }.sorted()
    }
    
    var body: some View {
        VStack {
            TextField("Search Time Zones", text: $searchText)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
            
            List {
                ForEach(filteredTimeZones, id: \.self) { timeZone in
                    Button(action: {
                        selectedTimeZone = timeZone
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Text(formatTimeZoneForDisplay(timeZone))
                            Spacer()
                            if selectedTimeZone == timeZone {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .navigationBarTitle("Select Time Zone", displayMode: .inline)
    }
    
    private func formatTimeZoneForDisplay(_ identifier: String) -> String {
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
}

// Add LocationSharingInvitationView
struct LocationSharingInvitationView: View {
    @ObservedObject var viewModel: ContactViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showingContactPicker = false
    @Binding var confirmationMessage: String
    @State private var showingMessageConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Your Invitations")) {
                    ForEach(viewModel.locationManager.getAcceptedInvitations()) { invitation in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(invitation.contactName)
                                    .font(.headline)
                                Text(invitation.contactEmail)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if invitation.invitationStatus == .accepted {
                                Text("Connected")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else if invitation.invitationStatus == .pending {
                                Text("Pending")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    if viewModel.locationManager.getAcceptedInvitations().isEmpty {
                        Text("No active location sharing connections")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    
                    Button(action: {
                        // Show contact picker directly - no need to dismiss first
                        showingContactPicker = true
                    }) {
                        Label("Invite a Contact", systemImage: "person.badge.plus")
                    }
                }
                
                Section(header: Text("Privacy Information")) {
                    Text("Location sharing helps contacts see your accurate local time. Your location is only shared with people you specifically invite.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("To stop sharing with a contact, swipe left on their name and tap 'Remove'.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationBarTitle("Location Sharing", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .fullScreenCover(isPresented: $showingContactPicker) {
                // Use fullScreenCover instead of sheet to avoid nesting issues
                NavigationView {
                    RealContactPickerViewController(selectedContact: Binding<CNContact?>(
                        get: { nil },
                        set: { contact in
                            if let contact = contact {
                                // Process the selected contact for location sharing
                                viewModel.locationManager.sendLocationSharingInvitation(contact: contact)
                                
                                // Show confirmation message
                                let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                                let displayName = fullName.isEmpty ? contact.organizationName : fullName
                                confirmationMessage = "Location sharing invitation sent to \(displayName)."
                                showingMessageConfirmation = true
                            }
                            
                            // Dismiss the picker
                            showingContactPicker = false
                        }
                    ))
                    .ignoresSafeArea()
                    .navigationBarItems(leading: Button("Cancel") {
                        showingContactPicker = false
                    })
                }
            }
            .alert(isPresented: $showingMessageConfirmation) {
                Alert(
                    title: Text("Invitation Sent"),
                    message: Text(confirmationMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

// Add RealContactPickerViewController after LocationSharingInvitationView
struct RealContactPickerViewController: UIViewControllerRepresentable {
    @Binding var selectedContact: CNContact?
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {
        // Nothing to update
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: RealContactPickerViewController
        
        init(_ parent: RealContactPickerViewController) {
            self.parent = parent
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            // Handle cancellation
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.selectedContact = contact
        }
    }
}

// ContentViewState to share data between different views in ContentView
class ContentViewState: ObservableObject {
    @Published var activeSheet: ContentView.ActiveSheet?
    @Published var newContactName = ""
    @Published var newContactTimeZone = TimeZone.current.identifier
    @Published var newContactColor = "blue"
    @Published var useLocationTracking = false
    @Published var selectedAppleIdEmail: String?
    @Published var newContactPhoneNumber = ""
    @Published var hasAvailabilityWindow = false
    @Published var availableStartTime = 0
    @Published var availableEndTime = 24
    @Published var readyToShowForm = false
    
    func resetForm() {
        newContactName = ""
        newContactTimeZone = TimeZone.current.identifier
        newContactColor = "blue"
        useLocationTracking = false
        selectedAppleIdEmail = nil
        newContactPhoneNumber = ""
        hasAvailabilityWindow = false
        availableStartTime = 8 * 60 // 8:00 AM
        availableEndTime = 22 * 60 // 10:00 PM
        readyToShowForm = false
    }
}

// SettingsView to display all the settings previously in ContentView
struct SettingsView: View {
    @ObservedObject var viewModel: ContactViewModel
    @State private var myTimeZone = TimeZone.current.identifier
    @State private var searchText = ""
    @Environment(\.presentationMode) var presentationMode
    
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
    
    func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var body: some View {
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
                    // Dismiss this view first, then show location sharing
                    presentationMode.wrappedValue.dismiss()
                    
                    // Use a small delay to ensure the view is dismissed first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        viewModel.showLocationSharingInvitation = true
                    }
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
        }
        .navigationTitle("Settings")
    }
}

// Extension to check if Optional String is nil or empty
extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        self == nil || self!.isEmpty
    }
}

#Preview {
    ContentView()
} 

