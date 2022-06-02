//
//  FileUtils.m
//  cam2mac
//
//  Created by Nicolas Bonamy on 26/12/12.
//  Copyright (c) 2013 nabocorp. All rights reserved.
//

#import "NSFileManager+Utils.h"
#import "FileUtils.h"

NSMutableDictionary* iconCache;

@implementation FileUtils

+ (BOOL) isFile:(NSString*) path conformingTo:(CFStringRef) UTType orHasExtensionIn:(NSArray*) extensions {

	// first check UTType
	NSString* type = [[NSWorkspace sharedWorkspace] typeOfFile:path error:nil];
	if (UTTypeConformsTo((__bridge CFStringRef) type, UTType)) {
		return TRUE;
	}
		
	// next check extension
	NSString* extension = [[path pathExtension] lowercaseString];
	if ([extensions containsObject:extension]) {
		return TRUE;
	}

	// done
	return FALSE;
}

+ (BOOL) isImageFile:(NSString*) path {
	
	NSArray* extensions = [NSArray arrayWithObjects:@"jpg", @"jpeg", @"png", @"gif", @"heic", @"tif", @"tiff", nil];
	return [FileUtils isFile:path conformingTo:kUTTypeImage orHasExtensionIn:extensions];
	
}

+ (BOOL) isVideoFile:(NSString*) path {
	
	NSArray* extensions = [NSArray arrayWithObjects:@"mov", @"mp4", @"avi", @"mkv", @"divx", @"ts", @"mts", @"m2ts", nil];
	return [FileUtils isFile:path conformingTo:kUTTypeMovie orHasExtensionIn:extensions];

}

+ (NSImage*) getIcon:(NSString*) path {
	
	// icon cache
	if (iconCache == nil) {
		iconCache = [NSMutableDictionary dictionary];
	}
	
	// the key on dict is different for folders
	NSString* key = path;
	BOOL isDir = FALSE;
	if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir]) {
		if (isDir == FALSE) {
			key = [path pathExtension];
		}
	}
	
	// now check in cache
	NSImage* image = [iconCache valueForKey:key];
	if (image != nil) {
		return image;
	}
			
	// get it
	image = [[NSWorkspace sharedWorkspace] iconForFile:path];
	[iconCache setValue:image forKey:key];
	return image;

}

+ (void) moveItemToTrash:(NSString*) path {
	
	[[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
																							 source:[path stringByDeletingLastPathComponent]
																					destination:@""
																								files:[NSArray arrayWithObject:[path lastPathComponent]]
																									tag:nil];
	
}

+ (NSDate*) getCreationDateForFile:(NSString*) file  {
	NSDictionary* fileAttribs = [[NSFileManager defaultManager] attributesOfItemAtPath:file error:nil];
	return [fileAttribs fileCreationDate];
}

+ (NSDate*) getModificationDateForFile:(NSString*) file  {
	NSDictionary* fileAttribs = [[NSFileManager defaultManager] attributesOfItemAtPath:file error:nil];
	return [fileAttribs fileModificationDate];
}

+ (void) setCreationDate:(NSDate*) creationDate forFile:(NSString*) file {
	NSDictionary *creationDateAttr = [NSDictionary dictionaryWithObjectsAndKeys:creationDate, NSFileCreationDate, nil];
	[[NSFileManager defaultManager] setAttributes:creationDateAttr ofItemAtPath:file error:nil];
}

+ (void) setModificationDate:(NSDate*) modificationDate forFile:(NSString*) file {
	NSDictionary *modificationDateAttr = [NSDictionary dictionaryWithObjectsAndKeys:modificationDate, NSFileModificationDate, nil];
	[[NSFileManager defaultManager] setAttributes:modificationDateAttr ofItemAtPath:file error:nil];
}

+ (BOOL) replaceFile:(NSString*) oldFile withFile:(NSString*) newFile {
	return [FileUtils replaceFile:oldFile withFile:newFile isTemporary:FALSE];
}

+ (BOOL) replaceFile:(NSString*) oldFile withFile:(NSString*) newFile isTemporary:(BOOL) isTemp{
	
	// much needed
	NSFileManager* fileManager = [NSFileManager defaultManager];
	
	// first put oldFile apart
	NSString* tempFile = [fileManager temporaryFilename:oldFile];
	if ([fileManager moveItemAtPath:oldFile toPath:tempFile error:nil] == FALSE) {
		if (isTemp) {
			[fileManager removeItemAtPath:newFile error:nil];
		}
		return FALSE;
	}
	
	// now rename newFile
	if ([fileManager moveItemAtPath:newFile toPath:oldFile error:nil] == FALSE) {
		[fileManager moveItemAtPath:tempFile toPath:oldFile error:nil];
		if (isTemp) {
			[fileManager removeItemAtPath:newFile error:nil];
		}
		return FALSE;
	}
	
	// done
	[fileManager removeItemAtPath:tempFile error:nil];
	return TRUE;
	
}

@end
