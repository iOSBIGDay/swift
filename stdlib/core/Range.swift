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

@public struct RangeGenerator<T: ForwardIndex> : Generator, Sequence, Reflectable {
  @public typealias Element = T

  @public @transparent
  init(_ bounds: Range<T>) {
    self.startIndex = bounds.startIndex
    self.endIndex = bounds.endIndex
  }

  @public mutating func next() -> Element? {
    if startIndex == endIndex {
      return .None
    }
    return startIndex++
  }

  // Every Generator is also a single-pass Sequence
  @public typealias GeneratorType = RangeGenerator<T>
  @public func generate() -> GeneratorType {
    return self
  }

  @public var startIndex: T
  @public var endIndex: T

	@public func getMirror() -> Mirror {
		return _RangeGeneratorMirror(self)
	}
}

@internal struct _RangeGeneratorMirror<T: ForwardIndex>: Mirror {
	var _value: RangeGenerator<T>

	init(_ x : RangeGenerator<T>) {
	  _value = x
	}

	var value: Any { return _value }

	var valueType: Any.Type { return (_value as Any).dynamicType }

	var objectIdentifier: ObjectIdentifier? { return .None }

	var count: Int { return 2 }

	subscript(i: Int) -> (String, Mirror) {
	  switch i {
		case 0:	return ("startIndex",reflect(_value.startIndex))
		case 1:	return ("endIndex",reflect(_value.endIndex))
	  default: _preconditionFailure("cannot extract this child index")
	  }
	}

	var summary: String { 
		return "RangeGenerator(\( reflect(_value.startIndex).summary ) to \( reflect(_value.endIndex).summary))"
	}

	var quickLookObject: QuickLookObject? { return .None }

	var disposition: MirrorDisposition { return .Struct }
}

@public struct StridedRangeGenerator<T: ForwardIndex> : Generator, Sequence, Reflectable {
  @public typealias Element = T

  @transparent @public
  init(_ bounds: Range<T>, stride: T.DistanceType) {
    self._bounds = bounds
    self._stride = stride
  }

  @public mutating func next() -> Element? {
    if !_bounds {
      return .None
    }
    let ret = _bounds.startIndex
    _bounds.startIndex = advance(_bounds.startIndex, _stride, _bounds.endIndex)
    return ret
  }

  // Every Generator is also a single-pass Sequence
  @public typealias GeneratorType = StridedRangeGenerator
  @public func generate() -> GeneratorType {
    return self
  }

  var _bounds: Range<T>
  var _stride: T.DistanceType

	@public func getMirror() -> Mirror {
		return _StridedRangeGeneratorMirror(self)
	}
}

@internal struct _StridedRangeGeneratorMirror<T: ForwardIndex>: Mirror {
	var _value: StridedRangeGenerator<T>

	init(_ x : StridedRangeGenerator<T>) {
	  _value = x
	}

	var value: Any { return _value }

	var valueType: Any.Type { return (_value as Any).dynamicType }

	var objectIdentifier: ObjectIdentifier? { return .None }

	var count: Int { return 3 }

	subscript(i: Int) -> (String, Mirror) {
	  switch i {
		case 0:	return ("startIndex",reflect(_value._bounds.startIndex))
		case 1:	return ("endIndex",reflect(_value._bounds.endIndex))
		case 2: return ("_stride",reflect(_value._stride))
	  default: _preconditionFailure("cannot extract this child index")
	  }
	}

	var summary: String { 
		return "RangeGenerator(\( reflect(_value._bounds.startIndex).summary ) to \( reflect(_value._bounds.endIndex).summary) with stride \( reflect(_value._stride).summary ))"
	}

	var quickLookObject: QuickLookObject? { return .None }

	var disposition: MirrorDisposition { return .Struct }
}

@public struct Range<T: ForwardIndex> : LogicValue, Sliceable, Reflectable {  
  @transparent @public
  init(start: T, end: T) {
    _startIndex = start
    _endIndex = end
  }

  @public var isEmpty : Bool {
    return startIndex == endIndex
  }

  @public func getLogicValue() -> Bool {
    return !isEmpty
  }

  @public subscript(i: T) -> T {
    return i
  }

  @public subscript(x: Range<T>) -> Range {
    return Range(start: x.startIndex, end: x.endIndex)
  }

  @public typealias GeneratorType = RangeGenerator<T>
  @public func generate() -> RangeGenerator<T> {
    return GeneratorType(self)
  }

  @public func by(stride: T.DistanceType) -> StridedRangeGenerator<T> {
    return StridedRangeGenerator(self, stride: stride)
  }

  @public var startIndex: T {
    get {
      return _startIndex
    }
    set(newValue) {
      _startIndex = newValue
    }
  }

  @public var endIndex: T {
    get {
      return _endIndex
    }
    set(newValue) {
      _endIndex = newValue
    }
  }
  
  var _startIndex: T
  var _endIndex: T

	@public func getMirror() -> Mirror {
		return _RangeMirror(self)
	}
}

@internal struct _RangeMirror<T: ForwardIndex>: Mirror {
	var _value: Range<T>

	init(_ x : Range<T>) {
	  _value = x
	}

	var value: Any { return _value }

	var valueType: Any.Type { return (_value as Any).dynamicType }

	var objectIdentifier: ObjectIdentifier? { return .None }

	var count: Int { return 2 }

	subscript(i: Int) -> (String, Mirror) {
	  switch i {
		case 0:	return ("startIndex",reflect(_value._startIndex))
		case 1:	return ("endIndex",reflect(_value._endIndex))
	  default: _preconditionFailure("cannot extract this child index")
	  }
	}

