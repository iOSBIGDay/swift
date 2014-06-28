//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

@exported import Foundation // Clang module
import CoreFoundation

//===----------------------------------------------------------------------===//
// Enums
//===----------------------------------------------------------------------===//

// FIXME: one day this will be bridged from CoreFoundation and we
// should drop it here. <rdar://problem/14497260> (need support
// for CF bridging)
@public let kCFStringEncodingASCII: CFStringEncoding = 0x0600

// FIXME: <rdar://problem/16074941> NSStringEncoding doesn't work on 32-bit
@public typealias NSStringEncoding = UInt
@public let NSASCIIStringEncoding: UInt = 1
@public let NSNEXTSTEPStringEncoding: UInt = 2
@public let NSJapaneseEUCStringEncoding: UInt = 3
@public let NSUTF8StringEncoding: UInt = 4
@public let NSISOLatin1StringEncoding: UInt = 5
@public let NSSymbolStringEncoding: UInt = 6
@public let NSNonLossyASCIIStringEncoding: UInt = 7
@public let NSShiftJISStringEncoding: UInt = 8
@public let NSISOLatin2StringEncoding: UInt = 9
@public let NSUnicodeStringEncoding: UInt = 10
@public let NSWindowsCP1251StringEncoding: UInt = 11
@public let NSWindowsCP1252StringEncoding: UInt = 12
@public let NSWindowsCP1253StringEncoding: UInt = 13
@public let NSWindowsCP1254StringEncoding: UInt = 14
@public let NSWindowsCP1250StringEncoding: UInt = 15
@public let NSISO2022JPStringEncoding: UInt = 21
@public let NSMacOSRomanStringEncoding: UInt = 30
@public let NSUTF16StringEncoding: UInt = NSUnicodeStringEncoding
@public let NSUTF16BigEndianStringEncoding: UInt = 0x90000100
@public let NSUTF16LittleEndianStringEncoding: UInt = 0x94000100
@public let NSUTF32StringEncoding: UInt = 0x8c000100
@public let NSUTF32BigEndianStringEncoding: UInt = 0x98000100
@public let NSUTF32LittleEndianStringEncoding: UInt = 0x9c000100


//===----------------------------------------------------------------------===//
// NSObject
//===----------------------------------------------------------------------===//

// NSObject implements Equatable's == as -[NSObject isEqual:]
// NSObject implements Hashable's hashValue() as -[NSObject hash]
// FIXME: what about NSObjectProtocol?

extension NSObject : Equatable, Hashable {
  @public var hashValue: Int {
    return hash
  }
}

@public func == (lhs: NSObject, rhs: NSObject) -> Bool {
  return lhs.isEqual(rhs)
}

// This is a workaround for:
// <rdar://problem/16883288> Property of type 'String!' does not satisfy
// protocol requirement of type 'String'
extension NSObject : _PrintableNSObject {}

//===----------------------------------------------------------------------===//
// Strings
//===----------------------------------------------------------------------===//

@availability(*, unavailable, message="Please use String or NSString") @public
class NSSimpleCString {}

@asmname("swift_convertStringToNSString") @internal
func _convertStringToNSString(string: String) -> NSString {
  return string as NSString
}

@internal func _convertNSStringToString(nsstring: NSString) -> String {
  return String(nsstring)
}

extension NSString : StringLiteralConvertible {
  @public class func convertFromExtendedGraphemeClusterLiteral(
    value: StaticString) -> Self {
    return convertFromStringLiteral(value)
  }

  @public class func convertFromStringLiteral(value: StaticString) -> Self {
    
    let immutableResult = NSString(
      bytesNoCopy: UnsafePointer<Void>(value.start),
      length: Int(value.byteSize),
      encoding:
        Bool(value.isASCII) ? NSASCIIStringEncoding : NSUTF8StringEncoding,
      freeWhenDone: false)
    
    return self(string: immutableResult)
  }
}


extension NSString {
  @conversion @public func __conversion() -> String {
    return String(self)
  }
}

extension CFString {
  @conversion @public func __conversion() -> String {
    return String(self as NSString)
  }
}

//===----------------------------------------------------------------------===//
// New Strings
//===----------------------------------------------------------------------===//
extension NSString : _CocoaString {}

/// Sets variables in Swift's core stdlib that allow it to
/// bridge Cocoa strings properly.  Currently invoked by a HACK in
/// Misc.mm; a better mechanism may be needed.
@asmname("__swift_initializeCocoaStringBridge") 
func __swift_initializeCocoaStringBridge() -> COpaquePointer {
  _cocoaStringToContiguous = _cocoaStringToContiguousImpl
  _cocoaStringReadAll = _cocoaStringReadAllImpl
  _cocoaStringLength = _cocoaStringLengthImpl
  _cocoaStringSlice = _cocoaStringSliceImpl
  _cocoaStringSubscript = _cocoaStringSubscriptImpl
  return COpaquePointer()
}

// When used as a _CocoaString, an NSString should be either
// immutable or uniquely-referenced, and not have a buffer of
// contiguous UTF16.  Ideally these distinctions would be captured in
// the type system, so one would have to explicitly convert NSString
// to a type that conforms.  Unfortunately, we don't have a way to do
// that without an allocation (to wrap NSString in another class
// instance) or growing these protocol instances from one word to four
// (by way of allowing structs to conform).  Fortunately, correctness
// doesn't depend on these preconditions but efficiency might,
// because producing a _StringBuffer from an
// NSString-as-_CocoaString is assumed to require allocation and
// buffer copying.
//
func _cocoaStringReadAllImpl(
  source: _CocoaString, destination: UnsafePointer<UTF16.CodeUnit>) {
  let cfSelf: CFString = reinterpretCast(source)
  CFStringGetCharacters(
  cfSelf, CFRange(location: 0, length: CFStringGetLength(cfSelf)), destination)
}
  
