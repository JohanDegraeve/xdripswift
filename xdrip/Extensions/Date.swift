import Foundation

extension Date {
    
    //source https://freakycoder.com/ios-notes-22-how-to-get-current-time-as-timestamp-fa8a0d422879
    /// extension to Date class
    /// - returns:
    ///     time since 1 Jan 1970 in ms, can be negative if Date is before 1 Jan 1970
    func toMillisecondsAsDouble() -> Double {
        return Double(self.timeIntervalSince1970 * 1000)
    }
    
    /// returns Date in milliseconds as Int64, since 1.1.1970
    func toMillisecondsAsInt64() -> Int64 {
        return Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
    /// returns Date in seconds as Int64, since 1.1.1970
    func toSecondsAsInt64() -> Int64 {
        return Int64((self.timeIntervalSince1970).rounded())
    }
    
    /// gives number of minutes since 00:00 local time
    func minutesSinceMidNightLocalTime() -> Int {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: self)
        let minute = calendar.component(.minute, from: self)
        return Int(hour * 60 + minute)
    }
    
    /// changes the date to 00:00 the same day, local time, and returns the result as a new Date object
    func toMidnight() -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: self)
        let minute = calendar.component(.minute, from: self)
        let seconds = calendar.component(.second, from: self)
        let timeInterval = TimeInterval(-Double(hour * 3600 + minute * 60 + seconds))
        return Date(timeInterval: timeInterval, since: self)
    }
	
	/// The same ISO Formtter is used for various conversions, e.g. fromISOString and ISOStringFromDate.
	/// ISODateFormatter abstracts the creation of this DateFormatter.
	/// DateFormatter creation is expensive, and having it as a separate func allows reusing.
	/// Example string: "2022-01-12T23:04:17.190Z"
	static func ISODateFormatter() -> DateFormatter {
		let dateFormatter = DateFormatter()
		dateFormatter.locale = Locale(identifier: "en_US_POSIX")
		dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
		dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
		return dateFormatter
	}

	/// Given a date represented as a string, returns a Date object, the reverse of ISOStringFromDate.
	/// Example string: "2022-01-12T23:04:17.190Z"
	/// Overloads accepts and uses an optional reuseDateFormatter.
	static func fromISOString(_ string: String, reuseDateFormatter: DateFormatter? = nil) -> Date? {
		guard let reuseDateFormatter = reuseDateFormatter else {
			return Date.ISODateFormatter().date(from: string)
		}
		return reuseDateFormatter.date(from: string)
	}
	
	/// Given a date represented as a string, returns a Date object, the reverse of ISOStringFromDate.
	/// Example string: "2022-01-12T23:04:17.190Z"
	static func fromISOString(_ string: String) -> Date? {
		return Date.fromISOString(string, reuseDateFormatter: Date.ISODateFormatter())
	}


	/// Returns the date represented as a ISO string.
	/// Example return: "2022-01-12T23:04:17.190Z"
	/// Overloads accepts and uses an optional reuseDateFormatter.
	func ISOStringFromDate(reuseDateFormatter: DateFormatter? = nil) -> String {
		guard let reuseDateFormatter = reuseDateFormatter else {
			return Date.ISODateFormatter().string(from: self)
		}
		return reuseDateFormatter.string(from: self)
	}

	/// Returns the date represented as a ISO string.
	/// Example return: "2022-01-12T23:04:17.190Z"
	func ISOStringFromDate() -> String {
		return self.ISOStringFromDate(reuseDateFormatter: Date.ISODateFormatter())
	}
    
    /// Returns a short date string for use in the filename of the json export file - this should reflect the user's local time
    ///
    /// Example return: "20220112-2304"
    func jsonFilenameStringFromDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyyMMdd-HHmm"
        
        return dateFormatter.string(from: self)
    }
    
    /// date to string, with date and time as specified by one of the values in DateFormatter.Style
    func toString(timeStyle: DateFormatter.Style, dateStyle: DateFormatter.Style) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = timeStyle
        dateFormatter.dateStyle = dateStyle
        return dateFormatter.string(from: self)
    }
    
    /// date to string, with date and time as specified by one of the values in DateFormatter.Style
    /// this is a special version of this function used only for the trace/log files and sets the locale to British
    /// so that we can get the date string in English irrespective of the user locale/settings
    func toStringForTrace(timeStyle: DateFormatter.Style, dateStyle: DateFormatter.Style) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_GB")
        dateFormatter.timeStyle = timeStyle
        dateFormatter.dateStyle = dateStyle
        return dateFormatter.string(from: self)
    }
    
    /// date to string, with date and time as specified by one of the values in DateFormatter.Style and formatted to match the user's locale
    /// Example return: "31/12/2022, 17:48" (spain locale)
    /// Example return: "12/31/2022, 5:48 pm" (us locale)
    func toStringInUserLocale(timeStyle: DateFormatter.Style, dateStyle: DateFormatter.Style, showTimeZone: Bool? = false) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = timeStyle
        dateFormatter.dateStyle = dateStyle
        dateFormatter.amSymbol = ConstantsUI.timeFormatAM
        dateFormatter.pmSymbol = ConstantsUI.timeFormatPM
        
        let showUserTimeZone = showTimeZone ?? false
        
        if timeStyle == .none {
            
            dateFormatter.setLocalizedDateFormatFromTemplate("dd/MM/yyyy")
            
        } else if dateStyle == .none {
            
            if showUserTimeZone {
            
            dateFormatter.setLocalizedDateFormatFromTemplate("jj:mm zzz")
                
            } else {
                
                dateFormatter.setLocalizedDateFormatFromTemplate("jj:mm")
                
            }
            
        } else {
            
            if showUserTimeZone {
                
                dateFormatter.setLocalizedDateFormatFromTemplate("dd/MM/yyyy, jj:mm zzz")
                
            } else {
                
                dateFormatter.setLocalizedDateFormatFromTemplate("dd/MM/yyyy, jj:mm")
            }
            
        }
        
        return dateFormatter.string(from: self)
    }
    
    /// returns seconds since 1.1.1970 local time for current timezone
    func toSecondsAsInt64Local() -> Int64 {
        let calendar = Calendar.current
        return (Date().toSecondsAsInt64() + Int64(calendar.timeZone.secondsFromGMT()))
    }
    
    /// creates a new date, rounded to lower hour, eg if date = 26 10 2019 23:23:35, returnvalue is date 26 10 2019 23:00:00
    func toLowerHour() -> Date {
        return Date(timeIntervalSinceReferenceDate:
            (timeIntervalSinceReferenceDate / 3600.0).rounded(.down) * 3600.0)
    }
    
    /// returns the Nightscout style string showing the days and hours since a date (e.g. "6d11h")
    /// Example return: "6d11h" if optional appendAgo is false or not used
    /// Example return: "6d11h ago" if optional appendAgo is true
    /// if less than 12 hours, return also minutes, e.g: "7h43m" or "58m" to give extra granularity
    func daysAndHoursAgo(appendAgo: Bool? = false, showOnlyDays: Bool? = false, showOnlyHours: Bool? = false) -> String {
        // set a default value assuming that we're unable to calculate the hours + days
        var daysAndHoursAgoString: String = "n/a"

        let diffComponents = Calendar.current.dateComponents([.day, .hour, .minute], from: self, to: Date())

        if let days = diffComponents.day, let hours = diffComponents.hour, let minutes = diffComponents.minute {
            if let showOnlyHours = showOnlyHours, showOnlyHours {
                // show just the total hours
                daysAndHoursAgoString = abs((days * 24) + hours).description + Texts_Common.hourshort
            } else if days == 0 && hours < 1 {
                // show just minutes for less than one hour
                daysAndHoursAgoString = abs(minutes).description + Texts_Common.minuteshort
            } else if days == 0 {
                // show just hours if less than a day
                // also show only hours if requested (i.e. 24h instead of 1d0h)
                daysAndHoursAgoString = abs(hours).description + Texts_Common.hourshort
            } else {
                // default show days and hours
                daysAndHoursAgoString = abs(days).description + Texts_Common.dayshort + (!(showOnlyDays ?? false) ? abs(hours).description + Texts_Common.hourshort : "")
            }
            
            // if the function was called using appendAgo == true, then add the "ago" string
            if appendAgo ?? false {
                daysAndHoursAgoString += " " + Texts_HomeView.ago
            }
        }

        return daysAndHoursAgoString
    }
    
    /// returns the Nightscout style string showing the days and hours since a date (e.g. "6 days 11 hours") but using the "full abbreviated" texts
    /// Example return: "6 days 11 hours" if optional appendAgo is false or not used
    /// Example return: "6 days 11 hours ago" if optional appendAgo is true
    /// if less than 12 hours, return also minutes, e.g: "7 hours 43 minutes" or "58 minutes" to give extra granularity
    func daysAndHoursAgoFull(appendAgo: Bool? = false) -> String {
        // set a default value assuming that we're unable to calculate the hours + days
        var daysAndHoursAgoFullString: String = "n/a"

        let diffComponents = Calendar.current.dateComponents([.day, .hour, .minute], from: self, to: Date())

        if let days = diffComponents.day, let hours = diffComponents.hour, let minutes = diffComponents.minute {
            if days == 0 && hours < 1 {
                // show just minutes for less than one hour
                daysAndHoursAgoFullString = abs(minutes).description + " " + (abs(minutes) == 1 ? Texts_Common.minute : Texts_Common.minutes)
            } else if days == 0 && hours < 12 {
                // show just hours and minutes for less than twelve hours
                daysAndHoursAgoFullString = abs(hours).description + " " + (abs(hours) == 1 ? Texts_Common.hour : Texts_Common.hours) + " " + abs(minutes).description + " " + (abs(minutes) == 1 ? Texts_Common.minute : Texts_Common.minutes)
            } else {
                // default show days and hours
                daysAndHoursAgoFullString = abs(days).description + " " + (abs(days) == 1 ? Texts_Common.day : Texts_Common.days) + " " + abs(hours).description + " " + (abs(hours) == 1 ? Texts_Common.hour : Texts_Common.hours)
            }
            
            // if the function was called using appendAgo == true, then add the "ago" string
            if appendAgo ?? false {
                daysAndHoursAgoFullString += " " + Texts_HomeView.ago
            }
        }
        
        return daysAndHoursAgoFullString
    }
    
    
    /// returns the Nightscout style string showing the days and hours until a date (e.g. "6d11h")
    /// we will add directly 1 minute to the date to round up. This gives the result more context.
    /// Example return: "6d11h" if optional appendRemaining is false or not used
    /// Example return: "6d11h remaining" if optional appendRemaining is true
    /// if less than 12 hours, return also minutes, e.g: "7h43m" or "58m" to give extra granularity
    func daysAndHoursRemaining(appendRemaining: Bool? = false, showOnlyDays: Bool? = false) -> String {
        // add a minute to the date stored in self. This avoids showing "0m" when 59 seconds is actually remaining.
        let roundedDateToUpperMinute = self.addingTimeInterval(60)
        
        // set a default value assuming that we're unable to calculate the hours + days
        var daysAndHoursRemainingString: String = "n/a"

        let diffComponents = Calendar.current.dateComponents([.day, .hour, .minute], from: Date(), to: roundedDateToUpperMinute)

        if let days = diffComponents.day, let hours = diffComponents.hour, let minutes = diffComponents.minute {
            if days == 0 && hours < 1 {
                // show just minutes for less than one hour
                daysAndHoursRemainingString = abs(minutes).description + Texts_Common.minuteshort
            } else if days == 0 && hours < 12 {
                // show just hours and minutes for less than twelve hours
                daysAndHoursRemainingString = abs(hours).description + Texts_Common.hourshort + abs(minutes).description + Texts_Common.minuteshort
            } else {
                // default show days and hours
                daysAndHoursRemainingString = abs(days).description + Texts_Common.dayshort + (!(showOnlyDays ?? false) ? abs(hours).description + Texts_Common.hourshort : "")
            }
            
            // if the function was called using appendRemaining == true, then add the "remaining" string
            if appendRemaining ?? false {
                daysAndHoursRemainingString += " " + Texts_HomeView.remaining
            }
        }

        return daysAndHoursRemainingString
    }
}
