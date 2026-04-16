import Foundation

/// RepeatingTimer mimics the API of DispatchSourceTimer but in a way that prevents
/// crashes that occur from calling resume multiple times on a timer that is
/// already resumed (noted by https://github.com/SiftScience/sift-ios/issues/52
///
/// source : https://medium.com/over-engineering/a-background-repeating-timer-in-swift-412cecfd2ef9
class RepeatingTimer {
    
    private let timeInterval: TimeInterval
    
    private var eventHandler: (() -> Void)?
    
    init(timeInterval: TimeInterval, eventHandler: @escaping (() -> Void)) {
        self.timeInterval = timeInterval
        self.eventHandler = eventHandler
    }
    
    private lazy var timer: DispatchSourceTimer = {
        let t = DispatchSource.makeTimerSource()
        t.schedule(deadline: .now() + self.timeInterval, repeating: self.timeInterval)
        t.setEventHandler(handler: { [weak self] in
            if let eventHandler = self?.eventHandler {
                eventHandler()
            }
        })
        return t
    }()
    
    private enum State {
        case suspended
        case resumed
    }
    
    private var state: State = .suspended
    
    deinit {
        timer.setEventHandler {}
        timer.cancel()
        /*
         If the timer is suspended, calling cancel without resuming
         triggers a crash. This is documented here https://forums.developer.apple.com/thread/15902
         */
        resume()
        eventHandler = nil
    }
    
    func resume() {
        if state == .resumed {
            timer.suspend()
        }
        state = .resumed
        timer.resume()
    }
    
    func suspend() {
        if state == .suspended {
            return
        }
        state = .suspended
        timer.suspend()
    }
}
