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

#include <assert.h>

#import "OFLHAArchive.h"
#import "OFLHAArchiveEntry.h"
#import "OFLHAArchiveEntry+Private.h"
#ifdef OF_HAVE_FILES
# import "OFFile.h"
#endif
#import "OFStream.h"
#import "OFSeekableStream.h"
#import "OFString.h"

#import "crc16.h"
#import "huffman_tree.h"

#import "OFChecksumFailedException.h"
#import "OFInvalidArgumentException.h"
#import "OFInvalidFormatException.h"
#import "OFNotImplementedException.h"
#import "OFNotOpenException.h"
#import "OFTruncatedDataException.h"

#define LHSTREAM_BUFFER_SIZE 4096

@interface OFLHAArchive_LHStream: OFStream
{
@public
	OF_KINDOF(OFStream *) _stream;
	uint8_t _distanceBits, _dictionaryBits;
	unsigned char _buffer[LHSTREAM_BUFFER_SIZE];
	uint32_t _bytesConsumed;
	uint16_t _bufferIndex, _bufferLength;
	uint8_t _byte;
	uint8_t _bitIndex, _savedBitsLength;
	uint16_t _savedBits;
	unsigned char *_slidingWindow;
	uint32_t _slidingWindowIndex, _slidingWindowMask;
	int _state;
	uint16_t _symbolsLeft;
	struct of_huffman_tree *_codeLenTree, *_litLenTree, *_distTree;
	struct of_huffman_tree *_treeIter;
	uint16_t _codesCount, _codesReceived;
	bool _currentIsExtendedLength, _skip;
	uint8_t *_codesLengths;
	uint16_t _length;
	uint32_t _distance;
}

- (instancetype)of_initWithStream: (OF_KINDOF(OFStream *))stream
		     distanceBits: (uint8_t)distanceBits
		   dictionaryBits: (uint8_t)dictionaryBits;
@end

@interface OFLHAArchive_FileReadStream: OFStream <OFReadyForReadingObserving>
{
	OF_KINDOF(OFStream *) _stream;
	OF_KINDOF(OFStream *) _decompressedStream;
	OFLHAArchiveEntry *_entry;
	uint32_t _toRead, _bytesConsumed;
	uint16_t _CRC16;
	bool _atEndOfStream;
}

- (instancetype)of_initWithStream: (OF_KINDOF(OFStream *))stream
			    entry: (OFLHAArchiveEntry *)entry;
- (void)of_skip;
@end

enum state {
	STATE_BLOCK_HEADER,
	STATE_CODE_LEN_CODES_COUNT,
	STATE_CODE_LEN_TREE,
	STATE_CODE_LEN_TREE_SINGLE,
	STATE_LITLEN_CODES_COUNT,
	STATE_LITLEN_TREE,
	STATE_LITLEN_TREE_SINGLE,
	STATE_DIST_CODES_COUNT,
	STATE_DIST_TREE,
	STATE_DIST_TREE_SINGLE,
	STATE_BLOCK_LITLEN,
	STATE_BLOCK_DIST_LENGTH,
	STATE_BLOCK_DIST_LENGTH_EXTRA,
	STATE_BLOCK_LEN_DIST_PAIR
};

static bool
tryReadBits(OFLHAArchive_LHStream *stream, uint16_t *bits, uint8_t count)
{
	uint16_t ret = stream->_savedBits;

	assert(stream->_savedBitsLength < count);

	for (uint_fast8_t i = stream->_savedBitsLength; i < count; i++) {
		if OF_UNLIKELY (stream->_bitIndex == 8) {
			if (stream->_bufferIndex < stream->_bufferLength)
				stream->_byte =
				    stream->_buffer[stream->_bufferIndex++];
			else {
				size_t length = [stream->_stream
				    readIntoBuffer: stream->_buffer
					    length: LHSTREAM_BUFFER_SIZE];

				stream->_bytesConsumed += (uint32_t)length;

				if OF_UNLIKELY (length < 1) {
					stream->_savedBits = ret;
					stream->_savedBitsLength = i;
					return false;
				}

				stream->_byte = stream->_buffer[0];
				stream->_bufferIndex = 1;
				stream->_bufferLength = (uint16_t)length;
			}

			stream->_bitIndex = 0;
		}

		ret = (ret << 1) |
		    ((stream->_byte >> (7 - stream->_bitIndex++)) & 1);
	}

	stream->_savedBits = 0;
	stream->_savedBitsLength = 0;
	*bits = ret;

	return true;
}

