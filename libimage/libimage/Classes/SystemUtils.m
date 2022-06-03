//
//  SystemUtils.m
//  cam2mac
//
//  Created by Nicolas Bonamy on 02/01/13.
//  Copyright (c) 2013 nabocorp. All rights reserved.
//

#import "SystemUtils.h"
#import <QuickLook/QuickLook.h>

#define NIL @"nil"
NSMutableDictionary* bundles;

@implementation SystemUtils

+ (NSString*) defaultApplicationForFile:(NSString*) path {
	
	NSURL* appUrl = [[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL:[NSURL fileURLWithPath:path]];
	return (appUrl == nil) ? nil : [appUrl path];
	
}

+ (NSString*) bundlePathForIdentifier:(NSString*) identifier {

	// we do not want to look over and over again for a bundle that does not exist
	// as we cannot store nil in a NSDictionary, we use a dummy value (NIL) instead
	
	NSString* path = [bundles objectForKey:identifier];
	if (path == nil) {
		
		// get the path of the bunder
		path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:identifier];
		if (path == nil) {
			path = NIL;
		}
		
		// store it
		[bundles setObject:path forKey:identifier];
		
	}
	
	// done
	return [path isEqualToString:NIL] ? nil : path;

}

+ (void) openFiles:(NSArray*) files withBundleIdentifier:(NSString*) identifier {
	
	NSMutableArray* urls = [NSMutableArray arrayWithCapacity:[files count]];
	for (NSString* filepath in files) {
		[urls addObject:[NSURL fileURLWithPath:filepath]];
	}

	[[NSWorkspace sharedWorkspace] openURLs:urls
									withAppBundleIdentifier:PHOTOSHOP_BUNDLE_ID
																	options:0
					 additionalEventParamDescriptor:nil
												launchIdentifiers:nil];
	
}

@end