func _cocoaStringToContiguousImpl(
  source: _CocoaString, range: Range<Int>, minimumCapacity: Int
) -> _StringBuffer {
  let cfSelf: CFString = reinterpretCast(source)
  _sanityCheck(CFStringGetCharactersPtr(cfSelf)._isNull,
    "Known contiguously-stored strings should already be converted to Swift")

  var startIndex = range.startIndex
  var count = range.endIndex - startIndex

  var buffer = _StringBuffer(capacity: max(count, minimumCapacity), 
                             initialSize: count, elementWidth: 2)

  CFStringGetCharacters(
    cfSelf, CFRange(location: startIndex, length: count), 
    UnsafePointer<UniChar>(buffer.start))
  
  return buffer
}

func _cocoaStringLengthImpl(source: _CocoaString) -> Int {
  // FIXME: Not ultra-fast, but reliable... but we're counting on an
  // early demise for this function anyhow
  return (source as NSString).length
}

func _cocoaStringSliceImpl(
  target: _StringCore, subRange: Range<Int>) -> _StringCore {
  
  let buffer = _NSOpaqueString(
    owner: String(target), 
    subRange:
      NSRange(location: subRange.startIndex, length: countElements(subRange)))
  
  return _StringCore(
    baseAddress: nil,
    count: countElements(subRange),
    elementShift: 1,
    hasCocoaBuffer: true,
    owner: buffer)
}

func _cocoaStringSubscriptImpl(
  target: _StringCore, position: Int) -> UTF16.CodeUnit {
  let cfSelf: CFString = reinterpretCast(target.cocoaBuffer!)
  _sanityCheck(CFStringGetCharactersPtr(cfSelf)._isNull,
    "Known contiguously-stored strings should already be converted to Swift")

  return CFStringGetCharacterAtIndex(cfSelf, position)
}

//
// NSString slice subclasses created when converting String to
// NSString.  We take care to avoid creating long wrapper chains
// when converting back and forth.
//

/// An NSString built around a slice of contiguous Swift String storage
class _NSContiguousString : NSString {
  init(_ value: _StringCore) {
    _sanityCheck(
      value.hasContiguousStorage,
      "_NSContiguousString requires contiguous storage")
    self.value = value
    super.init()
  }

  func length() -> Int {
    return value.count
  }

  override func characterAtIndex(index: Int) -> unichar {
    return value[index]
  }

  override func getCharacters(buffer: UnsafePointer<unichar>,
                              range aRange: NSRange) {
    _precondition(aRange.location + aRange.length <= Int(value.count))

    if value.elementWidth == 2 {
      UTF16.copy(
        value.startUTF16 + aRange.location, destination: UnsafePointer<unichar>(buffer),
        count: aRange.length)
    }
    else {
      UTF16.copy(
        value.startASCII + aRange.location, destination: UnsafePointer<unichar>(buffer),
        count: aRange.length)
    }
  }

  @objc
  func _fastCharacterContents() -> UnsafePointer<unichar> {
    return value.elementWidth == 2 ? UnsafePointer(value.startUTF16) : nil
  }

  //
  // Implement sub-slicing without adding layers of wrapping
  // 
  override func substringFromIndex(start: Int) -> String {
    return _NSContiguousString(value[Int(start)..<Int(value.count)])
  }

  override func substringToIndex(end: Int) -> String {
    return _NSContiguousString(value[0..<Int(end)])
  }

  override func substringWithRange(aRange: NSRange) -> String {
    return _NSContiguousString(
      value[Int(aRange.location)..<Int(aRange.location + aRange.length)])
  }

  //
  // Implement copy; since this string is immutable we can just return ourselves
  override func copy() -> AnyObject {
    return self
  }

  let value: _StringCore
}

// A substring of an arbitrary immutable NSString.  The underlying
// NSString is assumed to not provide contiguous UTF16 storage.
class _NSOpaqueString : NSString {
  func length() -> Int {
    return subRange.length
  }

  override func characterAtIndex(index: Int) -> unichar {
    return owner.characterAtIndex(index + subRange.location)
  }

  override func getCharacters(buffer: UnsafePointer<unichar>,
                              range aRange: NSRange) {

    owner.getCharacters(
      buffer, 
      range: NSRange(location: aRange.location + subRange.location, 
                     length: aRange.length))
  }
  
  //
  // Implement sub-slicing without adding layers of wrapping
  // 
  override func substringFromIndex(start: Int) -> String {
    return _NSOpaqueString(
             owner: owner, 
             subRange: NSRange(location: subRange.location + start, 
                               length: subRange.length - start))
  }

  override func substringToIndex(end: Int) -> String {
    return _NSOpaqueString(
             owner: owner, 
             subRange: NSRange(location: subRange.location, length: end))
  }

  override func substringWithRange(aRange: NSRange) -> String {
    return _NSOpaqueString(
             owner: owner, 
             subRange: NSRange(location: aRange.location + subRange.location, 
                               length: aRange.length))
  }

  init(owner: String, subRange: NSRange) {
    self.owner = owner
    self.subRange = subRange
    super.init()
  }

