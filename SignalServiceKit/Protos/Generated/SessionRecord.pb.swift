//
// Copyright 2020 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

// DO NOT EDIT.
// swift-format-ignore-file
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: SessionRecord.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

//
// Copyright 2020 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only

import Foundation
import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

struct SessionRecordProtos_SessionStructure {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var sessionVersion: UInt32 {
    get {return _storage._sessionVersion ?? 0}
    set {_uniqueStorage()._sessionVersion = newValue}
  }
  /// Returns true if `sessionVersion` has been explicitly set.
  var hasSessionVersion: Bool {return _storage._sessionVersion != nil}
  /// Clears the value of `sessionVersion`. Subsequent reads from it will return its default value.
  mutating func clearSessionVersion() {_uniqueStorage()._sessionVersion = nil}

  var localIdentityPublic: Data {
    get {return _storage._localIdentityPublic ?? Data()}
    set {_uniqueStorage()._localIdentityPublic = newValue}
  }
  /// Returns true if `localIdentityPublic` has been explicitly set.
  var hasLocalIdentityPublic: Bool {return _storage._localIdentityPublic != nil}
  /// Clears the value of `localIdentityPublic`. Subsequent reads from it will return its default value.
  mutating func clearLocalIdentityPublic() {_uniqueStorage()._localIdentityPublic = nil}

  var remoteIdentityPublic: Data {
    get {return _storage._remoteIdentityPublic ?? Data()}
    set {_uniqueStorage()._remoteIdentityPublic = newValue}
  }
  /// Returns true if `remoteIdentityPublic` has been explicitly set.
  var hasRemoteIdentityPublic: Bool {return _storage._remoteIdentityPublic != nil}
  /// Clears the value of `remoteIdentityPublic`. Subsequent reads from it will return its default value.
  mutating func clearRemoteIdentityPublic() {_uniqueStorage()._remoteIdentityPublic = nil}

  var rootKey: Data {
    get {return _storage._rootKey ?? Data()}
    set {_uniqueStorage()._rootKey = newValue}
  }
  /// Returns true if `rootKey` has been explicitly set.
  var hasRootKey: Bool {return _storage._rootKey != nil}
  /// Clears the value of `rootKey`. Subsequent reads from it will return its default value.
  mutating func clearRootKey() {_uniqueStorage()._rootKey = nil}

  var previousCounter: UInt32 {
    get {return _storage._previousCounter ?? 0}
    set {_uniqueStorage()._previousCounter = newValue}
  }
  /// Returns true if `previousCounter` has been explicitly set.
  var hasPreviousCounter: Bool {return _storage._previousCounter != nil}
  /// Clears the value of `previousCounter`. Subsequent reads from it will return its default value.
  mutating func clearPreviousCounter() {_uniqueStorage()._previousCounter = nil}

  var senderChain: SessionRecordProtos_SessionStructure.Chain {
    get {return _storage._senderChain ?? SessionRecordProtos_SessionStructure.Chain()}
    set {_uniqueStorage()._senderChain = newValue}
  }
  /// Returns true if `senderChain` has been explicitly set.
  var hasSenderChain: Bool {return _storage._senderChain != nil}
  /// Clears the value of `senderChain`. Subsequent reads from it will return its default value.
  mutating func clearSenderChain() {_uniqueStorage()._senderChain = nil}

  /// The order is significant; keys at the end are "older" and will get trimmed.
  var receiverChains: [SessionRecordProtos_SessionStructure.Chain] {
    get {return _storage._receiverChains}
    set {_uniqueStorage()._receiverChains = newValue}
  }

  var pendingPreKey: SessionRecordProtos_SessionStructure.PendingPreKey {
    get {return _storage._pendingPreKey ?? SessionRecordProtos_SessionStructure.PendingPreKey()}
    set {_uniqueStorage()._pendingPreKey = newValue}
  }
  /// Returns true if `pendingPreKey` has been explicitly set.
  var hasPendingPreKey: Bool {return _storage._pendingPreKey != nil}
  /// Clears the value of `pendingPreKey`. Subsequent reads from it will return its default value.
  mutating func clearPendingPreKey() {_uniqueStorage()._pendingPreKey = nil}

