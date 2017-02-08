/**
 * Project. Hangul Clock Desktop Widget for Mac
 * User: MR.LEE(leeshoon1344@gmail.com)
 * Based on uebersicht
 * License GPLv3
 * Original Copyright (c) 2013 Felix Hageloh.
 */

#import <Cocoa/Cocoa.h>

@interface HCWindow : NSWindow

- (id)init;
- (void)loadUrl:(NSURL*)url;
- (void)reload;
- (void)sendToDesktop;
- (void)comeToFront;
- (BOOL)isInFront;
- (void)workspaceChanged;
- (void)wallpaperChanged;

@end
