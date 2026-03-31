/// defines name of the Soundfile and name of the sound shown to the user with an extra function - both are defined in one case, seperated by a backslash - to be used for alerts - all these sounds will be shown
enum ConstantsSounds: String, CaseIterable {
    
    // here using case iso properties because we want to iterate through them
    // name of the sound as shown to the user, and also stored in the alerttype
    case batterwakeup = "Better Wake Up/betterwakeup.caf"
    case bruteforce = "Brute Force/bruteforce.caf"
    case modernalarm2 = "Modern Alert 2/modern2.caf"
    case modernalarm = "Modern Alert/modernalarm.caf"
    case shorthigh1 = "Short High 1/shorthigh1.caf"
    case shorthigh2 = "Short High 2/shorthigh2.caf"
    case shorthigh3 = "Short High 3/shorthigh3.caf"
    case shorthigh4 = "Short High 4/shorthigh4.caf"
    case shortlow1  = "Short Low 1/shortlow1.caf"
    case shortlow2  = "Short Low 2/shortlow2.caf"
    case shortlow3  = "Short Low 3/shortlow3.caf"
    case shortlow4  = "Short Low 4/shortlow4.caf"
    case spaceship = "Space Ship/spaceship.caf"
    case xdripalert = "xDrip Alert/xdripalert.aif"
    
