import SwiftUI
import Contacts
import ContactsUI

struct LocationSharingInvitationView: View {
    var viewModel: ContactViewModel
    @State private var showingContactPicker = false
    @State private var showingMessageConfirmation = false
    @Binding var confirmationMessage: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Invite someone to share their location with you")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Text("When someone shares their location with you, their time zone will automatically update based on where they are.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    showingContactPicker = true
                }) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.title2)
                        Text("Select Contact")
                            .fontWeight(.semibold)
                    }
                    .frame(minWidth: 200)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                
                Text("Location information is only used to determine the contact's time zone and is never stored or shared with third parties.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding()
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