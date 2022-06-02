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
	
	// Check if the directory to write to exists first
	//BOOL isDir;
	//if (!([self fileExistsAtPath:baseFilename isDirectory:&isDir] && isDir)) {
	//	return nil;
	//}
	
	// Turn into FSRef
	FSRef outRef;
	OSStatus err = FSPathMakeRef((const UInt8 *)[baseFilename fileSystemRepresentation], &outRef, NULL);
	if (err != noErr) {
		return nil;
	}
	
	// Get volume ref number
	FSCatalogInfo catalogInfo;
	err = FSGetCatalogInfo(&outRef, kFSCatInfoVolume, &catalogInfo, NULL, NULL, NULL);
	if (err != noErr) {
		return nil;
	}
	
	// Determine the temporary folder, creating it if necesssary
	FSRef foundRef;
	err = FSFindFolder(catalogInfo.volume, kTemporaryFolderType, kCreateFolder, &foundRef);
	// NOTE: This is the most likely place to fail if the directory exists.
	// Some volumes don't have a temporary folder and don't allow its creation
	if (err != noErr) {
		return nil;
	}
	
	// Turn folder reference back to cocoa-land
	NSURL* foundURL = (NSURL*)CFBridgingRelease(CFURLCreateFromFSRef(kCFAllocatorDefault, &foundRef));
	if (foundURL == nil) {
		return nil;
	}
	
	// I got it biotch
	CFStringRef foundString = CFURLCopyFileSystemPath((CFURLRef)foundURL, kCFURLPOSIXPathStyle);
	if (foundString == NULL) {
		return nil;
	}
	
	// done
	return (NSString*)CFBridgingRelease(foundString);
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
	
	CFUUIDRef theUUID = CFUUIDCreate(NULL);
	CFStringRef string = CFUUIDCreateString(NULL, theUUID);
	CFRelease(theUUID);
	return (__bridge NSString *) string;
	
}

@end