    // copied from Spike project https://github.com/SpikeApp/Spike/tree/master/src/assets/sounds
    case Alarm_Buzzer = "Alarm Buzzer/Alarm_Buzzer.caf"
    case Alarm_Clock = "Alarm Clock/Alarm_Clock.caf"
    case Alert_Tone_Busy = "Alert Tone Busy/Alert_Tone_Busy.caf"
    case Alert_Tone_Ringtone_1 = "Alert Tone Ringtone 1/Alert_Tone_Ringtone_1.caf"
    case Alert_Tone_Ringtone_2 = "Alert Tone Ringtone 2/Alert_Tone_Ringtone_2.caf"
    case Alien_Siren = "Alien Siren/Alien_Siren.caf"
    case Ambulance = "Ambulance/Ambulance.caf"
    case Analog_Watch_Alarm = "Analog Watch Alarm/Analog_Watch_Alarm.caf"
    case Big_Clock_Ticking = "Big Clock Ticking/Big_Clock_Ticking.caf"
    case Burglar_Alarm_Siren_1 = "Burglar Alarm Siren 1/Burglar_Alarm_Siren_1.caf"
    case Burglar_Alarm_Siren_2 = "Burglar Alarm Siren 2/Burglar_Alarm_Siren_2.caf"
    case Cartoon_Ascend_Climb_Sneaky = "Cartoon Ascend Climb Sneaky/Cartoon_Ascend_Climb_Sneaky.caf"
    case Cartoon_Ascend_Then_Descend = "Cartoon Ascend Then Descend/Cartoon_Ascend_Then_Descend.caf"
    case Cartoon_Bounce_To_Ceiling = "Cartoon Bounce To Ceiling/Cartoon_Bounce_To_Ceiling.caf"
    case Cartoon_Dreamy_Glissando_Harp = "Cartoon Dreamy Glissando Harp/Cartoon_Dreamy_Glissando_Harp.caf"
    case Cartoon_Fail_Strings_Trumpet = "Cartoon Fail Strings Trumpet/Cartoon_Fail_Strings_Trumpet.caf"
    case Cartoon_Machine_Clumsy_Loop = "Cartoon Machine Clumsy Loop/Cartoon_Machine_Clumsy_Loop.caf"
    case Cartoon_Siren = "Cartoon Siren/Cartoon_Siren.caf"
    case Cartoon_Tip_Toe_Sneaky_Walk = "Cartoon Tip Toe Sneaky Walk/Cartoon_Tip_Toe_Sneaky_Walk.caf"
    case Cartoon_Uh_Oh = "Cartoon Uh Oh/Cartoon_Uh_Oh.caf"
    case Cartoon_Villain_Horns = "Cartoon Villain Horns/Cartoon_Villain_Horns.caf"
    case Cell_Phone_Ring_Tone = "Cell Phone Ring Tone/Cell_Phone_Ring_Tone.caf"
    case Chimes_Glassy = "Chimes Glassy/Chimes_Glassy.caf"
    case Computer_Magic = "Computer Magic/Computer_Magic.caf"
    case CSFX2_Alarm = "CSFX2 Alarm/CSFX-2_Alarm.caf"
    case Cuckoo_Clock = "Cuckoo Clock/Cuckoo_Clock.caf"
    case Dhol_Shuffleloop = "Dhol Shuffleloop/Dhol_Shuffleloop.caf"
    case Discreet = "Discreet/Discreet.caf"
    case Early_Sunrise = "Early Sunrise/Early_Sunrise.caf"
    case Emergency_Alarm_Carbon_Monoxide = "Emergency Alarm Carbon Monoxide/Emergency_Alarm_Carbon_Monoxide.caf"
    case Emergency_Alarm_Siren = "Emergency Alarm Siren/Emergency_Alarm_Siren.caf"
    case Emergency_Alarm = "Emergency Alarm/Emergency_Alarm.caf"
    case Ending_Reached = "Ending Reached/Ending_Reached.caf"
    case Fly = "Fly/Fly.caf"
    case Ghost_Hover = "Ghost Hover/Ghost_Hover.caf"
    case Good_Morning = "Good Morning/Good_Morning.caf"
    case Hell_Yeah_Somewhat_Calmer = "Hell Yeah Somewhat Calmer/Hell_Yeah_Somewhat_Calmer.caf"
    case In_A_Hurry = "In A Hurry/In_A_Hurry.caf"
    case Indeed = "Indeed/Indeed.caf"
    case Insistently = "Insistently/Insistently.caf"
    case Jingle_All_The_Way = "Jingle All The Way/Jingle_All_The_Way.caf"
    case Laser_Shoot = "Laser Shoot/Laser_Shoot.caf"
    case Machine_Charge = "Machine Charge/Machine_Charge.caf"
    case Magical_Twinkle = "Magical Twinkle/Magical_Twinkle.caf"
    case Marching_Heavy_Footed_Fat_Elephants = "Marching Heavy Footed Fat Elephants/Marching_Heavy_Footed_Fat_Elephants.caf"
    case Marimba_Descend = "Marimba Descend/Marimba_Descend.caf"
    case Marimba_Flutter_or_Shake = "Marimba Flutter or Shake/Marimba_Flutter_or_Shake.caf"
    case Martian_Gun = "Martian Gun/Martian_Gun.caf"
    case Martian_Scanner = "Martian Scanner/Martian_Scanner.caf"
    case Metallic = "Metallic/Metallic.caf"
    case Nightguard = "Nightguard/Nightguard.caf"
    case Not_Kiddin = "Not Kiddin/Not_Kiddin.caf"
    case Open_Your_Eyes_And_See = "Open Your Eyes And See/Open_Your_Eyes_And_See.caf"
    case Orchestral_Horns = "Orchestral Horns/Orchestral_Horns.caf"
    case Oringz = "Oringz/Oringz.caf"
    case Pager_Beeps = "Pager Beeps/Pager_Beeps.caf"
    case Remembers_Me_Of_Asia = "Remembers Me Of Asia/Remembers_Me_Of_Asia.caf"
    case Rise_And_Shine = "Rise And Shine/Rise_And_Shine.caf"
    case Rush = "Rush/Rush.caf"
    case SciFi_Air_Raid_Alarm = "SciFi Air Raid Alarm/Sci-Fi_Air_Raid_Alarm.caf"
    case SciFi_Alarm_Loop_1 = "SciFi Alarm Loop 1/Sci-Fi_Alarm_Loop_1.caf"
    case SciFi_Alarm_Loop_2 = "SciFi Alarm Loop 2/Sci-Fi_Alarm_Loop_2.caf"
    case SciFi_Alarm_Loop_3 = "SciFi Alarm Loop 3/Sci-Fi_Alarm_Loop_3.caf"
    case SciFi_Alarm_Loop_4 = "SciFi Alarm Loop 4/Sci-Fi_Alarm_Loop_4.caf"
    case SciFi_Alarm = "SciFi Alarm/Sci-Fi_Alarm.caf"
    case SciFi_Computer_Console_Alarm = "SciFi Computer Console Alarm/Sci-Fi_Computer_Console_Alarm.caf"
    case SciFi_Console_Alarm = "SciFi Console Alarm/Sci-Fi_Console_Alarm.caf"
    case SciFi_Eerie_Alarm = "SciFi Eerie Alarm/Sci-Fi_Eerie_Alarm.caf"
    case SciFi_Engine_Shut_Down = "SciFi Engine Shut Down/Sci-Fi_Engine_Shut_Down.caf"
    case SciFi_Incoming_Message_Alert = "SciFi Incoming Message Alert/Sci-Fi_Incoming_Message_Alert.caf"
    case SciFi_Spaceship_Message = "SciFi Spaceship Message/Sci-Fi_Spaceship_Message.caf"
    case SciFi_Spaceship_Warm_Up = "SciFi Spaceship Warm Up/Sci-Fi_Spaceship_Warm_Up.caf"
    case SciFi_Warning = "SciFi Warning/Sci-Fi_Warning.caf"
    case Signature_Corporate = "Signature Corporate/Signature_Corporate.caf"
    case Siri_Alert_Calibration_Needed = "Siri Alert Calibration Needed/Siri_Alert_Calibration_Needed.caf"
    case Siri_Alert_Device_Muted = "Siri Alert Device Muted/Siri_Alert_Device_Muted.caf"
    case Siri_Alert_Glucose_Dropping_Fast = "Siri Alert Glucose Dropping Fast/Siri_Alert_Glucose_Dropping_Fast.caf"
    case Siri_Alert_Glucose_Rising_Fast = "Siri Alert Glucose Rising Fast/Siri_Alert_Glucose_Rising_Fast.caf"
    case Siri_Alert_High_Glucose = "Siri Alert High Glucose/Siri_Alert_High_Glucose.caf"
    case Siri_Alert_Low_Glucose = "Siri Alert Low Glucose/Siri_Alert_Low_Glucose.caf"
    case Siri_Alert_Missed_Readings = "Siri Alert Missed Readings/Siri_Alert_Missed_Readings.caf"
    case Siri_Alert_Transmitter_Battery_Low = "Siri Alert Transmitter Battery Low/Siri_Alert_Transmitter_Battery_Low.caf"
    case Siri_Alert_Urgent_High_Glucose = "Siri Alert Urgent High Glucose/Siri_Alert_Urgent_High_Glucose.caf"
    case Siri_Alert_Urgent_Low_Glucose = "Siri Alert Urgent Low Glucose/Siri_Alert_Urgent_Low_Glucose.caf"
    case Siri_Calibration_Needed = "Siri Calibration Needed/Siri_Calibration_Needed.caf"
    case Siri_Device_Muted = "Siri Device Muted/Siri_Device_Muted.caf"
    case Siri_Glucose_Dropping_Fast = "Siri Glucose Dropping Fast/Siri_Glucose_Dropping_Fast.caf"
    case Siri_Glucose_Rising_Fast = "Siri Glucose Rising Fast/Siri_Glucose_Rising_Fast.caf"
    case Siri_High_Glucose = "Siri High Glucose/Siri_High_Glucose.caf"
    case Siri_Low_Glucose = "Siri Low Glucose/Siri_Low_Glucose.caf"
    case Siri_Missed_Readings = "Siri Missed Readings/Siri_Missed_Readings.caf"
    case Siri_Transmitter_Battery_Low = "Siri Transmitter Battery Low/Siri_Transmitter_Battery_Low.caf"
    case Siri_Urgent_High_Glucose = "Siri Urgent High Glucose/Siri_Urgent_High_Glucose.caf"
    case Siri_Urgent_Low_Glucose = "Siri Urgent Low Glucose/Siri_Urgent_Low_Glucose.caf"
    case Soft_Marimba_Pad_Positive = "Soft Marimba Pad Positive/Soft_Marimba_Pad_Positive.caf"
    case Soft_Warm_Airy_Optimistic = "Soft Warm Airy Optimistic/Soft_Warm_Airy_Optimistic.caf"
    case Soft_Warm_Airy_Reassuring = "Soft Warm Airy Reassuring/Soft_Warm_Airy_Reassuring.caf"
    case Store_Door_Chime = "Store Door Chime/Store_Door_Chime.caf"
    case Sunny = "Sunny/Sunny.caf"
    case Thunder_Sound_FX = "Thunder Sound FX/Thunder_Sound_FX.caf"
    case Time_Has_Come = "Time Has Come/Time_Has_Come.caf"
    case Tornado_Siren = "Tornado Siren/Tornado_Siren.caf"
    case Two_Turtle_Doves = "Two Turtle Doves/Two_Turtle_Doves.caf"
    case Unpaved = "Unpaved/Unpaved.caf"
    case Wake_Up_Will_You = "Wake Up Will You/Wake_Up_Will_You.caf"
    case Win_Gain = "Win Gain/Win_Gain.caf"
    case Wrong_Answer = "Wrong Answer/Wrong_Answer.caf"
    
