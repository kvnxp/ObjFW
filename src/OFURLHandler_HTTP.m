/*
 * Copyright (c) 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017,
 *               2018
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

#include "config.h"

#import "OFURLHandler_HTTP.h"
#import "OFHTTPClient.h"
#import "OFHTTPRequest.h"
#import "OFHTTPResponse.h"

@implementation OFURLHandler_HTTP
- (OFStream *)openItemAtURL: (OFURL *)URL
		       mode: (OFString *)mode
{
	void *pool = objc_autoreleasePoolPush();
	OFHTTPClient *client = [OFHTTPClient client];
	OFHTTPRequest *request = [OFHTTPRequest requestWithURL: URL];
	OFHTTPResponse *response = [client performRequest: request];

	[response retain];

	objc_autoreleasePoolPop(pool);

	return [response autorelease];
}
@end