  var remoteRegistrationID: UInt32 {
    get {return _storage._remoteRegistrationID ?? 0}
    set {_uniqueStorage()._remoteRegistrationID = newValue}
  }
  /// Returns true if `remoteRegistrationID` has been explicitly set.
  var hasRemoteRegistrationID: Bool {return _storage._remoteRegistrationID != nil}
  /// Clears the value of `remoteRegistrationID`. Subsequent reads from it will return its default value.
  mutating func clearRemoteRegistrationID() {_uniqueStorage()._remoteRegistrationID = nil}

  var localRegistrationID: UInt32 {
    get {return _storage._localRegistrationID ?? 0}
    set {_uniqueStorage()._localRegistrationID = newValue}
  }
  /// Returns true if `localRegistrationID` has been explicitly set.
  var hasLocalRegistrationID: Bool {return _storage._localRegistrationID != nil}
  /// Clears the value of `localRegistrationID`. Subsequent reads from it will return its default value.
  mutating func clearLocalRegistrationID() {_uniqueStorage()._localRegistrationID = nil}

  var needsRefresh: Bool {
    get {return _storage._needsRefresh ?? false}
    set {_uniqueStorage()._needsRefresh = newValue}
  }
  /// Returns true if `needsRefresh` has been explicitly set.
  var hasNeedsRefresh: Bool {return _storage._needsRefresh != nil}
  /// Clears the value of `needsRefresh`. Subsequent reads from it will return its default value.
  mutating func clearNeedsRefresh() {_uniqueStorage()._needsRefresh = nil}

  var aliceBaseKey: Data {
    get {return _storage._aliceBaseKey ?? Data()}
    set {_uniqueStorage()._aliceBaseKey = newValue}
  }
  /// Returns true if `aliceBaseKey` has been explicitly set.
  var hasAliceBaseKey: Bool {return _storage._aliceBaseKey != nil}
  /// Clears the value of `aliceBaseKey`. Subsequent reads from it will return its default value.
  mutating func clearAliceBaseKey() {_uniqueStorage()._aliceBaseKey = nil}

  var unknownFields = SwiftProtobuf.UnknownStorage()

  struct Chain {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    var senderRatchetKey: Data {
      get {return _senderRatchetKey ?? Data()}
      set {_senderRatchetKey = newValue}
    }
    /// Returns true if `senderRatchetKey` has been explicitly set.
    var hasSenderRatchetKey: Bool {return self._senderRatchetKey != nil}
    /// Clears the value of `senderRatchetKey`. Subsequent reads from it will return its default value.
    mutating func clearSenderRatchetKey() {self._senderRatchetKey = nil}

    var senderRatchetKeyPrivate: Data {
      get {return _senderRatchetKeyPrivate ?? Data()}
      set {_senderRatchetKeyPrivate = newValue}
    }
    /// Returns true if `senderRatchetKeyPrivate` has been explicitly set.
    var hasSenderRatchetKeyPrivate: Bool {return self._senderRatchetKeyPrivate != nil}
    /// Clears the value of `senderRatchetKeyPrivate`. Subsequent reads from it will return its default value.
    mutating func clearSenderRatchetKeyPrivate() {self._senderRatchetKeyPrivate = nil}

    var chainKey: SessionRecordProtos_SessionStructure.Chain.ChainKey {
      get {return _chainKey ?? SessionRecordProtos_SessionStructure.Chain.ChainKey()}
      set {_chainKey = newValue}
    }
    /// Returns true if `chainKey` has been explicitly set.
    var hasChainKey: Bool {return self._chainKey != nil}
    /// Clears the value of `chainKey`. Subsequent reads from it will return its default value.
    mutating func clearChainKey() {self._chainKey = nil}