  //
  // Implement copy; since this string is immutable we can just return ourselves
  override func copy() -> AnyObject {
    return self
  }
  
  var owner: NSString
  var subRange: NSRange
}

//
// Conversion from Swift's native representations to NSString
// 
extension String {
  @conversion @public func __conversion() -> NSString {
    if let ns = core.cocoaBuffer {
      if _cocoaStringLength(source: ns) == core.count {
        return ns as NSString
      }
    }
    _sanityCheck(core.hasContiguousStorage)
    return _NSContiguousString(core)
  }
}

//
// Conversion from NSString to Swift's native representation
//
extension String {
  @public init(_ value: NSString) {
    if let wrapped = value as? _NSContiguousString {
      self.core = wrapped.value
      return
    }
    
    // Treat it as a CF object because presumably that's what these
    // things tend to be, and CF has a fast path that avoids
    // objc_msgSend
    let cfValue: CFString = reinterpretCast(value)

    // "copy" it into a value to be sure nobody will modify behind
    // our backs.  In practice, when value is already immutable, this
    // just does a retain.
    let cfImmutableValue: CFString = CFStringCreateCopy(nil, cfValue)

    let length = CFStringGetLength(cfImmutableValue)
    
    // Look first for null-terminated ASCII
    // Note: the code in clownfish appears to guarantee
    // nul-termination, but I'm waiting for an answer from Chris Kane
    // about whether we can count on it for all time or not.
    let nulTerminatedASCII = CFStringGetCStringPtr(
      cfImmutableValue, kCFStringEncodingASCII)

    // start will hold the base pointer of contiguous storage, if it
    // is found.
    var start = UnsafePointer<RawByte>(nulTerminatedASCII._bytesPtr)
    let isUTF16 = nulTerminatedASCII._isNull
    if (isUTF16) {
      start = UnsafePointer(CFStringGetCharactersPtr(cfImmutableValue))
    }

    self.core = _StringCore(
      baseAddress: reinterpretCast(start),
      count: length,
      elementShift: isUTF16 ? 1 : 0,
      hasCocoaBuffer: true,
      owner: reinterpretCast(cfImmutableValue))
  }
}

extension String : _BridgedToObjectiveC {
  @public static func getObjectiveCType() -> Any.Type {
    return NSString.self
  }

  @public func bridgeToObjectiveC() -> NSString {
    return self
  }

  @public static func bridgeFromObjectiveC(x: NSString) -> String {
    return String(x)
  }
}

//===----------------------------------------------------------------------===//
// Numbers
//===----------------------------------------------------------------------===//

// Conversions between NSNumber and various numeric types. The
// conversion to NSNumber is automatic (auto-boxing), while conversion
// back to a specific numeric type requires a cast.
// FIXME: Incomplete list of types.
extension Int : _BridgedToObjectiveC {
  @public init(_ number: NSNumber) {
    value = number.integerValue.value
  }

  @conversion @public func __conversion() -> NSNumber {
    return NSNumber(integer: self)
  }

  @public static func getObjectiveCType() -> Any.Type {
    return NSNumber.self
  }

  @public func bridgeToObjectiveC() -> NSNumber {
    return self
  }

  @public static func bridgeFromObjectiveC(x: NSNumber) -> Int {
    return x.integerValue
  }
}

extension UInt : _BridgedToObjectiveC {
  @public init(_ number: NSNumber) {
    value = number.unsignedIntegerValue.value
  }

  @conversion @public func __conversion() -> NSNumber {
    // FIXME: Need a blacklist for certain methods that should not
    // import NSUInteger as Int.
    return NSNumber(unsignedInteger: Int(value))
  }

  @public static func getObjectiveCType() -> Any.Type {
    return NSNumber.self
  }

  @public func bridgeToObjectiveC() -> NSNumber {
    return self
  }

  @public static func bridgeFromObjectiveC(x: NSNumber) -> UInt {
    return UInt(x.unsignedIntegerValue.value)
  }
}

extension Float : _BridgedToObjectiveC {
  @public init(_ number: NSNumber) {
    value = number.floatValue.value
  }

  @conversion @public func __conversion() -> NSNumber {
    return NSNumber(float: self)
  }

  @public static func getObjectiveCType() -> Any.Type {
    return NSNumber.self
  }

  @public func bridgeToObjectiveC() -> NSNumber {
    return self
  }

  @public static func bridgeFromObjectiveC(x: NSNumber) -> Float {
    return x.floatValue
  }
}

extension Double : _BridgedToObjectiveC {
  @public init(_ number: NSNumber) {
    value = number.doubleValue.value
  }

  @conversion @public func __conversion() -> NSNumber {
    return NSNumber(double: self)
  }

  @public static func getObjectiveCType() -> Any.Type {
    return NSNumber.self
  }

  @public func bridgeToObjectiveC() -> NSNumber {
    return self
  }

  @public static func bridgeFromObjectiveC(x: NSNumber) -> Double {
    return x.doubleValue
  }
}

extension Bool: _BridgedToObjectiveC {
  @public init(_ number: NSNumber) {
    if number.boolValue { self = Bool.true }
    else { self = Bool.false }
  }

  @conversion @public func __conversion() -> NSNumber {
    return NSNumber(bool: self)
  }

  @public static func getObjectiveCType() -> Any.Type {
    return NSNumber.self
  }

  @public func bridgeToObjectiveC() -> NSNumber {
    return self
  }

