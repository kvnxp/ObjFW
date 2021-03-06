/*
 * Copyright (c) 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017,
 *               2018, 2019, 2020
 *   Jonathan Schleifer <js@nil.im>
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

#import "OFCryptoHash.h"

OF_ASSUME_NONNULL_BEGIN

@class OFSecureData;

/*!
 * @class OFSHA224Or256Hash OFSHA224Or256Hash.h ObjFW/OFSHA224Or256Hash.h
 *
 * @brief A base class for SHA-224 and SHA-256.
 */
@interface OFSHA224Or256Hash: OFObject <OFCryptoHash>
{
@private
	OFSecureData *_iVarsData;
@protected
	struct of_sha224_or_256_hash_ivars {
		uint32_t state[8];
		uint64_t bits;
		union of_sha224_or_256_hash_buffer {
			unsigned char bytes[64];
			uint32_t words[64];
		} buffer;
		size_t bufferLength;
	} *_iVars;
@private
	bool _allowsSwappableMemory;
	bool _calculated;
	OF_RESERVE_IVARS(4)
}
@end

OF_ASSUME_NONNULL_END
