import SwiftUI

struct FindMyContactPicker: View {
    @EnvironmentObject var viewModel: ContactViewModel
    @Binding var selectedEmail: String?
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.availableFindMyContacts()) { contact in
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
                
                if viewModel.availableFindMyContacts().isEmpty {
                    Text("No contacts available who share their location")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 10)
                }
            }
        }
        .frame(height: 200)
    }
} 