  @public static func bridgeFromObjectiveC(x: NSNumber) -> Bool {
    return x.boolValue
  }
}

// Literal support for NSNumber
extension NSNumber : FloatLiteralConvertible, IntegerLiteralConvertible {
  @public class func convertFromIntegerLiteral(value: Int) -> NSNumber {
    return NSNumber(integer: value)
  }

  @public class func convertFromFloatLiteral(value: Double) -> NSNumber {
    return NSNumber(double: value)
  }
}

@public let NSNotFound: Int = .max

//===----------------------------------------------------------------------===//
// Arrays
//===----------------------------------------------------------------------===//

extension NSArray : ArrayLiteralConvertible {
  @public class func convertFromArrayLiteral(elements: AnyObject...) -> Self {
    // + (instancetype)arrayWithObjects:(const id [])objects count:(NSUInteger)cnt;
    let x = _extractOrCopyToNativeArrayBuffer(elements._buffer)
    let result = self(objects: UnsafePointer(x.elementStorage), count: x.count)
    _fixLifetime(x)
    return result
  }
}

/// The entry point for converting `NSArray` to `Array` in bridge
/// thunks.  Used, for example, to expose ::
///
///   func f([NSView]) {}
///
/// to Objective-C code as a method that accepts an NSArray.  This operation
/// is referred to as a "forced conversion" in ../../../docs/Arrays.rst
@public func _convertNSArrayToArray<T>(source: NSArray) -> [T] {
  if _fastPath(isBridgedVerbatimToObjectiveC(T.self)) {
    // Forced down-cast (possible deferred type-checking)
    return Array(ArrayBuffer(reinterpretCast(source) as _CocoaArray))
  }

  var anyObjectArr: [AnyObject]
    = Array(ArrayBuffer(reinterpretCast(source) as _CocoaArray))
  return _arrayBridgeFromObjectiveC(anyObjectArr)
}

/// The entry point for converting `Array` to `NSArray` in bridge
/// thunks.  Used, for example, to expose ::
///
///   func f() -> [NSView] { return [] }
///
/// to Objective-C code as a method that returns an NSArray.
@public func _convertArrayToNSArray<T>(arr: [T]) -> NSArray {
  return arr.bridgeToObjectiveC()
}

extension Array : _ConditionallyBridgedToObjectiveC {
  @public static func isBridgedToObjectiveC() -> Bool {
    return Swift.isBridgedToObjectiveC(T.self)
  }

  @public static func getObjectiveCType() -> Any.Type {
    return NSArray.self
  }

  @public func bridgeToObjectiveC() -> NSArray {
    return reinterpretCast(self._buffer._asCocoaArray())
  }

  @public static func bridgeFromObjectiveC(source: NSArray) -> Array {
    _precondition(Swift.isBridgedToObjectiveC(T.self), 
                  "array element type is not bridged to Objective-C")
    if _fastPath(isBridgedVerbatimToObjectiveC(T.self)) {
      // Forced down-cast (possible deferred type-checking)
      return Array(ArrayBuffer(reinterpretCast(source) as _CocoaArray))
    }

    var anyObjectArr: [AnyObject]
      = [AnyObject](ArrayBuffer(reinterpretCast(source) as _CocoaArray))
    return _arrayBridgeFromObjectiveC(anyObjectArr)
  }

  @public
  static func bridgeFromObjectiveCConditional(source: NSArray) -> Array? {
    // Construct the result array by conditionally bridging each element.
    var anyObjectArr 
      = [AnyObject](ArrayBuffer(reinterpretCast(source) as _CocoaArray))
    if isBridgedVerbatimToObjectiveC(T.self) {
      return _arrayDownCastConditional(anyObjectArr)
    }

    return _arrayBridgeFromObjectiveCConditional(anyObjectArr)
  }

  @conversion @public func __conversion() -> NSArray {
    return self.bridgeToObjectiveC()
  }
}

extension NSArray : Reflectable {
  @public func getMirror() -> Mirror {
    return reflect(self as [AnyObject])
  }
}

//===----------------------------------------------------------------------===//
// Dictionaries
//===----------------------------------------------------------------------===//

extension NSDictionary : DictionaryLiteralConvertible {
  @public class func convertFromDictionaryLiteral(
    elements: (NSCopying, AnyObject)...
  ) -> Self {
    return self(
      objects: elements.map { (AnyObject?)($0.1) },
      forKeys: elements.map { (NSCopying?)($0.0) },
      count: elements.count)
  }
}

/// The entry point for bridging `NSDictionary` to `Dictionary`.
@public func _convertNSDictionaryToDictionary<K: NSObject, V: AnyObject>(
       d: NSDictionary
     ) -> [K : V] {
  return [K : V](_cocoaDictionary: reinterpretCast(d))
}