@implementation OFLHAArchive
@synthesize encoding = _encoding;

+ (instancetype)archiveWithStream: (OF_KINDOF(OFStream *))stream
			     mode: (OFString *)mode
{
	return [[[self alloc] initWithStream: stream
					mode: mode] autorelease];
}

#ifdef OF_HAVE_FILES
+ (instancetype)archiveWithPath: (OFString *)path
			   mode: (OFString *)mode
{
	return [[[self alloc] initWithPath: path
				      mode: mode] autorelease];
}
#endif

- (instancetype)init
{
	OF_INVALID_INIT_METHOD
}

- (instancetype)initWithStream: (OF_KINDOF(OFStream *))stream
			  mode: (OFString *)mode
{
	self = [super init];

	@try {
		if (![mode isEqual: @"r"])
			@throw [OFNotImplementedException
			    exceptionWithSelector: _cmd
					   object: self];

		_stream = [stream retain];
		_encoding = OF_STRING_ENCODING_ISO_8859_1;
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

#ifdef OF_HAVE_FILES
- (instancetype)initWithPath: (OFString *)path
			mode: (OFString *)mode
{
	OFFile *file;

	if ([mode isEqual: @"a"])
		file = [[OFFile alloc] initWithPath: path
					       mode: @"r+"];
	else
		file = [[OFFile alloc] initWithPath: path
					       mode: mode];

	@try {
		self = [self initWithStream: file
				       mode: mode];
	} @finally {
		[file release];
	}

	return self;
}
#endif

- (void)dealloc
{
	[self close];

	[super dealloc];
}

- (OFLHAArchiveEntry *)nextEntry
{
	char header[21];
	size_t headerLen;

	[_lastEntry release];
	_lastEntry = nil;

	[_lastReturnedStream of_skip];
	[_lastReturnedStream close];
	[_lastReturnedStream release];
	_lastReturnedStream = nil;

	for (headerLen = 0; headerLen < 21;) {
		if ([_stream isAtEndOfStream]) {
			if (headerLen == 0)
				return nil;

			if (headerLen == 1 && header[0] == 0)
				return nil;

			@throw [OFTruncatedDataException exception];
		}

		headerLen += [_stream readIntoBuffer: header + headerLen
					      length: 21 - headerLen];
	}

	_lastEntry = [[OFLHAArchiveEntry alloc]
	    of_initWithHeader: header
		       stream: _stream
		     encoding: _encoding];

	_lastReturnedStream = [[OFLHAArchive_FileReadStream alloc]
	    of_initWithStream: _stream
			entry: _lastEntry];

	return [[_lastEntry copy] autorelease];
}

- (OFStream <OFReadyForReadingObserving> *)streamForReadingCurrentEntry
{
	if (_lastReturnedStream == nil)
		@throw [OFInvalidArgumentException exception];

	return [[_lastReturnedStream retain] autorelease];
}

- (void)close
{
	if (_stream == nil)
		return;

	[_lastEntry release];
	_lastEntry = nil;

	[_lastReturnedStream close];
	[_lastReturnedStream release];
	_lastReturnedStream = nil;

	[_stream release];
	_stream = nil;
}
@end

@implementation OFLHAArchive_LHStream
- (instancetype)of_initWithStream: (OF_KINDOF(OFStream *))stream
		     distanceBits: (uint8_t)distanceBits
		   dictionaryBits: (uint8_t)dictionaryBits
{
	self = [super init];

	@try {
		_stream = [stream retain];

		/* 0-7 address the bit, 8 means fetch next byte */
		_bitIndex = 8;

		_distanceBits = distanceBits;
		_dictionaryBits = dictionaryBits;

		_slidingWindowMask = (1 << dictionaryBits) - 1;
		_slidingWindow = [self allocMemoryWithSize:
		    _slidingWindowMask + 1];
		memset(_slidingWindow, ' ', _slidingWindowMask + 1);
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (void)dealloc
{
	[self close];

	if (_codeLenTree != NULL)
		of_huffman_tree_release(_codeLenTree);
	if (_litLenTree != NULL)
		of_huffman_tree_release(_litLenTree);
	if (_distTree != NULL)
		of_huffman_tree_release(_distTree);

	[super dealloc];
}

- (size_t)lowlevelReadIntoBuffer: (void *)buffer_
			  length: (size_t)length
{
	unsigned char *buffer = buffer_;
	uint16_t bits, value;
	size_t bytesWritten = 0;

	if (_stream == nil)
		@throw [OFNotOpenException exceptionWithObject: self];

	if ([_stream isAtEndOfStream] && _bufferLength - _bufferIndex == 0 &&
	    _state == STATE_BLOCK_HEADER)
		return 0;

start:
	switch ((enum state)_state) {
	case STATE_BLOCK_HEADER:
		if OF_UNLIKELY (!tryReadBits(self, &bits, 16))
			return bytesWritten;

		_symbolsLeft = bits;

		_state = STATE_CODE_LEN_CODES_COUNT;
		goto start;
	case STATE_CODE_LEN_CODES_COUNT:
		if OF_UNLIKELY (!tryReadBits(self, &bits, 5))
			return bytesWritten;

		if OF_UNLIKELY (bits > 20)
			@throw [OFInvalidFormatException exception];

		if OF_UNLIKELY (bits == 0) {
			_state = STATE_CODE_LEN_TREE_SINGLE;
			goto start;
		}

		_codesCount = bits;
		_codesReceived = 0;
		_codesLengths = [self allocZeroedMemoryWithSize: bits];
		_skip = true;

		_state = STATE_CODE_LEN_TREE;
		goto start;
	case STATE_CODE_LEN_TREE:
		while (_codesReceived < _codesCount) {
			if OF_UNLIKELY (_currentIsExtendedLength) {
				if OF_UNLIKELY (!tryReadBits(self, &bits, 1))
					return bytesWritten;

				if OF_UNLIKELY (bits == 0) {
					_codesReceived++;
					_currentIsExtendedLength = false;
					continue;
				}

				_codesLengths[_codesReceived]++;
				continue;
			}

			if OF_UNLIKELY (_codesReceived == 3 && _skip) {
				if OF_UNLIKELY (!tryReadBits(self, &bits, 2))
					return bytesWritten;

				if OF_UNLIKELY (_codesReceived + bits >
				    _codesCount)
					@throw [OFInvalidFormatException
					    exception];

				for (uint_fast8_t j = 0; j < bits; j++)
					_codesLengths[_codesReceived++] = 0;

				_skip = false;
				continue;
			}

			if OF_UNLIKELY (!tryReadBits(self, &bits, 3))
				return bytesWritten;

			_codesLengths[_codesReceived] = bits;

			if OF_UNLIKELY (bits == 7) {
				_currentIsExtendedLength = true;
				continue;
			} else
				_codesReceived++;
		}

		_codeLenTree = of_huffman_tree_construct(_codesLengths,
		    _codesCount);
		[self freeMemory: _codesLengths];

		_state = STATE_LITLEN_CODES_COUNT;
		goto start;
	case STATE_CODE_LEN_TREE_SINGLE:
		if OF_UNLIKELY (!tryReadBits(self, &bits, 5))
			return bytesWritten;

		_codeLenTree = of_huffman_tree_construct_single(bits);

		_state = STATE_LITLEN_CODES_COUNT;
		goto start;
	case STATE_LITLEN_CODES_COUNT:
		if OF_UNLIKELY (!tryReadBits(self, &bits, 9))
			return bytesWritten;

		if OF_UNLIKELY (bits > 510)
			@throw [OFInvalidFormatException exception];

		if OF_UNLIKELY (bits == 0) {
			of_huffman_tree_release(_codeLenTree);
			_codeLenTree = NULL;

			_state = STATE_LITLEN_TREE_SINGLE;
			goto start;
		}

		_codesCount = bits;
		_codesReceived = 0;
		_codesLengths = [self allocZeroedMemoryWithSize: bits];
		_skip = false;

		_treeIter = _codeLenTree;
		_state = STATE_LITLEN_TREE;
		goto start;
	case STATE_LITLEN_TREE:
		while (_codesReceived < _codesCount) {
			if OF_UNLIKELY (_skip) {
				uint16_t skipCount;

				switch (_codesLengths[_codesReceived]) {
				case 0:
					skipCount = 1;
					break;
				case 1:
					if OF_UNLIKELY (!tryReadBits(self,
					    &bits, 4))
						return bytesWritten;

					skipCount = bits + 3;
					break;
				case 2:
					if OF_UNLIKELY (!tryReadBits(self,
					    &bits, 9))
						return bytesWritten;

					skipCount = bits + 20;
					break;
				default:
					assert(0);
				}

				if OF_UNLIKELY (_codesReceived + skipCount >
				    _codesCount)
					@throw [OFInvalidFormatException
					    exception];

				for (uint_fast16_t j = 0; j < skipCount; j++)
					_codesLengths[_codesReceived++] = 0;

				_skip = false;
				continue;
			}

			if (!of_huffman_tree_walk(self, tryReadBits,
			    &_treeIter, &value))
				return bytesWritten;

			_treeIter = _codeLenTree;

			if (value < 3) {
				_codesLengths[_codesReceived] = value;
				_skip = true;
			} else
				_codesLengths[_codesReceived++] = value - 2;
		}

		_litLenTree = of_huffman_tree_construct(_codesLengths,
		    _codesCount);
		[self freeMemory: _codesLengths];

		of_huffman_tree_release(_codeLenTree);
		_codeLenTree = NULL;

		_state = STATE_DIST_CODES_COUNT;
		goto start;
	case STATE_LITLEN_TREE_SINGLE:
		if OF_UNLIKELY (!tryReadBits(self, &bits, 9))
			return bytesWritten;

		_litLenTree = of_huffman_tree_construct_single(bits);

		_state = STATE_DIST_CODES_COUNT;
		goto start;
	case STATE_DIST_CODES_COUNT:
		if OF_UNLIKELY (!tryReadBits(self, &bits, _distanceBits))
			return bytesWritten;

		if OF_UNLIKELY (bits > _dictionaryBits)
			@throw [OFInvalidFormatException exception];

		if OF_UNLIKELY (bits == 0) {
			_state = STATE_DIST_TREE_SINGLE;
			goto start;
		}

		_codesCount = bits;
		_codesReceived = 0;
		_codesLengths = [self allocZeroedMemoryWithSize: bits];

		_treeIter = _codeLenTree;
		_state = STATE_DIST_TREE;
		goto start;
	case STATE_DIST_TREE:
		while (_codesReceived < _codesCount) {
			if OF_UNLIKELY (_currentIsExtendedLength) {
				if OF_UNLIKELY (!tryReadBits(self, &bits, 1))
					return bytesWritten;

				if OF_UNLIKELY (bits == 0) {
					_codesReceived++;
					_currentIsExtendedLength = false;
					continue;
				}

				_codesLengths[_codesReceived]++;
				continue;
			}

			if OF_UNLIKELY (!tryReadBits(self, &bits, 3))
				return bytesWritten;

			_codesLengths[_codesReceived] = bits;

			if OF_UNLIKELY (bits == 7) {
				_currentIsExtendedLength = true;
				continue;
			} else
				_codesReceived++;
		}

		_distTree = of_huffman_tree_construct(_codesLengths,
		    _codesCount);
		[self freeMemory: _codesLengths];

		_treeIter = _litLenTree;
		_state = STATE_BLOCK_LITLEN;
		goto start;
	case STATE_DIST_TREE_SINGLE:
		if OF_UNLIKELY (!tryReadBits(self, &bits, _distanceBits))
			return bytesWritten;

		_distTree = of_huffman_tree_construct_single(bits);

		_treeIter = _litLenTree;
		_state = STATE_BLOCK_LITLEN;
		goto start;
	case STATE_BLOCK_LITLEN:
		if OF_UNLIKELY (_symbolsLeft == 0) {
			of_huffman_tree_release(_litLenTree);
			of_huffman_tree_release(_distTree);
			_litLenTree = _distTree = NULL;

			_state = STATE_BLOCK_HEADER;

			/*
			 * We must return here, as there is no indication
			 * whether this was the last block. Whoever called this
			 * method needs to check if everything has been read
			 * already and only call read again if that is not the
			 * case.
			 *
			 * We must also unread the buffer, in case this was the
			 * last block and something else follows, e.g. another
			 * LHA header.
			 */
			[_stream unreadFromBuffer: _buffer + _bufferIndex
					   length: _bufferLength -
						   _bufferIndex];
			_bytesConsumed -= _bufferLength - _bufferIndex;
			_bufferIndex = _bufferLength = 0;

			return bytesWritten;
		}

		if OF_UNLIKELY (length == 0)
			return bytesWritten;

		if OF_UNLIKELY (!of_huffman_tree_walk(self, tryReadBits,
		    &_treeIter, &value))
			return bytesWritten;

		if OF_LIKELY (value < 256) {
			buffer[bytesWritten++] = value;
			length--;

			_slidingWindow[_slidingWindowIndex] = value;
			_slidingWindowIndex = (_slidingWindowIndex + 1) &
			    _slidingWindowMask;

			_symbolsLeft--;
			_treeIter = _litLenTree;
		} else {
			_length = value - 253;
			_treeIter = _distTree;
			_state = STATE_BLOCK_DIST_LENGTH;
		}

		goto start;
	case STATE_BLOCK_DIST_LENGTH:
		if OF_UNLIKELY (!of_huffman_tree_walk(self, tryReadBits,
		    &_treeIter, &value))
			return bytesWritten;

		_distance = value;

		_state = (value < 2
		    ? STATE_BLOCK_LEN_DIST_PAIR
		    : STATE_BLOCK_DIST_LENGTH_EXTRA);
		goto start;
	case STATE_BLOCK_DIST_LENGTH_EXTRA:
		if OF_UNLIKELY (!tryReadBits(self, &bits, _distance - 1))
			return bytesWritten;

		_distance = bits + (1 << (_distance - 1));

		_state = STATE_BLOCK_LEN_DIST_PAIR;
		goto start;
	case STATE_BLOCK_LEN_DIST_PAIR:
		for (uint_fast16_t i = 0; i < _length; i++) {
			uint32_t idx;

			if OF_UNLIKELY (length == 0) {
				_length -= i;
				return bytesWritten;
			}

			idx = (_slidingWindowIndex - _distance - 1) &
			    _slidingWindowMask;
			value = _slidingWindow[idx];

			buffer[bytesWritten++] = value;
			length--;

			_slidingWindow[_slidingWindowIndex] = value;
			_slidingWindowIndex = (_slidingWindowIndex + 1) &
			    _slidingWindowMask;
		}

		_symbolsLeft--;

		_treeIter = _litLenTree;
		_state = STATE_BLOCK_LITLEN;
		goto start;
	}

	OF_UNREACHABLE
}

- (bool)lowlevelIsAtEndOfStream
{
	if (_stream == nil)
		@throw [OFNotOpenException exceptionWithObject: self];

	return ([_stream isAtEndOfStream] &&
	    _bufferLength - _bufferIndex == 0 && _state == STATE_BLOCK_HEADER);
}

- (int)fileDescriptorForReading
{
	return [_stream fileDescriptorForReading];
}

- (bool)hasDataInReadBuffer
{
	return ([super hasDataInReadBuffer] || [_stream hasDataInReadBuffer] ||
	    _bufferLength - _bufferIndex > 0);
}

- (void)close
{
	/* Give back our buffer to the stream, in case it's shared */
	[_stream unreadFromBuffer: _buffer + _bufferIndex
			   length: _bufferLength - _bufferIndex];
	_bytesConsumed -= _bufferLength - _bufferIndex;
	_bufferIndex = _bufferLength = 0;

	[_stream release];
	_stream = nil;

	[super close];
}
@end

@implementation OFLHAArchive_FileReadStream
- (instancetype)of_initWithStream: (OF_KINDOF(OFStream *))stream
			    entry: (OFLHAArchiveEntry *)entry
{
	self = [super init];

	@try {
		OFString *compressionMethod;

		_stream = [stream retain];

		compressionMethod = [entry compressionMethod];

		if ([compressionMethod isEqual: @"-lh4-"] ||
		    [compressionMethod isEqual: @"-lh5-"])
			_decompressedStream = [[OFLHAArchive_LHStream alloc]
			    of_initWithStream: stream
				 distanceBits: 4
			       dictionaryBits: 14];
		else if ([compressionMethod isEqual: @"-lh6-"])
			_decompressedStream = [[OFLHAArchive_LHStream alloc]
			    of_initWithStream: stream
				 distanceBits: 5
			       dictionaryBits: 16];
		else if ([compressionMethod isEqual: @"-lh7-"])
			_decompressedStream = [[OFLHAArchive_LHStream alloc]
			    of_initWithStream: stream
				 distanceBits: 5
			       dictionaryBits: 17];
		else
			_decompressedStream = [stream retain];

		_entry = [entry copy];
		_toRead = [entry uncompressedSize];
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (void)dealloc
{
	[self close];

	[_stream release];
	[_decompressedStream release];
	[_entry release];

	[super dealloc];
}

- (bool)lowlevelIsAtEndOfStream
{
	if (_stream == nil)
		@throw [OFNotOpenException exceptionWithObject: self];

	return _atEndOfStream;
}

- (size_t)lowlevelReadIntoBuffer: (void *)buffer
			  length: (size_t)length
{
	size_t ret;

	if (_stream == nil)
		@throw [OFNotOpenException exceptionWithObject: self];

	if (_atEndOfStream)
		return 0;

	if ([_stream isAtEndOfStream] &&
	    ![_decompressedStream hasDataInReadBuffer])
		@throw [OFTruncatedDataException exception];

	if (length > _toRead)
		length = _toRead;

	ret = [_decompressedStream readIntoBuffer: buffer
					   length: length];

	_toRead -= ret;
	_CRC16 = of_crc16(_CRC16, buffer, ret);

	if (_toRead == 0) {
		_atEndOfStream = true;

		if (_CRC16 != [_entry CRC16])
			@throw [OFChecksumFailedException exception];
	}

	return ret;
}

- (bool)hasDataInReadBuffer
{
	return ([super hasDataInReadBuffer] ||
	    [_decompressedStream hasDataInReadBuffer]);
}

- (int)fileDescriptorForReading
{
	return [_decompressedStream fileDescriptorForReading];
}

- (void)of_skip
{
	OF_KINDOF(OFStream *) stream;
	uint32_t toRead;

	if (_stream == nil || _toRead == 0)
		return;

	stream = _stream;
	toRead = _toRead;

	/*
	 * Get the number of consumed bytes and directly read from the
	 * compressed stream, to make skipping much faster.
	 */
	if ([_decompressedStream isKindOfClass:
	    [OFLHAArchive_LHStream class]]) {
		OFLHAArchive_LHStream *LHStream = _decompressedStream;

		[LHStream close];
		toRead = [_entry compressedSize] - LHStream->_bytesConsumed;

		stream = _stream;
	}

	if ([stream isKindOfClass: [OFSeekableStream class]] &&
	    (sizeof(of_offset_t) > 4 || toRead < INT32_MAX))
		[stream seekToOffset: (of_offset_t)toRead
			      whence: SEEK_CUR];
	else {
		while (toRead > 0) {
			char buffer[512];
			size_t min = toRead;

			if (min > 512)
				min = 512;

			toRead -= [stream readIntoBuffer: buffer
						  length: min];
		}
	}

	_toRead = 0;
}

- (void)close
{
	[self of_skip];

	[_stream release];
	_stream = nil;

	[_decompressedStream release];
	_decompressedStream = nil;

	[super close];
}
@end
