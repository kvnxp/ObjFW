/*
 * Copyright (c) 2008, 2009, 2010, 2011
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

#import "OFObject.h"

@class OFString;

/**
 * \brief A representation of an attribute of an XML element as an object.
 */
@interface OFXMLAttribute: OFObject
{
@public
	OFString *name;
	OFString *ns;
	OFString *stringValue;
}

#ifdef OF_HAVE_PROPERTIES
@property (readonly, retain) OFString *name;
@property (readonly, retain, getter=namespace) OFString *ns;
@property (readonly, retain) OFString *stringValue;
#endif

/**
 * \param name The name of the attribute
 * \param ns The namespace of the attribute
 * \param value The string value of the attribute
 * \return A new autoreleased OFXMLAttribute with the specified parameters
 */
+ attributeWithName: (OFString*)name
	  namespace: (OFString*)ns
	stringValue: (OFString*)value;

/**
 * Initializes an already allocated OFXMLAttribute.
 *
 * \param name The name of the attribute
 * \param ns The namespace of the attribute
 * \param value The string value of the attribute
 * \return An initialized OFXMLAttribute with the specified parameters
 */
- initWithName: (OFString*)name
     namespace: (OFString*)ns
   stringValue: (OFString*)value;

/**
 * \return The name of the attribute as an autoreleased OFString
 */
- (OFString*)name;

/**
 * \return The namespace of the attribute as an autoreleased OFString
 */
- (OFString*)namespace;

/**
 * \return The string value of the attribute as an autoreleased OFString
 */
- (OFString*)stringValue;
@end