/// The entry point for bridging `Dictionary` to `NSDictionary`.
@public func _convertDictionaryToNSDictionary<KeyType, ValueType>(
    d: [KeyType : ValueType]
) -> NSDictionary {
  switch d._variantStorage {
  case .Native(let nativeOwner):
    _precondition(isBridgedToObjectiveC(KeyType.self),
                  "KeyType is not bridged to Objective-C")
    _precondition(isBridgedToObjectiveC(ValueType.self),
                  "ValueType is not bridged to Objective-C")

    let isKeyBridgedVerbatim = isBridgedVerbatimToObjectiveC(KeyType.self)
    let isValueBridgedVerbatim = isBridgedVerbatimToObjectiveC(ValueType.self)

    // If both `KeyType` and `ValueType` can be bridged verbatim, return the
    // underlying storage.
    if _fastPath(isKeyBridgedVerbatim && isValueBridgedVerbatim) {
      let anNSSwiftDictionary: _NSSwiftDictionary = nativeOwner
      return reinterpretCast(anNSSwiftDictionary)
    }

    // At least either one of `KeyType` or `ValueType` can not be bridged
    // verbatim.  Bridge all the contents eagerly and create an `NSDictionary`.
    let nativeStorage = nativeOwner.nativeStorage
    let result = NSMutableDictionary(capacity: nativeStorage.count)
    let endIndex = nativeStorage.endIndex
    for var i = nativeStorage.startIndex; i != endIndex; ++i {
      let (key, value) = nativeStorage.assertingGet(i)
      var bridgedKey: AnyObject
      if _fastPath(isKeyBridgedVerbatim) {
        // Avoid calling the runtime.
        bridgedKey = _reinterpretCastToAnyObject(key)
      } else {
        bridgedKey = bridgeToObjectiveC(key)!
      }
      var bridgedValue: AnyObject
      if _fastPath(isValueBridgedVerbatim) {
        // Avoid calling the runtime.
        bridgedValue = _reinterpretCastToAnyObject(value)
      } else {
        if let theBridgedValue: AnyObject = bridgeToObjectiveC(value) {
          bridgedValue = theBridgedValue
        } else {
          _preconditionFailure("Dictionary to NSDictionary bridging: value failed to bridge")
        }
      }

      // NOTE: the just-bridged key is copied here.  It would be nice to avoid
      // copying it, but it seems like there is no public APIs for this.  But
      // since the key may potentially come from user code, it might be a good
      // idea to copy it anyway.  In the case of bridging stdlib types, this is
      // wasteful.
      if let nsCopyingKey = bridgedKey as? NSCopying {
        result[nsCopyingKey] = bridgedValue
      } else {
        // Note: on a different code path -- when KeyType bridges verbatim --
        // we are not doing this check eagerly.  Instead, the message send will
        // fail at runtime when NSMutableDictionary attempts to copy the key
        // that does not conform to NSCopying.
        _preconditionFailure("key bridged to an object that does not conform to NSCopying")
      }
    }
    return reinterpretCast(result)

  case .Cocoa(let cocoaStorage):
    // The `Dictionary` is already backed by `NSDictionary` of some kind.  Just
    // unwrap it.
    return reinterpretCast(cocoaStorage.cocoaDictionary)
  }
}

// Dictionary<KeyType, ValueType> is conditionally bridged to NSDictionary
extension Dictionary : _ConditionallyBridgedToObjectiveC {
  @public static func getObjectiveCType() -> Any.Type {
    return NSDictionary.self
  }

  @public func bridgeToObjectiveC() -> NSDictionary {
    return _convertDictionaryToNSDictionary(self)
  }

  @public static func bridgeFromObjectiveC(x: NSDictionary) -> Dictionary {
    return Dictionary(_cocoaDictionary: reinterpretCast(x))
  }

  @public static func bridgeFromObjectiveCConditional(
    x: NSDictionary
  ) -> Dictionary? {
    let anyDict = x as [NSObject : AnyObject]
    if isBridgedVerbatimToObjectiveC(KeyType.self) &&
       isBridgedVerbatimToObjectiveC(ValueType.self) {
      return Swift._dictionaryDownCastConditional(anyDict)
    }

    return Swift._dictionaryBridgeFromObjectiveCConditional(anyDict)
  }

  @public static func isBridgedToObjectiveC() -> Bool {
    return Swift.isBridgedToObjectiveC(KeyType.self) &&
           Swift.isBridgedToObjectiveC(ValueType.self)
  }
}

extension NSDictionary {
  @conversion @public
  func __conversion() -> [NSObject : AnyObject] {
    return _convertNSDictionaryToDictionary(reinterpretCast(self))
  }
}

extension Dictionary {
  @conversion @public
  func __conversion() -> NSDictionary {
    return _convertDictionaryToNSDictionary(self)
  }
}

extension NSDictionary : Reflectable {
  @public func getMirror() -> Mirror {
    let dict : [NSObject : AnyObject] = _convertNSDictionaryToDictionary(self)
    return reflect(dict)
  }
}

//===----------------------------------------------------------------------===//
// General objects
//===----------------------------------------------------------------------===//

extension NSObject : CVarArg {
  @public func encode() -> [Word] {
    _autorelease(self)
    return encodeBitsAsWords(self)
  }
}

//===----------------------------------------------------------------------===//
// Fast enumeration
//===----------------------------------------------------------------------===//

// Give NSFastEnumerationState a default initializer, for convenience.
extension NSFastEnumerationState {
  @public init() {
    state = 0
    itemsPtr = .null()
    mutationsPtr = .null()
    extra = (0,0,0,0,0)
  }
}


// NB: This is a class because fast enumeration passes around interior pointers
// to the enumeration state, so the state cannot be moved in memory. We will
// probably need to implement fast enumeration in the compiler as a primitive
// to implement it both correctly and efficiently.
@public class NSFastGenerator : Generator {
  var enumerable: NSFastEnumeration
  var state: [NSFastEnumerationState]
  var n: Int
  var count: Int

  /// Size of ObjectsBuffer, in ids.
  var STACK_BUF_SIZE: Int { return 4 }

