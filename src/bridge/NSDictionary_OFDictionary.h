/*
 * Copyright (c) 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017
 *   Jonathan Schleifer <js@heap.zone>
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

#import <Foundation/NSDictionary.h>

@class OFDictionary;

NS_ASSUME_NONNULL_BEGIN

@interface NSDictionary_OFDictionary: NSDictionary
{
	OFDictionary *_dictionary;
}

- (instancetype)initWithOFDictionary: (OFDictionary *)dictionary;
@end

NS_ASSUME_NONNULL_END
