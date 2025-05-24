import SwiftUI
import Contacts
import ContactsUI

struct LocationSharingInvitationView: View {
    @ObservedObject var locationManager: LocationManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showingContactPicker = false
    @State private var selectedContact: CNContact?
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Send New Invitation")) {
                    Button(action: {
                        showingContactPicker = true
                    }) {
                        Label("Select Contact", systemImage: "person.crop.circle.badge.plus")
                    }
                }
                
                if !locationManager.getPendingInvitations().isEmpty {
                    Section(header: Text("Pending Invitations")) {
                        ForEach(locationManager.getPendingInvitations()) { invitation in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(invitation.contactName)
                                        .font(.headline)
                                    Text(invitation.contactEmail)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text("Pending")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(4)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            .contextMenu {
                                Button(action: {
                                    // Resend invitation
                                    if let contact = createContact(from: invitation) {
                                        locationManager.sendLocationSharingInvitation(contact: contact)
                                    }
                                }) {
                                    Label("Resend Invitation", systemImage: "arrow.clockwise")
                                }
                                
                                Button(role: .destructive, action: {
                                    locationManager.updateInvitationStatus(id: invitation.id, status: .declined)
                                }) {
                                    Label("Cancel Invitation", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                
                if !locationManager.getAcceptedInvitations().isEmpty {
                    Section(header: Text("Active Sharing")) {
                        ForEach(locationManager.getAcceptedInvitations()) { invitation in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(invitation.contactName)
                                        .font(.headline)
                                    
                                    if let lastUpdate = invitation.lastLocationUpdate {
                                        Text("Last update: \(formatDate(lastUpdate))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Text("Active")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .padding(4)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Location Sharing")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingContactPicker) {
                DirectContactPickerView(selectedContact: $selectedContact, locationManager: locationManager)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func createContact(from invitation: LocationSharingInvitation) -> CNContact? {
        let contact = CNMutableContact()
        contact.givenName = invitation.contactName.components(separatedBy: " ").first ?? ""
        contact.familyName = invitation.contactName.components(separatedBy: " ").dropFirst().joined(separator: " ")
        
        let emailAddress = CNLabeledValue(
            label: CNLabelHome,
            value: invitation.contactEmail as NSString
        )
        contact.emailAddresses = [emailAddress]
        
        return contact
    }
}

// Direct contact picker view that immediately shows the system contact picker
struct DirectContactPickerView: View {
    @Binding var selectedContact: CNContact?
    var locationManager: LocationManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        SystemContactPicker(selectedContact: $selectedContact)
            .ignoresSafeArea()
            .onDisappear {
                if let contact = selectedContact {
                    locationManager.sendLocationSharingInvitation(contact: contact)
                }
                presentationMode.wrappedValue.dismiss()
            }
    }
}

// System contact picker
struct SystemContactPicker: UIViewControllerRepresentable {
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
        var parent: SystemContactPicker
        
        init(_ parent: SystemContactPicker) {
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