	var summary: String { 
		return "Range(\( reflect(_value._startIndex).summary ) to \( reflect(_value._endIndex).summary))"
	}

	var quickLookObject: QuickLookObject? { return .None }

	var disposition: MirrorDisposition { return .Struct }
}

@public func count<I: RandomAccessIndex>(r: Range<I>) -> I.DistanceType {
  return r.startIndex.distanceTo(r.endIndex)
}


/// Forms a half open range including the minimum value but excluding the
/// maximum value.
@transparent @public
@availability(*, unavailable, message="half-open range operator .. has been renamed to ..<")
func .. <Pos : ForwardIndex> (min: Pos, max: Pos) -> Range<Pos> {
  return Range(start: min, end: max)
}

@transparent @public
func ..< <Pos : ForwardIndex> (min: Pos, max: Pos) -> Range<Pos> {
  return Range(start: min, end: max)
}


/// Forms a closed range including both the minimum and maximum values.
@transparent @public
func ... <Pos : ForwardIndex> (min: Pos, max: Pos) -> Range<Pos> {
  return Range(start: min, end: max.successor())
}

@public struct ReverseRangeGenerator<T: BidirectionalIndex> : Generator, 
                                                              Sequence,
 																															Reflectable {
  @public typealias Element = T

  @transparent @public
  init(start: T, pastEnd: T) {
    self._bounds = (start,pastEnd)
  }

  @public mutating func next() -> Element? {
    if _bounds.0 == _bounds.1 { return .None }
    _bounds.1 = _bounds.1.predecessor()
    return _bounds.1
  }

  // Every Generator is also a single-pass Sequence
  @public typealias GeneratorType = ReverseRangeGenerator<T>
  @public func generate() -> GeneratorType {
    return self
  }

  var _bounds: (T, T)

	@public func getMirror() -> Mirror {
		return _ReverseRangeGeneratorMirror(self)
	}
}

@internal struct _ReverseRangeGeneratorMirror<T: BidirectionalIndex>: Mirror {
	var _value: ReverseRangeGenerator<T>

	init(_ x : ReverseRangeGenerator<T>) {
	  _value = x
	}

	var value: Any { return _value }

	var valueType: Any.Type { return (_value as Any).dynamicType }

	var objectIdentifier: ObjectIdentifier? { return .None }

	var count: Int { return 2 }

	subscript(i: Int) -> (String, Mirror) {
	  switch i {
		case 0:	return ("startIndex",reflect(_value._bounds.0))
		case 1:	return ("endIndex",reflect(_value._bounds.1))
	  default: _preconditionFailure("cannot extract this child index")
	  }
	}

	var summary: String { 
		return "ReverseRangeGenerator(\( reflect(_value._bounds.0).summary ) to \( reflect(_value._bounds.1).summary))"
	}

	var quickLookObject: QuickLookObject? { return .None }

	var disposition: MirrorDisposition { return .Struct }
}

@public struct ReverseRange<T: BidirectionalIndex> : Sequence, Reflectable {
  @public init(start: T, pastEnd: T) {
    self._bounds = (start, pastEnd)
  }

  @public init(range fwd: Range<T>) {
    self._bounds = (fwd.startIndex, fwd.endIndex)
  }

  @public func isEmpty() -> Bool {
    return _bounds.0 == _bounds.1
  }

  @public func bounds() -> (T, T) {
    return _bounds
  }

  @public typealias GeneratorType = ReverseRangeGenerator<T>
  @public func generate() -> GeneratorType {
    return GeneratorType(start: _bounds.0, pastEnd: _bounds.1)
  }

  var _bounds: (T, T)

	@public func getMirror() -> Mirror {
		return _ReverseRangeMirror(self)
	}
}

@internal struct _ReverseRangeMirror<T: BidirectionalIndex>: Mirror {
	var _value: ReverseRange<T>

	init(_ x : ReverseRange<T>) {
	  _value = x
	}

	var value: Any { return _value }

	var valueType: Any.Type { return (_value as Any).dynamicType }

	var objectIdentifier: ObjectIdentifier? { return .None }

	var count: Int { return 2 }

	subscript(i: Int) -> (String, Mirror) {
	  switch i {
		case 0:	return ("startIndex",reflect(_value._bounds.0))
		case 1:	return ("endIndex",reflect(_value._bounds.1))
	  default: _preconditionFailure("cannot extract this child index")
	  }
	}

	var summary: String { 
		return "ReverseRange(\( reflect(_value._bounds.0).summary ) to \( reflect(_value._bounds.1).summary))"
	}

	var quickLookObject: QuickLookObject? { return .None }

	var disposition: MirrorDisposition { return .Struct }
}

//
// Pattern matching support for ranges
//
// Ranges can be used to match values contained within the range, e.g.:
// switch x {
// case 0...10:
//   println("single digit")
// case _:
//   println("too big")
// }

@infix @public
func ~= <
  T: RandomAccessIndex where T.DistanceType : SignedInteger
>(x: Range<T>, y: T) -> Bool {
  let a = x.startIndex.distanceTo(y) >= 0
  let b = y.distanceTo(x.endIndex) > 0
  return a && b
}


extension Range {
  /// Return an array containing the results of calling
  /// `transform(x)` on each element `x` of `self`.
  @public func map<U>(transform: (T)->U) -> [U] {
    return lazy(self).map(transform).array
  }
}
