//
//  NSFileManager+Utils.m
//  cam2mac
//
//  Created by Nicolas Bonamy on 11/01/13.
//  Copyright (c) 2013 nabocorp. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NSFileManager+Utils.h"

@implementation NSFileManager (Utils)

- (NSString*) temporaryDirectoryOnSameVolumeThan:(NSString*) baseFilename {
	NSURL* baseURL = [NSURL fileURLWithPath:baseFilename];
	NSURL* directoryURL = baseURL.URLByDeletingLastPathComponent;
	BOOL isDirectory = NO;
	if ([self fileExistsAtPath:directoryURL.path isDirectory:&isDirectory] && isDirectory) {
		return directoryURL.path;
	}
	return nil;
}

- (NSString*) randomFilename {
	return [NSString stringWithFormat:@"%@-%@", [[NSProcessInfo processInfo] processName], [NSFileManager UUIDString]];
}

- (NSString*) temporaryFilename {
	return [NSTemporaryDirectory() stringByAppendingPathComponent:[self randomFilename]];
}

- (NSString*) temporaryFilename:(NSString*) baseFilename {

	NSString* temporaryDirectory = [self temporaryDirectoryOnSameVolumeThan:baseFilename];
	if (temporaryDirectory == nil) {
		return [[self temporaryFilename] stringByAppendingPathExtension:[baseFilename pathExtension]];
	} else {
		return [[temporaryDirectory stringByAppendingPathComponent:[self randomFilename]] stringByAppendingPathExtension:[baseFilename pathExtension]];
	}
	
}

+ (NSString*) temporaryFilename {
	return [[NSFileManager defaultManager] temporaryFilename];
}

+ (NSString*) temporaryFilename:(NSString*) baseFilename {
	return [[NSFileManager defaultManager] temporaryFilename:baseFilename];
}

+ (NSString*) UUIDString {
	return [NSUUID UUID].UUIDString;
}

@end
