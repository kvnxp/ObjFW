/*
 * Copyright (c) 2008 - 2009
 *   Jonathan Schleifer <js@webkeks.org>
 *
 * All rights reserved.
 *
 * This file is part of libobjfw. It may be distributed under the terms of the
 * Q Public License 1.0, which can be found in the file LICENSE included in
 * the packaging of this file.
 */

#import "config.h"

#include <stdio.h>
#include <string.h>

#import "OFAutoreleasePool.h"
#import "OFDictionary.h"
#import "OFString.h"
#import "OFExceptions.h"

#define TESTS 10

int
main()
{
	int i = 0;

	OFDictionary *dict = [OFMutableDictionary dictionaryWithHashSize: 16];
	OFIterator *iter = [dict iterator];

	OFAutoreleasePool *pool = [[OFAutoreleasePool alloc] init];
	OFString *key1 = [OFString stringWithCString: "key1"];
	OFString *key2 = [OFString stringWithCString: "key2"];
	OFString *value1 = [OFString stringWithCString: "value1"];
	OFString *value2 = [OFString stringWithCString: "value2"];

	[dict set: key1
	       to: value1];
	[dict set: key2
	       to: value2];
	[pool release];

	i++;
	if (strcmp([[dict get: @"key1"] cString], "value1")) {
		printf("\033[K\033[1;31mTest %d/%d failed!\033[m\n", i, TESTS);
		return 1;
	}

	i++;
	if (strcmp([[dict get: key2] cString], "value2")) {
		printf("\033[K\033[1;31mTest %d/%d failed!\033[m\n", i, TESTS);
		return 1;
	}

	i++;
	if (![[iter nextObject] isEqual: @"key2"] ||
	    ![[iter nextObject] isEqual: @"value2"] ||
	    ![[iter nextObject] isEqual: @"key1"] ||
	    ![[iter nextObject] isEqual: @"value1"]) {
		printf("\033[K\033[1;31mTest %d/%d failed!\033[m\n", i, TESTS);
		return 1;
	}

	i++;
	[dict changeHashSize: 8];
	iter = [dict iterator];
	if (![[iter nextObject] isEqual: @"key1"] ||
	    ![[iter nextObject] isEqual: @"value1"] ||
	    ![[iter nextObject] isEqual: @"key2"] ||
	    ![[iter nextObject] isEqual: @"value2"]) {
		printf("\033[K\033[1;31mTest %d/%d failed!\033[m\n", i, TESTS);
		return 1;
	}

	i++;
	if ([dict averageItemsPerBucket] != 1.0) {
		printf("\033[K\033[1;31mTest %d/%d failed!\033[m\n", i, TESTS);
		return 1;
	}

	i++;
	if ([iter nextObject] != nil) {
		printf("\033[K\033[1;31mTest %d/%d failed!\033[m\n", i, TESTS);
		return 1;
	}

	i++;
	if ([dict get: @"key3"] != nil) {
		printf("\033[K\033[1;31mTest %d/%d failed!\033[m\n", i, TESTS);
		return 1;
	}

	i++;
	[dict release];
	dict = [OFDictionary dictionaryWithKeysAndObjects: @"foo", @"bar",
							    @"baz", @"qux",
							    nil];

	if (![[dict get: @"foo"] isEqual: @"bar"]) {
		printf("\033[K\033[1;31mTest %d/%d failed!\033[m\n", i, TESTS);
		return 1;
	}

	i++;
	if (![[dict get: @"baz"] isEqual: @"qux"]) {
		printf("\033[K\033[1;31mTest %d/%d failed!\033[m\n", i, TESTS);
		return 1;
	}

	i++;
	[dict release];
	dict = [OFDictionary dictionaryWithKey: @"foo"
				     andObject: @"bar"];
	if (![[dict get: @"foo"] isEqual: @"bar"]) {
		printf("\033[K\033[1;31mTest %d/%d failed!\033[m\n", i, TESTS);
		return 1;
	}

	printf("\033[1;32mTests successful: %d/%d\033[0m\n", i, TESTS);

	return 0;
}
