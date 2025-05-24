// ContactPickerWrapper for adding new contacts
import SwiftUI
import Contacts
import ContactsUI

struct ContactPickerWrapper: View {
    var viewModel: ContactViewModel
    @Binding var showingMessageConfirmation: Bool
    @Binding var confirmationMessage: String
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var contentView: ContentViewState
    @State private var contactSelected = false
    
    var body: some View {
        if contactSelected {
            // Show the form after contact is selected
            Form {
                Section(header: Text("Contact Information")) {
                    Text("This contact was selected from your address book. You can customize additional details below.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)
                    
                    VStack(alignment: .leading) {
                        Text("Contact Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Contact Name", text: $contentView.newContactName)
                            .font(.body)
                    }
                    
                    if !contentView.selectedAppleIdEmail.isNilOrEmpty {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(contentView.selectedAppleIdEmail ?? "")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Color")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 10) {
                        ForEach(viewModel.availableColors, id: \.self) { color in
                            colorCircleView(for: color)
                        }
                    }
                    .padding(.vertical, 5)
                }
                
                Section(header: Text("Location Tracking")) {
                    Toggle("Use Location for Time Zone", isOn: $contentView.useLocationTracking)
                    
                    if contentView.useLocationTracking {
                        Text("Select the person who shares their location with you:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        FindMyContactPicker(viewModel: viewModel, selectedEmail: $contentView.selectedAppleIdEmail)
                    }
                }
                
                Section(header: Text("Availability Window")) {
                    Toggle("Set Availability Hours", isOn: $contentView.hasAvailabilityWindow)
                    
                    if contentView.hasAvailabilityWindow {
                        HStack {
                            Text("Start Time")
                            Spacer()
                            TimePicker(minutes: $contentView.availableStartTime)
                        }
                        
                        HStack {
                            Text("End Time")
                            Spacer()
                            TimePicker(minutes: $contentView.availableEndTime)
                        }
                    }
                }
                
                Section(header: Text("Time Zone")) {
                    if !contentView.useLocationTracking {
                        Text("Select a time zone for this contact")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Time Zone", selection: $contentView.newContactTimeZone) {
                            ForEach(viewModel.filteredTimeZones, id: \.self) { timeZone in
                                Text(viewModel.formatTimeZoneForDisplay(timeZone)).tag(timeZone)
                            }
                        }
                    }
                }
                
                Section {
                    Button("Cancel Adding Contact") {
                        contentView.activeSheet = nil
                    }
                    .foregroundColor(.red)
                    
                    Button("Add to Family Time Zones") {
                        saveContactAction()
                    }
                    .disabled(contentView.newContactName.isEmpty || 
                             (contentView.useLocationTracking && contentView.selectedAppleIdEmail == nil))
                }
            }
            .navigationTitle("New Contact")
        } else {
            // Show the contact picker first
            RealContactPickerViewController(selectedContact: Binding<CNContact?>(
                get: { nil },
                set: { contact in
                    if let contact = contact {
                        // For adding new contacts
                        if contentView.activeSheet == .contactPicker {
                            // Populate the form with contact info
                            let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                            contentView.newContactName = fullName.isEmpty ? contact.organizationName : fullName
                            
                            // Find Apple ID email if available (typically ends with @icloud.com)
                            if !contact.emailAddresses.isEmpty {
                                let appleEmail = contact.emailAddresses.first { 
                                    ($0.value as String).lowercased().contains("@icloud.com") 
                                }
                                contentView.selectedAppleIdEmail = (appleEmail?.value as String?) ?? 
                                                                   (contact.emailAddresses.first?.value as String?) ?? ""
                            }
                            
                            // Show the form in the same sheet
                            contactSelected = true
                        } 
                        // For location sharing invitations
                        else {
                            // Process the selected contact for location sharing
                            viewModel.locationManager.sendLocationSharingInvitation(contact: contact)
                            
                            // Show confirmation message
                            let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                            let displayName = fullName.isEmpty ? contact.organizationName : fullName
                            confirmationMessage = "Location sharing invitation sent to \(displayName)."
                            showingMessageConfirmation = true
                            
                            // Dismiss this picker
                            presentationMode.wrappedValue.dismiss()
                        }
                    } else {
                        // Handle case when user cancels the picker without selecting a contact
                        contentView.activeSheet = nil
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            ))
            .ignoresSafeArea()
        }
    }
    
    private func colorCircleView(for color: String) -> some View {
        Circle()
            .fill(colorFromString(color))
            .frame(width: 40, height: 40)
            .overlay(
                Circle()
                    .stroke(Color.primary, lineWidth: contentView.newContactColor == color ? 2 : 0)
            )
            .padding(5)
            .onTapGesture {
                contentView.newContactColor = color
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
        var timeZoneIdentifier = contentView.newContactTimeZone
        if contentView.useLocationTracking,
           let email = contentView.selectedAppleIdEmail,
           let contact = viewModel.locationManager.locationSharedContacts.first(where: { $0.email == email }),
           let timeZone = contact.timeZone {
            timeZoneIdentifier = timeZone.identifier
        }
        
        // Add new contact
        let newContact = Contact(
            name: contentView.newContactName,
            timeZoneIdentifier: timeZoneIdentifier,
            color: contentView.newContactColor,
            useLocationTracking: contentView.useLocationTracking,
            appleIdEmail: contentView.selectedAppleIdEmail,
            lastLocationUpdate: nil,
            hasAvailabilityWindow: contentView.hasAvailabilityWindow,
            availableStartTime: contentView.hasAvailabilityWindow ? contentView.availableStartTime : 0,
            availableEndTime: contentView.hasAvailabilityWindow ? contentView.availableEndTime : 24 * 60
        )
        viewModel.contacts.append(newContact)
        viewModel.saveContacts()
        
        // Force widget refresh
        WidgetCenter.shared.reloadAllTimelines()
        
        // Dismiss
        contentView.activeSheet = nil
    }
} 