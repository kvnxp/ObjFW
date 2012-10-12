/*
 * Copyright (c) 2008, 2009, 2010, 2011, 2012
 *   Jonathan Schleifer <js@webkeks.org>
 *
 * All rights reserved.
 *
 * This file is part of ObjFW. It may be distributed under the terms of the
 * Q Public License 1.0, which can be found in the file LICENSE.QPL included in
 * the packaging of this file.
 *
 * Alternatively, it may be distributed under the terms of the GNU General
 * Public License, either version 2 or 3, which can be found in the file
 * LICENSE.GPLv2 or LICENSE.GPLv3 respectively included in the packaging of this
 * file.
 */

#ifndef __STDC_LIMIT_MACROS
# define __STDC_LIMIT_MACROS
#endif
#ifndef __STDC_CONSTANT_MACROS
# define __STDC_CONSTANT_MACROS
#endif

#include <stdarg.h>

#import "OFObject.h"
#import "OFCollection.h"
#import "OFEnumerator.h"
#import "OFSerialization.h"
#import "OFJSONRepresentation.h"

@class OFString;

#ifdef OF_HAVE_BLOCKS
typedef void (^of_array_enumeration_block_t)(id object, size_t index,
    BOOL *stop);
typedef BOOL (^of_array_filter_block_t)(id odject, size_t index);
typedef id (^of_array_map_block_t)(id object, size_t index);
typedef id (^of_array_fold_block_t)(id left, id right);
#endif

/**
 * \brief An abstract class for storing objects in an array.
 */
@interface OFArray: OFObject <OFCopying, OFMutableCopying, OFCollection,
    OFSerialization, OFJSONRepresentation>
#ifdef OF_HAVE_PROPERTIES
@property (readonly) size_t count;
#endif

/**
 * \brief Creates a new OFArray.
 *
 * \return A new autoreleased OFArray
 */
+ (instancetype)array;

/**
 * \brief Creates a new OFArray with the specified object.
 *
 * \param object An object
 * \return A new autoreleased OFArray
 */
+ (instancetype)arrayWithObject: (id)object;

/**
 * \brief Creates a new OFArray with the specified objects, terminated by nil.
 *
 * \param firstObject The first object in the array
 * \return A new autoreleased OFArray
 */
+ (instancetype)arrayWithObjects: (id)firstObject, ... OF_SENTINEL;

/**
 * \brief Creates a new OFArray with the objects from the specified array.
 *
 * \param array An array
 * \return A new autoreleased OFArray
 */
+ (instancetype)arrayWithArray: (OFArray*)array;

/**
 * \brief Creates a new OFArray with the objects from the specified C array of
 *	  the specified length.
 *
 * \param objects A C array of objects
 * \param length The length of the C array
 * \return A new autoreleased OFArray
 */
+ (instancetype)arrayWithObjects: (id const*)objects
			   count: (size_t)count;

/**
 * \brief Initializes an OFArray with the specified object.
 *
 * \param object An object
 * \return An initialized OFArray
 */
- initWithObject: (id)object;

/**
 * \brief Initializes an OFArray with the specified objects.
 *
 * \param firstObject The first object
 * \return An initialized OFArray
 */
- initWithObjects: (id)firstObject, ... OF_SENTINEL;

/**
 * \brief Initializes an OFArray with the specified object and a va_list.
 *
 * \param firstObject The first object
 * \param arguments A va_list
 * \return An initialized OFArray
 */
- initWithObject: (id)firstObject
       arguments: (va_list)arguments;

/**
 * \brief Initializes an OFArray with the objects from the specified array.
 *
 * \param array An array
 * \return An initialized OFArray
 */
- initWithArray: (OFArray*)array;

/**
 * \brief Initializes an OFArray with the objects from the specified C array of
 *	  the specified length.
 *
 * \param objects A C array of objects
 * \param length The length of the C array
 * \return An initialized OFArray
 */
- initWithObjects: (id const*)objects
	    count: (size_t)count;

/**
 * \brief Returns a specified object of the array.
 *
 * The returned object is <i>not</i> retained and autoreleased for performance
 * reasons!
 *
 * \param index The number of the object to return
 * \return The specified object of the OFArray
 */
- (id)objectAtIndex: (size_t)index;
- (id)objectAtIndexedSubscript: (size_t)index;

/**
 * \brief Copies the objects at the specified range to the specified buffer.
 *
 * \param buffer The buffer to copy the objects to
 * \param range The range to copy
 */
- (void)getObjects: (__unsafe_unretained id*)buffer
	   inRange: (of_range_t)range;

/**
 * \brief Returns the objects of the array as a C array.
 *
 * \return The objects of the array as a C array
 */
- (id*)objects;

/**
 * \brief Returns the index of the first object that is equivalent to the
 *	  specified object or OF_INVALID_INDEX if it was not found.
 *
 * \param object The object whose index is returned
 * \return The index of the first object equivalent to the specified object
 *	   or OF_INVALID_INDEX if it was not found
 */
- (size_t)indexOfObject: (id)object;

