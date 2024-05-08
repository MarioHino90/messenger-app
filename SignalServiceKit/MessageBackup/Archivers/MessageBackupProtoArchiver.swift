//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

public protocol MessageBackupLoggableId {
    /// The type, e.g. "TSInteraction" or "ChatItemProto"
    var typeLogString: String { get }

    /// The identifier, scoped to the type, e.g. TSInteraction.uniqueId
    var idLogString: String { get }
}

extension MessageBackup {

    /// Note the "multi"; covers the archiving of multiple frames, typically
    /// batched by type.
    public enum ArchiveMultiFrameResult<AppIdType: MessageBackupLoggableId> {
        public typealias ArchiveFrameError = MessageBackup.ArchiveFrameError<AppIdType>

        case success
        /// We managed to write some frames, but failed for others.
        /// Note that some errors _may_ be terminal; the caller should check.
        case partialSuccess([ArchiveFrameError])
        /// Catastrophic failure, e.g. we failed to read from the database at all
        /// for an entire category of frame.
        case completeFailure(FatalArchivingError)
    }

    public enum RestoreFrameResult<ProtoIdType: MessageBackupLoggableId> {
        case success
        /// We managed to restore some part of the frame, meaning it is represented in our database.
        /// For example, we restored a message but dropped some invalid recipients.
        /// Generally restoration of other frames can proceed, but the caller can determine
        /// whether to stop or not based on the specific error(s).
        case partialRestore([RestoreFrameError<ProtoIdType>])
        /// Failure to restore the given frame.
        /// Generally restoration of other frames can proceed, but the caller can determine
        /// whether to stop or not based on the specific error(s).
        case failure([RestoreFrameError<ProtoIdType>])
    }
}

public protocol MessageBackupProtoArchiver {

}

extension MessageBackupProtoArchiver {

    /**
     * Helper function to build a frame and write the proto to the backup file in one action
     * with standard error handling.
     */
    internal static func writeFrameToStream<AppIdType>(
        _ stream: MessageBackupProtoOutputStream,
        objectId: AppIdType,
        frameBuilder: () -> BackupProto.Frame
    ) -> MessageBackup.ArchiveFrameError<AppIdType>? {
        let frame = frameBuilder()
        switch stream.writeFrame(frame) {
        case .success:
            return nil
        case .fileIOError(let error):
            return .archiveFrameError(.fileIOError(error), objectId)
        case .protoSerializationError(let error):
            return .archiveFrameError(.protoSerializationError(error), objectId)
        }
    }
}