    var messageKeys: [SessionRecordProtos_SessionStructure.Chain.MessageKey] = []

    var unknownFields = SwiftProtobuf.UnknownStorage()

    struct ChainKey {
      // SwiftProtobuf.Message conformance is added in an extension below. See the
      // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
      // methods supported on all messages.

      var index: UInt32 {
        get {return _index ?? 0}
        set {_index = newValue}
      }
      /// Returns true if `index` has been explicitly set.
      var hasIndex: Bool {return self._index != nil}
      /// Clears the value of `index`. Subsequent reads from it will return its default value.
      mutating func clearIndex() {self._index = nil}

      var key: Data {
        get {return _key ?? Data()}
        set {_key = newValue}
      }
      /// Returns true if `key` has been explicitly set.
      var hasKey: Bool {return self._key != nil}
      /// Clears the value of `key`. Subsequent reads from it will return its default value.
      mutating func clearKey() {self._key = nil}

      var unknownFields = SwiftProtobuf.UnknownStorage()

      init() {}

      fileprivate var _index: UInt32? = nil
      fileprivate var _key: Data? = nil
    }

    struct MessageKey {
      // SwiftProtobuf.Message conformance is added in an extension below. See the
      // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
      // methods supported on all messages.

      var index: UInt32 {
        get {return _index ?? 0}
        set {_index = newValue}
      }
      /// Returns true if `index` has been explicitly set.
      var hasIndex: Bool {return self._index != nil}
      /// Clears the value of `index`. Subsequent reads from it will return its default value.
      mutating func clearIndex() {self._index = nil}

      var cipherKey: Data {
        get {return _cipherKey ?? Data()}
        set {_cipherKey = newValue}
      }
      /// Returns true if `cipherKey` has been explicitly set.
      var hasCipherKey: Bool {return self._cipherKey != nil}
      /// Clears the value of `cipherKey`. Subsequent reads from it will return its default value.
      mutating func clearCipherKey() {self._cipherKey = nil}

      var macKey: Data {
        get {return _macKey ?? Data()}
        set {_macKey = newValue}
      }
      /// Returns true if `macKey` has been explicitly set.
      var hasMacKey: Bool {return self._macKey != nil}
      /// Clears the value of `macKey`. Subsequent reads from it will return its default value.
      mutating func clearMacKey() {self._macKey = nil}

      var iv: Data {
        get {return _iv ?? Data()}
        set {_iv = newValue}
      }
      /// Returns true if `iv` has been explicitly set.
      var hasIv: Bool {return self._iv != nil}
      /// Clears the value of `iv`. Subsequent reads from it will return its default value.
      mutating func clearIv() {self._iv = nil}

      var unknownFields = SwiftProtobuf.UnknownStorage()

      init() {}

      fileprivate var _index: UInt32? = nil
      fileprivate var _cipherKey: Data? = nil
      fileprivate var _macKey: Data? = nil
      fileprivate var _iv: Data? = nil
    }

    init() {}

    fileprivate var _senderRatchetKey: Data? = nil
    fileprivate var _senderRatchetKeyPrivate: Data? = nil
    fileprivate var _chainKey: SessionRecordProtos_SessionStructure.Chain.ChainKey? = nil
  }

  struct PendingPreKey {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    var preKeyID: UInt32 {
      get {return _preKeyID ?? 0}
      set {_preKeyID = newValue}
    }
    /// Returns true if `preKeyID` has been explicitly set.
    var hasPreKeyID: Bool {return self._preKeyID != nil}
    /// Clears the value of `preKeyID`. Subsequent reads from it will return its default value.
    mutating func clearPreKeyID() {self._preKeyID = nil}

    var signedPreKeyID: Int32 {
      get {return _signedPreKeyID ?? 0}
      set {_signedPreKeyID = newValue}
    }
    /// Returns true if `signedPreKeyID` has been explicitly set.
    var hasSignedPreKeyID: Bool {return self._signedPreKeyID != nil}
    /// Clears the value of `signedPreKeyID`. Subsequent reads from it will return its default value.
    mutating func clearSignedPreKeyID() {self._signedPreKeyID = nil}

