Class {
	#name : #DataSeries,
	#superclass : #OrderedDictionary,
	#instVars : [
		'name',
		'forcedIsNumerical'
	],
	#category : #'DataFrame-Core'
}

{ #category : #'instance creation' }
DataSeries class >> newFrom: aCollection [

	aCollection ifEmpty: [ ^ self new ].

	aCollection species == self ifTrue: [ ^ super newFrom: aCollection associations ].

	"If it's a collection of associations use the superclass implementation"
	^ super newFrom: (aCollection anyOne isAssociation
			   ifTrue: [ aCollection ]
			   ifFalse: [ aCollection withIndexCollect: [ :each :i | i -> each ] ])
]

{ #category : #'instance creation' }
DataSeries class >> newFromKeys: keys andValues: values [

	| dict |
	self flag: #pharo12. "This is a copy of the superclass with a speed up. I'll propose this speedup in Pharo 12 so when Pharo 12 will be the minimal suuported version then we can drop this method."
	dict := self new: keys size.
	keys with: values do: [ :k :v | dict at: k put: v ].
	^ dict
]

{ #category : #'instance creation' }
DataSeries class >> withKeys: keys values: values [
	^ self newFromKeys: keys andValues: values
]

{ #category : #'instance creation' }
DataSeries class >> withKeys: keys values: values name: aName [
	^ (self withKeys: keys values: values) name: aName; yourself
]

{ #category : #'instance creation' }
DataSeries class >> withValues: values [
	| keys |
	keys := (1 to: values size) asArray.
	^ self withKeys: keys values: values
]

{ #category : #'instance creation' }
DataSeries class >> withValues: values name: aName [
	| keys |
	keys := (1 to: values size) asArray.
	^ (self withKeys: keys values: values) name: aName; yourself
]

{ #category : #comparing }
DataSeries >> < arg [
	"Element-wise comparision between two DataSeries.
	 Does not consider keys for comparision."

	^ arg adaptToCollection: self andSend: #<
]

{ #category : #comparing }
DataSeries >> <= arg [
	"Element-wise comparision between two DataSeries.
	 Does not consider keys for comparision."

	^ arg adaptToCollection: self andSend: #<=
]

{ #category : #comparing }
DataSeries >> = anObject [
	(super = anObject)
		ifFalse: [ ^ false ].

	^ anObject name = self name
		"order of keys"
		and: [ anObject keys = self keys ]
]

{ #category : #comparing }
DataSeries >> > arg [
	"Element-wise comparision between two DataSeries.
	 Does not consider keys for comparision."

	^ arg adaptToCollection: self andSend: #>
]

{ #category : #comparing }
DataSeries >> >= arg [
	"Element-wise comparision between two DataSeries.
	 Does not consider keys for comparision."

	^ arg adaptToCollection: self andSend: #>=
]

{ #category : #adapting }
DataSeries >> adaptToCollection: rcvr andSend: selector [
	"If I am involved in arithmetic with another Collection, return a Collection of
	the results of each element combined with the scalar in that expression."

	(rcvr isSequenceable and: [ self isSequenceable ]) ifFalse: [ self error: 'Only sequenceable collections may be combined arithmetically' ].


	^ rcvr withSeries: self collect: [ :rcvrElement :myElement |
		  (rcvrElement isNil or: [ myElement isNil ])
			  ifTrue: [ nil ]
			  ifFalse: [ rcvrElement perform: selector with: myElement ] ]
]

{ #category : #statistics }
DataSeries >> argmax [
	"Returns the key which corresponds to the maximum value of the dataseries"

	"(#(100 10 20 30) asDataSeries argmax) >>> 1"

	"((DataSeries withKeys: #(A B C) values: #(1 2 40)) argmax) >>> #C"

	^ self keyAtValue: self max
]

{ #category : #statistics }
DataSeries >> argmin [
	"Returns the key which corresponds to the minimum value of the dataseries"

	"(#(100 10 20 30) asDataSeries argmin) >>> 2"

	"((DataSeries withKeys: #(A B C) values: #(1 2 40)) argmin) >>> #A"

	^ self keyAtValue: self min
]

{ #category : #converting }
DataSeries >> asDataFrame [
	"Converts a data series to a data frame with 1 column. The values in the column of the data frame are the values of the data series. The row names of this data frame are the keys of the data series. The column name of the data frame is same as the name of the data series"
	
	^ DataFrame
		withColumns: {  self values }
		rowNames: self keys
		columnNames: { self name }
]

{ #category : #accessing }
DataSeries >> at: aKey transform: aBlock [
	"Evaluate aBlock on the value at aKey and replace that value with the result. Signal an exception if aKey was not found"

	"((DataSeries withKeys: #(A B C) values: #(1 4 3)) at: #C transform: [ :x | x * x ]) >>> (DataSeries withKeys: #(A B C) values: #(1 4 9))."

	self
		at: aKey
		transform: aBlock
		ifAbsent: [ self errorKeyNotFound: aKey ]
]

{ #category : #accessing }
DataSeries >> at: aKey transform: aBlock ifAbsent: exceptionBlock [
	"Evaluate aBlock on the value at aKey and replace that value with the result. Evaluate exceptionBlock if aKey was not found"
	| oldValue |
	oldValue := self at: aKey ifAbsent: [
		exceptionBlock value.
		^ self ].

	self at: aKey put: (aBlock value: oldValue)
]

{ #category : #accessing }
DataSeries >> atAll: aCollectionOfIndexes [
	"Returns a data series of only those elements of the receiver whose indices are present in the collection aCollectionOfIndexes"
	
	^ self withIndexSelect: [ :each :index | aCollectionOfIndexes includes: index ]
]

{ #category : #accessing }
DataSeries >> atIndex: aNumber [
	"Answer the element of the receiver at index aNumber"

	"(#(1 4 9) asDataSeries atIndex: 2) >>> 4"

	"((DataSeries withKeys: #(A B C) values: #(1 2 40)) atIndex: 3) >>> 40"

	^ self at: (self keys at: aNumber)
]

{ #category : #accessing }
DataSeries >> atIndex: aNumber put: aValue [
	"Replace the element of the receiver at index aNumber with the value aValue"

	^ self at: (self keys at: aNumber) put: aValue
]

{ #category : #accessing }
DataSeries >> atIndex: aNumber transform: aBlock [
	"Evaluate aBlock on the value at aNumber and replace that value with the result"

	"	((DataSeries withKeys: #( A B C ) values: #( 1 4 3 ))
		 atIndex: 3
		 transform: [ :x | x * x ])
	>>> (DataSeries withKeys: #( A B C ) values: #( 1 4 9 ))"

	"(#( 1 3 3 ) asDataSeries atIndex: 2 transform: [ :x | x - 1 ])
	>>> (#( 1 2 3 ) asDataSeries)"

	| key |
	key := self keys at: aNumber.
	self at: key transform: aBlock
]

{ #category : #statistics }
DataSeries >> average [
	"Returns the average without including nils"

	"(#(1 2 nil 3) asDataSeries average) >>> 2"

	^ self removeNils values average
]

{ #category : #'data-types' }
DataSeries >> calculateDataType [
	"Returns the data type of the data series"

	"(#(1 2 3) asDataSeries calculateDataType) >>> SmallInteger"

	"(#(1 a 3) asDataSeries calculateDataType) >>> Object"

	"(#(1.1 2.5 3.7) asDataSeries calculateDataType) >>> SmallFloat64"

	"(#(1.1 2.5 3) asDataSeries calculateDataType) >>> Number"

	^ self values calculateDataType
]

{ #category : #comparing }
DataSeries >> closeTo: anObject [
	^ self closeTo: anObject precision: self defaultPrecision
]

{ #category : #comparing }
DataSeries >> closeTo: anObject precision: aPrecision [
	self == anObject
		ifTrue: [^ true].

	(self species == anObject species
		and: [self size = anObject size])
		ifFalse: [^ false].

	(anObject name = self name)
		ifFalse: [ ^ false ].

	(anObject keys = self keys)
		ifFalse: [ ^ false ].

	^ (1 to: self values size)
		detect: [ :i | ((self atIndex: i) closeTo: (anObject atIndex: i) precision: aPrecision) not ]
		ifFound: [ false ]
		ifNone: [ true ]
]

{ #category : #enumerating }
DataSeries >> collect: aBlock [
	"Applies aBlock to every element"

	| result |
	result :=  super collect: aBlock.
	result name: self name.
	^ result
]

{ #category : #enumerating }
DataSeries >> collectWithNotNils: aBlock [
	"Applies aBlock to every non-nil element"

	^ self collect: [ :each | each ifNotNil: [ aBlock value: each ] ]
]

{ #category : #'math functions' }
DataSeries >> correlationWith: otherSeries [
	"Calculate the Pearson correlation coefficient between self and the other series"

	"((#(1 2 4) asDataSeries) correlationWith: (#(2 4 8) asDataSeries)) >>> 1."

	"((#(1 2 4) asDataSeries) correlationWith: (#(-3 -6 -12) asDataSeries)) >>> -1."

	^ self
		  correlationWith: otherSeries
		  using: DataPearsonCorrelationMethod
]

{ #category : #'math functions' }
DataSeries >> correlationWith: otherSeries using: aCorrelationCoefficient [
	"Calculate the correlation coefficient between self and the other series using the given method"

	"((#(1 2 4) asDataSeries) correlationWith: (#(2 4 8) asDataSeries) using: DataPearsonCorrelationMethod) >>> 1."

	"((#(1 2 4) asDataSeries) correlationWith: (#(-3 -6 -12) asDataSeries) using: DataPearsonCorrelationMethod) >>> -1."

	^ aCorrelationCoefficient between: self and: otherSeries
]

{ #category : #statistics }
DataSeries >> countNils [
	"Returns the number of nil values in the data series"

	"(#(1 nil 2 nil nil) asDataSeries countNils) >>> 3"

	"(#('A' 'nil' nil 'B') asDataSeries countNils) >>> 1"

	^ self count: [ :each | each isNil ]
]

{ #category : #statistics }
DataSeries >> countNonNils [
	"Returns the number of non-nil values in the data series"

	"(#(1 nil 2 nil nil) asDataSeries countNonNils) >>> 2"

	"(#('A' 'nil' nil 'B') asDataSeries countNonNils) >>> 3"

	^ self count: [ :each | each isNotNil ]
]

{ #category : #statistics }
DataSeries >> crossTabulateWith: aSeries [
	"A DataFrame is returned which is useful in quantitatively analyzing the relationship of values in one data series with the values in another data series"

	| df |
	self size = aSeries size ifFalse: [ SizeMismatch signal ].

	df := DataFrame withRows:
		      (self removeDuplicates sortIfPossible collect: [ :each1 |
			       aSeries removeDuplicates sortIfPossible collect: [ :each2 |
				       (1 to: self size) inject: 0 into: [ :accum :i |
					       ((self atIndex: i) = each1 and:
						        (aSeries atIndex: i) = each2)
						       ifTrue: [ accum + 1 ]
						       ifFalse: [ accum ] ] ] ]).

	df rowNames: self removeDuplicates sortIfPossible.
	df columnNames: aSeries removeDuplicates sortIfPossible.
	^ df
]

{ #category : #statistics }
DataSeries >> cumulativeSum [
	"Calculate the cumulative sum of a data series and return a new data series with keys as self keys and values as cumulative sum"

	"(#(1 nil 2 3 4) asDataSeries cumulativeSum) >>> (#(1 1 3 6 10) asDataSeries)"

	"(#(nil nil 10 90) asDataSeries cumulativeSum) >>> (#(0 0 10 100) asDataSeries)"

	| sum |
	sum := 0.

	^ self collect: [ :each |
		  each ifNotNil: [ sum := sum + each ].
		  sum ]
]

{ #category : #defaults }
DataSeries >> defaultHeadTailSize [
	^ 5
]

{ #category : #defaults }
DataSeries >> defaultName [
	^ '(no name)'
]

{ #category : #defaults }
DataSeries >> defaultPrecision [
	^ 0.0001
]

{ #category : #accessing }
DataSeries >> eighth [
	"Answer the eighth element of the receiver.
	Raise an error if there are not enough elements."

	"(#(a b c d e f g h i j) asDataSeries eighth) >>> #h"

	^ self atIndex: 8
]

{ #category : #converting }
DataSeries >> encodeOneHot [
	"Encode the values of the DataSeries into one-hot vectors."

	"(#(a b) asDataSeries encodeOneHot) >>>(#(#(1 0) #(0 1))asDataSeries) "

	"(#(1 2 3) asDataSeries encodeOneHot) >>>(#(#(1 0 0) #(0 1 0) #(0 0 1))asDataSeries) "

	"(#(23 0.5 542) asDataSeries encodeOneHot) >>>(#(#(0 1 0) #(1 0 0) #(0 0 1))asDataSeries) "

	| uniqueValues encodingDataSeries oneHotValues |
	uniqueValues := self removeDuplicates sortIfPossible.
	encodingDataSeries := self class new.
	uniqueValues withIndexDo: [ :value :index |
		encodingDataSeries at: value put: index ].
	oneHotValues := self values collect: [ :value |
		                | oneHot |
		                oneHot := encodingDataSeries keys collect: [ :key |
			                          value = key
				                          ifTrue: [ 1 ]
				                          ifFalse: [ 0 ] ].
		                oneHot ].
	^ DataSeries withKeys: self keys values: oneHotValues name: self name
]

{ #category : #private }
DataSeries >> errorKeyNotFound: aKey [

	KeyNotFound signalFor: aKey
]

{ #category : #errors }
DataSeries >> errorKeysMismatch [
	Error signal: 'Keys of two series do not match'
]

{ #category : #accessing }
DataSeries >> fifth [
	"Answer the fifth element of the receiver.
	Raise an error if there are not enough elements."

	"(#(a b c d e f g h i j) asDataSeries fifth) >>> #e"

	^ self atIndex: 5
]

{ #category : #accessing }
DataSeries >> first [
	"Answer the first element of the receiver.
	Raise an error if there are not enough elements."

	"(#(a b c d e f g h i j) asDataSeries first) >>> #a"

	^ self atIndex: 1
]

{ #category : #statistics }
DataSeries >> firstQuartile [
	"25% of the values in a set are smaller than or equal to the first Quartile of that set"

	"(#(7 4 20) asDataSeries firstQuartile) >>> 4"

	^ self quartile: 1
]

{ #category : #accessing }
DataSeries >> fourth [
	"Answer the fourth element of the receiver.
	Raise an error if there are not enough elements."

	"(#(a b c d e f g h i j) asDataSeries fourth) >>> #d"

	^ self atIndex: 4
]

{ #category : #statistics }
DataSeries >> fourthQuartile [
	"Fourth Quartile is the maximum value in a set of values"

	"(#(7 4 20) asDataSeries fourthQuartile) >>> 20"

	^ self quartile: 4
]

{ #category : #grouping }
DataSeries >> groupBy: otherSeries aggregateUsing: aBlock [
	"Group my values by the unique values of otherSeries, aggregate them using aBlock. Use my name by default"
	^ self groupBy: otherSeries aggregateUsing: aBlock as: self name
]

{ #category : #grouping }
DataSeries >> groupBy: otherSeries aggregateUsing: aBlock as: aNewName [
	"Group my values by the unique values of otherSeries, aggregate them using aBlock, and answer a new DataSeries with unique values of otherSeries as keys, aggregated values of myself as values, and aNewName as name"

	| groupMap |
	self size = otherSeries size ifFalse: [ SizeMismatch signal ].

	groupMap := (otherSeries removeDuplicates sortIfPossible collect: [
		             :e | e -> OrderedCollection new ]) asOrderedDictionary.

	1 to: self size do: [ :index |
		(groupMap at: (otherSeries atIndex: index)) add:
			(self atIndex: index) ].

	^ self class
		  withKeys: groupMap keys
		  values: (groupMap values collect: aBlock)
		  name: aNewName
]

{ #category : #grouping }
DataSeries >> groupByBins: bins [

	^ self groupByBins: bins labelled: (1 to: bins size - 1)
]

{ #category : #grouping }
DataSeries >> groupByBins: bins labelled: aCollection [
	"I receive two parameters:
	- A collection of bins that will determine intervals to group the values
	- A collection of labels to apply for each intervals of the bins

	I return a new DataSeries associating each key to a label corresponding to the bin they match."

	| labelledIntervals |
	bins size = (aCollection size + 1) ifFalse: [ SizeMismatch signal: 'The labels should have one less elements than the bins.' ].

	labelledIntervals := OrderedDictionary new.
	bins overlappingPairsWithIndexDo: [ :min :max :index | labelledIntervals at: (aCollection at: index) put: min -> max ].

	^ self collect: [ :each | labelledIntervals keyAtValue: (labelledIntervals values detect: [ :asso | each between: asso key and: asso value ]) ]
]

{ #category : #grouping }
DataSeries >> groupByUniqueValuesAndAggregateUsing: aBlock [
	"Group my values by their unique values and aggregate them using aBlock. Use my name by default"
	^ self groupByUniqueValuesAndAggregateUsing: aBlock as: self name
]

{ #category : #grouping }
DataSeries >> groupByUniqueValuesAndAggregateUsing: aBlock as: aNewName [
	"Group my values by unique values, aggregate them using aBlock, and answer a new DataSeries with theunique values as keys, aggregated values of myself as values, and aNewName as name"

	| groupMap |
	groupMap := (self removeDuplicates sortIfPossible collect: [ :e |
		             e -> OrderedCollection new ]) asOrderedDictionary.

	self do: [ :each | (groupMap at: each) add: each ].

	^ self class
		  withKeys: groupMap keys
		  values: (groupMap values collect: aBlock)
		  name: aNewName
]

{ #category : #testing }
DataSeries >> hasNil [
	"return true if data series has at least one nil value"

	"(#(a nil b) asDataSeries hasNil) >>> true"

	"(#(a 'nil' b) asDataSeries hasNil) >>> false"

	"(#(1 nil 3) asDataSeries hasNil) >>> true"

	"(#(1 0 3) asDataSeries hasNil) >>> false"

	^ self includes: nil
]

{ #category : #slicing }
DataSeries >> head [
	"Returns a data series with first 5 elements of the receiver"

	"(#(a b c d e f g h i j) asDataSeries head) >>> (#(a b c d e) asDataSeries)"

	"(#(1 2 3 4 5 6 7 8 9 10) asDataSeries head) >>> (#(1 2 3 4 5) asDataSeries)"

	^ self head: self defaultHeadTailSize
]

{ #category : #slicing }
DataSeries >> head: aNumber [
	"Returns a data series with first aNumber elements of the receiver"

	"(#(a b c d e f g h i j) asDataSeries head: 3) >>> (#(a b c) asDataSeries)"

	"(#(1 2 3 4 5 6 7 8 9 10) asDataSeries head: 1) >>> (#(1) asDataSeries)"

	^ self species
		  withKeys: (self keys copyFrom: 1 to: aNumber)
		  values: (self values copyFrom: 1 to: aNumber)
		  name: self name
]

{ #category : #initialization }
DataSeries >> initialize [
	super initialize.
	name := self defaultName
]

{ #category : #initialization }
DataSeries >> initialize: aCapacity [
	"Make sure that initialize is called and the default name is set"
	self initialize.
	^ super initialize: aCapacity
]

{ #category : #statistics }
DataSeries >> interquartileRange [
	"The Inter Quartile Range is the difference between the third Quartile and the first Quartile"

	"(#(7 4 20) asDataSeries interquartileRange) >>> 16"

	^ self thirdQuartile - self firstQuartile
]

{ #category : #'categorical-numerical' }
DataSeries >> isCategorical [
	"Returns true if atleast one value of the data series is non numerical and returns false otherwise"

	"(#(a 1 2 3) asDataSeries isCategorical) >>> true"

	"(#(0 1 2 3) asDataSeries isCategorical) >>> false"

	"(#(a b c d) asDataSeries isCategorical) >>> true"

	^ self isNumerical not
]

{ #category : #'categorical-numerical' }
DataSeries >> isNumerical [
	"Returns true if all values of the data series are numerical values and returns false otherwise"

	"(#(a 1 2 3) asDataSeries isNumerical) >>> false"

	"(#(0 1 2.2 3) asDataSeries isNumerical) >>> true"

	"((#( I XIV VII XII ) collect: [ :each | each romanNumber ]) asDataSeries isNumerical) >>> true"

	^ forcedIsNumerical ifNil: [
		  (self removeDuplicates copyWithout: nil) allSatisfy: [ :each |
			  each isNumber ] ]
]

{ #category : #testing }
DataSeries >> isSequenceable [
	^ true
]

{ #category : #private }
DataSeries >> keys: anArrayOfKeys [
	| keys |
	keys := anArrayOfKeys asArray deepCopy.
	dictionary := self dictionaryClass newFromKeys: keys andValues: self values.
	orderedKeys := keys
]

{ #category : #accessing }
DataSeries >> last [
	"Answer the last element of the receiver.
	Raise an error if there are not enough elements."

	"(#(a b c d e f g h i j) asDataSeries last) >>> #j"

	^ self atIndex: self size
]

{ #category : #'math functions' }
DataSeries >> log: base [
	"Returns a data series containing the logarithm of each value in the receiver using the specified base."

	"(#(1 2 4 8 16) asDataSeries log: 2) >>> (#(0.0 1.0 2.0 3.0 4.0) asDataSeries)"

	"(#(1 10 100) asDataSeries log: 10) >>> (#(0.0 1.0 2.0) asDataSeries)"

	^ self collect: [ :each | each log: base ]
]

{ #category : #'categorical-numerical' }
DataSeries >> makeCategorical [
	"Converts a data series to a categorical data series"
	
	forcedIsNumerical := false
]

{ #category : #'categorical-numerical' }
DataSeries >> makeNumerical [
	"Converts a data series to a numerical data series"

	forcedIsNumerical := true
]

{ #category : #statistics }
DataSeries >> max [
	"Returns the maximum value of the dataseries without including nils"

	"(#(7 4 20) asDataSeries max) >>> 20"

	^ self removeNils values max
]

{ #category : #statistics }
DataSeries >> median [
	"Returns the median without including nils"

	"(#(7 4 20) asDataSeries median) >>> 7"

	^ self removeNils values median
]

{ #category : #statistics }
DataSeries >> min [
	"Returns the minimum value of the dataseries without including nils"

	"(#(7 4 20) asDataSeries min) >>> 4"

	^ self removeNils values min
]

{ #category : #accessing }
DataSeries >> mode [
	"The mode of a set of values is the value that appears most often. "

	"(#(a j a j e j g j i j) asDataSeries mode) >>> #j"

	"(#(1 2 3 2) asDataSeries mode) >>> 2"

	| valueCounts |
	valueCounts := self valueCounts.
	^ valueCounts keyAtValue: valueCounts max
]

{ #category : #accessing }
DataSeries >> name [
	"Answer the name of the receiver"
	
	^ name
]

{ #category : #accessing }
DataSeries >> name: anObject [
	"Set the name of the receiver to anObject"
	
	name := anObject
]

{ #category : #accessing }
DataSeries >> ninth [
	"Answer the ninth element of the receiver.
	Raise an error if there are not enough elements."

	"(#(a b c d e f g h i j) asDataSeries ninth) >>> #i"

	^ self atIndex: 9
]

{ #category : #statistics }
DataSeries >> quantile: aNumber [
	"A quantile determines how many values in a distribution are above or below a certain limit.
Eg: if the parameter aNumber is 85, a value from the data series is returned which is greater than or equal to 85% of the values in the data series"

	"(#(7 4 20) asDataSeries quantile: 50) >>> 7"

	| sortedSeries index |
	sortedSeries := self withoutNils sorted.

	aNumber = 0 ifTrue: [ ^ sortedSeries first ].

	index := (sortedSeries size * (aNumber / 100)) ceiling.
	^ sortedSeries atIndex: index
]

{ #category : #statistics }
DataSeries >> quartile: aNumber [
	"Quartiles are three values that split sorted data into four parts, each with an equal number of observations.
Eg: if the parameter aNumber is 3, the Third Quartile of the data series is returned"

	"(#(7 4 20) asDataSeries quartile: 3) >>> 20"

	^ self quantile: 25 * aNumber
]

{ #category : #enumerating }
DataSeries >> reject: aBlock [
	| result |
	result := super reject: aBlock.
	result name: self name.
	^ result
]

{ #category : #removing }
DataSeries >> removeAt: aKey [
	"Removes element from the data series with key aKey"

	^ self removeKey: aKey
]

{ #category : #removing }
DataSeries >> removeAtIndex: aNumber [
	"Removes element from the data series with index aNumber"

	^ self removeAt: (self keys at: aNumber)
]

{ #category : #removing }
DataSeries >> removeDuplicates [
	"Answer the unique values of the receiver by removing duplicates"

	"(#(1 2 3 3 2) asDataSeries removeDuplicates) >>> (#(1 2 3))"

	"(#(c d b c d d) asDataSeries removeDuplicates) >>> (#(#c #d #b))"

	^ self asSet asArray
]

{ #category : #removing }
DataSeries >> removeNils [
	"Removes elements with nil values from the data series"

	"(#(nil 1 nil nil 2) asDataSeries removeNils) >>> (DataSeries withKeys: #(2 5) values: #(1 2))"

	"(#(a b 'nil' nil nil nil) asDataSeries removeNils) >>> (#(a b 'nil') asDataSeries)"

	| keysWithNilValues |
	keysWithNilValues := OrderedCollection new.
	self associationsDo: [ :each |
		each value ifNil: [ keysWithNilValues add: each key ] ].
	self removeKeys: keysWithNilValues
]

{ #category : #replacing }
DataSeries >> replaceNilsWith: anObject [
	"Replaces nils inplace with anObject"

	"(#(a 'nil' nil d nil) asDataSeries replaceNilsWith: #b) >>> (#(a 'nil' b d b) asDataSeries)"

	"(#(1 0 nil 3 nil) asDataSeries replaceNilsWith: 7) >>> (#(1 0 7 3 7) asDataSeries)"

	self withIndexDo: [ :ele :index |
		ele ifNil: [ self atIndex: index put: anObject ] ]
]

{ #category : #replacing }
DataSeries >> replaceNilsWithAverage [
	"Replaces nils inplace with average"

	"(#(1 2 nil 3 nil) asDataSeries replaceNilsWithAverage) >>> (#(1 2 2 3 2) asDataSeries)"

	"(#(3 6 2 9 nil) asDataSeries replaceNilsWithAverage) >>> (#(3 6 2 9 5) asDataSeries)"

	| mean |
	mean := (self select: [ :ele | ele isNotNil ]) average.
	self replaceNilsWith: mean
]

{ #category : #replacing }
DataSeries >> replaceNilsWithMedian [
	"Replaces nils inplace with median"

	"(#(1 2 nil 3) asDataSeries replaceNilsWithMedian) >>> (#(1 2 2 3) asDataSeries)"

	"(#(3 7 nil 9 nil) asDataSeries replaceNilsWithMedian) >>> (#(3 7 7 9 7) asDataSeries)"

	| median |
	median := (self select: [ :ele | ele isNotNil ]) median.
	self replaceNilsWith: median
]

{ #category : #replacing }
DataSeries >> replaceNilsWithMode [
	"Replaces nils inplace with mode"

	"(#(1 2 1 3 nil) asDataSeries replaceNilsWithMode) >>> (#(1 2 1 3 1) asDataSeries)"

	"(#(a a a b nil) asDataSeries replaceNilsWithMode) >>> (#(a a a b a) asDataSeries)"

	| mode |
	mode := (self select: [ :ele | ele isNotNil ]) mode.
	self replaceNilsWith: mode
]

{ #category : #replacing }
DataSeries >> replaceNilsWithPreviousValue [
	"Replaces nils inplace with previous non-nil value"

	"(#(nil 2 nil 3 nil) asDataSeries replaceNilsWithPreviousValue) >>> (#(nil 2 2 3 3) asDataSeries)"

	"(#(a nil b c nil) asDataSeries replaceNilsWithPreviousValue) >>> (#(a a b c c) asDataSeries)"

	| value |
	self withIndexDo: [ :ele :index |
		index > 1 ifTrue: [ ele ifNil: [ self atIndex: index put: value ] ].
		value := self atIndex: index ]
]

{ #category : #replacing }
DataSeries >> replaceNilsWithZeros [
	"Replaces nils inplace with zero"

	"(#(1 2 nil 3 nil) asDataSeries replaceNilsWithZeros) >>> (#(1 2 0 3 0) asDataSeries)"

	"(#(a b c d nil) asDataSeries replaceNilsWithZeros) >>> (#(a b c d 0) asDataSeries)"

	self replaceNilsWith: 0
]

{ #category : #accessing }
DataSeries >> second [
	"Answer the second element of the receiver.
	Raise an error if there are not enough elements."

	"(#(a b c d e f g h i j) asDataSeries second) >>> #b"

	^ self atIndex: 2
]

{ #category : #statistics }
DataSeries >> secondQuartile [
	"50% of the values in a set are smaller than or equal to the second Quartile of that set. It is also known as the median"

	"(#(7 4 20) asDataSeries secondQuartile) >>> 7"

	^ self quartile: 2
]

{ #category : #enumerating }
DataSeries >> select: aBlock [
	| result |
	result := super select: aBlock.
	result name: self name.
	^ result
]

{ #category : #accessing }
DataSeries >> seventh [
	"Answer the seventh element of the receiver.
	Raise an error if there are not enough elements."

	"(#(a b c d e f g h i j) asDataSeries seventh) >>> #g"

	^ self atIndex: 7
]

{ #category : #accessing }
DataSeries >> sixth [
	"Answer the sixth element of the receiver.
	Raise an error if there are not enough elements."

	"(#(a b c d e f g h i j) asDataSeries sixth) >>> #f"

	^ self atIndex: 6
]

{ #category : #sorting }
DataSeries >> sort [
	"Arranges a data series in ascending order of its values"

	"(#(a c b) asDataSeries sort) >>> (DataSeries withKeys: #(1 3 2) values: #(a b c))"

	"(#(500 5 37) asDataSeries sort) >>> (DataSeries withKeys: #(2 3 1) values: #(5 37 500))"

	self sort: [ :a :b | a <= b ]
]

{ #category : #sorting }
DataSeries >> sort: aBlock [
	"Arranges a data series by applying aBlock on its values"

	"(#( z aaa cc ) asDataSeries sort: [ :a :b |
		 a asString size < b asString size ])
	>>> (DataSeries withKeys: #( 1 3 2 ) values: #( z cc aaa ))."

	"(#( 500 5 37 ) asDataSeries sort: [ :a :b | a >= b ])
	>>> (DataSeries withKeys: #( 1 3 2 ) values: #( 500 37 5 ))"

	| associationBlock |
	associationBlock := [ :a :b | aBlock value: a value value: b value ].
	self sortAssociations: associationBlock
]

{ #category : #sorting }
DataSeries >> sortAssociations: aBlock [
	| sortedAssociations |
	sortedAssociations := self associations sort: aBlock.
	self removeAll.
	self addAll: sortedAssociations
]

{ #category : #sorting }
DataSeries >> sortDescending [
	"Arranges a data series in descending order of its values"

	"(#(a c b) asDataSeries sortDescending) >>> (DataSeries withKeys: #(2 3 1) values: #(c b a))"

	"(#(500 5 37) asDataSeries sortDescending) >>> (DataSeries withKeys: #(1 3 2) values: #(500 37 5))"

	self sort: [ :a :b | a > b ]
]

{ #category : #sorting }
DataSeries >> sorted [
	"Returns a sorted copy of the data series without rearranging the original data series"

	"(#(a c b) asDataSeries sorted) >>> (DataSeries withKeys: #(1 3 2) values: #(a b c))"

	"(#(500 5 37) asDataSeries sorted) >>> (DataSeries withKeys: #(2 3 1) values: #(5 37 500))"

	^ self sorted: [ :a :b | a <= b ]
]

{ #category : #sorting }
DataSeries >> sorted: aBlock [
	"Returns a copy of the data series after applying aBlock without rearranging the original data series"

	"(#( z aaa cc ) asDataSeries sorted: [ :a :b |
		 a asString size < b asString size ])
	>>> (DataSeries withKeys: #( 1 3 2 ) values: #( z cc aaa ))."

	"(#( 500 5 37 ) asDataSeries sorted: [ :a :b | a >= b ])
	>>> (DataSeries withKeys: #( 1 3 2 ) values: #( 500 37 5 ))"

	| associationBlock |
	associationBlock := [ :a :b | aBlock value: a value value: b value ].
	^ self sortedAssociations: associationBlock
]

{ #category : #sorting }
DataSeries >> sortedAssociations: aBlock [
	| sortedAssociations |
	sortedAssociations := self associations sort: aBlock.
	^ sortedAssociations asDataSeries name: self name; yourself
]

{ #category : #sorting }
DataSeries >> sortedDescending [
	"Returns a sorted copy of the data series in descending order without rearranging the original data series"

	"(#(a c b) asDataSeries sortedDescending) >>> (DataSeries withKeys: #(2 3 1) values: #(c b a))"

	"(#(50 5 37) asDataSeries sortedDescending) >>> (DataSeries withKeys: #(1 3 2) values: #(50 37 5))"

	^ self sorted: [ :a :b | a > b ]
]

{ #category : #statistics }
DataSeries >> stdev [
	"Returns the standard deviation of the dataseries without including nils"

	"(#(10 20 30) asDataSeries stdev) >>> 10"

	^ self removeNils values stdev
]

{ #category : #transformation }
DataSeries >> sum [
	"Return the sum of the values over the requested axis. Nil values are excluded."

	"(#(1 1 1) asDataSeries sum) >>> 3"

	"(#(1 nil 1) asDataSeries sum) >>> 2"

	"(#(1 1.1 1) asDataSeries sum) >>> 3.1"

	| result |
	result := 0.
	self do: [ :each | each ifNotNil: [ result := result + each ] ].
	^ result
]

{ #category : #statistics }
DataSeries >> summary [
	"A data series is returned which is a statistical summary of the data series. 
	With keys as different statistical measures and values as the values returned
	when those statistical measures are applied on the data series."
	
	| summary |
	summary := self species new.
	summary name: self name.

	summary
		at: 'Count' put: self size;
		at: 'Average' put: self average;
		at: 'Stdev' put: self stdev;
		at: 'Min' put: self min;
		at: '25%' put: self firstQuartile;
		at: '50%' put: self median;
		at: '75%' put: self thirdQuartile;
		at: 'Max' put: self max.

	^ summary
]

{ #category : #slicing }
DataSeries >> tail [
	"Returns a data series with last 5 elements of the receiver"

	"(#(a b c d e f) asDataSeries tail) >>> (DataSeries withKeys: #(2 3 4 5 6) values: #(b c d e f) )"

	"(#(1 2 3 4 5 6 7) asDataSeries tail) >>> (DataSeries withKeys: #(3 4 5 6 7) values: #(3 4 5 6 7) )"

	^ self tail: self defaultHeadTailSize
]

{ #category : #slicing }
DataSeries >> tail: aNumber [
	"Returns a data series with last aNumber elements of the receiver"

	"(#(a b c d e f) asDataSeries tail: 3) >>> (DataSeries withKeys: #(4 5 6) values: #(d e f) )"

	"(#(1 2 3 4 5 6 7) asDataSeries tail: 2) >>> (DataSeries withKeys: #(6 7) values: #(6 7) )"

	^ self species
		  withKeys:
		  (self keys copyFrom: self size - aNumber + 1 to: self size)
		  values:
		  (self values copyFrom: self size - aNumber + 1 to: self size)
		  name: self name
]

{ #category : #accessing }
DataSeries >> third [
	"Answer the third element of the receiver.
	Raise an error if there are not enough elements."

	"(#(a b c d e f g h i j) asDataSeries third) >>> #c"

	^ self atIndex: 3
]

{ #category : #statistics }
DataSeries >> thirdQuartile [
	"75% of the values in a set are smaller than or equal to the third Quartile of that set"

	"(#(7 4 20) asDataSeries thirdQuartile) >>> 20"

	^ self quartile: 3
]

{ #category : #accessing }
DataSeries >> uniqueValues [

	self
		deprecated:
		'The name of this method has been changed to removeDuplicates.'
		transformWith:
		'`@receiver uniqueValues' -> '`@receiver removeDuplicates'.
	^ self removeDuplicates
]

{ #category : #statistics }
DataSeries >> valueCounts [
	"Calculates the frequency of each value in the data series and returns a data series in descending order of frequencies"

	"(#(7 20 20) asDataSeries valueCounts) >>> (DataSeries withKeys: #(20 7) values: #(2 1))"

	^ (self groupByUniqueValuesAndAggregateUsing: #size) sortDescending
]

{ #category : #statistics }
DataSeries >> valueFrequencies [
	"Calculates the relative frequency of values in the data series. Relative frequency is the ratio of the number of times a value occurs in a set to the total number of values in the set"

	"(#(7 20 20) asDataSeries valueFrequencies) >>> (DataSeries withKeys: #( 20 7 ) values: {
			(2 / 3). (1 / 3) })"

	| count freq |
	count := self valueCounts.
	freq := count / self size.
	^ freq
]

{ #category : #enumerating }
DataSeries >> with: aCollection collect: twoArgBlock [
	"Collect and return the result of evaluating twoArgBlock with corresponding elements from this series and aCollection."
	| result |
	aCollection size = self size ifFalse: [self errorSizeMismatch].

	result := self species new: self size.
	result name: self name.

	self keys withIndexDo: [ :key :i |
		result at: key put:
		(twoArgBlock
			value: (self at: key)
			value: (aCollection at: i))].
	^ result
]

{ #category : #enumerating }
DataSeries >> withIndexCollect: aBlock [
	| result |
	result := self species newFrom:
		(self associations withIndexCollect: [:each :i |
			each key -> (aBlock value: each value value: i)]).
	result name: self name.
	^ result
]

{ #category : #enumerating }
DataSeries >> withIndexDetect: aBlock [

	^ self withIndexDetect: aBlock ifNone: [ NotFound signal ]
]

{ #category : #enumerating }
DataSeries >> withIndexDetect: aBlock ifNone: exceptionBlock [

	| selectedIndex |

	selectedIndex := (1 to: self size)
		detect: [ :i | aBlock value: (self atIndex: i) value: i ]
		ifNone: [ ^ exceptionBlock value ].

	^ self atIndex: selectedIndex
]

{ #category : #enumerating }
DataSeries >> withIndexDo: aBlock [
	self keys withIndexDo: [ :each :i | aBlock value: (self at: each) value: i ]
]

{ #category : #enumerating }
DataSeries >> withIndexReject: aBlock [
	^ self withIndexSelect: [ :each :i | (aBlock value: each value: i) not ]
]

{ #category : #enumerating }
DataSeries >> withIndexSelect: aBlock [
	| selectedIndices |

	selectedIndices := (1 to: self size) select: [ :i |
		aBlock value: (self atIndex: i) value: i ].

	^ DataSeries
		withKeys: (selectedIndices collect: [ :i | self keys at: i ])
		values: (selectedIndices collect: [ :i | self atIndex: i ])
		name: self name
]

{ #category : #enumerating }
DataSeries >> withKeyCollect: aBlock [
	| result |
	result := self species newFrom:
		(self associations collect: [:each |
			each key -> (aBlock value: each value value: each key)]).
	result name: self name.
	^ result
]

{ #category : #enumerating }
DataSeries >> withKeyDetect: aBlock [

	^ self withKeyDetect: aBlock ifNone: [ NotFound signal ]
]

{ #category : #enumerating }
DataSeries >> withKeyDetect: aBlock ifNone: exceptionBlock [

	| selectedKey |

	selectedKey := self keys
		detect: [ :key | aBlock value: (self at: key) value: key ]
		ifNone: [ ^ exceptionBlock value ].

	^ self at: selectedKey
]

{ #category : #enumerating }
DataSeries >> withKeyDo: aBlock [
	self keysDo: [ :each | aBlock value: (self at: each) value: each ]
]

{ #category : #enumerating }
DataSeries >> withKeyReject: aBlock [
	^ self withKeySelect: [ :each :key | (aBlock value: each value: key) not ]
]

{ #category : #enumerating }
DataSeries >> withKeySelect: aBlock [
	| selectedKeys |

	selectedKeys := self keys select: [ :key |
		aBlock value: (self at: key) value: key ].

	^ DataSeries
		withKeys: selectedKeys
		values: (selectedKeys collect: [ :key | self at: key ])
		name: self name
]

{ #category : #enumerating }
DataSeries >> withSeries: otherDataSeries collect: twoArgBlock [
	"Collect and return the result of evaluating twoArgBlock with corresponding elements from this series and otherDataSeries."
	| result |
	otherDataSeries size = self size ifFalse: [self errorSizeMismatch].
	otherDataSeries keys = self keys ifFalse: [ self errorKeysMismatch ].

	result := self species new: self size.
	result name: self name.

	self keysDo: [ :key |
		result at: key put:
		(twoArgBlock
			value: (self at: key)
			value: (otherDataSeries at: key))].
	^ result
]

{ #category : #private }
DataSeries >> withoutNils [
	"Returns a copy of the data series without the nil values"

	"(#(nil 1 nil nil 2) asDataSeries withoutNils) >>> (DataSeries withKeys: #(2 5) values: #(1 2))"

	"(#(a b 'nil' nil nil nil) asDataSeries withoutNils) >>> (#(a b 'nil') asDataSeries)"

	^ self reject: #isNil
]

{ #category : #statistics }
DataSeries >> zerothQuartile [
	"Zeroth Quartile is the minimum value in a set of values"

	"(#(7 4 20) asDataSeries zerothQuartile) >>> 4"

	^ self quartile: 0
]
