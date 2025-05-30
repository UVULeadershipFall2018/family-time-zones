                    // ... existing time zone picker code ...
                }
                
                // Location-based time zone option
                Section(header: Text("Location Updates")) {
                    Toggle("Use Location for Time Zone", isOn: $contact.useLocationForTimeZone)
                    
                    if contact.useLocationForTimeZone {
                        TextField("Email Address", text: $contact.email)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                        
                        if !viewModel.availableSharedLocationContacts().isEmpty {
                            Picker("Select Contact", selection: $selectedLocationContactEmail) {
                                Text("None").tag("")
                                ForEach(viewModel.availableSharedLocationContacts(), id: \.id) { contact in
                                    Text("\(contact.name) (\(contact.email))").tag(contact.email)
                                }
                            }
                            .onChange(of: selectedLocationContactEmail) { oldValue, newValue in
                                if !newValue.isEmpty {
                                    contact.email = newValue
                                }
                            }
                        }
                        
                        Button("Send Location Sharing Invitation") {
                            // Save before showing location sharing
                            if isNewContact {
                                onSave(contact)
                            }
                            showLocationSharingSheet = true
                        }
                        
                        if let lastUpdate = contact.lastLocationUpdate {
                            HStack {
                                Text("Last Update:")
                                Spacer()
                                Text(formatRelativeTime(lastUpdate))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } 

    // Helper function to format relative times
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        NavigationView {
            Form {
                // ... existing form sections ...
                
                // Location-based time zone option
                Section(header: Text("Location Updates")) {
                    // ... existing location updates section ...
                }
            }
            .navigationTitle(isNewContact ? "New Contact" : "Edit Contact")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(contact)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(contact.name.isEmpty)
                }
                
                if !isNewContact {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Delete") {
                            showDeleteConfirmation = true
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .sheet(isPresented: $showLocationSharingSheet) {
                LocationSharingInvitationView(locationManager: viewModel.locationManager)
            }
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Delete Contact"),
                    message: Text("Are you sure you want to delete this contact?"),
                    primaryButton: .destructive(Text("Delete")) {
                        onDelete(contact)
                        presentationMode.wrappedValue.dismiss()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
} 