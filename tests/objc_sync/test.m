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

#include "config.h"

#include <stdio.h>

#import "OFString.h"
#import "OFThread.h"

OFObject *lock;

@interface MyThread: OFThread
- main;
@end

@implementation MyThread
- main
{
	printf("[%s] Entering #1\n", [object UTF8String]);
	@synchronized (lock) {
		printf("[%s] Entering #2\n", [object UTF8String]);
		@synchronized (lock) {
			printf("[%s] Hello!\n", [object UTF8String]);
		}
		printf("[%s] Left #2\n", [object UTF8String]);
	}
	printf("[%s] Left #1\n", [object UTF8String]);

	return nil;
}
@end

int
main()
{
	lock = [[OFObject alloc] init];
	MyThread *t1 = [MyThread threadWithObject: @"A"];
	MyThread *t2 = [MyThread threadWithObject: @"B"];

	[t1 start];
	[t2 start];

	[t1 join];
	[t2 join];

	return 0;
}
