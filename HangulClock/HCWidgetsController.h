/**
 * Project. Hangul Clock Desktop Widget for Mac
 * User: MR.LEE(leeshoon1344@gmail.com)
 * Based on uebersicht
 * License GPLv3
 * Original Copyright (c) 2013 Felix Hageloh.
 */

#import <Cocoa/Cocoa.h>
@class HCScreensController;
@class HCWidgetsStore;

@interface HCWidgetsController : NSController

- (id)initWithMenu:(NSMenu*)menu
           widgets:(HCWidgetsStore*)theWidgets
           screens:(HCScreensController*)screens;
- (void)render;
- (NSArray*)widgetsForScripting;

@end
