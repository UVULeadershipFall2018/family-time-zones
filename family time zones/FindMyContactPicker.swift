import SwiftUI

struct FindMyContactPicker: View {
    var viewModel: ContactViewModel
    @Binding var selectedEmail: String?
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.availableSharedLocationContacts()) { contact in
                    Button(action: {
                        selectedEmail = contact.email
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(contact.name)
                                    .fontWeight(selectedEmail == contact.email ? .bold : .regular)
                                Text(contact.email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedEmail == contact.email {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                }
                
                if viewModel.availableSharedLocationContacts().isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No shared-location entries on this device")
                            .foregroundColor(.secondary)
                        Text("Invitations are stored locally. Use manual time zones for friends until you add sync (e.g. CloudKit).")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 10)
                }
            }
        }
        .frame(height: 200)
    }
} 