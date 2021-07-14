//
//  MKWhisperImplementation.swift
//  MumbleKit
//
//  Created by Phaninder Kumar on 10/07/21.
//

import Foundation

@objc public protocol WhisperTarget {
    
    
    func createTarget() -> MPVoiceTarget_Target?

    // *
    //      * Returns a user-readable name for the whisper target, to display in the UI.
    //      * @return A channel name or list of users, depending on the implementation.
    func getName() -> String
}

@objc open class WhisperTargetUsers : NSObject, WhisperTarget {
    
    public let users: [MKUser]
    
    @objc public init(users: [MKUser]) {
        self.users = users
    }
    
    @objc open func createTarget() -> MPVoiceTarget_Target? {
        let builder = MPVoiceTarget_Target.builder()
        builder?.setLinks(false)
        builder?.setChildren(false)
        for user in users {
            builder?.addSession(UInt32(user.session()))
        }
        return builder?.build()
    }
    
    @objc open func getName() -> String {
        return users.first?.comment() ?? ""
    }
}

@objc open class WhisperTargetChannel : NSObject, WhisperTarget {
    private let channel: MKChannel
    private let includeLinked: Bool
    private let includeSubchannels: Bool
    private let groupRestriction: String?

    @objc public init(_ channel: MKChannel!, includeLinked: Bool, includeSubchannels: Bool, groupRestriction: String?) {
        self.channel = channel
        self.includeLinked = includeLinked
        self.includeSubchannels = includeSubchannels
        self.groupRestriction = groupRestriction
    }

    @objc open func createTarget() -> MPVoiceTarget_Target? {
        guard let builder = MPVoiceTarget_Target.builder() else {
            return nil
        }
        builder.setLinks(includeLinked)
        builder.setChildren(includeSubchannels)
        if let restriction = groupRestriction {
            builder.setGroup(restriction)
        }
        builder.setChannelId(UInt32(channel.channelId()))
        return builder.build()
    }

    @objc open func getName() -> String {
        return channel.channelName() ?? ""
    }
}
@objc class WhisperTargetList: NSObject {
    public let TARGET_MIN: Int = 1
    public let TARGET_MAX: Int = 30
    private var mActiveTargets: [WhisperTarget?]
    //  Mumble stores voice targets using a 5-bit identifier.
    //  Use a bit vector to represent this 32-element range.

    private var mTakenIds: Int32 = 0

    public override init() {
        mActiveTargets = [WhisperTarget?](repeating: nil, count: (TARGET_MAX - TARGET_MIN) + 1)
        mTakenIds = 1 | (1 << 31)
    }

    // *
    //      * Assigns the target to a slot.
    //      * @param target The whisper target to assign.
    //      * @return The slot number in range [1, 30].
    @objc public func append(_ target: WhisperTarget!) -> Int {
        var freeId: Int = -1
        for i in TARGET_MIN ... TARGET_MAX - 1 {
            if (mTakenIds & (1 << i)) == 0 {
                freeId = i
                break
            }
        }
        if freeId != (-1) {
            mActiveTargets[freeId - TARGET_MIN] = target
        }
        return freeId
    }

    @objc public func get(_ id: Int) -> WhisperTarget! {
        if (mTakenIds & (1 << id)) > 0 {
            return nil
        }
        return mActiveTargets[id - TARGET_MIN]
    }

    //TODO: Implemente this if this is necessary.
    @objc public func free(_ slot: Int) {
        if (slot < TARGET_MIN) || (slot > TARGET_MAX) {
            return
//            throw IllegalArgumentException()
        }
        mTakenIds &= ~(1 << slot);
    }

    @objc public func spaceRemaining() -> Int32 {
        var counter: Int32 = 0
        for i in TARGET_MIN ... TARGET_MAX - 1 {
            if (mTakenIds & (1 << i)) == 0 {
                counter += 1
            }
        }
        return counter
    }

    @objc public func clear() {
        //  Slots 0 and 31 are non-whisper targets.
        mTakenIds = 1 | (1 << 31)
    }
}

@objc public extension MKServerModel {
    
    @objc func fetchUsersWithIds(_ userIds: [String]) -> [MKUser] {
        guard let userMap = self.userMap() as? [Int: MKUser] else { return [] }
        let filteredUsers = userMap.values.filter { (user) -> Bool in
            userIds.contains(user.comment() ?? "")
        }
        return filteredUsers
    }
    
    @objc func sendMessageToUsers(_ users: [MKUser], andChannelId channelId: String?, talkType type: Int) {
        guard let connectedUser = self.connectedUser(),
              let userId = connectedUser.comment() else { return }
        var dict = ["user_id": userId,
                    "sent_at": Int(Date().timeIntervalSince1970 * 1000),
                    "type": type,
                    "session_id": connectedUser.session()] as [String : Any]
        if let channelId = channelId {
            dict["channel_id"] = channelId
        }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        self.send(MKTextMessage(plainText: jsonString), toTreeChannels: nil, andChannels: nil, andUsers: users)
    }
    
}