  /// Must have enough space for STACK_BUF_SIZE object references.
  struct ObjectsBuffer {
    var buf = (COpaquePointer(), COpaquePointer(),
               COpaquePointer(), COpaquePointer())
  }
  var objects: [ObjectsBuffer]

  @public func next() -> AnyObject? {
    if n == count {
      // FIXME: Is this check necessary before refresh()?
      if count == 0 { return .None }
      refresh()
      if count == 0 { return .None }
    }
    var next : AnyObject = state[0].itemsPtr[n]!
    ++n
    return next
  }

  func refresh() {
    n = 0
    count = enumerable.countByEnumeratingWithState(
      state._elementStorageIfContiguous,
      objects: AutoreleasingUnsafePointer(
        objects._elementStorageIfContiguous),
      count: STACK_BUF_SIZE)
  }

  @public init(_ enumerable: NSFastEnumeration) {
    self.enumerable = enumerable
    self.state = [NSFastEnumerationState](count: 1, repeatedValue: NSFastEnumerationState())
    self.state[0].state = 0
    self.objects = [ObjectsBuffer](count: 1, repeatedValue: ObjectsBuffer())
    self.n = -1
    self.count = -1
  }
}

extension NSArray : Sequence {
  @final @public
  func generate() -> NSFastGenerator {
    return NSFastGenerator(self)
  }
}

/*
// FIXME: <rdar://problem/16951124> prevents this from being used
extension NSArray : Swift.Collection {
  @final
  var startIndex: Int {
    return 0
  }
  
  @final
  var endIndex: Int {
    return count
  }

  subscript(i: Int) -> AnyObject {
    return self.objectAtIndex(i)
  }
}
*/

// FIXME: This should not be necessary.  We
// should get this from the extension on 'NSArray' above.
extension NSMutableArray : Sequence {}

extension NSSet : Sequence {
  @public func generate() -> NSFastGenerator {
    return NSFastGenerator(self)
  }
}

// FIXME: This should not be necessary.  We
// should get this from the extension on 'NSSet' above.
extension NSMutableSet : Sequence {}

// FIXME: A class because we can't pass a struct with class fields through an
// [objc] interface without prematurely destroying the references.
@public class NSDictionaryGenerator : Generator {
  var fastGenerator : NSFastGenerator
  var dictionary : NSDictionary {
    return fastGenerator.enumerable as NSDictionary
  }

  @public func next() -> (key: AnyObject, value: AnyObject)? {
    switch fastGenerator.next() {
    case .None:
      return .None
    case .Some(var key):
      // Deliberately avoid the subscript operator in case the dictionary
      // contains non-copyable keys. This is rare since NSMutableDictionary
      // requires them, but we don't want to paint ourselves into a corner.
      return (key: key, value: dictionary.objectForKey(key))
    }
  }

  @public init(_ dict: NSDictionary) {
    self.fastGenerator = NSFastGenerator(dict)
  }
}

extension NSDictionary : Sequence {
  @public func generate() -> NSDictionaryGenerator {
    return NSDictionaryGenerator(self)
  }
}

// FIXME: This should not be necessary.  We
// should get this from the extension on 'NSDictionary' above.
extension NSMutableDictionary : Sequence {}

//===----------------------------------------------------------------------===//
// Ranges
//===----------------------------------------------------------------------===//

extension NSRange {
  @public init(_ x: Range<Int>) {
    location = x.startIndex
    length = countElements(x)
  }
  @conversion @public func __conversion() -> Range<Int> {
    return Range(start: location, end: location + length)
  }
}

extension NSRange : _BridgedToObjectiveC {
  @public static func getObjectiveCType() -> Any.Type {
    return NSValue.self
  }

  @public func bridgeToObjectiveC() -> NSValue {
    return NSValue(range: self)
  }

  @public static func bridgeFromObjectiveC(x: NSValue) -> NSRange {
    return x.rangeValue
  }
}

//===----------------------------------------------------------------------===//
// NSZone
//===----------------------------------------------------------------------===//

@public struct NSZone : NilLiteralConvertible {
  var pointer : COpaquePointer

  @public init() { pointer = nil }
  
  @transparent @public
  static func convertFromNilLiteral() -> NSZone {
    return NSZone()
  }
}

//===----------------------------------------------------------------------===//
// NSLocalizedString
//===----------------------------------------------------------------------===//

/// Returns a localized string, using the main bundle if one is not specified.
@public 
func NSLocalizedString(key: String,
                       tableName: String? = nil,
                       bundle: NSBundle = NSBundle.mainBundle(),
                       value: String = "",
                       #comment: String) -> String {
  return bundle.localizedStringForKey(key, value:value, table:tableName)
}

//===----------------------------------------------------------------------===//
// Reflection
//===----------------------------------------------------------------------===//

@asmname("swift_ObjCMirror_count") 
func _getObjCCount(_MagicMirrorData) -> Int
@asmname("swift_ObjCMirror_subscript") 
func _getObjCChild(Int, _MagicMirrorData) -> (String, Mirror)

func _getObjCSummary(data: _MagicMirrorData) -> String {
  // FIXME: Trying to call debugDescription on AnyObject crashes.
  // <rdar://problem/16349526>
  // Work around by reinterpretCasting to NSObject and hoping for the best.
  return (data._loadValue() as NSObject).debugDescription
}

struct _ObjCMirror: Mirror {
  let data: _MagicMirrorData