    /// gets all sound names in array, ie part of the case before the /
    static func allSoundsBySoundNameAndFileName() -> (soundNames:[String], fileNames:[String]) {
        var soundNames = [String]()
        var soundFileNames = [String]()
        
        soundloop: for sound in ConstantsSounds.allCases {
            
            // ConstantsSounds defines available sounds. Per case there a string which is the soundname as shown in the UI and the filename of the sound in the Resources folder, seperated by backslash
            // get array of indexes, of location of "/"
            let indexOfBackSlash = sound.rawValue.indexes(of: "/")
            
            // define range to get the soundname (as shown in UI)
            let soundNameRange = sound.rawValue.startIndex..<indexOfBackSlash[0]
            
            // now get the soundName in a string
            let soundName = String(sound.rawValue[soundNameRange])
            
            // add the soundName to the returnvalue
            soundNames.append(soundName)
            
            // define range to get the soundFileName
            let languageCodeRange = sound.rawValue.index(after: indexOfBackSlash[0])..<sound.rawValue.endIndex
            
            // now get the language in a string
            let fileName = String(sound.rawValue[languageCodeRange])
            // add the languageCode to the returnvalue
            
            soundFileNames.append(fileName)
            
        }
        return (soundNames, soundFileNames)
    }
    
    /// gets the soundname for specific case
    static func getSoundName(forSound:ConstantsSounds) -> String {
        let indexOfBackSlash = forSound.rawValue.indexes(of: "/")
        let soundNameRange = forSound.rawValue.startIndex..<indexOfBackSlash[0]
        return String(forSound.rawValue[soundNameRange])
    }
    
    /// gets the soundFile for specific case
    static func getSoundFile(forSound:ConstantsSounds) -> String {
        let indexOfBackSlash = forSound.rawValue.indexes(of: "/")
        let soundNameRange = forSound.rawValue.index(after: indexOfBackSlash[0])..<forSound.rawValue.endIndex
        return String(forSound.rawValue[soundNameRange])
    }
}