    var baseKey: Data {
      get {return _baseKey ?? Data()}
      set {_baseKey = newValue}
    }
    /// Returns true if `baseKey` has been explicitly set.
    var hasBaseKey: Bool {return self._baseKey != nil}
    /// Clears the value of `baseKey`. Subsequent reads from it will return its default value.
    mutating func clearBaseKey() {self._baseKey = nil}

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}

    fileprivate var _preKeyID: UInt32? = nil
    fileprivate var _signedPreKeyID: Int32? = nil
    fileprivate var _baseKey: Data? = nil
  }

  init() {}

  fileprivate var _storage = _StorageClass.defaultInstance
}

struct SessionRecordProtos_RecordStructure {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var currentSession: SessionRecordProtos_SessionStructure {
    get {return _currentSession ?? SessionRecordProtos_SessionStructure()}
    set {_currentSession = newValue}
  }
  /// Returns true if `currentSession` has been explicitly set.
  var hasCurrentSession: Bool {return self._currentSession != nil}
  /// Clears the value of `currentSession`. Subsequent reads from it will return its default value.
  mutating func clearCurrentSession() {self._currentSession = nil}

  /// The order is significant; sessions at the end are "older" and will get trimmed.
  var previousSessions: [SessionRecordProtos_SessionStructure] = []

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}

  fileprivate var _currentSession: SessionRecordProtos_SessionStructure? = nil
}

#if swift(>=5.5) && canImport(_Concurrency)
extension SessionRecordProtos_SessionStructure: @unchecked Sendable {}
extension SessionRecordProtos_SessionStructure.Chain: @unchecked Sendable {}
extension SessionRecordProtos_SessionStructure.Chain.ChainKey: @unchecked Sendable {}
extension SessionRecordProtos_SessionStructure.Chain.MessageKey: @unchecked Sendable {}
extension SessionRecordProtos_SessionStructure.PendingPreKey: @unchecked Sendable {}
extension SessionRecordProtos_RecordStructure: @unchecked Sendable {}
#endif  // swift(>=5.5) && canImport(_Concurrency)

// MARK: - Code below here is support for the SwiftProtobuf runtime.

fileprivate let _protobuf_package = "SessionRecordProtos"