  var value: Any { return data.objcValue }
  var valueType: Any.Type { return data.objcValueType }
  var objectIdentifier: ObjectIdentifier? {
    return data._loadValue() as ObjectIdentifier
  }
  var count: Int {
    return _getObjCCount(data)
  }
  subscript(i: Int) -> (String, Mirror) {
    return _getObjCChild(i, data)
  }
  var summary: String {
    return _getObjCSummary(data)
  }
  var quickLookObject: QuickLookObject? {
    return _getClassQuickLookObject(data)
  }
  var disposition: MirrorDisposition { return .Class }
}

struct _ObjCSuperMirror: Mirror {
  let data: _MagicMirrorData

  var value: Any { return data.objcValue }
  var valueType: Any.Type { return data.objcValueType }

  // Suppress the value identifier for super mirrors.
  var objectIdentifier: ObjectIdentifier? {
    return nil
  }
  var count: Int {
    return _getObjCCount(data)
  }
  subscript(i: Int) -> (String, Mirror) {
    return _getObjCChild(i, data)
  }
  var summary: String {
    return _getObjCSummary(data)
  }
  var quickLookObject: QuickLookObject? {
    return _getClassQuickLookObject(data)
  }
  var disposition: MirrorDisposition { return .Class }
}

struct _NSURLMirror : Mirror {
  var _u : NSURL
  
  init(_ u : NSURL) {_u = u}
  
  var value : Any { get { return _u } }
  
  var valueType : Any.Type { get { return (_u as Any).dynamicType } }
  
  var objectIdentifier: ObjectIdentifier? { get { return .None } }
  
  var count: Int { get { return 0 } }
  
  subscript(_: Int) -> (String,Mirror) { get { _fatalError("Mirror access out of bounds") } }
  
  var summary: String { get { return _u.absoluteString } }
  
  var quickLookObject: QuickLookObject? { get { return .Some(.URL(summary)) } }
  
  var disposition : MirrorDisposition { get { return .Aggregate } }
}

extension NSURL : Reflectable {
  @public func getMirror() -> Mirror {
    return _NSURLMirror(self)
  }
}

struct _NSRangeMirror : Mirror {
  var _r : NSRange
  
  init(_ r : NSRange) {_r = r}
  
  var value : Any { get { return _r } }
  
  var valueType : Any.Type { get { return (_r as Any).dynamicType } }
  
  var objectIdentifier: ObjectIdentifier? { get { return .None } }
  
  var count: Int { get { return 2 } }
  
  subscript(i: Int) -> (String,Mirror) {
    switch i {
      case 0: return ("location",reflect(_r.location))
      case 1: return ("length",reflect(_r.length))
      default: _fatalError("Mirror access out of bounds")
    }
  }
  
  var summary: String { return "(\(_r.location),\(_r.length))" }
  
  var quickLookObject: QuickLookObject? { return .Some(.Range(UInt64(_r.location),UInt64(_r.length))) }
  
  var disposition : MirrorDisposition { return .Aggregate }
}

extension NSRange : Reflectable {
  @public func getMirror() -> Mirror {
    return _NSRangeMirror(self)
  }
}

extension NSString : Reflectable {
  @public func getMirror() -> Mirror {
    return reflect(self as String)
  }
}

//===----------------------------------------------------------------------===//
// NSDate
//===----------------------------------------------------------------------===//

struct _NSDateMirror : Mirror {
  var _d : NSDate
  
  init(_ d : NSDate) {_d = d}
  
  var value : Any { get { return _d } }
  
  var valueType : Any.Type { get { return (_d as Any).dynamicType } }
  
  var objectIdentifier: ObjectIdentifier? { get { return .None } }
  
  var count: Int { get { return 0 } }
  
  subscript(i: Int) -> (String,Mirror) {
    _fatalError("Mirror access out of bounds")
  }
  
  var summary: String {
    let df = NSDateFormatter()
    df.dateStyle = .MediumStyle
    df.timeStyle = .ShortStyle
    return df.stringFromDate(_d)
  }
  
  var quickLookObject: QuickLookObject? { return .Some(.Text(summary)) }
  
  var disposition : MirrorDisposition { return .Aggregate }
}

extension NSDate : Reflectable {
  @public func getMirror() -> Mirror {
    return _NSDateMirror(self)
  }
}

//===----------------------------------------------------------------------===//
// NSLog
//===----------------------------------------------------------------------===//

@public func NSLog(format: String, args: CVarArg...) {
  withVaList(args) { NSLogv(format, $0) }
}

//===----------------------------------------------------------------------===//
// NSUndoManager
//===----------------------------------------------------------------------===//

// We need a typed overlay for -prepareWithInvocationTarget:.
// The method returns a proxy, and swift_dynamicCastClass() doesn't 
// allow a proxy to be cast to its proxied type.
@asmname("_swift_undoProxy") 
func _swift_undoProxy<T: NSObject>(undoManager: NSUndoManager, target: T) -> T

extension NSUndoManager {
  @public func prepareWithInvocationTarget<T: NSObject>(target: T) -> T {
    return _swift_undoProxy(self, target)
  }
}

//===----------------------------------------------------------------------===//
// NSError (as an out parameter).
//===----------------------------------------------------------------------===//

@public typealias NSErrorPointer = AutoreleasingUnsafePointer<NSError?>

//===----------------------------------------------------------------------===//
// Variadic initializers and methods
//===----------------------------------------------------------------------===//