/**
 * \brief Returns the index of the first object that has the same address as the
 *	  specified object or OF_INVALID_INDEX if it was not found.
 *
 * \param object The object whose index is returned
 * \return The index of the first object that has the same aaddress as
 *	   the specified object or OF_INVALID_INDEX if it was not found
 */
- (size_t)indexOfObjectIdenticalTo: (id)object;

/**
 * \brief Checks whether the array contains an object with the specified
 *	  address.
 *
 * \param object The object which is checked for being in the array
 * \return A boolean whether the array contains an object with the specified
 *	   address.
 */
- (BOOL)containsObjectIdenticalTo: (id)object;

/**
 * \brief Returns the first object of the array or nil.
 *
 * The returned object is <i>not</i> retained and autoreleased for performance
 * reasons!
 *
 * \return The first object of the array or nil
 */
- (id)firstObject;

/**
 * \brief Returns the last object of the array or nil.
 *
 * The returned object is <i>not</i> retained and autoreleased for performance
 * reasons!
 *
 * \return The last object of the array or nil
 */
- (id)lastObject;

/**
 * \brief Returns the objects in the specified range as a new OFArray.
 *
 * \param range The range for the subarray
 * \return The subarray as a new autoreleased OFArray
 */
- (OFArray*)objectsInRange: (of_range_t)range;

/**
 * \brief Creates a string by joining all objects of the array.
 *
 * \param separator The string with which the objects should be joined
 * \return A string containing all objects joined by the separator
 */
- (OFString*)componentsJoinedByString: (OFString*)separator;

/**
 * \brief Creates a string by calling the selector on all objects of the array
 *	  and joining the strings returned by calling the selector.
 *
 * \param separator The string with which the objects should be joined
 * \param selector The selector to perform on the objects
 * \return A string containing all objects joined by the separator
 */
- (OFString*)componentsJoinedByString: (OFString*)separator
			usingSelector: (SEL)selector;

/**
 * \brief Performs the specified selector on all objects in the array.
 *
 * \param selector The selector to perform on all objects in the array
 */
- (void)makeObjectsPerformSelector: (SEL)selector;

/**
 * \brief Performs the specified selector on all objects in the array with the
 *	  specified object.
 *
 * \param selector The selector to perform on all objects in the array
 * \param object The object to perform the selector with on all objects in the
 *	      array
 */
- (void)makeObjectsPerformSelector: (SEL)selector
			withObject: (id)object;

/**
 * \brief Returns a sorted copy of the array.
 *
 * \return A sorted copy of the array
 */
- (OFArray*)sortedArray;

/**
 * \brief Returns a copy of the array with the order reversed.
 *
 * \return A copy of the array with the order reversed
 */
- (OFArray*)reversedArray;

/**
 * \brief Creates a new array with the specified object added.
 *
 * \param object The object to add
 * \return A new array with the specified object added
 */
- (OFArray*)arrayByAddingObject: (id)object;

/**
 * \brief Creates a new array with the objects from the specified array added.
 *
 * \param array The array with objects to add
 * \return A new array with the objects from the specified array added
 */
- (OFArray*)arrayByAddingObjectsFromArray: (OFArray*)array;

/**
 * \brief Creates a new array with the specified object removed.
 *
 * \param object The object to remove
 * \return A new array with the specified object removed
 */
- (OFArray*)arrayByRemovingObject: (id)object;

#ifdef OF_HAVE_BLOCKS
/**
 * \brief Executes a block for each object.
 *
 * \param block The block to execute for each object
 */
- (void)enumerateObjectsUsingBlock: (of_array_enumeration_block_t)block;

/**
 * \brief Creates a new array, mapping each object using the specified block.
 *
 * \param block A block which maps an object for each object
 * \return A new, autoreleased OFArray
 */
- (OFArray*)mappedArrayUsingBlock: (of_array_map_block_t)block;

/**
 * \brief Creates a new array, only containing the objects for which the block
 *	  returns YES.
 *
 * \param block A block which determines if the object should be in the new
 *		array
 * \return A new, autoreleased OFArray
 */
- (OFArray*)filteredArrayUsingBlock: (of_array_filter_block_t)block;

/**
 * \brief Folds the array to a single object using the specified block.
 *
 * If the array is empty, it will return nil.
 *
 * If there is only one object in the array, that object will be returned and
 * the block will not be invoked.
 *
 * If there are at least two objects, the block is invoked for each object
 * except the first, where left is always to what the array has already been
 * folded and right what should be added to left.
 *
 * \param block A block which folds two objects into one, which is called for
 *		all objects except the first
 * \return The array folded to a single object
 */
- (id)foldUsingBlock: (of_array_fold_block_t)block;
#endif
@end

@interface OFArrayEnumerator: OFEnumerator
{
	OFArray	      *array;
	size_t	      count;
	unsigned long mutations;
	unsigned long *mutationsPtr;
	size_t	      position;
}

- initWithArray: (OFArray*)data
   mutationsPtr: (unsigned long*)mutationsPtr;
@end

#import "OFMutableArray.h"

#ifndef NSINTEGER_DEFINED
/* Required for array literals to work */
@compatibility_alias NSArray OFArray;
#endif
