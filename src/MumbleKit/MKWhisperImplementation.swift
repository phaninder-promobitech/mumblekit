//
//  MKWhisperImplementation.swift
//  MumbleKit
//
//  Created by Phaninder Kumar on 10/07/21.
//

import Foundation

@objc public protocol WhisperTarget {
    
    func createTarget() -> MPVoiceTargetTarget?

    // *
    //      * Returns a user-readable name for the whisper target, to display in the UI.
    //      * @return A channel name or list of users, depending on the implementation.
    func getName() -> String
}

@objc open class WhisperTargetUsers: NSObject, WhisperTarget {
    
    public let users: [MKUser]
    
    @objc public init(users: [MKUser]) {
        self.users = users
    }
    
    @objc open func createTarget() -> MPVoiceTargetTarget? {
        let builder = MPVoiceTargetTarget.builder()
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

@objc open class WhisperTargetChannel: NSObject, WhisperTarget {
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

    @objc open func createTarget() -> MPVoiceTargetTarget? {
        guard let builder = MPVoiceTargetTarget.builder() else {
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
    public let targetMin: Int = 1
    public let targetMax: Int = 30
    private var mActiveTargets: [WhisperTarget?]
    //  Mumble stores voice targets using a 5-bit identifier.
    //  Use a bit vector to represent this 32-element range.

    private var mTakenIds: Int32 = 0

    public override init() {
        mActiveTargets = [WhisperTarget?](repeating: nil, count: (targetMax - targetMin) + 1)
        mTakenIds = 1 | (1 << 31)
    }

    // *
    //      * Assigns the target to a slot.
    //      * @param target The whisper target to assign.
    //      * @return The slot number in range [1, 30].
    @objc public func append(_ target: WhisperTarget!) -> Int {
        var freeId: Int = -1
        for index in targetMin ... targetMax - 1 {
            if mTakenIds & (1 << index) == 0 {
                freeId = index
                break
            }
        }
        if freeId != (-1) {
            mActiveTargets[freeId - targetMin] = target
        }
        return freeId
    }

    @objc public func get(_ id: Int) -> WhisperTarget! {
        if (mTakenIds & (1 << id)) > 0 {
            return nil
        }
        return mActiveTargets[id - targetMin]
    }

    // TODO: Implemente this if this is necessary.
    @objc public func free(_ slot: Int) {
        if (slot < targetMin) || (slot > targetMax) {
            return
//            throw IllegalArgumentException()
        }
        mTakenIds &= ~(1 << slot)
    }

    @objc public func spaceRemaining() -> Int32 {
        var counter: Int32 = 0
        for index in targetMin ... targetMax - 1 {
            if mTakenIds & (1 << index) == 0 {
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
    
    func fetchUsersWithIds(_ userIds: [String]) -> [MKUser] {
        guard let userMap = self.userMap() as? [Int: MKUser] else { return [] }
        let filteredUsers = userMap.values.filter { (user) -> Bool in
            userIds.contains(user.userName() ?? "")
        }
        return filteredUsers
    }
    
    func sendMessageToUsers(_ users: [MKUser], fromUserName userName: String, andChannelId channelId: String?, withChannelName channelName: String?, talkType type: Int, sentAt: Int) {
        guard let connectedUser = self.connectedUser(),
              let userId = connectedUser.comment() else { return }
        var dict = ["user_id": userId,
                    "sent_at": sentAt,
                    "type": type,
                    "ptt_session_id": connectedUser.session(),
                    "user_name": userName] as [String: Any]
        if let channelId = channelId {
            dict["channel_id"] = channelId
        }
        if let channelName = channelName {
            dict["channel_name"] = channelName
        }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        self.send(MKTextMessage(plainText: jsonString), toTreeChannels: nil, andChannels: nil, andUsers: users)
    }
    
}