extension NSPredicate {
  // + (NSPredicate *)predicateWithFormat:(NSString *)predicateFormat, ...;
  @public
  convenience init(format predicateFormat: String, _ args: CVarArg...) {
    let va_args = getVaList(args)
    return self.init(format: predicateFormat, arguments: va_args)
  }
}

extension NSExpression {
  // + (NSExpression *) expressionWithFormat:(NSString *)expressionFormat, ...;
  @public
  convenience init(format expressionFormat: String, _ args: CVarArg...) {
    let va_args = getVaList(args)
    return self.init(format: expressionFormat, arguments: va_args)
  }
}

extension NSString {
  @public
  convenience init(format: NSString, _ args: CVarArg...) {
    // We can't use withVaList because 'self' cannot be captured by a closure
    // before it has been initialized.
    let va_args = getVaList(args)
    self.init(format: format, arguments: va_args)
  }
  
  @public
  convenience init(format: NSString, locale: NSLocale?, _ args: CVarArg...) {
    // We can't use withVaList because 'self' cannot be captured by a closure
    // before it has been initialized.
    let va_args = getVaList(args)
    self.init(format: format, locale: locale, arguments: va_args)
  }

  @public
  class func localizedStringWithFormat(format: NSString,
                                       _ args: CVarArg...) -> NSString {
    return withVaList(args) {
      NSString(format: format, locale: NSLocale.currentLocale(),
               arguments: $0)
    }
  }

  @public
  func stringByAppendingFormat(format: NSString, _ args: CVarArg...)
  -> NSString {
    return withVaList(args) {
      self.stringByAppendingString(NSString(format: format, arguments: $0))
    }
  }
}

extension NSMutableString {
  @public
  func appendFormat(format: NSString, _ args: CVarArg...) {
    return withVaList(args) {
      self.appendString(NSString(format: format, arguments: $0))
    }
  }
}

extension NSArray {
  // Overlay: - (instancetype)initWithObjects:(id)firstObj, ...
  @public
  convenience init(objects elements: AnyObject...) {
    // - (instancetype)initWithObjects:(const id [])objects count:(NSUInteger)cnt;
    let x = _extractOrCopyToNativeArrayBuffer(elements._buffer)
    // Use Imported:
    // @objc(initWithObjects:count:)
    //    init(withObjects objects: ConstUnsafePointer<AnyObject?>,
    //    count cnt: Int)
    self.init(objects: UnsafePointer(x.elementStorage), count: x.count)
    _fixLifetime(x)
  }

  @final @conversion @public
  func __conversion() -> [AnyObject] {
    return Array(
             ArrayBuffer(reinterpretCast(self.copyWithZone(nil)) as _CocoaArray))
  }
}

extension NSDictionary {
  // - (instancetype)initWithObjectsAndKeys:(id)firstObject, ...
  @public
  convenience init(objectsAndKeys objects: AnyObject...) {
    // - (instancetype)initWithObjects:(NSArray *)objects forKeys:(NSArray *)keys;
    var values: [AnyObject] = []
    var keys:   [AnyObject] = []
    for var i = 0; i < objects.count; i += 2 {
      values.append(objects[i])
      keys.append(objects[i+1])
    }
    // - (instancetype)initWithObjects:(NSArray *)values forKeys:(NSArray *)keys;
    self.init(objects: values, forKeys: keys)
  }
}

extension NSOrderedSet {
  // - (instancetype)initWithObjects:(id)firstObj, ...
  @public
  convenience init(objects elements: AnyObject...) {
    let x = _extractOrCopyToNativeArrayBuffer(elements._buffer)
    // - (instancetype)initWithObjects:(const id [])objects count:(NSUInteger)cnt;
    // Imported as:
    // @objc(initWithObjects:count:)
    // init(withObjects objects: ConstUnsafePointer<AnyObject?>,
    //      count cnt: Int)
    self.init(objects: UnsafePointer(x.elementStorage), count: x.count)
    _fixLifetime(x)
  }
}

extension NSSet {
  // - (instancetype)initWithObjects:(id)firstObj, ...
  @public
  convenience init(objects elements: AnyObject...) {
    let x = _extractOrCopyToNativeArrayBuffer(elements._buffer)
    // - (instancetype)initWithObjects:(const id [])objects count:(NSUInteger)cnt;
    // Imported as:
    // @objc(initWithObjects:count:)
    // init(withObjects objects: ConstUnsafePointer<AnyObject?>, count cnt: Int)
    self.init(objects: UnsafePointer(x.elementStorage), count: x.count)
    _fixLifetime(x)
  }
}

struct _NSSetMirror : Mirror {
  var _s : NSSet
  var _a : NSArray!
  
  init(_ s : NSSet) {
    _s = s
    _a = _s.allObjects
  }
  
  var value : Any { get { return _s } }
  
  var valueType : Any.Type { get { return (_s as Any).dynamicType } }
  
  var objectIdentifier: ObjectIdentifier? { get { return .None } }
  
  var count: Int { 
    if _a {
      return _a.count
    }
    return 0
  }
  
  subscript(i: Int) -> (String,Mirror) {
    if i >= 0 && i < count {
      return ("[\(i)]",reflect(_a[i]))
    }
    _fatalError("Mirror access out of bounds")
  }
  
  var summary: String { return "\(count) elements" }
  
  var quickLookObject: QuickLookObject? { return nil }
  
  var disposition : MirrorDisposition { return .MembershipContainer }
}

extension NSSet : Reflectable {
  @public func getMirror() -> Mirror {
    return _NSSetMirror(self)
  }
}

