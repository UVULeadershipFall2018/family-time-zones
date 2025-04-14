    // Format time for a specific entry date
    private func formattedTime(for contact: Contact, at date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = contact.timeZone
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Format date difference for contact's timezone
    private func formattedDate(for contact: Contact, at date: Date, in family: WidgetFamily) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = contact.timeZone
        
        // Get today and tomorrow in the contact's time zone
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.timeZone = contact.timeZone
        
        guard let todayInTimeZone = calendar.date(from: components) else {
            return ""
        }
        
        // Only show date if different from local date
        let localCalendar = Calendar.current
        let localComponents = localCalendar.dateComponents([.year, .month, .day], from: date)
        let contactComponents = calendar.dateComponents([.year, .month, .day], from: date)
        
        if localComponents.day != contactComponents.day || 
           localComponents.month != contactComponents.month {
            // Date is different, show it
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: todayInTimeZone)
        }
        
        return ""
    } 