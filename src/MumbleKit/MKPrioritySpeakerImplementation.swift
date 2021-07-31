//
//  MKPrioritySpeakerImplementation.swift
//  MumbleKit (iOS)
//
//  Created by Phaninder Kumar on 31/07/21.
//

import Foundation

@objc open class AudioPriorityManager: NSObject {
    
    private static var privateShared : AudioPriorityManager?

    @objc class func shared() -> AudioPriorityManager {
        guard let sharedInstance = privateShared else {
            privateShared = AudioPriorityManager()
            return privateShared!
        }
        return sharedInstance
    }

    private var prioritySpeaker: MKUser? = nil
    public var shouldPauseAudio: Bool = false
    
    @objc open func fetchPrioritySpeaker() -> MKUser? {
        return prioritySpeaker
    }
    
    @objc open func setPrioritySpeaker(_ user: MKUser) {
        prioritySpeaker = user
//        shouldPauseAudio = false
    }
        
    @objc open func clearPrioritySpeaker() {
        prioritySpeaker = nil
    }
    
    @objc open func setAudioPauseState(_ status: Bool) {
        shouldPauseAudio = status
        if status {
            prioritySpeaker = nil
        }
    }
    
    @objc open func isAudioAllowedForUser(_ session: NSInteger) -> Bool {
        guard let speaker = self.prioritySpeaker else {
            return !shouldPauseAudio
        }
//        shouldPauseAudio = false
        return speaker.session() == session
    }
 
}