extension SessionRecordProtos_SessionStructure: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".SessionStructure"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "sessionVersion"),
    2: .same(proto: "localIdentityPublic"),
    3: .same(proto: "remoteIdentityPublic"),
    4: .same(proto: "rootKey"),
    5: .same(proto: "previousCounter"),
    6: .same(proto: "senderChain"),
    7: .same(proto: "receiverChains"),
    9: .same(proto: "pendingPreKey"),
    10: .same(proto: "remoteRegistrationId"),
    11: .same(proto: "localRegistrationId"),
    12: .same(proto: "needsRefresh"),
    13: .same(proto: "aliceBaseKey"),
  ]

  fileprivate class _StorageClass {
    var _sessionVersion: UInt32? = nil
    var _localIdentityPublic: Data? = nil
    var _remoteIdentityPublic: Data? = nil
    var _rootKey: Data? = nil
    var _previousCounter: UInt32? = nil
    var _senderChain: SessionRecordProtos_SessionStructure.Chain? = nil
    var _receiverChains: [SessionRecordProtos_SessionStructure.Chain] = []
    var _pendingPreKey: SessionRecordProtos_SessionStructure.PendingPreKey? = nil
    var _remoteRegistrationID: UInt32? = nil
    var _localRegistrationID: UInt32? = nil
    var _needsRefresh: Bool? = nil
    var _aliceBaseKey: Data? = nil

    #if swift(>=5.10)
      // This property is used as the initial default value for new instances of the type.
      // The type itself is protecting the reference to its storage via CoW semantics.
      // This will force a copy to be made of this reference when the first mutation occurs;
      // hence, it is safe to mark this as `nonisolated(unsafe)`.
      static nonisolated(unsafe) let defaultInstance = _StorageClass()
    #else
      static let defaultInstance = _StorageClass()
    #endif

    private init() {}

    init(copying source: _StorageClass) {
      _sessionVersion = source._sessionVersion
      _localIdentityPublic = source._localIdentityPublic
      _remoteIdentityPublic = source._remoteIdentityPublic
      _rootKey = source._rootKey
      _previousCounter = source._previousCounter
      _senderChain = source._senderChain
      _receiverChains = source._receiverChains
      _pendingPreKey = source._pendingPreKey
      _remoteRegistrationID = source._remoteRegistrationID
      _localRegistrationID = source._localRegistrationID
      _needsRefresh = source._needsRefresh
      _aliceBaseKey = source._aliceBaseKey
    }
  }

  fileprivate mutating func _uniqueStorage() -> _StorageClass {
    if !isKnownUniquelyReferenced(&_storage) {
      _storage = _StorageClass(copying: _storage)
    }
    return _storage
  }

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    _ = _uniqueStorage()
    try withExtendedLifetime(_storage) { (_storage: _StorageClass) in
      while let fieldNumber = try decoder.nextFieldNumber() {
        // The use of inline closures is to circumvent an issue where the compiler
        // allocates stack space for every case branch when no optimizations are
        // enabled. https://github.com/apple/swift-protobuf/issues/1034
        switch fieldNumber {
        case 1: try { try decoder.decodeSingularUInt32Field(value: &_storage._sessionVersion) }()
        case 2: try { try decoder.decodeSingularBytesField(value: &_storage._localIdentityPublic) }()
        case 3: try { try decoder.decodeSingularBytesField(value: &_storage._remoteIdentityPublic) }()
        case 4: try { try decoder.decodeSingularBytesField(value: &_storage._rootKey) }()
        case 5: try { try decoder.decodeSingularUInt32Field(value: &_storage._previousCounter) }()
        case 6: try { try decoder.decodeSingularMessageField(value: &_storage._senderChain) }()
        case 7: try { try decoder.decodeRepeatedMessageField(value: &_storage._receiverChains) }()
        case 9: try { try decoder.decodeSingularMessageField(value: &_storage._pendingPreKey) }()
        case 10: try { try decoder.decodeSingularUInt32Field(value: &_storage._remoteRegistrationID) }()
        case 11: try { try decoder.decodeSingularUInt32Field(value: &_storage._localRegistrationID) }()
        case 12: try { try decoder.decodeSingularBoolField(value: &_storage._needsRefresh) }()
        case 13: try { try decoder.decodeSingularBytesField(value: &_storage._aliceBaseKey) }()
        default: break
        }
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    try withExtendedLifetime(_storage) { (_storage: _StorageClass) in
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every if/case branch local when no optimizations
      // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
      // https://github.com/apple/swift-protobuf/issues/1182
      try { if let v = _storage._sessionVersion {
        try visitor.visitSingularUInt32Field(value: v, fieldNumber: 1)
      } }()
      try { if let v = _storage._localIdentityPublic {
        try visitor.visitSingularBytesField(value: v, fieldNumber: 2)
      } }()
      try { if let v = _storage._remoteIdentityPublic {
        try visitor.visitSingularBytesField(value: v, fieldNumber: 3)
      } }()
      try { if let v = _storage._rootKey {
        try visitor.visitSingularBytesField(value: v, fieldNumber: 4)
      } }()
      try { if let v = _storage._previousCounter {
        try visitor.visitSingularUInt32Field(value: v, fieldNumber: 5)
      } }()
      try { if let v = _storage._senderChain {
        try visitor.visitSingularMessageField(value: v, fieldNumber: 6)
      } }()
      if !_storage._receiverChains.isEmpty {
        try visitor.visitRepeatedMessageField(value: _storage._receiverChains, fieldNumber: 7)
      }
      try { if let v = _storage._pendingPreKey {
        try visitor.visitSingularMessageField(value: v, fieldNumber: 9)
      } }()
      try { if let v = _storage._remoteRegistrationID {
        try visitor.visitSingularUInt32Field(value: v, fieldNumber: 10)
      } }()
      try { if let v = _storage._localRegistrationID {
        try visitor.visitSingularUInt32Field(value: v, fieldNumber: 11)
      } }()
      try { if let v = _storage._needsRefresh {
        try visitor.visitSingularBoolField(value: v, fieldNumber: 12)
      } }()
      try { if let v = _storage._aliceBaseKey {
        try visitor.visitSingularBytesField(value: v, fieldNumber: 13)
      } }()
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: SessionRecordProtos_SessionStructure, rhs: SessionRecordProtos_SessionStructure) -> Bool {
    if lhs._storage !== rhs._storage {
      let storagesAreEqual: Bool = withExtendedLifetime((lhs._storage, rhs._storage)) { (_args: (_StorageClass, _StorageClass)) in
        let _storage = _args.0
        let rhs_storage = _args.1
        if _storage._sessionVersion != rhs_storage._sessionVersion {return false}
        if _storage._localIdentityPublic != rhs_storage._localIdentityPublic {return false}
        if _storage._remoteIdentityPublic != rhs_storage._remoteIdentityPublic {return false}
        if _storage._rootKey != rhs_storage._rootKey {return false}
        if _storage._previousCounter != rhs_storage._previousCounter {return false}
        if _storage._senderChain != rhs_storage._senderChain {return false}
        if _storage._receiverChains != rhs_storage._receiverChains {return false}
        if _storage._pendingPreKey != rhs_storage._pendingPreKey {return false}
        if _storage._remoteRegistrationID != rhs_storage._remoteRegistrationID {return false}
        if _storage._localRegistrationID != rhs_storage._localRegistrationID {return false}
        if _storage._needsRefresh != rhs_storage._needsRefresh {return false}
        if _storage._aliceBaseKey != rhs_storage._aliceBaseKey {return false}
        return true
      }
      if !storagesAreEqual {return false}
    }
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension SessionRecordProtos_SessionStructure.Chain: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = SessionRecordProtos_SessionStructure.protoMessageName + ".Chain"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "senderRatchetKey"),
    2: .same(proto: "senderRatchetKeyPrivate"),
    3: .same(proto: "chainKey"),
    4: .same(proto: "messageKeys"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularBytesField(value: &self._senderRatchetKey) }()
      case 2: try { try decoder.decodeSingularBytesField(value: &self._senderRatchetKeyPrivate) }()
      case 3: try { try decoder.decodeSingularMessageField(value: &self._chainKey) }()
      case 4: try { try decoder.decodeRepeatedMessageField(value: &self.messageKeys) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._senderRatchetKey {
      try visitor.visitSingularBytesField(value: v, fieldNumber: 1)
    } }()
    try { if let v = self._senderRatchetKeyPrivate {
      try visitor.visitSingularBytesField(value: v, fieldNumber: 2)
    } }()
    try { if let v = self._chainKey {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 3)
    } }()
    if !self.messageKeys.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.messageKeys, fieldNumber: 4)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: SessionRecordProtos_SessionStructure.Chain, rhs: SessionRecordProtos_SessionStructure.Chain) -> Bool {
    if lhs._senderRatchetKey != rhs._senderRatchetKey {return false}
    if lhs._senderRatchetKeyPrivate != rhs._senderRatchetKeyPrivate {return false}
    if lhs._chainKey != rhs._chainKey {return false}
    if lhs.messageKeys != rhs.messageKeys {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension SessionRecordProtos_SessionStructure.Chain.ChainKey: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = SessionRecordProtos_SessionStructure.Chain.protoMessageName + ".ChainKey"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "index"),
    2: .same(proto: "key"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularUInt32Field(value: &self._index) }()
      case 2: try { try decoder.decodeSingularBytesField(value: &self._key) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._index {
      try visitor.visitSingularUInt32Field(value: v, fieldNumber: 1)
    } }()
    try { if let v = self._key {
      try visitor.visitSingularBytesField(value: v, fieldNumber: 2)
    } }()
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: SessionRecordProtos_SessionStructure.Chain.ChainKey, rhs: SessionRecordProtos_SessionStructure.Chain.ChainKey) -> Bool {
    if lhs._index != rhs._index {return false}
    if lhs._key != rhs._key {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension SessionRecordProtos_SessionStructure.Chain.MessageKey: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = SessionRecordProtos_SessionStructure.Chain.protoMessageName + ".MessageKey"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "index"),
    2: .same(proto: "cipherKey"),
    3: .same(proto: "macKey"),
    4: .same(proto: "iv"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularUInt32Field(value: &self._index) }()
      case 2: try { try decoder.decodeSingularBytesField(value: &self._cipherKey) }()
      case 3: try { try decoder.decodeSingularBytesField(value: &self._macKey) }()
      case 4: try { try decoder.decodeSingularBytesField(value: &self._iv) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._index {
      try visitor.visitSingularUInt32Field(value: v, fieldNumber: 1)
    } }()
    try { if let v = self._cipherKey {
      try visitor.visitSingularBytesField(value: v, fieldNumber: 2)
    } }()
    try { if let v = self._macKey {
      try visitor.visitSingularBytesField(value: v, fieldNumber: 3)
    } }()
    try { if let v = self._iv {
      try visitor.visitSingularBytesField(value: v, fieldNumber: 4)
    } }()
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: SessionRecordProtos_SessionStructure.Chain.MessageKey, rhs: SessionRecordProtos_SessionStructure.Chain.MessageKey) -> Bool {
    if lhs._index != rhs._index {return false}
    if lhs._cipherKey != rhs._cipherKey {return false}
    if lhs._macKey != rhs._macKey {return false}
    if lhs._iv != rhs._iv {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension SessionRecordProtos_SessionStructure.PendingPreKey: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = SessionRecordProtos_SessionStructure.protoMessageName + ".PendingPreKey"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "preKeyId"),
    3: .same(proto: "signedPreKeyId"),
    2: .same(proto: "baseKey"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularUInt32Field(value: &self._preKeyID) }()
      case 2: try { try decoder.decodeSingularBytesField(value: &self._baseKey) }()
      case 3: try { try decoder.decodeSingularInt32Field(value: &self._signedPreKeyID) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._preKeyID {
      try visitor.visitSingularUInt32Field(value: v, fieldNumber: 1)
    } }()
    try { if let v = self._baseKey {
      try visitor.visitSingularBytesField(value: v, fieldNumber: 2)
    } }()
    try { if let v = self._signedPreKeyID {
      try visitor.visitSingularInt32Field(value: v, fieldNumber: 3)
    } }()
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: SessionRecordProtos_SessionStructure.PendingPreKey, rhs: SessionRecordProtos_SessionStructure.PendingPreKey) -> Bool {
    if lhs._preKeyID != rhs._preKeyID {return false}
    if lhs._signedPreKeyID != rhs._signedPreKeyID {return false}
    if lhs._baseKey != rhs._baseKey {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension SessionRecordProtos_RecordStructure: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".RecordStructure"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "currentSession"),
    2: .same(proto: "previousSessions"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularMessageField(value: &self._currentSession) }()
      case 2: try { try decoder.decodeRepeatedMessageField(value: &self.previousSessions) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._currentSession {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
    } }()
    if !self.previousSessions.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.previousSessions, fieldNumber: 2)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: SessionRecordProtos_RecordStructure, rhs: SessionRecordProtos_RecordStructure) -> Bool {
    if lhs._currentSession != rhs._currentSession {return false}
    if lhs.previousSessions != rhs.previousSessions {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}
