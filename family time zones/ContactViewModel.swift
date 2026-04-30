import Foundation
import SwiftUI
import Combine
import WidgetKit
import CoreLocation

class ContactViewModel: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var useMyLocationForTimeZone: Bool = false
    @Published var myTimeZone: String = TimeZone.current.identifier
    @Published var searchText = ""
    @Published var showLocationSharingInvitation: Bool = false

    let locationManager = LocationManager.shared

    let availableColors = ["blue", "green", "red", "purple", "orange", "pink", "yellow"]

    var filteredTimeZones: [String] {
        TimeZone.knownTimeZoneIdentifiers.filter { identifier in
            searchText.isEmpty || identifier.localizedCaseInsensitiveContains(searchText)
        }.sorted()
    }

    private var locationUpdateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadContacts()
        loadUserPreferences()

        if useMyLocationForTimeZone {
            startLocationUpdateTimer()
        }

        LocationManager.shared.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        setupSharedLocationObservers()
    }

    deinit {
        locationUpdateTimer?.invalidate()
    }

    private func loadUserPreferences() {
        useMyLocationForTimeZone = UserDefaults.standard.bool(forKey: "useMyLocationForTimeZone")

        if let savedTimeZone = UserDefaults.standard.string(forKey: "myTimeZone"),
           TimeZone(identifier: savedTimeZone) != nil {
            myTimeZone = savedTimeZone
        } else {
            myTimeZone = TimeZone.current.identifier
        }
    }

    func setUseMyLocationForTimeZone(_ use: Bool) {
        useMyLocationForTimeZone = use
        saveUserPreferences()

        if use {
            if locationManager.permissionStatus == .notDetermined {
                locationManager.requestLocationPermission()
            }
            startLocationUpdateTimer()
            updateUserTimeZone()
        } else {
            locationUpdateTimer?.invalidate()
            locationUpdateTimer = nil
        }
    }

    func setManualTimeZone(_ timeZone: String) {
        if !useMyLocationForTimeZone {
            myTimeZone = timeZone
            saveUserPreferences()
        }
    }

    func saveUserPreferences() {
        UserDefaults.standard.set(useMyLocationForTimeZone, forKey: "useMyLocationForTimeZone")
        UserDefaults.standard.set(myTimeZone, forKey: "myTimeZone")
    }

    func updateUserTimeZone() {
        if useMyLocationForTimeZone {
            locationManager.lookupTimeZoneFromCurrentLocation { [weak self] timeZoneIdentifier in
                guard let self else { return }

                if let timeZoneIdentifier {
                    DispatchQueue.main.async {
                        self.myTimeZone = timeZoneIdentifier
                        self.saveUserPreferences()
                    }
                }
            }
        }
    }

    private func setupSharedLocationObservers() {
        if locationManager.permissionStatus == .notDetermined {
            locationManager.requestLocationPermission()
        }

        locationManager.$locationSharedContacts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadSharedLocationContacts()
                self?.refreshLocationBasedTimeZones()
            }
            .store(in: &cancellables)

        locationManager.$currentLocation
            .sink { [weak self] _ in
                if self?.useMyLocationForTimeZone == true {
                    self?.updateUserTimeZone()
                }
            }
            .store(in: &cancellables)

        loadSharedLocationContacts()
    }

    func refreshLocationBasedTimeZones() {
        for contact in contacts where contact.useLocationTracking {
            guard let shared = matchingSharedContact(for: contact) else { continue }
            guard let tzId = shared.timeZone?.identifier else { continue }

            let contactId = contact.id
            DispatchQueue.main.async { [weak self] in
                guard let self, let idx = self.contacts.firstIndex(where: { $0.id == contactId }) else { return }
                var updated = self.contacts[idx]
                if updated.timeZoneIdentifier != tzId {
                    updated.timeZoneIdentifier = tzId
                    updated.lastLocationUpdate = shared.lastUpdated ?? Date()
                    self.contacts[idx] = updated
                    self.saveContacts()
                }
            }
        }
    }

    private func matchingSharedContact(for contact: Contact) -> LocationManager.SharedLocationContact? {
        let email = contact.appleIdEmail?.lowercased() ?? ""
        let phoneDigits = contact.phoneNumber.filter(\.isNumber)
        return locationManager.locationSharedContacts.first { sc in
            let se = sc.email.lowercased()
            if !email.isEmpty, se == email { return true }
            if !phoneDigits.isEmpty, sc.email.filter(\.isNumber) == phoneDigits { return true }
            return false
        }
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

        let id = contacts[index].id
        let useLocationTracking = contacts[index].useLocationTracking
        let appleIdEmail = contacts[index].appleIdEmail
        let phoneNumber = contacts[index].phoneNumber
        let lastLocationUpdate = contacts[index].lastLocationUpdate
        let hasAvailabilityWindow = contacts[index].hasAvailabilityWindow
        let availableStartTime = contacts[index].availableStartTime
        let availableEndTime = contacts[index].availableEndTime

        contacts[index] = Contact(
            id: id,
            name: name,
            timeZoneIdentifier: timeZoneIdentifier,
            color: color,
            useLocationTracking: useLocationTracking,
            appleIdEmail: appleIdEmail,
            phoneNumber: phoneNumber,
            lastLocationUpdate: lastLocationUpdate,
            hasAvailabilityWindow: hasAvailabilityWindow,
            availableStartTime: availableStartTime,
            availableEndTime: availableEndTime
        )
        saveContacts()
    }

    func updateContactLocationSettings(at index: Int, useLocationTracking: Bool, appleIdEmail: String?) {
        guard index >= 0 && index < contacts.count else { return }

        var updatedContact = contacts[index]
        updatedContact.useLocationTracking = useLocationTracking
        updatedContact.appleIdEmail = appleIdEmail

        if useLocationTracking, let refreshedContact = locationManager.updateTimeZoneForContact(updatedContact) {
            updatedContact = refreshedContact
        }

        contacts[index] = updatedContact
        saveContacts()
    }

    func removeContact(at indices: IndexSet) {
        contacts.remove(atOffsets: indices)
        saveContacts()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func moveContact(from source: IndexSet, to destination: Int) {
        contacts.move(fromOffsets: source, toOffset: destination)
        saveContacts()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func saveContacts() {
        SharedStorage.saveContacts(contacts)
    }

    private func loadContacts() {
        contacts = SharedStorage.loadContacts()
    }

    func availableTimeZones() -> [String] {
        TimeZone.knownTimeZoneIdentifiers.sorted()
    }

    private func startLocationUpdateTimer() {
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.updateUserTimeZone()
        }
        updateUserTimeZone()
    }

    func refreshFindMyContacts() {
        loadSharedLocationContacts()
    }

    private func loadSharedLocationContacts() {
        for sharedContact in locationManager.locationSharedContacts {
            let email = sharedContact.email.lowercased()
            let phoneDigits = sharedContact.email.filter(\.isNumber)
            let index = contacts.firstIndex { c in
                let ce = c.email.lowercased()
                if !email.isEmpty, ce == email { return true }
                if !phoneDigits.isEmpty, c.phoneNumber.filter(\.isNumber) == phoneDigits { return true }
                return false
            }
            if let index, let timeZone = sharedContact.timeZone?.identifier {
                var updatedContact = contacts[index]
                updatedContact.timeZoneIdentifier = timeZone
                updatedContact.lastLocationUpdate = sharedContact.lastUpdated
                contacts[index] = updatedContact
            } else if let timeZone = sharedContact.timeZone?.identifier {
                let raw = sharedContact.email
                let isEmail = raw.contains("@")
                let newContact = Contact(
                    name: sharedContact.name,
                    timeZoneIdentifier: timeZone,
                    color: "blue",
                    useLocationTracking: true,
                    appleIdEmail: isEmail ? raw : nil,
                    phoneNumber: isEmail ? nil : raw,
                    lastLocationUpdate: sharedContact.lastUpdated
                )
                contacts.append(newContact)
            }
        }
        saveContacts()
    }

    func getLocationSharingContacts() -> [Contact] {
        contacts.filter { $0.useLocationForTimeZone }
    }

    func availableSharedLocationContacts() -> [LocationManager.SharedLocationContact] {
        locationManager.locationSharedContacts
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
}
