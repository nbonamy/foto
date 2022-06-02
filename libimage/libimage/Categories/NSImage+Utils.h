//
//  NSImage+Utils.h
//  cam2mac
//
//  Created by Nicolas Bonamy on 26/12/12.
//  Copyright (c) 2013 nabocorp. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSImage (Utils)

+ (NSImage*) imageFromCGImageRef:(CGImageRef)image;

- (NSImageRep*) largestRepresentation;
- (void) selectLargestRepresentation;

@end
